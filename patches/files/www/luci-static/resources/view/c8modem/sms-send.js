'use strict';
'require view';
'require request';
'require uci';
'require ui';

function postSms(payload) {
	const body = 'scode=%s'.format(encodeURIComponent(payload));

	return request.post(L.url('admin/modem/run_sms'), body, {
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
	}).then(function(res) {
		return res.text();
	});
}

function validNumber(value) {
	value = (value || '').replace(/\s+/g, '').replace(/^\+/, '');
	if (/^\d{3,20}$/.test(value))
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
				ui.addNotification(null, E('p', _('请输入有效的电话号码')));
				return Promise.resolve();
			}
			if (!msg) {
				ui.addNotification(null, E('p', _('请输入短信内容')));
				return Promise.resolve();
			}

			output.textContent = _('发送中...');
			return postSms((nr + '                    ').slice(0, 20) + msg).then(function(result) {
				output.textContent = result || '-';
				if (result.indexOf('+CMGS') !== -1) {
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
				showInfo ? E('div', { 'class': 'cbi-section-descr' }, _('电话号码前需加国家前缀（中国为86，不加+）。短号可直接填写。')) : '',
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
