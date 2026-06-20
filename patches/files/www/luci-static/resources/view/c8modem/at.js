'use strict';
'require view';
'require fs';
'require ui';

function validCommand(cmd) {
	cmd = (cmd || '').replace(/[\r\n\0]/g, ' ').trim();
	if (cmd.length === 0 || cmd.length > 160)
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

		function send() {
			const cmd = validCommand(input.value);
			if (!cmd) {
				ui.addNotification(null, E('p', _('请输入有效的 AT 命令')));
				return Promise.resolve();
			}

			output.value = pendingText + '\n' + output.value;
			return fs.exec('/usr/share/modem/delatcmd.sh')
				.then(function() {
					return fs.exec('/usr/share/modem/atcmd.sh', [ port.value, cmd ]);
				})
				.then(function() {
					return fs.read('/tmp/result.at');
				})
				.then(function(text) {
					output.value = (text || '') + '\n' + output.value.replace(pendingText + '\n', '');
				})
				.catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				});
		}

		return E([
			E('h2', _('AT命令工具')),
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
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						'click': send
					}, _('发送')),
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
