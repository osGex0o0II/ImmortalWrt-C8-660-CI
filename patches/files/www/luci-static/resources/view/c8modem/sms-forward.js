'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

const channelTypes = [
	[ 'serverchan', _('Server酱') ],
	[ 'serverchan3', _('Server酱3') ],
	[ 'pushplus', _('PushPlus') ],
	[ 'telegram', _('Telegram') ],
	[ 'wxpusher', _('WxPusher') ],
	[ 'qywx', _('企业微信') ],
	[ 'diy', _('自定义 Webhook') ]
];

function sectionId(section) {
	return section && (section['.name'] || section.name || section['.anonymous']);
}

function channelTypeTitle(value) {
	for (let i = 0; i < channelTypes.length; i++)
		if (channelTypes[i][0] === value)
			return channelTypes[i][1];

	return value || '-';
}

function channelLabel(section) {
	const id = sectionId(section);
	const name = section.name || id || '-';
	const type = channelTypeTitle(section.type);
	const enabled = section.enabled !== '0';
	const ready = channelReady(section);

	return '%s（%s%s%s）'.format(
		name,
		type,
		enabled ? '' : _('，已停用'),
		ready ? '' : _('，未配置完整')
	);
}

function channelReady(section) {
	if (!section || section.enabled === '0')
		return false;

	switch (section.type) {
	case 'serverchan':
		return !!section.sckey;
	case 'serverchan3':
		return !!section.uid && !!section.sendkey;
	case 'pushplus':
		return !!section.token;
	case 'telegram':
		return !!section.bot_token && !!section.chat_id;
	case 'wxpusher':
		return !!section.app_token && (!!section.uids || !!section.topic_ids);
	case 'qywx':
		return !!section.corpid && !!section.corpsecret && !!section.agentid;
	case 'diy':
		return !!section.url;
	default:
		return false;
	}
}

function channelIssue(section) {
	let missing = [];

	if (!section)
		return _('通道不存在');
	if (section.enabled === '0')
		return _('通道已停用');

	switch (section.type) {
	case 'serverchan':
		if (!section.sckey)
			missing.push(_('Server酱 SendKey'));
		break;
	case 'serverchan3':
		if (!section.uid)
			missing.push(_('Server酱3 UID'));
		if (!section.sendkey)
			missing.push(_('Server酱3 SendKey'));
		break;
	case 'pushplus':
		if (!section.token)
			missing.push(_('PushPlus Token'));
		break;
	case 'telegram':
		if (!section.bot_token)
			missing.push(_('Telegram Bot Token'));
		if (!section.chat_id)
			missing.push(_('Telegram Chat ID'));
		break;
	case 'wxpusher':
		if (!section.app_token)
			missing.push(_('WxPusher AppToken'));
		if (!section.uids && !section.topic_ids)
			missing.push(_('WxPusher UID/主题 ID'));
		break;
	case 'qywx':
		if (!section.corpid)
			missing.push(_('企业微信 CorpID'));
		if (!section.corpsecret)
			missing.push(_('企业微信 Secret'));
		if (!section.agentid)
			missing.push(_('企业微信 AgentID'));
		break;
	case 'diy':
		if (!section.url)
			missing.push(_('Webhook 地址'));
		break;
	default:
		return _('未知通道类型');
	}

	return missing.length ? _('缺少%s').format(missing.join('、')) : _('可用');
}

function sectionFromUci(section_id) {
	return {
		type: uci.get('sms_tool', section_id, 'type'),
		enabled: uci.get('sms_tool', section_id, 'enabled'),
		sckey: uci.get('sms_tool', section_id, 'sckey'),
		uid: uci.get('sms_tool', section_id, 'uid'),
		sendkey: uci.get('sms_tool', section_id, 'sendkey'),
		token: uci.get('sms_tool', section_id, 'token'),
		bot_token: uci.get('sms_tool', section_id, 'bot_token'),
		chat_id: uci.get('sms_tool', section_id, 'chat_id'),
		app_token: uci.get('sms_tool', section_id, 'app_token'),
		uids: uci.get('sms_tool', section_id, 'uids'),
		topic_ids: uci.get('sms_tool', section_id, 'topic_ids'),
		corpid: uci.get('sms_tool', section_id, 'corpid'),
		corpsecret: uci.get('sms_tool', section_id, 'corpsecret'),
		agentid: uci.get('sms_tool', section_id, 'agentid'),
		url: uci.get('sms_tool', section_id, 'url')
	};
}

