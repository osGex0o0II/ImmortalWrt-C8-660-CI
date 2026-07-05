'use strict';
'require view';
'require fs';
'require poll';

const STATUS_EXEC_TIMEOUT = 15000;

function execWithTimeout(cmd, args, timeout, label) {
	let timer;

	return Promise.race([
		fs.exec(cmd, args || []).then(function(res) {
			clearTimeout(timer);
			return res;
		}, function(err) {
			clearTimeout(timer);
			throw err;
		}),
		new Promise(function(resolve, reject) {
			timer = setTimeout(function() {
				reject(new Error(_('%s 执行超时，请确认模组 AT 响应正常。').format(label)));
			}, timeout);
		})
	]);
}

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
	return execWithTimeout('/usr/share/modem/zinfo.sh', [], STATUS_EXEC_TIMEOUT, _('蜂窝状态读取')).then(function() {
		return fs.read('/tmp/cpe_cell.file');
	}).then(function(text) {
		const lines = String(text || '').replace(/\r/g, '').split('\n');
		const keys = [
			'modem', 'conntype', 'firmware', 'temper', 'date',
			'simsel', 'cops', 'imei', 'imsi', 'iccid', 'phone',
			'mode', 'per', 'rssi', 'rsrq', 'rscp', 'sinr',
			'mcc', 'lac', 'cid', 'band', 'rfcn', 'pci'
		];
		const rv = {};

		keys.forEach(function(key, index) {
			rv[key] = lines[index] || '';
		});

		return rv;
	}).catch(function(e) {
		return { error: e.message || String(e) };
	});
}

function clean(value) {
	value = String(value == null ? '' : value).replace(/\r/g, '').trim();
	return value || '-';
}

function signalRows(data) {
	const rows = [
		[ _('综合质量'), clean(data && data.per) ],
		[ _('RSRP 接收功率'), clean(data && data.rscp) ],
		[ _('RSRQ 接收质量'), clean(data && data.rsrq) ],
		[ _('SINR 信噪比'), clean(data && data.sinr) ],
		[ _('RSSI 信号强度'), clean(data && data.rssi) ]
	];

	return rows.map(function(row) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '28%' }, row[0]),
			E('td', { 'class': 'td left' }, row[1])
		]);
	});
}

function renderSignalSection(data) {
	return E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '28%' }, _('网络类型')),
			E('td', { 'class': 'td left' }, clean(data && data.mode))
		])
	].concat(signalRows(data || {})));
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
		if (section.title === _('信号状态')) {
			children.push(E('fieldset', { 'class': 'cbi-section c8-signal-section' }, [
				E('legend', {}, section.title),
				renderSignalSection(data || {})
			]));
			return;
		}

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
