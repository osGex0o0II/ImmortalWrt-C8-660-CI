'use strict';
'require view';
'require fs';
'require uci';
'require ui';

function parseStatus(text, storage) {
	const match = String(text || '').match(/Storage type:\s*([^,\s]+),\s*used:\s*(\d+),\s*total:\s*(\d+)/);

	return {
		storage: match ? match[1] : storage,
		used: match ? +match[2] : 0,
		total: match ? +match[3] : 0
	};
}

function smsConfig() {
	return uci.load('sms_tool').then(function() {
		return {
			storage: uci.get('sms_tool', 'general', 'storage') || 'ME',
			port: uci.get('sms_tool', 'general', 'readport') || '/dev/ttyUSB2'
		};
	});
}

function readMessages() {
	return smsConfig().then(function(cfg) {
		return Promise.all([
			fs.exec('/usr/bin/sms_tool', [ '-s', cfg.storage, '-d', cfg.port, 'status' ]),
			fs.exec('/usr/bin/sms_tool', [ '-s', cfg.storage, '-d', cfg.port, '-f', '%Y-%m-%d %H:%M', '-j', 'recv' ])
		]).then(function(res) {
			let parsed = {};
			try {
				parsed = JSON.parse(res[1].stdout || '{}');
			} catch (e) {
				parsed = {};
			}

			let messages = parsed.msg || parsed.messages || parsed;
			if (!Array.isArray(messages))
				messages = [];

			return {
				ok: true,
				status: parseStatus(res[0].stdout, cfg.storage),
				messages: messages
			};
		});
	});
}

function messageIndex(msg) {
	if (msg && msg.index != null)
		return msg.index;
	if (msg && msg.id != null)
		return msg.id;
	if (msg && msg.slot != null)
		return msg.slot;
	return '';
}

function smsIndexes(value) {
	const seen = {};
	const indexes = [];

	String(value || '').replace(/\d+/g, function(index) {
		index = String(+index);
		if (!seen[index]) {
			seen[index] = true;
			indexes.push(index);
		}
	});

	return indexes;
}

function normalizeMessages(messages) {
	return (Array.isArray(messages) ? messages : []).map(function(msg) {
		const index = smsIndexes(messageIndex(msg)).join(',');

		return {
			index: index,
			sender: msg.sender || '-',
			timestamp: msg.timestamp || msg.date || msg.time || '-',
			reference: msg.reference || msg.ref || '',
			part: +msg.part || 1,
			total: +msg.total || 1,
			content: msg.content || msg.text || msg.message || ''
		};
	}).sort(function(a, b) {
		return (+smsIndexes(b.index)[0] || 0) - (+smsIndexes(a.index)[0] || 0);
	});
}

function mergeMessages(messages, direction) {
	const groups = {};

	messages.forEach(function(msg) {
		const key = msg.total > 1
			? [ msg.sender, msg.timestamp, msg.reference, msg.total ].join('|')
			: [ msg.sender, msg.timestamp, msg.index ].join('|');

		if (!groups[key])
			groups[key] = {
				index: [],
				sender: msg.sender,
				timestamp: msg.timestamp,
				content: [],
				parts: 0
			};

		groups[key].index = groups[key].index.concat(smsIndexes(msg.index));
		groups[key].content[msg.part - 1] = msg.content;
		groups[key].parts = Math.max(groups[key].parts, msg.total);
	});

	return Object.keys(groups).map(function(key) {
		const item = groups[key];
		const parts = item.content.filter(function(v) { return v != null; });

		if (direction === 'End')
			parts.reverse();

		return {
			index: item.index.join(','),
			sender: item.sender,
			timestamp: item.timestamp,
			content: parts.join(''),
			parts: item.parts
		};
	}).sort(function(a, b) {
		return (+smsIndexes(b.index)[0] || 0) - (+smsIndexes(a.index)[0] || 0);
	});
}

function statusNodes(status, shown, raw) {
	const used = +(status && status.used) || 0;
	const total = +(status && status.total) || 0;
	const remain = Math.max(total - used, 0);
	const storage = status && status.storage ? status.storage : '-';

	return E('div', { 'class': 'sms-stats' }, [
		E('span', {}, _('存储 %s：已用 %d / 上限 %d / 剩余 %d').format(storage, used, total, remain)),
		E('br'),
		E('span', {}, _('当前显示：%d 条；原始短信：%d 条').format(shown, raw))
	]);
}

