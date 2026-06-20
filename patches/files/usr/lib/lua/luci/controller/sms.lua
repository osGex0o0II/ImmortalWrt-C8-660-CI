-- Copyright 2020-2022 Rafa³ Wabik (IceG) - From eko.one.pl forum
-- Licensed to the GNU General Public License v3.0.

	local util = require "luci.util"
	local fs = require "nixio.fs"
	local sys = require "luci.sys"
	local http = require "luci.http"
	local dispatcher = require "luci.dispatcher"
	local safe = require "luci.c8modem.safe"
	local uci = require "luci.model.uci".cursor()

module("luci.controller.sms", package.seeall)

function index()
	entry({"admin", "modem", "readsms"},template("modem/readsms"),translate("Received Messages"), 20)
 	entry({"admin", "modem", "sendsms"},template("modem/sendsms"),translate("Send Messages"), 30)
	if nixio.fs.access("/etc/config/sms_tool") then
        entry({"admin", "modem", "smsconfig"}, cbi("smsconfig"), translate("Configuration"), 50)
    end
	entry({"admin", "modem", "delete_one"}, call("delete_sms", smsindex), nil).leaf = true
	entry({"admin", "modem", "delete_all"}, call("delete_all_sms"), nil).leaf = true
	entry({"admin", "modem", "run_sms"}, call("sms"), nil).leaf = true
	entry({"admin", "modem", "readsim"}, call("slots"), nil).leaf = true
end


function delete_sms(smsindex)
	local devv = safe.sms_port(uci:get("sms_tool", "general", "readport"))
	if not devv then
		return
	end

	for _, d in ipairs(safe.sms_index(smsindex)) do
		os.execute("sms_tool -d " .. safe.shellquote(devv) .. " delete " .. d)
	end
end

function delete_all_sms()
	local devv = safe.sms_port(uci:get("sms_tool", "general", "readport"))
	if not devv then
		return
	end

	os.execute("sms_tool -d " .. safe.shellquote(devv) .. " delete all")
end


function sms()
    local sms_code = http.formvalue("scode")

    if sms_code then
		local nr = safe.phone_number(string.sub(sms_code, 1, 20))
		local msgall = string.sub(sms_code, 21)
		local msg = string.gsub(msgall or "", "\n", " ")

		if not nr or #msg == 0 or #msg > 670 then
			http.status(400, "Invalid SMS request")
			http.write("Invalid SMS request")
			return
		end

		local odp = encodeToPDU(nr, msg)
        http.write(tostring(odp or ""))
    else
        http.write_json(http.formvalue())
    end

end

