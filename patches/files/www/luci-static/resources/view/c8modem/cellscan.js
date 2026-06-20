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

function renderRows(cells) {
	if (!cells || !cells.length)
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td center', 'colspan': 8 }, _('暂无扫描结果'))
		]);

	return cells.map(function(cell) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, cell.mode || '-'),
			E('td', { 'class': 'td left' }, cell.operator || '-'),
			E('td', { 'class': 'td left' }, [ cell.mcc || '-', ' / ', cell.mnc || '-' ]),
			E('td', { 'class': 'td left' }, cell.earfcn || '-'),
			E('td', { 'class': 'td left' }, cell.pci || '-'),
			E('td', { 'class': 'td left' }, cell.signal || '-'),
			E('td', { 'class': 'td left' }, [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					click: function() {
						return uci.load('modem').then(function() {
							uci.set('modem', '@ndis[0]', 'earfcn', cell.earfcn || '');
							uci.set('modem', '@ndis[0]', 'cellid', cell.pci || '');
							return uci.save();
						}).then(function() {
							ui.addNotification(null, E('p', _('已写入频点和PCI，请到模块设置确认并应用。')));
						});
					}
				}, _('填入锁频'))
			]),
			E('td', { 'class': 'td left' }, cell.raw || '-')
		]);
	});
}

function renderContent(data) {
	data = data || {};

	return E('div', { 'class': 'cbi-map' }, [
		E('h2', _('基站扫描')),
		E('fieldset', { 'class': 'cbi-section' }, [
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('扫描状态')),
				E('div', { 'class': 'cbi-value-field' }, [
					E('strong', {}, statusText(data)),
					' ',
					E('span', {}, data.message || ''),
					E('br'),
					E('small', {}, _('端口：%s；更新时间：%s').format(data.port || '-', data.updated || '-'))
				])
			]),
			E('div', { 'class': 'cbi-page-actions' }, [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					click: function() {
						return fs.exec('/usr/bin/cellscan.sh', [ 'start' ]).then(readAndRedraw)
							.catch(function(e) { ui.addNotification(null, E('p', e.message)); });
					}
				}, _('开始扫描')),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-reset',
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
			E('table', { 'class': 'table' }, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th left' }, _('制式')),
					E('th', { 'class': 'th left' }, _('运营商')),
					E('th', { 'class': 'th left' }, _('MCC/MNC')),
					E('th', { 'class': 'th left' }, _('频点')),
					E('th', { 'class': 'th left' }, _('PCI')),
					E('th', { 'class': 'th left' }, _('信号')),
					E('th', { 'class': 'th left' }, _('操作')),
					E('th', { 'class': 'th left' }, _('原始数据'))
				]),
				renderRows(data.cells || [])
			])
		])
	]);
}

let container;

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
			return readAndRedraw();
		}, 5);
		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
