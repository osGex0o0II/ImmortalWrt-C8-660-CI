'use strict';
'require view';
'require request';
'require poll';

const sections = [
	{
		title: _('综合信息'),
		fields: [
			[ 'conntype', _('模块型号') ],
			[ 'modem', _('制造商') ],
			[ 'firmware', _('固件版本') ],
			[ 'temper', _('设备温度') ],
			[ 'date', _('更新时间') ]
		]
	},
	{
		title: _('通信模块/SIM卡信息'),
		fields: [
			[ 'simsel', _('卡槽') ],
			[ 'cops', _('运营商') ],
			[ 'imei', _('IMEI') ],
			[ 'imsi', _('IMSI') ],
			[ 'iccid', _('ICCID') ],
			[ 'phone', _('SIM卡号码') ]
		]
	},
	{
		title: _('信号状态'),
		fields: [
			[ 'mode', _('网络类型') ],
			[ 'per', _('信号质量') ],
			[ 'rssi', _('信号强度 RSSI') ],
			[ 'rsrq', _('接收质量 RSRQ') ],
			[ 'rscp', _('接收功率 RSRP') ],
			[ 'sinr', _('信噪比 SINR') ]
		]
	},
	{
		title: _('基站信息'),
		fields: [
			[ 'mcc', _('MCC/MNC') ],
			[ 'lac', _('位置ID LAC') ],
			[ 'cid', _('小区ID Cell ID') ],
			[ 'band', _('频段 Band') ],
			[ 'rfcn', _('频点 EARFCN') ],
			[ 'pci', _('物理小区标识 PCI') ]
		]
	}
];

function readStatus() {
	return request.get(L.url('admin/modem/get_csq')).then(function(res) {
		if (!res.ok)
			throw new Error(_('状态读取失败：HTTP %d').format(res.status));

		return res.json();
	}).catch(function(e) {
		return { error: e.message || String(e) };
	});
}

function clean(value) {
	value = String(value == null ? '' : value).replace(/\r/g, '').trim();
	return value || '-';
}

function renderTable(data, fields) {
	return E('table', { 'class': 'table' }, fields.map(function(field) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '28%' }, field[1]),
			E('td', { 'class': 'td left' }, clean(data[field[0]]))
		]);
	}));
}

function renderSections(data) {
	const children = [
		E('h2', _('信号状态')),
		E('div', { 'class': 'cbi-map-descr' }, _('接口存在刷新延迟，部分数据因模组限制可能为空。'))
	];

	if (data && data.error)
		children.push(E('div', { 'class': 'alert-message warning' }, data.error));

	sections.forEach(function(section) {
		children.push(E('fieldset', { 'class': 'cbi-section' }, [
			E('legend', {}, section.title),
			renderTable(data || {}, section.fields)
		]));
	});

	return E('div', { 'class': 'cbi-map' }, children);
}

return view.extend({
	load: readStatus,

	render: function(data) {
		let container = renderSections(data);
		poll.add(function() {
			return readStatus().then(function(next) {
				const nextContainer = renderSections(next);
				container.parentNode.replaceChild(nextContainer, container);
				container = nextContainer;
			});
		}, 30);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
