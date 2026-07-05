'use strict';
'require view';
'require fs';
'require ui';

const AT_EXEC_TIMEOUT = 20000;

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
				reject(new Error(_('%s 执行超时，请确认模块端口和 AT 响应正常。').format(label)));
			}, timeout);
		})
	]);
}

function validCommand(cmd) {
	cmd = (cmd || '').replace(/[\r\n\0]/g, ' ').trim();
	if (cmd.length === 0 || cmd.length > 160)
		return null;
	if (!/^AT(?:$|[+&*#A-Z0-9?=,;:" ._\-\/]*)$/i.test(cmd))
		return null;
	return cmd;
}

return view.extend({
	render: function() {
		const port = E('select', { 'class': 'cbi-input-select' }, [
			E('option', { 'value': '2', 'selected': 'selected' }, 'ttyUSB2'),
			E('option', { 'value': '3' }, 'ttyUSB3')
		]);
		const input = E('input', {
			'type': 'text',
			'class': 'cbi-input-text',
			'maxlength': '160',
			'placeholder': 'AT+QENG="servingcell"'
		});
		const output = E('textarea', {
			'readonly': 'readonly',
			'rows': '24',
			'style': 'width:100%; font-family:monospace;'
		});
		const pendingText = _('发送中...');
		let sendButton;
		let sending = false;

		function send() {
			const cmd = validCommand(input.value);
			if (!cmd) {
				ui.addNotification(null, E('p', _('请输入以 AT 开头的有效命令，不能包含换行或控制字符。')));
				return Promise.resolve();
			}
			if (sending)
				return Promise.resolve();

			sending = true;
			if (sendButton)
				sendButton.disabled = true;
			output.value = pendingText + '\n' + output.value;
			return execWithTimeout('/usr/share/modem/delatcmd.sh', [], AT_EXEC_TIMEOUT, _('清理 AT 结果'))
				.then(function() {
					return execWithTimeout('/usr/share/modem/atcmd.sh', [ port.value, cmd ], AT_EXEC_TIMEOUT, _('AT 命令'));
				})
				.then(function() {
					return fs.read('/tmp/result.at');
				})
				.then(function(text) {
					output.value = (text || '') + '\n' + output.value.replace(pendingText + '\n', '');
				})
				.catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				}).finally(function() {
					sending = false;
					if (sendButton)
						sendButton.disabled = false;
				});
		}

		sendButton = E('button', {
			'class': 'cbi-button cbi-button-apply',
			'click': send
		}, _('发送'));

		return E([
			E('h2', _('调试工具')),
			E('div', { 'class': 'cbi-section' }, [
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('模块端口')),
					E('div', { 'class': 'cbi-value-field' }, port)
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('AT命令')),
					E('div', { 'class': 'cbi-value-field' }, input)
				]),
				E('div', { 'class': 'cbi-page-actions' }, [
					sendButton,
					' ',
					E('button', {
						'class': 'cbi-button cbi-button-reset',
						'click': function() { output.value = ''; }
					}, _('清除'))
				]),
				output
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
