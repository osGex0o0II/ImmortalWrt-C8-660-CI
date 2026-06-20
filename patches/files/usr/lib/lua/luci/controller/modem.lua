local http = require "luci.http"
local safe = require "luci.c8modem.safe"

module("luci.controller.modem", package.seeall)

function index()
	entry({"admin", "modem"}, firstchild(), _("蜂窝"), 25).dependent=false
	entry({"admin", "modem", "nets"}, template("zmode/net_status"), _("信号状态"), 97)
	entry({"admin", "modem", "at"}, template("zmode/at"), _("调试工具"), 98)
	entry({"admin", "modem", "modem"}, cbi("modem"), _("模块设置"), 99) 
	entry({"admin", "modem", "get_csq"}, call("action_get_csq"))
	entry({"admin", "modem", "send_atcmd"}, call("action_send_atcmd"))
end

function action_send_atcmd()
	local rv ={}
	local file
	local port = safe.at_port(http.formvalue("p"))
	local atcmd = safe.at_command(http.formvalue("set"))

	rv["at"] = atcmd or ""
	rv["port"] = port or ""

	if not port or not atcmd then
		rv["result"] = "Invalid AT command or modem port"
		http.prepare_content("application/json")
		http.write_json(rv)
		return
	end

	os.execute("/usr/share/modem/atcmd.sh " .. safe.shellquote(port) .. " " .. safe.shellquote(atcmd))
	local result = "/tmp/result.at"
	file = io.open(result, "r")
	if file ~= nil then
		rv["result"] = file:read("*all")
		file:close()
	else
		rv["result"] = " "
	end
	os.execute("/usr/share/modem/delatcmd.sh")
	http.prepare_content("application/json")
	http.write_json(rv)

end

function action_get_csq()
	os.execute("/usr/share/modem/zinfo.sh")
	local file
	local stat = "/tmp/cpe_cell.file"
	file = io.open(stat, "r")
	local rv ={}
	local function read_line()
		if file then
			return file:read("*line") or ""
		end
		return ""
	end
	rv["modem"] = read_line()
	rv["conntype"] = read_line()
	rv["firmware"] = read_line()
	rv["temper"] = read_line()
	rv["date"] = read_line()
	--------------------------------
	rv["simsel"] = read_line()
	rv["cops"] = read_line()
	rv["imei"] = read_line()
	rv["imsi"] = read_line()
	rv["iccid"] = read_line()
	rv["phone"] = read_line()
	--------------------------------
	rv["mode"] = read_line()
	rv["per"] = read_line()
	rv["rssi"] = read_line()
	rv["rsrq"] = read_line()
	rv["rscp"] = read_line()
	rv["sinr"] = read_line()
	-------------------------------
	rv["mcc"] = read_line()
	rv["lac"] = read_line()
	rv["cid"] = read_line()
	rv["band"] = read_line()
	rv["rfcn"] = read_line()
	rv["pci"] = read_line()
	--------------------------------
	if file then
		file:close()
	end
	http.prepare_content("application/json")
	http.write_json(rv)
end