function addChannelValues(option, sections, includeEmpty) {
	let count = 0;

	if (includeEmpty)
		option.value('', _('不使用'));

	sections.forEach(function(section) {
		const id = sectionId(section);
		if (!id || section.enabled === '0' || !channelReady(section))
			return;

		option.value(id, channelLabel(section));
		count++;
	});

	return count;
}

function addTypeValues(option) {
	channelTypes.forEach(function(item) {
		option.value(item[0], item[1]);
	});
}

function dependsType(option, type) {
	option.depends('type', type);
}

function printable(maxlen) {
	return function(section_id, value) {
		value = (value || '').trim();
		if (value === '' || (/^[^\r\n\0<>]+$/.test(value) && value.length <= maxlen))
			return true;
		return _('包含无效字符或长度过长');
	};
}

function validateUrl(section_id, value) {
	value = (value || '').trim();
	if (value === '' || /^https?:\/\/[^\s"'<>]+$/i.test(value))
		return true;
	return _('请输入以 http:// 或 https:// 开头的有效地址');
}

function validateProxy(section_id, value) {
	value = (value || '').trim();
	if (value === '' || /^(https?|socks5h?):\/\/[^\s"'<>]+$/i.test(value))
		return true;
	return _('请输入有效代理地址，例如 http://127.0.0.1:7890');
}

function withBusyButton(ev, task) {
	const button = ev && (ev.currentTarget || ev.target);

	if (button && button.disabled)
		return Promise.resolve();
	if (button)
		button.disabled = true;

	return Promise.resolve().then(task).finally(function() {
		if (button)
			button.disabled = false;
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('sms_tool'),
			fs.exec('/usr/bin/c8-sms-forward', [ 'status' ]).then(function(res) {
				try {
					return JSON.parse(res.stdout || '{}');
				} catch (e) {
					return {};
				}
			}).catch(function(e) {
				return { deps_ready: false, missing_deps: e.message };
			})
		]);
	},

	render: function(loadData) {
		const channelSections = uci.sections('sms_tool', 'forward_channel') || [];
		const initialStatus = loadData && loadData[1] ? loadData[1] : {};
		let m, s, c, o, readyCount;

		m = new form.Map('sms_tool', _('短信转发'));
		s = m.section(form.NamedSection, 'general', 'sms_tool', _('转发设置'));
		s.anonymous = true;
		s.addremove = false;

		s.tab('status', _('转发状态'));
		s.tab('advanced', _('高级设置'));
		s.tab('logs', _('转发日志'));

		o = s.taboption('status', form.Flag, 'forward_enable', _('启用短信转发'));
		o.rmempty = false;
		if (initialStatus.deps_ready === false)
			o.readonly = true;
		o.validate = function(section_id, value) {
			if (value === '1' && initialStatus.deps_ready === false)
				return _('运行依赖缺失：%s').format(initialStatus.missing_deps || '-');
			return true;
		};

		o = s.taboption('status', form.DummyValue, '_forward_status', _('当前状态'));
		o.cfgvalue = function() {
			return fs.exec('/usr/bin/c8-sms-forward', [ 'status' ]).then(function(res) {
				let data = {};
				try {
					data = JSON.parse(res.stdout || '{}');
				} catch (e) {
					data = {};
				}

				const deps = data.deps_ready === false
					? _('；运行依赖缺失：%s').format(data.missing_deps || '-')
					: '';

				return _('服务：%s%s；可用通道：%s/%s；主通道：%s%s；备用：%s%s；最近状态：%s').format(
					data.running ? _('运行中') : _('未运行'),
					deps,
					data.ready_channel_count || 0,
					data.channel_count || 0,
					data.primary_name || data.primary_channel || '-',
					data.primary_ready ? '' : _('（%s）').format(data.primary_issue || _('需要先配置通道')),
					data.backup_enabled ? (data.backup_name || data.backup_channel || '-') : _('未启用'),
					(data.backup_enabled && !data.backup_ready) ? _('（%s）').format(data.backup_issue || _('需要先配置通道')) : '',
					data.last || '-'
				);
			}).catch(function(e) {
				return e.message;
			});
		};

		o = s.taboption('status', form.ListValue, 'forward_primary_channel', _('主通道'));
		readyCount = addChannelValues(o, channelSections, false);
		if (!readyCount)
			o.value('', _('请先配置通道'));
		o.rmempty = false;
		o.validate = function(section_id, value) {
			if (uci.get('sms_tool', 'general', 'forward_enable') !== '1')
				return true;
			if (!readyCount)
				return _('请先在通道配置中添加并启用一个配置完整的通道');
			if (!value)
				return _('请选择主通道');
			return true;
		};

		o = s.taboption('status', form.Flag, 'forward_backup_enable', _('启用备用通道'));
		o.rmempty = false;

		o = s.taboption('status', form.ListValue, 'forward_backup_channel', _('备用通道'));
		addChannelValues(o, channelSections, true);
		o.depends('forward_backup_enable', '1');
		o.validate = function(section_id, value) {
			const primary = uci.get('sms_tool', 'general', 'forward_primary_channel');
			if (uci.get('sms_tool', 'general', 'forward_enable') !== '1')
				return true;
			if (uci.get('sms_tool', 'general', 'forward_backup_enable') === '1' && !value)
				return _('请选择备用通道');
			if (value && value === primary)
				return _('备用通道不能和主通道相同');
			return true;
		};

		o = s.taboption('status', form.Button, '_forward_test', _('测试转发'));
		o.inputtitle = _('发送测试通知');
		o.inputstyle = 'apply';
		o.depends('forward_enable', '1');
		o.onclick = function(ev) {
			return withBusyButton(ev, function() {
				return m.save().then(function() {
					return fs.exec('/usr/bin/c8-sms-forward', [ 'test' ]);
				}).then(function(res) {
					ui.addNotification(null, E('p', (res.stdout || '').trim() || _('测试命令已执行')));
				}).catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				});
			});
		};

		o = s.taboption('status', form.Button, '_forward_once', _('立即扫描'));
		o.inputtitle = _('扫描并转发');
		o.inputstyle = 'apply';
		o.depends('forward_enable', '1');
		o.onclick = function(ev) {
			return withBusyButton(ev, function() {
				return m.save().then(function() {
					return fs.exec('/usr/bin/c8-sms-forward', [ 'once' ]);
				}).then(function() {
					ui.addNotification(null, E('p', _('已执行一次短信转发扫描。')));
				}).catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				});
			});
		};

		o = s.taboption('advanced', form.Value, 'forward_interval', _('扫描间隔'));
		o.placeholder = '30';
		o.datatype = 'and(uinteger,min(10))';
		o.default = '30';
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'forward_retry_count', _('失败重试次数'));
		o.datatype = 'and(uinteger,max(5))';
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'forward_retry_delay', _('重试间隔'));
		o.datatype = 'and(uinteger,max(60))';
		o.default = '3';
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'sms_tool_timeout', _('短信读取超时'));
		o.datatype = 'and(uinteger,range(5,120))';
		o.placeholder = '20';
		o.default = '20';
		o.rmempty = false;

		o = s.taboption('advanced', form.Flag, 'forward_complete_only', _('只转发完整长短信'));
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('advanced', form.Flag, 'forward_delete_after', _('转发后删除原短信'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'forward_proxy', _('网络代理'));
		o.placeholder = 'http://127.0.0.1:7890';
		o.validate = validateProxy;

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
		o.onclick = function(ev) {
			if (!confirm(_('确认清空短信转发日志？')))
				return Promise.resolve();

			return withBusyButton(ev, function() {
				return fs.exec('/usr/bin/c8-sms-forward', [ 'clear-log' ]).then(function() {
					ui.addNotification(null, E('p', _('日志已清空。')));
				}).catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				});
			});
		};

		c = m.section(form.GridSection, 'forward_channel', _('通道配置'));
		c.addremove = true;
		c.anonymous = false;
		c.sortable = false;
		c.nodescriptions = true;
		c.addbtntitle = _('添加通道');
		c.sectiontitle = function(section_id) {
			return uci.get('sms_tool', section_id, 'name') || section_id;
		};

		o = c.option(form.Flag, 'enabled', _('启用'));
		o.default = '1';
		o.rmempty = false;
		o.modalonly = false;

		o = c.option(form.Value, 'name', _('名称'));
		o.rmempty = false;
		o.modalonly = true;
		o.validate = printable(32);

		o = c.option(form.ListValue, 'type', _('类型'));
		addTypeValues(o);
		o.rmempty = false;
		o.modalonly = false;

		o = c.option(form.Value, 'remark', _('备注'));
		o.modalonly = false;
		o.validate = printable(80);

		o = c.option(form.DummyValue, '_ready', _('状态'));
		o.cfgvalue = function(section_id) {
			const section = sectionFromUci(section_id);

			return channelReady(section) ? _('可用') : channelIssue(section);
		};
		o.modalonly = false;

		o = c.option(form.DummyValue, '_test_channel', _('测试'));
		o.rawhtml = true;
		o.modalonly = false;
		o.textvalue = function(section_id) {
			return E('button', {
				'class': 'cbi-button cbi-button-apply',
				'click': function(ev) {
					ev.preventDefault();
					return withBusyButton(ev, function() {
						return m.save().then(function() {
							return fs.exec('/usr/bin/c8-sms-forward', [ 'test-channel', section_id ]);
						}).then(function(res) {
							ui.addNotification(null, E('p', (res.stdout || '').trim() || _('测试命令已执行')));
						}).catch(function(e) {
							ui.addNotification(null, E('p', e.message));
						});
					});
				}
			}, _('测试'));
		};

		o = c.option(form.Value, 'sckey', _('Server酱 SendKey'));
		o.password = true;
		o.modalonly = true;
		dependsType(o, 'serverchan');

		o = c.option(form.Value, 'uid', _('Server酱3 UID'));
		o.modalonly = true;
		dependsType(o, 'serverchan3');

		o = c.option(form.Value, 'sendkey', _('Server酱3 SendKey'));
		o.password = true;
		o.modalonly = true;
		dependsType(o, 'serverchan3');

		o = c.option(form.Value, 'tags', _('Server酱3 标签'));
		o.modalonly = true;
		dependsType(o, 'serverchan3');

		o = c.option(form.Value, 'token', _('PushPlus Token'));
		o.password = true;
		o.modalonly = true;
		dependsType(o, 'pushplus');

		o = c.option(form.Value, 'api_server', _('Telegram API 地址'));
		o.placeholder = 'https://api.telegram.org';
		o.default = 'https://api.telegram.org';
		o.modalonly = true;
		o.validate = validateUrl;
		dependsType(o, 'telegram');

		o = c.option(form.Value, 'bot_token', _('Telegram Bot Token'));
		o.password = true;
		o.modalonly = true;
		dependsType(o, 'telegram');

		o = c.option(form.Value, 'chat_id', _('Telegram Chat ID'));
		o.modalonly = true;
		dependsType(o, 'telegram');

		o = c.option(form.Value, 'thread_id', _('Telegram 主题 ID'));
		o.modalonly = true;
		dependsType(o, 'telegram');

		o = c.option(form.Value, 'app_token', _('WxPusher AppToken'));
		o.password = true;
		o.modalonly = true;
		dependsType(o, 'wxpusher');

		o = c.option(form.Value, 'uids', _('WxPusher UID'));
		o.placeholder = 'UID1 UID2';
		o.modalonly = true;
		dependsType(o, 'wxpusher');

		o = c.option(form.Value, 'topic_ids', _('WxPusher 主题 ID'));
		o.placeholder = '1 2';
		o.modalonly = true;
		dependsType(o, 'wxpusher');

		o = c.option(form.Value, 'corpid', _('企业微信 CorpID'));
		o.modalonly = true;
		dependsType(o, 'qywx');

		o = c.option(form.Value, 'corpsecret', _('企业微信 Secret'));
		o.password = true;
		o.modalonly = true;
		dependsType(o, 'qywx');

		o = c.option(form.Value, 'agentid', _('企业微信 AgentID'));
		o.datatype = 'uinteger';
		o.modalonly = true;
		dependsType(o, 'qywx');

		o = c.option(form.Value, 'userid', _('企业微信接收人'));
		o.placeholder = '@all';
		o.default = '@all';
		o.modalonly = true;
		dependsType(o, 'qywx');

		o = c.option(form.Value, 'url', _('Webhook 地址'));
		o.placeholder = 'https://example.com/webhook';
		o.modalonly = true;
		o.validate = validateUrl;
		dependsType(o, 'diy');

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
