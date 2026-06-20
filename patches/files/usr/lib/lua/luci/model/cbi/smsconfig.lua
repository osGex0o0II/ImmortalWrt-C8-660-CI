-- Copyright 2020-2023 Rafa� Wabik (IceG) - From eko.one.pl forum
-- Licensed to the GNU General Public License v3.0.

local util = require "luci.util"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local safe = require "luci.c8modem.safe"
local uci = require "luci.model.uci".cursor()

local m
local s
local dev1, dev2, dev3, dev4, leds
local try_devices1 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices2 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices3 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices4 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_leds = nixio.fs.glob("/sys/class/leds/*")


local devv = safe.sms_port(uci:get("sms_tool", "general", "readport"))

local smsmem = safe.sms_storage(uci:get("sms_tool", "general", "storage"))

local statusb = safe.sms_status(smsmem, devv)

local smsnum = string.sub (statusb, 23, 27)

local smscount = string.match(smsnum, '%d+')

m = Map("sms_tool", "短信工具配置",
	"短信工具和GUI应用程序的配置面板")

s = m:section(NamedSection, 'general' , "sms_tool" , "" .. "")
s.anonymous = true
s:tab("sms", "短信设置")

this_tab = "sms"

dev1 = s:taboption(this_tab, Value, "readport", "SMS读取端口")
if try_devices1 then
local node
for node in try_devices1 do
dev1:value(node, node)
end
end
dev1.validate = function(self, value)
	if safe.sms_port(value) then
		return value
	end
	return nil, translate("请选择有效的短信读取端口")
end

mem = s:taboption(this_tab, ListValue, "storage", "消息存储区域", "消息存储在特定位置（例如SIM卡或模组内存），具体取决于设备类型。")
mem.default = "SM"
mem:value("SM", "SIM卡")
mem:value("ME", "模组内存")
mem.rmempty = true

local msm = s:taboption(this_tab, Flag, "mergesms", "合并分割消息", "启用此选项可更轻松阅读消息，但会导致显示和接收的消息数量不一致。")
msm.rmempty = false

msma = s:taboption(this_tab, ListValue, "algorithm", "合并算法", "")
msma.default = "Simple"
msma:value("Simple", "简单（不排序合并）")
msma:value("Advanced", "高级（排序合并）")
msma:depends("mergesms", "1")
msma.rmempty = true

msmd = s:taboption(this_tab, ListValue, "direction", "消息合并方向", "")
msmd.default = "Start"
msmd:value("Start", "从头到尾")
msmd:value("End", "从尾到头")
msmd:depends("algorithm", "Advanced")
msmd.rmempty = true

dev2 = s:taboption(this_tab, Value, "sendport", "SMS发送端口")
if try_devices2 then
local node
for node in try_devices2 do
dev2:value(node, node)
end
end
dev2.validate = function(self, value)
	if safe.sms_port(value) then
		return value
	end
	return nil, translate("请选择有效的短信发送端口")
end

local t = s:taboption(this_tab, Value, "pnumber", "前缀号码", "电话号码前需加国家前缀（中国为86，不加+）。若号码为5、4或3位，则视为短号，不加前缀。")
t.rmempty = true
t.default = 86
t.validate = function(self, value)
	if safe.decimal(value, 5) then
		return value
	end
	return nil, translate("号码前缀只能包含数字")
end

local f = s:taboption(this_tab, Flag, "prefix", "为电话号码添加前缀", "自动在电话号码字段中添加前缀。")
f.rmempty = false


local i = s:taboption(this_tab, Flag, "information", "号码和前缀说明", "在发送短信的标签页中显示前缀和正确电话号码的说明。")
i.rmempty = false

return m
