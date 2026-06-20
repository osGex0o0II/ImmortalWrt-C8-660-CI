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

function metricQuality(kind, raw) {
	const value = numberValue(raw);
	let percent = null;

	if (kind === 'percent')
		percent = value == null ? null : clamp(Math.round(value), 0, 100);
	else if (kind === 'rsrp')
		percent = percentFromRange(value, -120, -70);
	else if (kind === 'rsrq')
		percent = percentFromRange(value, -20, -3);
	else if (kind === 'sinr')
		percent = percentFromRange(value, 0, 30);
	else if (kind === 'rssi')
		percent = percentFromRange(value, -95, -50);

	if (percent == null)
		return { value: value, percent: null, label: _('未知'), tone: 'unknown' };

	let label = _('较弱');
	let tone = 'bad';

	if (percent >= 80) {
		label = _('优秀');
		tone = 'great';
	} else if (percent >= 60) {
		label = _('良好');
		tone = 'good';
	} else if (percent >= 40) {
		label = _('一般');
		tone = 'fair';
	}

	return {
		value: value,
		percent: percent,
		label: label,
		tone: tone
	};
}

function qualityBar(title, raw, kind, hint) {
	const q = metricQuality(kind, raw);
	const width = q.percent == null ? 0 : q.percent;

	return E('div', { 'class': 'c8-signal-meter c8-signal-meter-' + q.tone }, [
		E('div', { 'class': 'c8-signal-meter-head' }, [
			E('span', { 'class': 'c8-signal-meter-title' }, title),
			E('span', { 'class': 'c8-signal-meter-value' }, [
				clean(raw),
				q.percent == null ? '' : ' / %d%%'.format(q.percent),
				' · ',
				q.label
			])
		]),
		E('div', { 'class': 'c8-signal-track', 'title': hint || '' }, [
			E('div', { 'class': 'c8-signal-fill', 'style': 'width:%d%%'.format(width) })
		]),
		hint ? E('div', { 'class': 'c8-signal-hint' }, hint) : ''
	]);
}

function renderSignalMeters(data) {
	return E('div', { 'class': 'c8-signal-grid' }, [
		qualityBar(_('综合质量'), data.per, 'percent', _('由 RSRP、RSRQ、SINR 综合估算，适合快速判断。')),
		qualityBar(_('RSRP 接收功率'), data.rscp, 'rsrp', _('越接近 -70 dBm 越强；低于 -110 dBm 通常偏弱。')),
		qualityBar(_('RSRQ 接收质量'), data.rsrq, 'rsrq', _('越接近 -3 dB 越好；数值过低说明小区负载或干扰较高。')),
		qualityBar(_('SINR 信噪比'), data.sinr, 'sinr', _('大于 20 dB 通常很好；低于 5 dB 说明干扰明显。')),
		qualityBar(_('RSSI 总接收强度'), data.rssi, 'rssi', _('RSSI 包含噪声和邻区信号，仅作辅助参考。'))
	]);
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
		if (section.title === _('信号状态'))
			children.push(E('fieldset', { 'class': 'cbi-section c8-signal-section' }, [
				E('legend', {}, _('信号质量概览')),
				E('style', {}, [
					'.c8-signal-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin:4px 0 10px}',
					'.c8-signal-meter{border:1px solid var(--border-color,#d8dde5);border-radius:6px;padding:10px;background:var(--background-color-high,#fff)}',
					'.c8-signal-meter-head{display:flex;justify-content:space-between;gap:8px;align-items:flex-start;margin-bottom:8px}',
					'.c8-signal-meter-title{font-weight:600}',
					'.c8-signal-meter-value{font-variant-numeric:tabular-nums;text-align:right;color:var(--text-color-medium,#52606d)}',
					'.c8-signal-track{height:10px;border-radius:999px;background:var(--background-color-low,#edf1f5);overflow:hidden}',
					'.c8-signal-fill{height:100%;border-radius:999px;background:#d94841;transition:width .2s ease}',
					'.c8-signal-meter-fair .c8-signal-fill{background:#e6a700}',
					'.c8-signal-meter-good .c8-signal-fill{background:#2d9cdb}',
					'.c8-signal-meter-great .c8-signal-fill{background:#2fa66a}',
					'.c8-signal-meter-unknown .c8-signal-fill{background:#a7b0bc}',
					'.c8-signal-hint{font-size:12px;line-height:1.35;margin-top:7px;color:var(--text-color-medium,#667085)}'
				].join('')),
				renderSignalMeters(data || {})
			]));

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