function asRows(rows) {
	return Array.isArray(rows) ? rows : [ rows ];
}

return view.extend({
	load: function() {
		return Promise.all([
			readMessages(),
			uci.load('sms_tool')
		]).then(function(data) {
			return data[0];
		}).catch(function(e) {
			ui.addNotification(null, E('p', e.message));
			return { ok: false, status: {}, messages: [] };
		});
	},

	render: function(data) {
		let messages = normalizeMessages(data.messages);
		let merged = uci.get('sms_tool', 'general', 'mergesms') !== '0';
		let direction = uci.get('sms_tool', 'general', 'direction') || 'Start';
		let selected = {};
		let container;

		function visibleMessages() {
			return merged ? mergeMessages(messages, direction) : messages;
		}

		function renderRows(rows) {
			if (!rows.length)
				return E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td center', 'colspan': 5 }, _('暂无短信'))
				]);

			return rows.map(function(msg) {
				const indexes = smsIndexes(msg.index).join(',');

				return E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'style': 'width:48px' }, E('input', {
						type: 'checkbox',
						value: indexes,
						checked: selected[indexes] ? 'checked' : null,
						change: function(ev) {
							selected[indexes] = ev.target.checked;
						}
					})),
					E('td', { 'class': 'td left', 'style': 'width:12%' }, indexes || '-'),
					E('td', { 'class': 'td left', 'style': 'width:16%' }, msg.sender),
					E('td', { 'class': 'td left', 'style': 'width:18%' }, msg.timestamp),
					E('td', { 'class': 'td left' }, [
						msg.parts > 1 ? E('span', { 'class': 'ifacebadge' }, _('合并 %d 段').format(msg.parts)) : '',
						msg.parts > 1 ? ' ' : '',
						msg.content || '-'
					])
				]);
			});
		}

		function renderContent() {
			const rows = visibleMessages();
			const tableRows = [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th left' }, ''),
					E('th', { 'class': 'th left' }, _('索引')),
					E('th', { 'class': 'th left' }, _('发件人')),
					E('th', { 'class': 'th left' }, _('接收时间')),
					E('th', { 'class': 'th left' }, _('内容'))
				])
			].concat(asRows(renderRows(rows)));

			return E('div', { 'class': 'cbi-map' }, [
				E('h2', _('短信接收')),
				E('fieldset', { 'class': 'cbi-section' }, [
					E('div', { 'class': 'cbi-value' }, [
						E('label', { 'class': 'cbi-value-title' }, _('短信统计')),
						E('div', { 'class': 'cbi-value-field' }, statusNodes(data.status, rows.length, messages.length))
					]),
					E('div', { 'class': 'cbi-page-actions' }, [
						E('button', {
							'class': 'cbi-button cbi-button-apply',
							click: refresh
						}, _('刷新')),
						' ',
						E('button', {
							'class': 'cbi-button',
							click: function() {
								merged = !merged;
								selected = {};
								redraw();
							}
						}, merged ? _('显示原始分段') : _('合并分段显示')),
						' ',
						E('button', {
							'class': 'cbi-button cbi-button-reset',
							click: deleteSelected
						}, _('删除选中'))
					]),
					E('table', { 'class': 'table' }, tableRows)
				])
			]);
		}

		function redraw() {
			const next = renderContent();
			container.parentNode.replaceChild(next, container);
			container = next;
		}

		function refresh() {
			return readMessages().then(function(next) {
				data = next;
				messages = normalizeMessages(next.messages);
				selected = {};
				redraw();
			});
		}

		function deleteSelected() {
			const indexes = smsIndexes(Object.keys(selected).filter(function(k) {
				return selected[k];
			}).join(',')).join(',');

			if (!indexes) {
				ui.addNotification(null, E('p', _('请选择要删除的短信')));
				return Promise.resolve();
			}

			if (!confirm(_('删除选中的短信？')))
				return Promise.resolve();

			return smsConfig().then(function(cfg) {
				let chain = Promise.resolve();
				smsIndexes(indexes).forEach(function(index) {
					chain = chain.then(function() {
						return fs.exec('/usr/bin/sms_tool', [ '-s', cfg.storage, '-d', cfg.port, 'delete', index ]);
					});
				});
				return chain;
			}).then(refresh).catch(function(e) {
				ui.addNotification(null, E('p', e.message));
			});
		}

		container = renderContent();
		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
