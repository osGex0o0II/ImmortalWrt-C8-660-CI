'use strict';
'require view';
'require fs';
'require uci';
'require ui';

const SMS_SEND_TIMEOUT = 60000;

function execWithTimeout(cmd, args, timeout, label) {
	let timer;

	return Promise.race([
		fs.exec(cmd, args).then(function(res) {
			clearTimeout(timer);
			return res;
		}, function(err) {
			clearTimeout(timer);
			throw err;
		}),
		new Promise(function(resolve, reject) {
			timer = setTimeout(function() {
				reject(new Error(_('%s 执行超时，请确认 SIM 卡、短信端口、余额和模组 AT 响应正常。').format(label)));
			}, timeout);
		})
	]);
}

function validNumber(value) {
	value = (value || '').replace(/\s+/g, '').replace(/^\+/, '');
	if (/^\d{2,20}$/.test(value))
		return value;
	return null;
}

return view.extend({
	load: function() {
		return uci.load('sms_tool');
	},

	render: function() {
		const prefixEnabled = uci.get('sms_tool', 'general', 'prefix') === '1';
		const prefix = uci.get('sms_tool', 'general', 'pnumber') || '86';
		const showInfo = uci.get('sms_tool', 'general', 'information') === '1';
		const port = uci.get('sms_tool', 'general', 'sendport') || '/dev/ttyUSB2';
		const number = E('input', {
			type: 'text',
			'class': 'cbi-input-text',
			maxlength: '24',
			value: prefixEnabled ? prefix : ''
		});
		const text = E('textarea', {
			'class': 'cbi-input-textarea',
			rows: 7,
			maxlength: '670',
			style: 'width:100%; resize:vertical;'
		});
		const counter = E('span', {}, '0 / 670');
		const output = E('pre', {
			'style': 'white-space:pre-wrap; min-height:3em;'
		}, '');

		function updateCounter() {
			counter.textContent = '%d / 670'.format(text.value.length);
		}

		text.addEventListener('input', updateCounter);

		function send() {
			const nr = validNumber(number.value);
			const msg = (text.value || '').trim();

			if (!nr) {
				ui.addNotification(null, E('p', _('请输入有效号码，支持短号或带国家前缀的手机号')));
				return Promise.resolve();
			}
			if (!msg) {
				ui.addNotification(null, E('p', _('请输入短信内容')));
				return Promise.resolve();
			}

			output.textContent = _('发送中...');
			return execWithTimeout('/usr/bin/sms_tool', [ '-d', port, 'send', nr, msg ], SMS_SEND_TIMEOUT, _('短信发送')).then(function(res) {
				const result = [ res.stdout || '', res.stderr || '' ].join('\n').trim();
				output.textContent = result || '-';
				if (/sent|CMGS|OK/i.test(result)) {
					ui.addNotification(null, E('p', _('短信发送成功')));
					text.value = '';
					updateCounter();
				} else {
					ui.addNotification(null, E('p', _('短信发送失败')));
				}
			}).catch(function(e) {
				output.textContent = e.message;
				ui.addNotification(null, E('p', e.message));
			});
		}

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', _('短信发送')),
			E('fieldset', { 'class': 'cbi-section' }, [
				showInfo ? E('div', { 'class': 'cbi-section-descr' }, _('手机号建议加国家前缀（中国为86，不加+）；运营商短号可直接填写。')) : '',
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('发送至')),
					E('div', { 'class': 'cbi-value-field' }, number)
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('短信内容')),
					E('div', { 'class': 'cbi-value-field' }, [ text, E('div', {}, counter) ])
				]),
				E('div', { 'class': 'cbi-page-actions' }, [
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						click: send
					}, _('发送'))
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('发送结果')),
					E('div', { 'class': 'cbi-value-field' }, output)
				])
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
