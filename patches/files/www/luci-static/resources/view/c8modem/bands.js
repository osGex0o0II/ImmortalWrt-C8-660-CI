'use strict';
'require view';
'require form';
'require fs';
'require uci';
'require ui';

function readScan() {
	return fs.read('/tmp/cellscan.json').then(function(text) {
		try {
			return JSON.parse(text || '{}');
		} catch (e) {
			return {};
		}
	}).catch(function() {
		return {};
	});
}

function renderScanHint(scan) {
	const cells = scan && Array.isArray(scan.cells) ? scan.cells : [];

	if (!cells.length)
		return E('div', { 'class': 'cbi-map-descr' }, _('基站扫描暂无结果，可先在“基站扫描”页面获取附近小区。'));

	return E('fieldset', { 'class': 'cbi-section' }, [
		E('legend', {}, _('最近扫描结果')),
		E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th left' }, _('运营商')),
				E('th', { 'class': 'th left' }, _('制式')),
				E('th', { 'class': 'th left' }, _('频点')),
				E('th', { 'class': 'th left' }, _('PCI')),
				E('th', { 'class': 'th left' }, _('信号'))
			]),
			cells.slice(0, 8).map(function(cell) {
				return E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left' }, cell.operator || '-'),
					E('td', { 'class': 'td left' }, cell.mode || '-'),
					E('td', { 'class': 'td left' }, cell.earfcn || '-'),
					E('td', { 'class': 'td left' }, cell.pci || '-'),
					E('td', { 'class': 'td left' }, cell.signal || '-')
				]);
			})
		])
	]);
}

function validNumber(maxlen) {
	return function(section_id, value) {
		value = (value || '').trim();
		if (value === '' || value === '0' || (/^\d+$/.test(value) && value.length <= maxlen))
			return true;
		return _('请输入有效数字');
	};
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('modem'),
			readScan()
		]);
	},

	render: function(data) {
		let m, s, o;
		const scan = data[1] || {};

		m = new form.Map('modem', _('频段工具'), _('频段、频点和PCI设置会在模块重新初始化时下发到 RM520N。'));
		s = m.section(form.TypedSection, 'ndis', _('RM520N 频段设置'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.ListValue, 'smode', _('网络制式'));
		o.value('0', _('自动'));
		o.value('1', _('4G网络'));
		o.value('2', _('5G网络'));
		o.default = '0';
		o.rmempty = false;

		o = s.option(form.ListValue, 'nrmode', _('5G模式'));
		o.value('0', _('SA/NSA双模'));
		o.value('1', _('SA模式'));
		o.value('2', _('NSA模式'));
		o.default = '0';
		o.depends('smode', '2');

		o = s.option(form.ListValue, 'bandlist_lte', _('LTE频段'));
		[ '0', '1', '3', '5', '8', '34', '38', '39', '40', '41' ].forEach(function(v) {
			o.value(v, v === '0' ? _('自动') : 'B%s'.format(v));
		});
		o.default = '0';

		o = s.option(form.ListValue, 'bandlist_sa', _('5G-SA频段'));
		[ '0', '1', '3', '8', '28', '41', '78', '79' ].forEach(function(v) {
			o.value(v, v === '0' ? _('自动') : 'n%s'.format(v));
		});
		o.default = '0';

		o = s.option(form.ListValue, 'bandlist_nsa', _('5G-NSA频段'));
		[ '0', '41', '78', '79' ].forEach(function(v) {
			o.value(v, v === '0' ? _('自动') : 'n%s'.format(v));
		});
		o.default = '0';

		o = s.option(form.Value, 'earfcn', _('频点 EARFCN/NRARFCN'));
		o.placeholder = '0';
		o.validate = validNumber(10);

		o = s.option(form.Value, 'cellid', _('小区 PCI'));
		o.placeholder = '0';
		o.validate = validNumber(6);

		o = s.option(form.Flag, 'freqlock', _('启用 EARFCN + PCI 锁定'));
		o.rmempty = false;

		o = s.option(form.Flag, 'autofreqlock', _('自动锁定当前基站'));
		o.rmempty = false;

		o = s.option(form.Button, '_apply_modem', _('应用到模块'));
		o.inputtitle = _('重新初始化模块');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/usr/share/modem/luci-reinit.sh').then(function() {
				ui.addNotification(null, E('p', _('已启动模块重新初始化。')));
			}).catch(function(e) {
				ui.addNotification(null, E('p', e.message));
			});
		};

		return Promise.all([
			m.render()
		]).then(function(nodes) {
			return E('div', {}, [
				nodes[0],
				renderScanHint(scan)
			]);
		});
	}
});
