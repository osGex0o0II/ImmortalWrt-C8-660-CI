local util = require "luci.util"

local M = {}

function M.shellquote(value)
	if util.shellquote then
		return util.shellquote(tostring(value or ""))
	end

	return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

function M.sms_port(value)
	value = tostring(value or "")
	if value:match("^/dev/ttyUSB%d+$") or
	   value:match("^/dev/ttyACM%d+$") or
	   value:match("^/dev/cdc%-wdm%d+$") then
		return value
	end
end

function M.at_port(value)
	value = tostring(value or "")
	if value:match("^%d%d?$") then
		return value
	end

	return M.sms_port(value)
end

function M.sms_storage(value)
	value = tostring(value or "")
	if value == "SM" or value == "ME" then
		return value
	end

	return "ME"
end

function M.at_command(value)
	value = tostring(value or "")
	value = value:gsub("[%z\r\n]", " "):match("^%s*(.-)%s*$")

	if #value == 0 or #value > 160 then
		return nil
	end

	return value
end

function M.phone_number(value)
	value = tostring(value or ""):gsub("%s+", "")
	value = value:gsub("^%+", "")

	if value:match("^%d%d%d*$") and #value <= 20 then
		return value
	end
end

function M.sms_index(value)
	value = tostring(value or "")
	local indexes = {}
	local seen = {}

	for index in value:gmatch("%d+") do
		local number = tonumber(index)
		if number and number >= 0 and number <= 99999 and not seen[number] then
			seen[number] = true
			indexes[#indexes + 1] = tostring(number)
		end
	end

	table.sort(indexes, function(a, b)
		return tonumber(a) > tonumber(b)
	end)

	return indexes
end

function M.pdu_segment(value)
	value = tostring(value or "")
	if value:match("^[0-9A-F ]+$") then
		return value
	end
end

function M.apn(value)
	value = tostring(value or ""):match("^%s*(.-)%s*$")
	if value == "" or (#value <= 64 and value:match("^[A-Za-z0-9_.-]+$")) then
		return value
	end
end

function M.pin(value)
	value = tostring(value or "")
	if value == "" or value:match("^%d%d%d%d%d?%d?%d?%d?$") then
		return value
	end
end

function M.decimal(value, maxlen)
	value = tostring(value or "")
	maxlen = maxlen or 10
	if value == "" or (value:match("^%d+$") and #value <= maxlen) then
		return value
	end
end

function M.token(value, maxlen)
	value = tostring(value or ""):match("^%s*(.-)%s*$")
	maxlen = maxlen or 128
	if value == "" or (#value <= maxlen and value:match("^[A-Za-z0-9_.:-]+$")) then
		return value
	end
end

function M.readfile(path, fallback)
	local file = io.open(path, "r")
	if not file then
		return fallback or ""
	end

	local data = file:read("*all") or ""
	file:close()
	return data
end

function M.sms_status(storage, port)
	local dev = M.sms_port(port)
	local mem = M.sms_storage(storage)

	if not dev then
		return ""
	end

	return util.exec("sms_tool -s" .. mem .. " -d " .. M.shellquote(dev) .. " status 2>/dev/null") or ""
end

function M.sms_status_info(storage, port)
	local text = M.sms_status(storage, port)
	local mem, used, total = text:match("Storage type:%s*([^,%s]+),%s*used:%s*(%d+),%s*total:%s*(%d+)")

	return {
		storage = M.sms_storage(mem or storage),
		used = tonumber(used) or 0,
		total = tonumber(total) or 0
	}
end

function M.sms_json(storage, port)
	local dev = M.sms_port(port)
	local mem = M.sms_storage(storage)

	if not dev then
		return "[]"
	end

	local output = util.exec("sms_tool -s" .. mem .. " -d " .. M.shellquote(dev) ..
		" -f '%Y-%m-%d %H:%M' -j recv 2>/dev/null") or ""

	local json = output:match("(%b[])")
	return json or "[]"
end

function M.sms_raw_json(storage, port)
	local dev = M.sms_port(port)
	local mem = M.sms_storage(storage)
	local output

	if not dev then
		return "{}"
	end

	output = util.exec("sms_tool -s" .. mem .. " -d " .. M.shellquote(dev) ..
		" -f '%Y-%m-%d %H:%M' -j recv 2>/dev/null") or "{}"

	return output:match("(%b{})") or output:match("(%b[])") or "{}"
end

return M
