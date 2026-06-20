'use strict';
'require view';
'require fs';
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
	return fs.exec('/usr/share/modem/zinfo.sh').then(function() {
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

function numberValue(value) {
	const match = String(value == null ? '' : value).match(/-?\d+(?:\.\d+)?/);
	return match ? +match[0] : null;
}

function clamp(value, min, max) {
	return Math.max(min, Math.min(max, value));
}

function percentFromRange(value, min, max) {
	if (value == null || isNaN(value))
		return null;
	return Math.round(clamp((value - min) * 100 / (max - min), 0, 100));
}

function gradePercent(value, ranges) {
	if (value == null || isNaN(value))
		return null;

	for (let i = 0; i < ranges.length; i++)
		if (value >= ranges[i][0])
			return ranges[i][1];

	return 0;
}

function compositeSignal(data) {
	const reported = numberValue(data.per);
	if (reported != null)
		return clamp(Math.round(reported), 0, 100);

	const metrics = [
		{ score: gradePercent(numberValue(data.rscp), [ [ -65, 100 ], [ -80, 80 ], [ -90, 60 ], [ -110, 40 ], [ -120, 20 ] ]), weight: 35 },
		{ score: gradePercent(numberValue(data.rsrq), [ [ -8, 100 ], [ -10, 80 ], [ -12, 70 ], [ -15, 50 ], [ -20, 30 ] ]), weight: 35 },
		{ score: gradePercent(numberValue(data.sinr), [ [ 30, 100 ], [ 20, 80 ], [ 13, 60 ], [ 5, 40 ], [ 0, 20 ] ]), weight: 30 }
	].filter(function(metric) {
		return metric.score != null;
	});

	if (!metrics.length)
		return null;

	let sum = 0;
	let weight = 0;
	let floor = 100;

	metrics.forEach(function(metric) {
		sum += metric.score * metric.weight;
		weight += metric.weight;
		floor = Math.min(floor, metric.score);
	});

	return Math.round((floor * 70 + (sum / weight) * 30) / 100);
}

function progressbar(percent, label) {
	const pc = percent == null ? 0 : clamp(Math.round(percent), 0, 100);

	return E('div', {
		'class': 'c8-progress-value',
		'title': percent == null ? _('未知') : '%s (%d%%)'.format(label, pc)
	}, [
		E('div', { 'class': 'cbi-progressbar' }, E('div', {
			'style': 'width:%.2f%%'.format(pc)
		})),
		E('span', { 'class': 'c8-progress-label' }, percent == null ? '-' : label)
	]);
}

function signalRows(data) {
	const composite = compositeSignal(data || {});
	const rows = [
		[ _('综合质量'), composite, composite == null ? '-' : '%d%%'.format(composite) ],
		[ _('RSRP 接收功率'), gradePercent(numberValue(data && data.rscp), [ [ -65, 100 ], [ -80, 80 ], [ -90, 60 ], [ -110, 40 ], [ -120, 20 ] ]), clean(data && data.rscp) ],
		[ _('RSRQ 接收质量'), gradePercent(numberValue(data && data.rsrq), [ [ -8, 100 ], [ -10, 80 ], [ -12, 70 ], [ -15, 50 ], [ -20, 30 ] ]), clean(data && data.rsrq) ],
		[ _('SINR 信噪比'), gradePercent(numberValue(data && data.sinr), [ [ 30, 100 ], [ 20, 80 ], [ 13, 60 ], [ 5, 40 ], [ 0, 20 ] ]), clean(data && data.sinr) ],
		[ _('RSSI 信号强度'), gradePercent(numberValue(data && data.rssi), [ [ -65, 100 ], [ -75, 80 ], [ -85, 60 ], [ -95, 40 ], [ -105, 20 ] ]), clean(data && data.rssi) ]
	];

	return rows.map(function(row) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '28%' }, row[0]),
			E('td', { 'class': 'td left' }, progressbar(row[1], row[2]))
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
		E('div', { 'class': 'cbi-map-descr' }, _('接口存在刷新延迟，部分数据因模组限制可能为空。')),
		E('style', {}, [
			'.c8-progress-value{display:grid;grid-template-columns:minmax(120px,1fr) max-content;align-items:center;gap:.75em;max-width:460px}',
			'.c8-progress-value .cbi-progressbar{min-width:120px}',
			'.c8-progress-label{min-width:4.5em;text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums;color:var(--text-muted,#5f636b)}',
			'@media(max-width:480px){.c8-progress-value{grid-template-columns:1fr}.c8-progress-label{text-align:left;min-width:0}}'
		].join(''))
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
