'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

function smsPort(section_id, value) {
	value = value || '';
	if (/^\/dev\/ttyUSB\d+$/.test(value) || /^\/dev\/ttyACM\d+$/.test(value))
		return true;
	return _('请选择有效的短信端口');
}

return view.extend({
	load: function() {
		return uci.load('sms_tool');
	},

	render: function() {
		let m, s, o;

		m = new form.Map('sms_tool', _('短信设置'));
		s = m.section(form.NamedSection, 'general', 'sms_tool', _('短信工具'));
		s.anonymous = true;
		s.addremove = false;
		s.tab('ports', _('端口设置'));
		s.tab('display', _('接收设置'));
		s.tab('send', _('发送设置'));

		o = s.taboption('ports', form.Value, 'readport', _('SMS读取端口'));
		o.placeholder = '/dev/ttyUSB2';
		o.validate = smsPort;
		o.rmempty = false;

		o = s.taboption('ports', form.Value, 'sendport', _('SMS发送端口'));
		o.placeholder = '/dev/ttyUSB2';
		o.validate = smsPort;
		o.rmempty = false;

		o = s.taboption('ports', form.Value, 'ussdport', _('USSD端口'));
		o.placeholder = '/dev/ttyUSB2';
		o.validate = smsPort;

		o = s.taboption('ports', form.Value, 'atport', _('AT端口'));
		o.placeholder = '/dev/ttyUSB2';
		o.validate = smsPort;

		o = s.taboption('display', form.ListValue, 'storage', _('消息存储区域'));
		o.value('ME', _('模组内存'));
		o.value('SM', _('SIM卡'));
		o.default = 'ME';
		o.rmempty = false;

		o = s.taboption('display', form.Flag, 'mergesms', _('合并分段短信'));
		o.rmempty = false;

		o = s.taboption('display', form.ListValue, 'algorithm', _('合并算法'));
		o.value('Advanced', _('高级'));
		o.value('Simple', _('简单'));
		o.default = 'Advanced';
		o.depends('mergesms', '1');

		o = s.taboption('display', form.ListValue, 'direction', _('合并方向'));
		o.value('Start', _('从头到尾'));
		o.value('End', _('从尾到头'));
		o.default = 'Start';
		o.depends('algorithm', 'Advanced');

		o = s.taboption('send', form.Flag, 'prefix', _('自动添加国家前缀'));
		o.rmempty = false;

		o = s.taboption('send', form.Value, 'pnumber', _('国家前缀'));
		o.placeholder = '86';
		o.datatype = 'and(uinteger,rangelength(1,5))';
		o.depends('prefix', '1');

		o = s.taboption('send', form.Flag, 'information', _('显示号码说明'));
		o.rmempty = false;

		o = s.taboption('display', form.Button, '_delete_all', _('清空短信'));
		o.inputtitle = _('删除全部短信');
		o.inputstyle = 'remove';
		o.onclick = function() {
			if (!confirm(_('确认删除当前存储区域内的全部短信？')))
				return Promise.resolve();

			const storage = uci.get('sms_tool', 'general', 'storage') || 'ME';
			const port = uci.get('sms_tool', 'general', 'readport') || '/dev/ttyUSB2';

			return fs.exec('/usr/bin/sms_tool', [ '-s', storage, '-d', port, 'delete', 'all' ])
				.then(function() {
					ui.addNotification(null, E('p', _('已发送清空短信命令。')));
				}).catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				});
		};

		return m.render();
	}
});
