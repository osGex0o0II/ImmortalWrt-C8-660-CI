'use strict';
'require view';
'require fs';
'require poll';

function execLines(cmd, args) {
	return fs.exec(cmd, args || []).then(function(res) {
		return String(res.stdout || '').replace(/\r/g, '').split('\n');
	}).catch(function() {
		return [];
	});
}

function parseInterfaces(lines) {
	const radios = [];
	let current = null;

	lines.forEach(function(line) {
		let m = line.match(/^(\S+)\s+ESSID:\s+"(.*)"/);
		if (m) {
			current = { ifname: m[1], ssid: m[2] };
			radios.push(current);
			return;
		}

		if (!current)
			return;

		m = line.match(/Mode:\s+(\S+)\s+Channel:\s+([^(]+)\(([^)]+)\).*HT Mode:\s+(.+)$/);
		if (m) {
			current.mode = m[1];
			current.channel = m[2].trim();
			current.frequency = m[3].trim();
			current.htmode = m[4].trim();
		}

		m = line.match(/Tx-Power:\s+(-?\d+)\s+dBm\s+Link Quality:\s+(\d+)\/(\d+)/);
		if (m) {
			current.txpower = m[1];
			current.quality = +m[2];
			current.qualityMax = +m[3];
		}

		m = line.match(/Signal:\s+(-?\d+)\s+dBm\s+Noise:\s+(-?\d+)\s+dBm/);
		if (m) {
			current.signal = +m[1];
			current.noise = +m[2];
		}

		m = line.match(/Encryption:\s+(.+)$/);
		if (m)
			current.encryption = m[1].trim();
	});

	return radios;
}

function parseAssoc(ifname, lines) {
	const clients = [];
	let current = null;

	lines.forEach(function(line) {
		let m = line.match(/^([0-9A-Fa-f:]{17})\s+/);
		if (m) {
			current = { ifname: ifname, mac: m[1] };
			clients.push(current);
			return;
		}

		if (!current)
			return;

		m = line.match(/signal:\s+(-?\d+)\s+dBm/i) || line.match(/Signal:\s+(-?\d+)\s+dBm/);
		if (m)
			current.signal = +m[1];

		m = line.match(/noise:\s+(-?\d+)\s+dBm/i) || line.match(/Noise:\s+(-?\d+)\s+dBm/);
		if (m)
			current.noise = +m[1];

		m = line.match(/rx rate:\s+(.+)$/i);
		if (m)
			current.rx = m[1].trim();

		m = line.match(/tx rate:\s+(.+)$/i);
		if (m)
			current.tx = m[1].trim();
	});

	return clients;
}

function qualityFromSignal(signal) {
	if (signal == null || signal >= 0)
		return '-';

	return Math.max(0, Math.min(100, Math.round((signal + 100) * 2)));
}

function loadWifi() {
	return execLines('/usr/bin/iwinfo').then(function(lines) {
		const radios = parseInterfaces(lines);
		return Promise.all(radios.map(function(radio) {
			return execLines('/usr/bin/iwinfo', [ radio.ifname, 'assoclist' ]).then(function(assoc) {
				radio.clients = parseAssoc(radio.ifname, assoc);
				return radio;
			});
		}));
	});
}

function radioRows(radios) {
	if (!radios.length)
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td center', 'colspan': 8 }, _('未发现无线接口'))
		]);

	return radios.map(function(radio) {
		const apQuality = radio.qualityMax ? Math.round(radio.quality * 100 / radio.qualityMax) : '-';
		const apSignal = radio.signal === 0 ? _('AP接口无客户端RSSI') : '%s dBm'.format(radio.signal);

		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, radio.ifname),
			E('td', { 'class': 'td left' }, radio.ssid || '-'),
			E('td', { 'class': 'td left' }, radio.mode || '-'),
			E('td', { 'class': 'td left' }, radio.channel || '-'),
			E('td', { 'class': 'td left' }, radio.htmode || '-'),
			E('td', { 'class': 'td left' }, radio.txpower ? '%s dBm'.format(radio.txpower) : '-'),
			E('td', { 'class': 'td left' }, apQuality === '-' ? '-' : '%d%%'.format(apQuality)),
			E('td', { 'class': 'td left' }, apSignal)
		]);
	});
}

function clientRows(radios) {
	const clients = [];
	radios.forEach(function(radio) {
		(radio.clients || []).forEach(function(client) {
			clients.push(client);
		});
	});

	if (!clients.length)
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td center', 'colspan': 7 }, _('暂无已连接客户端'))
		]);

	return clients.map(function(client) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, client.ifname),
			E('td', { 'class': 'td left' }, client.mac),
			E('td', { 'class': 'td left' }, client.signal != null ? '%d dBm'.format(client.signal) : '-'),
			E('td', { 'class': 'td left' }, client.noise != null ? '%d dBm'.format(client.noise) : '-'),
			E('td', { 'class': 'td left' }, client.signal != null && client.noise != null ? '%d dB'.format(client.signal - client.noise) : '-'),
			E('td', { 'class': 'td left' }, qualityFromSignal(client.signal) === '-' ? '-' : '%d%%'.format(qualityFromSignal(client.signal))),
			E('td', { 'class': 'td left' }, [ client.rx || '-', E('br'), client.tx || '-' ])
		]);
	});
}

function asRows(rows) {
	return Array.isArray(rows) ? rows : [ rows ];
}

function renderContent(radios) {
	const radioTableRows = [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th left' }, _('接口')),
			E('th', { 'class': 'th left' }, _('SSID')),
			E('th', { 'class': 'th left' }, _('模式')),
			E('th', { 'class': 'th left' }, _('信道')),
			E('th', { 'class': 'th left' }, _('带宽')),
			E('th', { 'class': 'th left' }, _('发射功率')),
			E('th', { 'class': 'th left' }, _('链路质量')),
			E('th', { 'class': 'th left' }, _('接口信号'))
		])
	].concat(asRows(radioRows(radios || [])));
	const clientTableRows = [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th left' }, _('接口')),
			E('th', { 'class': 'th left' }, _('MAC')),
			E('th', { 'class': 'th left' }, _('信号')),
			E('th', { 'class': 'th left' }, _('噪声')),
			E('th', { 'class': 'th left' }, _('SNR')),
			E('th', { 'class': 'th left' }, _('质量')),
			E('th', { 'class': 'th left' }, _('速率'))
		])
	].concat(asRows(clientRows(radios || [])));

	return E('div', { 'class': 'cbi-map' }, [
		E('h2', _('无线状态')),
		E('fieldset', { 'class': 'cbi-section' }, [
			E('legend', {}, _('无线接口')),
			E('table', { 'class': 'table' }, radioTableRows)
		]),
		E('fieldset', { 'class': 'cbi-section' }, [
			E('legend', {}, _('客户端信号')),
			E('table', { 'class': 'table' }, clientTableRows)
		])
	]);
}

let container;

function reload() {
	return loadWifi().then(function(radios) {
		const next = renderContent(radios);
		if (container && container.parentNode)
			container.parentNode.replaceChild(next, container);
		container = next;
	});
}

return view.extend({
	load: loadWifi,

	render: function(radios) {
		container = renderContent(radios);
		poll.add(reload, 10);
		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
