'use strict';
'require view';
'require form';
'require uci';
'require fs';

function token(maxlen) {
	return function(section_id, value) {
		value = (value || '').trim();
		if (value === '' || (/^[A-Za-z0-9_.:-]+$/.test(value) && value.length <= maxlen))
			return true;
		return _('包含无效字符');
	};
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('modem'),
			fs.read('/tmp/simcardstat').catch(function() { return ''; }),
			fs.read('/tmp/ipv6prefix').catch(function() { return ''; }),
			fs.exec('/bin/sendat', [ '2', 'AT+CGSN' ]).catch(function() { return { stdout: '' }; }),
			fs.exec('/bin/sendat', [ '2', 'AT+QADBKEY?' ]).catch(function() { return { stdout: '' }; }),
			fs.exec('/usr/bin/adb', [ 'devices' ]).catch(function() { return { stdout: '' }; }),
			fs.exec('/usr/bin/adb', [ 'shell', 'uptime' ]).catch(function() { return { stdout: '' }; })
		]);
	},

	render: function(data) {
		const simStatus = (data[1] || '').trim() || '-';
		const ipv6Status = (data[2] || '').trim() || _('Native IPV6未使能');
		const imei = ((data[3].stdout || '').match(/\b\d{15}\b/) || [ '' ])[0];
		const adbKey = ((data[4].stdout || '').match(/\+QADBKEY:\s*([A-Za-z0-9_.:-]+)/) || [ '', '' ])[1];
		const adbDevice = (data[5].stdout || '').split(/\r?\n/).filter(function(line) {
			return /\tdevice$/.test(line);
		}).map(function(line) {
			return line.split(/\s+/)[0];
		}).join(', ');
		const uptime = (data[6].stdout || '').trim();

		let m, s, o;
		m = new form.Map('modem', _('移动网络'));
		s = m.section(form.TypedSection, 'ndis', _('蜂窝设置'));
		s.anonymous = true;
		s.addremove = false;
		s.tab('general', _('常规设置'));
		s.tab('advanced', _('高级设置'));
		s.tab('nativeipv6', _('原生IPV6设置'));

		o = s.taboption('general', form.Flag, 'enable', _('启用模块'));
		o.rmempty = false;

		o = s.taboption('general', form.ListValue, 'simsel', _('SIM卡选择'));
		o.value('0', _('外置SIM卡'));
		o.value('1', _('内置SIM1'));
		o.value('2', _('内置SIM2'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'pincode', _('PIN密码'));
		o.datatype = 'and(rangelength(0,8),uinteger)';
		o.placeholder = _('留空');

		o = s.taboption('general', form.Value, 'apnconfig', _('APN接入点'));
		o.datatype = 'and(rangelength(0,64),string)';
		o.validate = function(section_id, value) {
			value = (value || '').trim();
			if (value === '' || /^[A-Za-z0-9_.-]+$/.test(value))
				return true;
			return _('APN只能包含字母、数字、点、下划线或横线');
		};

		o = s.taboption('general', form.DummyValue, '_sim_card_stat', _('SIM卡状态'));
		o.cfgvalue = function() { return simStatus; };

		o = s.taboption('advanced', form.ListValue, 'smode', _('网络制式'));
		o.value('0', _('自动'));
		o.value('1', _('4G网络'));
		o.value('2', _('5G网络'));
		o.default = '0';

		o = s.taboption('advanced', form.ListValue, 'nrmode', _('5G模式'));
		o.value('0', _('SA/NSA双模'));
		o.value('1', _('SA模式'));
		o.value('2', _('NSA模式'));
		o.depends('smode', '2');

		o = s.taboption('advanced', form.ListValue, 'bandlist_lte', _('LTE频段'));
		[ '0', '1', '3', '5', '8', '34', '38', '39', '40', '41' ].forEach(function(v) {
			o.value(v, v === '0' ? _('自动') : 'BAND %s'.format(v));
		});
		o.default = '0';
		o.depends('smode', '1');

		o = s.taboption('advanced', form.ListValue, 'bandlist_sa', _('5G-SA频段'));
		[ '0', '1', '3', '8', '28', '41', '78', '79' ].forEach(function(v) {
			o.value(v, v === '0' ? _('自动') : 'BAND %s'.format(v));
		});
		o.default = '0';
		o.depends('nrmode', '1');

		o = s.taboption('advanced', form.ListValue, 'bandlist_nsa', _('5G-NSA频段'));
		[ '0', '41', '78', '79' ].forEach(function(v) {
			o.value(v, v === '0' ? _('自动') : 'BAND %s'.format(v));
		});
		o.default = '0';
		o.depends('nrmode', '2');

		o = s.taboption('advanced', form.Value, 'earfcn', _('频点EARFCN'));
		o.datatype = 'uinteger';
		o.optional = true;

		o = s.taboption('advanced', form.Value, 'cellid', _('小区PCI'));
		o.datatype = 'uinteger';
		o.optional = true;

		o = s.taboption('advanced', form.Flag, 'dataroaming', _('行动网络漫游服务'));
		o.rmempty = true;

		o = s.taboption('advanced', form.Flag, 'autofreqlock', _('基地站自锁定功能'));
		o.rmempty = true;

		o = s.taboption('advanced', form.Flag, 'freqlock', _('EARFCN与PCI锁定持久化'));
		o.rmempty = true;

		o = s.taboption('advanced', form.Flag, 'enable_imei', _('修改IMEI'));
		o.depends('simsel', '0');

		o = s.taboption('advanced', form.Value, 'modify_imei', _('IMEI'));
		o.placeholder = imei || '';
		o.depends('enable_imei', '1');
		o.validate = function(section_id, value) {
			value = (value || '').trim();
			if (/^\d{15}$/.test(value))
				return true;
			return _('IMEI必须是15位数字');
		};

		o = s.taboption('nativeipv6', form.DummyValue, '_adbkey', _('模块解锁请求码'));
		o.cfgvalue = function() { return adbKey || '-'; };

		o = s.taboption('nativeipv6', form.Value, 'adbunlockkey', _('ADB解锁码'));
		o.validate = token(128);

		o = s.taboption('nativeipv6', form.DummyValue, '_adb_status', _('模块ADB状态'));
		o.cfgvalue = function() { return adbDevice || _('设备ADB连接失败'); };

		o = s.taboption('nativeipv6', form.Flag, 'enable_native_ipv6', _('启用原生IPV6支持'));
		if (!adbDevice)
			o.readonly = true;

		o = s.taboption('nativeipv6', form.DummyValue, '_nativeIPV6_status', _('IPV6状态'));
		o.cfgvalue = function() { return ipv6Status; };

		o = s.taboption('nativeipv6', form.DummyValue, '_module_uptime', _('模块运行时间'));
		o.cfgvalue = function() { return uptime || _('ADB未安装'); };

		return m.render();
	}
});
