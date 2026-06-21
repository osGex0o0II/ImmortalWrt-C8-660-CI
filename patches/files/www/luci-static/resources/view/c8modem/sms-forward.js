'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

const channels = [
	[ 'serverchan', _('Server酱') ],
	[ 'serverchan3', _('Server酱3') ],
	[ 'pushplus', _('PushPlus') ],
	[ 'telegram', _('Telegram') ],
	[ 'wxpusher', _('WxPusher') ],
	[ 'qywx', _('企业微信') ],
	[ 'diy', _('自定义 Webhook') ]
];

function channelTitle(value) {
	for (let i = 0; i < channels.length; i++)
		if (channels[i][0] === value)
			return channels[i][1];

	return value || '-';
}

function dependsChannel(option, channel) {
	option.depends({ forward_primary_channel: channel });
	option.depends({ forward_backup_enable: '1', forward_backup_channel: channel });
}

function addChannelValues(option) {
	channels.forEach(function(item) {
		option.value(item[0], item[1]);
	});
}

return view.extend({
	load: function() {
		return uci.load('sms_tool');
	},

	render: function() {
		let m, s, o;

		m = new form.Map('sms_tool', _('短信转发'));
		s = m.section(form.NamedSection, 'general', 'sms_tool', _('转发设置'));
		s.anonymous = true;
		s.addremove = false;

		s.tab('status', _('转发状态'));
		s.tab('route', _('主备通道'));
		s.tab('channels', _('通道配置'));
		s.tab('logs', _('转发日志'));

		o = s.taboption('status', form.Flag, 'forward_enable', _('启用短信转发'));
		o.rmempty = false;
		o.description = _('收到完整短信后自动推送到主通道，主通道失败后再尝试备用通道。');

		o = s.taboption('status', form.DummyValue, '_forward_status', _('当前状态'));
		o.cfgvalue = function() {
			return fs.exec('/usr/bin/c8-sms-forward', [ 'status' ]).then(function(res) {
				let data = {};
				try {
					data = JSON.parse(res.stdout || '{}');
				} catch (e) {
					data = {};
				}

				return _('服务：%s；主通道：%s；备用：%s；最近状态：%s').format(
					data.running ? _('运行中') : _('未运行'),
					channelTitle(data.primary_channel),
					data.backup_enabled ? channelTitle(data.backup_channel) : _('未启用'),
					data.last || '-'
				);
			}).catch(function(e) {
				return e.message;
			});
		};

		o = s.taboption('status', form.Button, '_forward_test', _('测试转发'));
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

		o = s.taboption('status', form.Button, '_forward_once', _('立即扫描'));
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

		o = s.taboption('route', form.ListValue, 'forward_primary_channel', _('主通道'));
		addChannelValues(o);
		o.default = 'pushplus';
		o.rmempty = false;

		o = s.taboption('route', form.Flag, 'forward_backup_enable', _('启用备用通道'));
		o.rmempty = false;

		o = s.taboption('route', form.ListValue, 'forward_backup_channel', _('备用通道'));
		addChannelValues(o);
		o.default = 'telegram';
		o.rmempty = false;
		o.depends('forward_backup_enable', '1');

		o = s.taboption('route', form.Value, 'forward_retry_count', _('失败重试次数'));
		o.datatype = 'and(uinteger,max(5))';
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('route', form.Value, 'forward_retry_delay', _('重试间隔'));
		o.datatype = 'and(uinteger,max(60))';
		o.default = '3';
		o.rmempty = false;

		o = s.taboption('route', form.Value, 'forward_interval', _('扫描间隔'));
		o.placeholder = '30';
		o.datatype = 'and(uinteger,min(10))';
		o.default = '30';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('route', form.Flag, 'forward_complete_only', _('只转发完整长短信'));
		o.default = '1';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('route', form.Flag, 'forward_delete_after', _('转发后删除原短信'));
		o.default = '0';
		o.rmempty = false;
		o.depends('forward_enable', '1');

		o = s.taboption('channels', form.Value, 'forward_serverchan_sckey', _('Server酱 SendKey'));
		o.password = true;
		dependsChannel(o, 'serverchan');

		o = s.taboption('channels', form.Value, 'forward_serverchan3_uid', _('Server酱3 UID'));
		dependsChannel(o, 'serverchan3');

		o = s.taboption('channels', form.Value, 'forward_serverchan3_key', _('Server酱3 SendKey'));
		o.password = true;
		dependsChannel(o, 'serverchan3');

		o = s.taboption('channels', form.Value, 'forward_serverchan3_tags', _('Server酱3 标签'));
		dependsChannel(o, 'serverchan3');

		o = s.taboption('channels', form.Value, 'forward_pushplus_token', _('PushPlus Token'));
		o.password = true;
		dependsChannel(o, 'pushplus');

		o = s.taboption('channels', form.Value, 'forward_tg_api_server', _('Telegram API 地址'));
		o.placeholder = 'https://api.telegram.org';
		o.default = 'https://api.telegram.org';
		dependsChannel(o, 'telegram');

		o = s.taboption('channels', form.Value, 'forward_tg_token', _('Telegram Bot Token'));
		o.password = true;
		dependsChannel(o, 'telegram');

		o = s.taboption('channels', form.Value, 'forward_tg_chat_id', _('Telegram Chat ID'));
		dependsChannel(o, 'telegram');

		o = s.taboption('channels', form.Value, 'forward_tg_thread_id', _('Telegram 主题 ID'));
		dependsChannel(o, 'telegram');

		o = s.taboption('channels', form.Value, 'forward_wxpusher_apptoken', _('WxPusher AppToken'));
		o.password = true;
		dependsChannel(o, 'wxpusher');

		o = s.taboption('channels', form.Value, 'forward_wxpusher_uids', _('WxPusher UID'));
		o.placeholder = 'UID1 UID2';
		dependsChannel(o, 'wxpusher');

		o = s.taboption('channels', form.Value, 'forward_wxpusher_topicids', _('WxPusher 主题 ID'));
		o.placeholder = '1 2';
		dependsChannel(o, 'wxpusher');

		o = s.taboption('channels', form.Value, 'forward_qywx_corpid', _('企业微信 CorpID'));
		dependsChannel(o, 'qywx');

		o = s.taboption('channels', form.Value, 'forward_qywx_corpsecret', _('企业微信 Secret'));
		o.password = true;
		dependsChannel(o, 'qywx');

		o = s.taboption('channels', form.Value, 'forward_qywx_agentid', _('企业微信 AgentID'));
		o.datatype = 'uinteger';
		dependsChannel(o, 'qywx');

		o = s.taboption('channels', form.Value, 'forward_qywx_userid', _('企业微信接收人'));
		o.placeholder = '@all';
		o.default = '@all';
		dependsChannel(o, 'qywx');

		o = s.taboption('channels', form.Value, 'forward_diy_url', _('Webhook 地址'));
		o.placeholder = 'https://example.com/webhook';
		o.description = _('将以 JSON 发送 title、content 和 text 字段。');
		dependsChannel(o, 'diy');

		o = s.taboption('channels', form.Value, 'forward_proxy', _('网络代理'));
		o.placeholder = 'http://127.0.0.1:7890';

		o = s.taboption('logs', form.DummyValue, '_forward_log', _('最近日志'));
		o.cfgvalue = function() {
			return fs.exec('/usr/bin/c8-sms-forward', [ 'log' ]).then(function(res) {
				return E('pre', {
					'style': 'white-space:pre-wrap; min-height:12em; max-height:28em; overflow:auto;'
				}, (res.stdout || '').trim() || _('暂无日志'));
			}).catch(function(e) {
				return e.message;
			});
		};

		o = s.taboption('logs', form.Button, '_forward_clear_log', _('清空日志'));
		o.inputtitle = _('清空日志');
		o.inputstyle = 'remove';
		o.onclick = function() {
			if (!confirm(_('确认清空短信转发日志？')))
				return Promise.resolve();

			return fs.exec('/usr/bin/c8-sms-forward', [ 'clear-log' ]).then(function() {
				ui.addNotification(null, E('p', _('日志已清空。')));
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
