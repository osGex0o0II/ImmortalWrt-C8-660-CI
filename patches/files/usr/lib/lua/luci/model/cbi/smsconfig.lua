-- Copyright 2020-2023 Rafa� Wabik (IceG) - From eko.one.pl forum
-- Licensed to the GNU General Public License v3.0.

local util = require "luci.util"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local http = require "luci.http"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

local m
local s
local dev1, dev2, dev3, dev4, leds
local try_devices1 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices2 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices3 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices4 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_leds = nixio.fs.glob("/sys/class/leds/*")


local devv = tostring(uci:get("sms_tool", "general", "readport"))

local smsmem = tostring(uci:get("sms_tool", "general", "storage"))

local statusb = luci.util.exec("sms_tool -s".. smsmem .. " -d ".. devv .. " status")

local smsnum = string.sub (statusb, 23, 27)

local smscount = string.match(smsnum, '%d+')

m = Map("sms_tool", translate("Configuration sms-tool"),
	translate("Configuration panel for sms_tool and gui application."))

s = m:section(NamedSection, 'general' , "sms_tool" , "" .. translate(""))
s.anonymous = true
s:tab("sms", translate("SMS Settings"))

this_tab = "sms"

dev1 = s:taboption(this_tab, Value, "readport", translate("SMS Reading Port"))
if try_devices1 then
local node
for node in try_devices1 do
dev1:value(node, node)
end
end

mem = s:taboption(this_tab, ListValue, "storage", translate("Message storage area"), translate("Messages are stored in a specific location (for example, on the SIM card or modem memory), but other areas may also be available depending on the type of device."))
mem.default = "SM"
mem:value("SM", translate("SIM card"))
mem:value("ME", translate("Modem memory"))
mem.rmempty = true

local msm = s:taboption(this_tab, Flag, "mergesms", translate("Merge split messages"), translate("Checking this option will make it easier to read the messages, but it will cause a discrepancy in the number of messages shown and received."))
msm.rmempty = false

msma = s:taboption(this_tab, ListValue, "algorithm", translate("Merge algorithm"), translate(""))
msma.default = "Simple"
msma:value("Simple", translate("Simple (merge without sorting)"))
msma:value("Advanced", translate("Advanced (merges with sorting)"))
msma:depends("mergesms", "1")
msma.rmempty = true

msmd = s:taboption(this_tab, ListValue, "direction", translate("Direction of message merging"), translate(""))
msmd.default = "Start"
msmd:value("Start", translate("From beginning to end"))
msmd:value("End", translate("From end to beginning"))
msmd:depends("algorithm", "Advanced")
msmd.rmempty = true

dev2 = s:taboption(this_tab, Value, "sendport", translate("SMS Sending Port"))
if try_devices2 then
local node
for node in try_devices2 do
dev2:value(node, node)
end
end

local t = s:taboption(this_tab, Value, "pnumber", translate("Prefix Number"), translate("The phone number should be preceded by the country prefix (for Poland it is 48, without '+'). If the number is 5, 4 or 3 characters, it is treated as 'short' and should not be preceded by a country prefix."))
t.rmempty = true
t.default = 48

local f = s:taboption(this_tab, Flag, "prefix", translate("Add Prefix to Phone Number"), translate("Automatically add prefix to the phone number field."))
f.rmempty = false


local i = s:taboption(this_tab, Flag, "information", translate("Explanation of number and prefix"), translate("In the tab for sending SMSes, show an explanation of the prefix and the correct phone number."))
i.rmempty = false

return m
