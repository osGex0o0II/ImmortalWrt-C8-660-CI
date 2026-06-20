'use strict';
'require view';
'require fs';
'require poll';

const statusFields = [
	_('模块'), _('制造商'), _('固件版本'), _('设备温度'), _('更新时间'),
	_('卡槽'), _('运营商'), _('IMEI'), _('IMSI'), _('ICCID'), _('SIM卡号码'),
	_('网络类型'), _('信号质量'), _('信号强度 RSSI'), _('接收质量 RSRQ'),
	_('接收功率 RSRP'), _('信噪比 SINR'),
	_('MCC/MNC'), _('位置ID LAC'), _('小区ID Cell ID'), _('频段 Band'),
	_('频点 EARFCN'), _('物理小区标识 PCI')
];

function readStatus() {
	return fs.exec('/usr/share/modem/zinfo.sh').catch(function() {}).then(function() {
		return fs.read('/tmp/cpe_cell.file').catch(function() { return ''; });
	}).then(function(text) {
		const lines = (text || '').split(/\r?\n/);
		return statusFields.map(function(label, index) {
			return [ label, lines[index] || '-' ];
		});
	});
}

function renderTable(rows) {
	return E('table', { 'class': 'table' }, rows.map(function(row) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '33%' }, row[0]),
			E('td', { 'class': 'td left' }, row[1])
		]);
	}));
}

return view.extend({
	load: readStatus,

	render: function(rows) {
		let table = renderTable(rows);
		poll.add(function() {
			return readStatus().then(function(next) {
				const nextTable = renderTable(next);
				table.parentNode.replaceChild(nextTable, table);
				table = nextTable;
			});
		}, 30);

		return E([
			E('h2', _('信号状态')),
			E('div', { 'class': 'cbi-map-descr' }, _('接口存在刷新延迟，部分数据因模组限制可能为空。')),
			table
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
