'use strict';
'require view';
'require fs';
'require poll';
'require ui';
'require uci';

function parseJson(text) {
	try {
		return JSON.parse(text || '{}');
	} catch (e) {
		return { status: 'error', message: e.message, cells: [] };
	}
}

function readScan() {
	return fs.exec('/usr/bin/cellscan.sh', [ 'status' ]).then(function(res) {
		return parseJson(res.stdout);
	}).catch(function(e) {
		return { status: 'error', message: e.message, cells: [] };
	});
}

function statusText(data) {
	const map = {
		idle: _('尚未扫描'),
		running: _('扫描中'),
		busy: _('扫描中'),
		done: _('扫描完成'),
		stopped: _('已停止'),
		timeout: _('扫描超时'),
		error: _('扫描错误')
	};

	return map[data.status] || data.status || '-';
}

function isRunning(data) {
	return data && (data.status === 'running' || data.status === 'busy');
}

function percentValue(value) {
	value = +value || 0;
	return Math.max(0, Math.min(100, value));
}

function formatSeconds(seconds) {
	seconds = Math.max(0, +seconds || 0);

	if (seconds >= 60)
		return _('%d 分 %02d 秒').format(Math.floor(seconds / 60), seconds % 60);

	return _('%d 秒').format(seconds);
}

function progressbar(value) {
	const pc = percentValue(value);

	return E('div', {
		'class': 'cbi-progressbar',
		'title': _('%d%%').format(pc)
	}, E('div', { 'style': 'width:%.2f%%'.format(pc) }));
}

function renderScanState(data) {
	const running = isRunning(data);
	const rows = [
		E('strong', {}, statusText(data)),
		' ',
		E('span', {}, data.message || '')
	];

	if (running) {
		rows.push(
			E('br'),
			progressbar(data.progress),
			E('small', {}, [
				_('预计总耗时：%s；剩余约：%s').format(formatSeconds(data.timeout), formatSeconds(data.remaining)),
				data.phase ? '；' + data.phase : ''
			])
		);
	}

	if (data.detail)
		rows.push(E('br'), E('small', {}, data.detail));

	if (data.last_response)
		rows.push(E('br'), E('small', {}, _('最后响应：%s').format(data.last_response)));

	rows.push(
		E('br'),
		E('small', {}, _('端口：%s；命令：%s；更新时间：%s').format(data.port || '-', data.command || '-', data.updated || '-'))
	);

	return rows;
}

function renderRows(cells) {
	if (!cells || !cells.length)
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td center', 'colspan': 10 }, _('暂无扫描结果'))
		]);

	return cells.map(function(cell) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, cell.mode || '-'),
			E('td', { 'class': 'td left' }, cell.operator || '-'),
			E('td', { 'class': 'td left' }, [ cell.mcc || '-', ' / ', cell.mnc || '-' ]),
			E('td', { 'class': 'td left' }, cell.earfcn || '-'),
			E('td', { 'class': 'td left' }, cell.pci || '-'),
			E('td', { 'class': 'td left' }, cell.rsrp || cell.signal || '-'),
			E('td', { 'class': 'td left' }, cell.rsrq || '-'),
			E('td', { 'class': 'td left' }, cell.band || '-'),
			E('td', { 'class': 'td left' }, [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					click: function() {
						return uci.load('modem').then(function() {
							uci.set('modem', '@ndis[0]', 'earfcn', cell.earfcn || '');
							uci.set('modem', '@ndis[0]', 'cellid', cell.pci || '');
							return uci.save();
						}).then(function() {
							ui.addNotification(null, E('p', [
								_('已填入频点和 PCI，请到模块设置确认后保存并应用。'),
								' ',
								E('a', { href: L.url('admin/modem/settings') }, _('打开模块设置'))
							]));
						});
					}
				}, _('填入锁频'))
			]),
			E('td', { 'class': 'td left' }, cell.raw || '-')
		]);
	});
}

function asRows(rows) {
	return Array.isArray(rows) ? rows : [ rows ];
}

function renderContent(data) {
	data = data || {};
	latestData = data;
	const running = isRunning(data);
	const tableRows = [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th left' }, _('制式')),
			E('th', { 'class': 'th left' }, _('运营商')),
			E('th', { 'class': 'th left' }, _('MCC/MNC')),
			E('th', { 'class': 'th left' }, _('频点')),
			E('th', { 'class': 'th left' }, _('PCI')),
			E('th', { 'class': 'th left' }, _('RSRP')),
			E('th', { 'class': 'th left' }, _('RSRQ')),
			E('th', { 'class': 'th left' }, _('频段')),
			E('th', { 'class': 'th left' }, _('操作')),
			E('th', { 'class': 'th left' }, _('原始数据'))
		])
	].concat(asRows(renderRows(data.cells || [])));

	return E('div', { 'class': 'cbi-map' }, [
		E('h2', _('基站扫描')),
		E('div', { 'class': 'cbi-map-descr' }, _('扫描通常需要 1-3 分钟，页面最多等待约 4 分钟。扫描期间蜂窝数据可能短暂不可用，远程访问可能短暂中断；请在信号稳定时操作。')),
		E('fieldset', { 'class': 'cbi-section' }, [
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('扫描状态')),
				E('div', { 'class': 'cbi-value-field' }, renderScanState(data))
			]),
			E('div', { 'class': 'cbi-page-actions' }, [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					'disabled': running ? 'disabled' : null,
					click: function() {
						if (!confirm(_('基站扫描通常持续 1-3 分钟，页面最多等待约 4 分钟，并可能短暂影响蜂窝数据连接。确定开始扫描？')))
							return Promise.resolve();

						return fs.exec('/usr/bin/cellscan.sh', [ 'start' ]).then(readAndRedraw)
							.catch(function(e) { ui.addNotification(null, E('p', e.message)); });
					}
				}, _('开始扫描')),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-reset',
					'disabled': running ? null : 'disabled',
					click: function() {
						return fs.exec('/usr/bin/cellscan.sh', [ 'stop' ]).then(readAndRedraw)
							.catch(function(e) { ui.addNotification(null, E('p', e.message)); });
					}
				}, _('停止扫描')),
				' ',
				E('button', {
					'class': 'cbi-button',
					click: readAndRedraw
				}, _('刷新结果'))
			]),
			E('table', { 'class': 'table' }, tableRows)
		])
	]);
}

let container;
let latestData;
let lastIdleRefresh = 0;

function readAndRedraw() {
	return readScan().then(function(data) {
		const next = renderContent(data);
		if (container && container.parentNode)
			container.parentNode.replaceChild(next, container);
		container = next;
		return data;
	});
}

return view.extend({
	load: readScan,

	render: function(data) {
		container = renderContent(data);
		poll.add(function() {
			const now = Date.now();
			if (!isRunning(latestData)) {
				if (now - lastIdleRefresh < 10000)
					return Promise.resolve();
				lastIdleRefresh = now;
			}
			return readAndRedraw();
		}, 2);
		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