function encodeToPDU(phoneNumber, message)
    local smsc=""
    local function TONGen(input, isPhonenum)
        local TONBegin = "91"
        local orinInput = input
        if #input % 2 == 1 then
            input = input .. 'F'
        end
        -- 交换数位
        local transformed = {}
        for i = 1, #input, 2 do
            local firstChar = input:sub(i, i)
            local secondChar = input:sub(i + 1, i + 1)
            transformed[#transformed + 1] = secondChar
            transformed[#transformed + 1] = firstChar
        end
        local TONStr = TONBegin .. table.concat(transformed)
        local TONLength = 0
        if (isPhonenum == false) then
            TONLength = string.len(TONStr) / 2
        else
            TONLength = string.format("%02X", string.len(orinInput))
        end
        if (string.len(TONLength) < 2) then
            TONLength = "0" .. TONLength
        end
        return TONLength .. TONStr
    end

    local function splitMessage(msg,subLen)
        local segments = {}
        local len = string.len(msg)
        local i = 1
        while i <= len do
            local segment = msg:sub(i,i+subLen-1)
            segments[#segments + 1] = segment
            i = i + subLen
        end
        return segments
    end
    
    local function generateRandomInt8()
        math.randomseed(os.time())
        local randomInt8 = math.random(0, 255)
        return randomInt8
    end
        

    local SCA=TONGen(smsc, false)
    local MTI0='1'
    local MTI1='0'
    local RD='0'
    local VPF0='0'
    local VPF1='0'
    local SR='0'
    local UDHI='0'
    local RP='0'
    local pdu
    local TPMR = "00"
    local phoneNumEncode = TONGen(phoneNumber, true)
    local TPPID = "00"
    local TPDCS = "08"
    local MSG = encodeToUCS2(message) 
    local sendLimit=60*4
  
        if string.len(MSG) >= sendLimit then
            UDHI='1'
        end
        local PDUType  = RP .. UDHI .. SR .. VPF1 .. VPF0 .. RD .. MTI1 .. MTI0

        local decimalValue = tonumber(PDUType, 2)
        PDUType = string.format("%02X", decimalValue)  
        if (string.len(smsc) == 0) then
            pdu = "00" .. PDUType  .. TPMR .. phoneNumEncode
        else
            pdu = SCA .. PDUType  .. TPMR .. phoneNumEncode
        end

    local sendList={}
    if string.len(MSG) <= sendLimit then
        local MSGLen = string.format("%02X", string.len(MSG) / 2)
        local AllMsgLen = 7 + string.len(phoneNumEncode) / 2 + string.len(MSG) / 2 - 2
        pdu = AllMsgLen .. " " .. pdu .. TPPID .. TPDCS .. MSGLen .. MSG
        sendList[#sendList + 1]=pdu
    else
        local RefSeq=generateRandomInt8()
        local segments = splitMessage(MSG,sendLimit)
        for i, segment in ipairs(segments) do
            local UDHIHeader = string.format("05%02X%02X%02X%02X%02X", 0,3,RefSeq,#segments,i)
            local MSGLen = string.format("%02X", string.len(segment) / 2 + 6)
            segment=UDHIHeader .. segment
            local AllMsgLen = 7 + string.len(phoneNumEncode) / 2 + string.len(segment) / 2 - 2 
            local currentPdu = AllMsgLen .. " " .. pdu  .. TPPID .. TPDCS .. MSGLen .. segment
            sendList[#sendList + 1]=currentPdu
        end
    end
    local file = io.open("/tmp/sms.log", "a")
    if file then
        file:write(table.concat(sendList),"\n")
        file:close()
    end

	local output = {}
    for i, segment in ipairs(sendList) do
		local safe_segment = safe.pdu_segment(segment)
		if safe_segment then
			local odpall = io.popen("/usr/share/modem/mopdu " .. safe_segment .. " 2>&1")
			if odpall then
				output[#output + 1] = odpall:read("*a") or ""
				odpall:close()
			end
			os.execute("sleep 2")
		end
    end
    return table.concat(output)

end

function encodeToUCS2(text)
    local ucs2 = {}
    local index = 1
    local length = string.len(text)

    while index <= length do
        local byte1 = string.byte(text, index)

        if byte1 < 128 then
            ucs2[#ucs2 + 1] = string.format("%04X", byte1)
            index = index + 1
        elseif byte1 >= 192 and byte1 < 224 then
            local byte2 = string.byte(text, index + 1)
            ucs2[#ucs2 + 1] = string.format("%04X", (byte1 - 192) * 64 + (byte2 - 128))
            index = index + 2
        elseif byte1 >= 224 then
            local byte2 = string.byte(text, index + 1)
            local byte3 = string.byte(text, index + 2)
            ucs2[#ucs2 + 1] = string.format("%04X", (byte1 - 224) * 4096 + (byte2 - 128) * 64 + (byte3 - 128))
            index = index + 3
        else
            return nil
        end
    end

    return table.concat(ucs2)
end


function slots()
	local sim = { }
	local devv = safe.sms_port(uci:get("sms_tool", "general", "readport"))
	local smsmem = safe.sms_storage(uci:get("sms_tool", "general", "storage"))

	local statusb = safe.sms_status(smsmem, devv)
	local usex = string.sub (statusb, 23, 27)
	local max = statusb:match('[^: ]+$')
	sim["use"] = string.match(usex, '%d+')
	local smscount = string.match(usex, '%d+')
	sim["all"] = string.match(max or "", '%d+')
	luci.http.prepare_content("application/json")
	luci.http.write_json(sim)
end
