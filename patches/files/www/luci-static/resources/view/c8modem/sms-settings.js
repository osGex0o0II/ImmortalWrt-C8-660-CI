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
		s.tab('forward', _('短信转发'));

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

		o = s.taboption('send', form.Flag, 'prefix', _('自动添加国家前缀'));
		o.rmempty = false;

		o = s.taboption('send', form.Value, 'pnumber', _('国家前缀'));
		o.placeholder = '86';
		o.datatype = 'and(uinteger,rangelength(1,5))';
		o.depends('prefix', '1');

		o = s.taboption('send', form.Flag, 'information', _('显示号码说明'));
		o.rmempty = false;

		o = s.taboption('forward', form.Flag, 'forward_enable', _('启用短信转发'));
		o.rmempty = false;
		o.description = _('收到完整短信后自动推送到通知通道。');

		o = s.taboption('forward', form.ListValue, 'forward_backend', _('推送后端'));
		o.value('wechatpush', _('微信推送'));
		o.default = 'wechatpush';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('forward', form.ListValue, 'forward_channel', _('推送通道'));
		o.value('auto', _('自动选择'));
		o.value('serverchan', _('Server酱'));
		o.value('serverchan3', _('Server酱3'));
		o.value('pushplus', _('PushPlus'));
		o.value('telegram', _('Telegram'));
		o.value('wxpusher', _('WxPusher'));
		o.value('qywx', _('企业微信'));
		o.value('diy', _('自定义 Webhook'));
		o.default = 'auto';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('forward', form.Value, 'forward_diy_url', _('自定义 Webhook'));
		o.placeholder = 'https://example.com/webhook';
		o.depends({ forward_enable: '1', forward_channel: 'diy' });
		o.description = _('将以 JSON 发送 title、content 和 text 字段。');

		o = s.taboption('forward', form.Value, 'forward_interval', _('扫描间隔'));
		o.placeholder = '30';
		o.datatype = 'and(uinteger,min(10))';
		o.default = '30';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('forward', form.Flag, 'forward_complete_only', _('只转发完整长短信'));
		o.default = '1';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('forward', form.Flag, 'forward_delete_after', _('转发后删除原短信'));
		o.default = '0';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('forward', form.Button, '_forward_test', _('测试转发'));
		o.inputtitle = _('发送测试通知');
		o.inputstyle = 'apply';
		o.depends('forward_enable', '1');
		o.onclick = function() {
			return m.save().then(function() {
				return fs.exec('/usr/bin/c8-sms-forward', [ 'test' ]);
			}).then(function(res) {
				ui.addNotification(null, E('p', (res.stdout || '').trim() || _('测试命令已执行')));
			}).catch(function(e) {
				ui.addNotification(null, E('p', e.message));
			});
		};

		o = s.taboption('forward', form.Button, '_forward_once', _('立即扫描'));
		o.inputtitle = _('扫描并转发');
		o.inputstyle = 'apply';
		o.depends('forward_enable', '1');
		o.onclick = function() {
			return m.save().then(function() {
				return fs.exec('/usr/bin/c8-sms-forward', [ 'once' ]);
			}).then(function() {
				ui.addNotification(null, E('p', _('已执行一次短信转发扫描。')));
			}).catch(function(e) {
				ui.addNotification(null, E('p', e.message));
			});
		};

		o = s.taboption('forward', form.DummyValue, '_forward_status', _('转发状态'));
		o.cfgvalue = function() {
			return fs.exec('/usr/bin/c8-sms-forward', [ 'status' ]).then(function(res) {
				let data = {};
				try {
					data = JSON.parse(res.stdout || '{}');
				} catch (e) {
					data = {};
				}

				return _('服务：%s；端口：%s；最近状态：%s').format(
					data.running ? _('运行中') : _('未运行'),
					data.port || '-',
					data.last || '-'
				);
			}).catch(function(e) {
				return e.message;
			});
		};

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
	},

	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			return fs.exec('/etc/init.d/c8-sms-forward', [ 'restart' ]);
		}).then(function() {
			ui.addNotification(null, E('p', _('短信转发服务已应用。')));
		});
	}
});
