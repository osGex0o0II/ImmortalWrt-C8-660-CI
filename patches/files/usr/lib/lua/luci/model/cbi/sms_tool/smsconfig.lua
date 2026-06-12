-- Copyright 2020-2022 Rafa³ Wabik (IceG) - From eko.one.pl forum
-- Licensed to the GNU General Public License v3.0.

local m = Map("sms_tool", translate("SMS Tool Configuration"), translate("Configure SMS tool ports and settings."))

local s = m:section(TypedSection, "sms_tool")
s.anonymous = true
s.addremove = false

local prefix = s:option(Value, "prefix", translate("Country Prefix"))
prefix.default = "1"
prefix.rmempty = false

local sendport = s:option(Value, "sendport", translate("Send Port"))
sendport.default = "/dev/ttyUSB2"
sendport.rmempty = false

local ussdport = s:option(Value, "ussdport", translate("USSD Port"))
ussdport.default = "/dev/ttyUSB2"
ussdport.rmempty = false

local atport = s:option(Value, "atport", translate("AT Port"))
atport.default = "/dev/ttyUSB2"
atport.rmempty = false

local readport = s:option(Value, "readport", translate("Read Port"))
readport.default = "/dev/ttyUSB2"
readport.rmempty = false

local storage = s:option(ListValue, "storage", translate("SMS Storage"))
storage:value("ME", "ME")
storage:value("SM", "SIM")
storage:value("MT", "MT")
storage.default = "ME"

local pnumber = s:option(Value, "pnumber", translate("Phone Number Length"))
pnumber.default = "86"
pnumber.rmempty = false

local mergesms = s:option(Flag, "mergesms", translate("Merge Multi-part SMS"))
mergesms.default = "1"
mergesms.enabled = "1"
mergesms.disabled = "0"

local information = s:option(Flag, "information", translate("Show Information Messages"))
information.default = "0"
information.enabled = "1"
information.disabled = "0"

local algorithm = s:option(ListValue, "algorithm", translate("Sort Algorithm"))
algorithm:value("Advanced", "Advanced")
algorithm:value("Simple", "Simple")
algorithm.default = "Advanced"

local direction = s:option(ListValue, "direction", translate("Sort Direction"))
direction:value("Start", "Start")
direction:value("End", "End")
direction.default = "Start"

return m
