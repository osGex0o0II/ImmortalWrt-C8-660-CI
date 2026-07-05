'use strict';
'require view';
'require fs';
'require uci';
'require ui';

const SMS_EXEC_TIMEOUT = 15000;

function execWithTimeout(cmd, args, timeout, label) {
	let timer;

	return Promise.race([
		fs.exec(cmd, args).then(function(res) {
			clearTimeout(timer);
			return res;
		}, function(err) {
			clearTimeout(timer);
			throw err;
		}),
		new Promise(function(resolve, reject) {
			timer = setTimeout(function() {
				reject(new Error(_('%s 执行超时，请确认 SIM 卡、短信端口和模组 AT 响应正常。').format(label)));
			}, timeout);
		})
	]);
}

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
			execWithTimeout('/usr/bin/sms_tool', [ '-s', cfg.storage, '-d', cfg.port, 'status' ], SMS_EXEC_TIMEOUT, _('短信状态读取')),
			execWithTimeout('/usr/bin/sms_tool', [ '-s', cfg.storage, '-d', cfg.port, '-f', '%Y-%m-%d %H:%M', '-j', 'recv' ], SMS_EXEC_TIMEOUT, _('短信列表读取'))
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

	String(value == null ? '' : value).replace(/\d+/g, function(index) {
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

function sortedIndexes(value, desc) {
	return smsIndexes(value).sort(function(a, b) {
		return desc ? (+b - +a) : (+a - +b);
	});
}

function mergeMessages(messages, direction) {
	const groups = {};

	messages.forEach(function(msg) {
		const expected = Math.max(+msg.total || 1, 1);
		const part = Math.max(+msg.part || 1, 1);
		const key = msg.total > 1
			? [ msg.sender, msg.timestamp, msg.reference, expected ].join('|')
			: [ msg.sender, msg.timestamp, msg.index ].join('|');

		if (!groups[key])
			groups[key] = {
				index: [],
				sender: msg.sender,
				timestamp: msg.timestamp,
				content: {},
				received: {},
				parts: expected
			};

		groups[key].index = groups[key].index.concat(smsIndexes(msg.index));
		groups[key].content[part] = msg.content;
		groups[key].received[part] = true;
		groups[key].parts = Math.max(groups[key].parts, expected);
	});

	return Object.keys(groups).map(function(key) {
		const item = groups[key];
		const parts = [];
		const indexes = sortedIndexes(item.index.join(','));
		const received = Object.keys(item.received).length;

		for (let i = 1; i <= item.parts; i++)
			if (item.content[i] != null)
				parts.push(item.content[i]);

		if (direction === 'End')
			parts.reverse();

		return {
			index: indexes.join(','),
			sender: item.sender,
			timestamp: item.timestamp,
			content: parts.join(''),
			parts: item.parts,
			received: received,
			complete: received >= item.parts,
			sortIndex: indexes.length ? +indexes[indexes.length - 1] : -1
		};
	}).sort(function(a, b) {
		return b.sortIndex - a.sortIndex;
	});
}

function statusNodes(shown) {
	return E('div', { 'class': 'sms-stats' },
		E('span', {}, _('收件箱：%d 条短信').format(shown)));
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
			return { ok: false, error: e.message, status: {}, messages: [] };
		});
	},

	render: function(data) {
		let messages = normalizeMessages(data.messages);
		let selected = {};
		let container;

		function visibleMessages() {
			return mergeMessages(messages, 'Start');
		}

		function allSelected(rows) {
			return rows.length > 0 && rows.every(function(msg) {
				return selected[smsIndexes(msg.index).join(',')];
			});
		}

		function renderRows(rows) {
			if (!rows.length)
				return E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td center', 'colspan': 4 }, _('暂无短信'))
				]);

			return rows.map(function(msg) {
				const indexes = smsIndexes(msg.index).join(',');
				let badge = '';

				if (msg.complete === false)
					badge = E('span', { 'class': 'ifacebadge' }, _('内容未完整接收'));

				return E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'style': 'width:48px' }, E('input', {
						type: 'checkbox',
						value: indexes,
						checked: selected[indexes] ? 'checked' : null,
						change: function(ev) {
							selected[indexes] = ev.target.checked;
						}
					})),
					E('td', { 'class': 'td left', 'style': 'width:16%' }, msg.sender),
					E('td', { 'class': 'td left', 'style': 'width:18%' }, msg.timestamp),
					E('td', { 'class': 'td left' }, [
						badge,
						badge ? ' ' : '',
						msg.content || '-'
					])
				]);
			});
		}

		function renderContent() {
			const rows = visibleMessages();
			const checkedAll = allSelected(rows);
			const tableRows = [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th left' }, ''),
					E('th', { 'class': 'th left' }, _('发件人')),
					E('th', { 'class': 'th left' }, _('接收时间')),
					E('th', { 'class': 'th left' }, _('内容'))
				])
			].concat(asRows(renderRows(rows)));

			return E('div', { 'class': 'cbi-map' }, [
				E('h2', _('短信接收')),
				E('fieldset', { 'class': 'cbi-section' }, [
					data.ok === false ? E('div', { 'class': 'cbi-section-descr alert-message warning' }, data.error || _('短信读取失败')) : '',
					E('div', { 'class': 'cbi-value' }, [
						E('label', { 'class': 'cbi-value-title' }, _('短信统计')),
						E('div', { 'class': 'cbi-value-field' }, statusNodes(rows.length))
					]),
					E('div', { 'class': 'cbi-page-actions' }, [
						E('button', {
							'class': 'cbi-button cbi-button-apply',
							click: refresh
						}, _('刷新')),
						' ',
						E('button', {
							'class': 'cbi-button cbi-button-neutral',
							'disabled': rows.length ? null : 'disabled',
							click: function() {
								return toggleSelectAll(rows, checkedAll);
							}
						}, checkedAll ? _('取消全选') : _('全选')),
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

		function toggleSelectAll(rows, checkedAll) {
			selected = {};

			if (!checkedAll)
				rows.forEach(function(msg) {
					const indexes = smsIndexes(msg.index).join(',');
					if (indexes)
						selected[indexes] = true;
				});

			redraw();
			return Promise.resolve();
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
				sortedIndexes(indexes, true).forEach(function(index) {
					chain = chain.then(function() {
						return execWithTimeout('/usr/bin/sms_tool', [ '-s', cfg.storage, '-d', cfg.port, 'delete', index ], SMS_EXEC_TIMEOUT, _('删除短信'));
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
