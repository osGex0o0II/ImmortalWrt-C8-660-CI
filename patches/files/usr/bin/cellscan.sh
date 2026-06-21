#!/bin/sh

LOCK_DIR="/tmp/cellscan.lock"
OUT_JSON="/tmp/cellscan.json"
OUT_TEXT="/tmp/cellinfo"
OUT_LOG="/tmp/cellscan.log"
TIMEOUT="${CELLSCAN_TIMEOUT:-240}"
SCAN_MODE="${CELLSCAN_MODE:-3}"
SCAN_EXT="${CELLSCAN_EXT:-1}"
TMP_CELLS=""
START_TS=""
PORT=""
COMMAND=""
PHASE=""
LAST_RESPONSE=""

json_escape() {
	printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g'
}

now_ts() {
	date +%s
}

status_elapsed() {
	[ -n "$START_TS" ] || START_TS="$(now_ts)"
	echo $(( $(now_ts) - START_TS ))
}

operator_name() {
	case "$1" in
		46000|46002|46007|46008|46020) echo "中国移动" ;;
		46001|46006|46009) echo "中国联通" ;;
		46003|46005|46011) echo "中国电信" ;;
		46015) echo "中国广电" ;;
		*) echo "未知运营商" ;;
	esac
}

resolve_port() {
	PORT="$(uci -q get sms_tool.general.atport || uci -q get sms_tool.general.readport || echo /dev/ttyUSB2)"
	case "$PORT" in
		[0-9]) PORT="/dev/ttyUSB$PORT" ;;
	esac
	case "$PORT" in
		/dev/ttyUSB[0-9]*|/dev/ttyACM[0-9]*) ;;
		*) PORT="/dev/ttyUSB2" ;;
	esac
}

write_json() {
	local status="$1"
	local message="$2"
	local detail="$3"
	local elapsed remaining progress cells_file json_tmp

	case "$TIMEOUT" in
		''|*[!0-9]*) TIMEOUT=240 ;;
	esac
	[ "$TIMEOUT" -gt 0 ] || TIMEOUT=240

	elapsed="$(status_elapsed)"
	remaining=$((TIMEOUT - elapsed))
	[ "$remaining" -lt 0 ] && remaining=0

	if [ "$status" = "running" ]; then
		progress=$((elapsed * 100 / TIMEOUT))
		[ "$progress" -gt 99 ] && progress=99
	elif [ "$status" = "done" ] || [ "$status" = "timeout" ] || [ "$status" = "error" ]; then
		progress=100
	else
		progress=0
	fi

	cells_file="${TMP_CELLS:-}"
	json_tmp="${OUT_JSON}.$$"
	{
		printf '{'
		printf '"status":"%s",' "$(json_escape "$status")"
		printf '"message":"%s",' "$(json_escape "$message")"
		printf '"detail":"%s",' "$(json_escape "$detail")"
		printf '"phase":"%s",' "$(json_escape "$PHASE")"
		printf '"last_response":"%s",' "$(json_escape "$LAST_RESPONSE")"
		printf '"port":"%s",' "$(json_escape "$PORT")"
		printf '"command":"%s",' "$(json_escape "$COMMAND")"
		printf '"timeout":%s,' "$TIMEOUT"
		printf '"elapsed":%s,' "$elapsed"
		printf '"remaining":%s,' "$remaining"
		printf '"progress":%s,' "$progress"
		printf '"started":"%s",' "$(date -d "@$START_TS" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')"
		printf '"updated":"%s",' "$(date '+%Y-%m-%d %H:%M:%S')"
		printf '"cells":['
		if [ -n "$cells_file" ] && [ -s "$cells_file" ]; then
			sed '$!s/$/,/' "$cells_file"
		fi
		printf ']}'
		printf '\n'
	} > "$json_tmp" && mv "$json_tmp" "$OUT_JSON"
}

write_idle() {
	START_TS="$(now_ts)"
	PHASE=""
	COMMAND=""
	resolve_port
	write_json "idle" "尚未扫描" ""
}

is_running() {
	[ -f "$LOCK_DIR/pid" ] || return 1
	local pid
	pid="$(cat "$LOCK_DIR/pid" 2>/dev/null)"
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

pause_helpers() {
	local name pids pid
	: > "$LOCK_DIR/helpers"

	for name in netmodeled.sh ipcheck.sh autofreqlock.sh; do
		pids="$(ps | awk -v n="$name" '$0 ~ n && $0 !~ /awk/ {print $1}')"
		[ -n "$pids" ] || continue
		echo "$name" >> "$LOCK_DIR/helpers"
		for pid in $pids; do
			kill "$pid" 2>/dev/null || true
		done
	done
	sleep 1
}

helper_running() {
	ps | grep -F "$1" | grep -v grep >/dev/null 2>&1
}

resume_helpers() {
	[ -f "$LOCK_DIR/helpers" ] || return 0

	if grep -q '^netmodeled\.sh$' "$LOCK_DIR/helpers" 2>/dev/null; then
		if ! helper_running '/usr/share/modem/netmodeled.sh'; then
			/usr/share/modem/netmodeled.sh >/dev/null 2>&1 &
		fi
	fi
	if grep -q '^ipcheck\.sh$' "$LOCK_DIR/helpers" 2>/dev/null; then
		if ! helper_running '/usr/share/modem/ipcheck.sh'; then
			/usr/share/modem/ipcheck.sh >/dev/null 2>&1 &
		fi
	fi
	if grep -q '^autofreqlock\.sh$' "$LOCK_DIR/helpers" 2>/dev/null &&
		[ "$(uci -q get modem.@ndis[0].autofreqlock || echo 0)" = "1" ]; then
		if ! helper_running '/usr/share/modem/autofreqlock.sh'; then
			/usr/share/modem/autofreqlock.sh >/dev/null 2>&1 &
		fi
	fi
}

cleanup() {
	resume_helpers
	rm -rf "$LOCK_DIR"
	rm -f "$TMP_CELLS"
}

append_cell() {
	local line="$1"
	local mode mcc mnc freq pci rsrp rsrq srx qvalue cellid tac bandwidth band operator_code operator

	line="$(printf '%s' "$line" | tr -d '\r')"
	line="${line#"+QSCAN:"}"
	line="$(printf '%s' "$line" | tr -d '" ')"

	mode="$(printf '%s' "$line" | awk -F, '{print $1}')"
	case "$mode" in
		LTE|NR5G) ;;
		*) return 0 ;;
	esac

	mcc="$(printf '%s' "$line" | awk -F, '{print $2}')"
	mnc="$(printf '%s' "$line" | awk -F, '{print $3}')"
	freq="$(printf '%s' "$line" | awk -F, '{print $4}')"
	pci="$(printf '%s' "$line" | awk -F, '{print $5}')"
	rsrp="$(printf '%s' "$line" | awk -F, '{print $6}')"
	rsrq="$(printf '%s' "$line" | awk -F, '{print $7}')"
	srx="$(printf '%s' "$line" | awk -F, '{print $8}')"
	qvalue="$(printf '%s' "$line" | awk -F, '{print $9}')"
	cellid="$(printf '%s' "$line" | awk -F, '{print $10}')"
	tac="$(printf '%s' "$line" | awk -F, '{print $11}')"
	bandwidth="$(printf '%s' "$line" | awk -F, '{print $12}')"
	band="$(printf '%s' "$line" | awk -F, '{print $13}')"
	operator_code="${mcc}${mnc}"
	operator="$(operator_name "$operator_code")"

	[ -n "$mode" ] || return 0

	printf 'Mode:%s Operator:%s freq:%s pci:%s rsrp:%s rsrq:%s\n' \
		"$mode" "$operator" "$freq" "$pci" "$rsrp" "$rsrq" >> "$OUT_TEXT"

	printf '{"mode":"%s","operator":"%s","mcc":"%s","mnc":"%s","earfcn":"%s","pci":"%s","signal":"%s","rsrp":"%s","rsrq":"%s","srxlev":"%s","quality":"%s","cellid":"%s","tac":"%s","bandwidth":"%s","band":"%s","raw":"%s"}\n' \
		"$(json_escape "$mode")" \
		"$(json_escape "$operator")" \
		"$(json_escape "$mcc")" \
		"$(json_escape "$mnc")" \
		"$(json_escape "$freq")" \
		"$(json_escape "$pci")" \
		"$(json_escape "$rsrp")" \
		"$(json_escape "$rsrp")" \
		"$(json_escape "$rsrq")" \
		"$(json_escape "$srx")" \
		"$(json_escape "$qvalue")" \
		"$(json_escape "$cellid")" \
		"$(json_escape "$tac")" \
		"$(json_escape "$bandwidth")" \
		"$(json_escape "$band")" \
		"$(json_escape "$line")" >> "$TMP_CELLS"
}

open_port() {
	if [ ! -c "$PORT" ]; then
		write_json "error" "模块端口不存在" "当前配置的 AT 端口为 $PORT，请检查短信工具/模块端口设置。"
		return 1
	fi

	exec 3<> "$PORT" || {
		write_json "error" "无法打开模块端口" "端口 $PORT 打开失败，可能被其它进程占用。"
		return 1
	}
	return 0
}

drain_port() {
	local end line
	end=$(( $(now_ts) + 1 ))
	while [ "$(now_ts)" -lt "$end" ]; do
		IFS= read -r -t 1 line <&3 || break
		:
	done
}

run_at() {
	local cmd="$1"
	local wait_s="$2"
	local phase="$3"
	local collect="${4:-0}"
	local end line

	COMMAND="$cmd"
	PHASE="$phase"
	LAST_RESPONSE=""
	write_json "running" "扫描中" "$phase"

	printf '%s\r\n' "$cmd" >&3
	end=$(( $(now_ts) + wait_s ))

	while [ "$(now_ts)" -lt "$end" ]; do
		if IFS= read -r -t 1 line <&3; then
			line="$(printf '%s' "$line" | tr -d '\r')"
			[ -n "$line" ] || continue
			LAST_RESPONSE="$line"
			printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$line"

			if [ "$collect" = "1" ]; then
				case "$line" in
					+QSCAN*) append_cell "$line" ;;
				esac
			fi
			case "$line" in
				*OK*)
					write_json "running" "扫描中" "$phase"
					return 0
				;;
				*ERROR*|*"+CME ERROR"*)
					write_json "running" "扫描中" "$phase"
					return 2
				;;
			esac
		fi
		write_json "running" "扫描中" "$phase"
	done

	return 1
}

run_scan() {
	local rc cmd detail

	START_TS="$(now_ts)"
	resolve_port
	TMP_CELLS="$(mktemp /tmp/cellscan.cells.XXXXXX)"
	>"$OUT_TEXT"
	>"$OUT_LOG"

	if ! mkdir "$LOCK_DIR" 2>/dev/null; then
		write_json "busy" "基站扫描正在运行" "如果页面长时间停留在扫描中，可点击停止扫描后重试。"
		exit 1
	fi

	echo "$$" > "$LOCK_DIR/pid"
	trap 'write_json "stopped" "已停止页面等待" "已停止本次页面等待；如果模组已经开始 QSCAN，底层 AT 命令无法立即取消，可能还会继续几分钟，请稍后再重新扫描。"; cleanup; exit 0' INT TERM
	trap 'cleanup' EXIT

	write_json "running" "准备扫描" "正在暂停后台 AT 检查任务，避免抢占模块端口。"
	pause_helpers
	killall sendat 2>/dev/null || true

	if ! open_port; then
		exit 1
	fi

	drain_port
	if ! run_at "AT" 8 "检查模块 AT 端口"; then
		write_json "error" "AT 端口无响应" "模块没有响应 AT。可能是端口被占用、模组忙于网络注册、或刚执行过扫描仍在恢复；请等待 1 分钟后重试。"
		exit 1
	fi

	run_at "AT+QSCAN=?" 12 "确认模组是否支持基站扫描" >/dev/null 2>&1 || true

	cmd="AT+QSCAN=${SCAN_MODE},${SCAN_EXT}"
	detail="正在执行 $cmd。Quectel 文档标注 QSCAN 最大响应时间约 180 秒，本页面预留 ${TIMEOUT} 秒；扫描期间蜂窝数据可能短暂不可用。"
	run_at "$cmd" "$TIMEOUT" "$detail" 1
	rc=$?
	if [ "$rc" -eq 0 ]; then
		if [ -s "$TMP_CELLS" ]; then
			write_json "done" "基站扫描完成" "扫描完成，共发现 $(wc -l < "$TMP_CELLS" | tr -d ' ') 个小区。"
			awk '{print NR, $0}' "$OUT_TEXT"
		else
			write_json "done" "基站扫描完成但无结果" "模组返回 OK，但没有返回小区列表。当前网络、SIM 状态或运营商策略可能限制完整邻区扫描。"
		fi
		exit 0
	fi

	if [ "$rc" -eq 2 ] && [ "$SCAN_EXT" = "1" ]; then
		cmd="AT+QSCAN=${SCAN_MODE},0"
		detail="扩展扫描返回错误，正在降级为 $cmd。"
		run_at "$cmd" "$TIMEOUT" "$detail" 1
		rc=$?
		if [ "$rc" -eq 0 ]; then
			if [ -s "$TMP_CELLS" ]; then
				write_json "done" "基站扫描完成" "扩展扫描不被支持，已用兼容模式完成扫描。"
			else
				write_json "done" "基站扫描完成但无结果" "兼容模式返回 OK，但没有返回小区列表。"
			fi
			exit 0
		fi
	fi

	if [ -s "$TMP_CELLS" ]; then
		write_json "done" "基站扫描完成" "模组未返回结束标记，但已经收到部分小区结果。"
	elif [ "$rc" -eq 2 ]; then
		write_json "error" "模组拒绝基站扫描" "最后响应：$LAST_RESPONSE。当前固件/网络模式/SIM 状态可能不支持该扫描命令。"
	else
		write_json "timeout" "基站扫描超时或无结果" "等待 ${TIMEOUT} 秒未收到小区列表。模组可能仍在收尾并稍后恢复 AT 响应，请等待几分钟后重试；扫描时请避免频繁刷新模块状态或重启蜂窝网络。"
	fi
}

resolve_port
case "$1" in
	start)
		if is_running; then
			[ -s "$OUT_JSON" ] && cat "$OUT_JSON" || {
				START_TS="$(now_ts)"
				write_json "busy" "基站扫描正在运行" "请等待当前扫描完成，或点击停止扫描。"
				cat "$OUT_JSON"
			}
			exit 0
		fi
		rm -rf "$LOCK_DIR"
		START_TS="$(now_ts)"
		COMMAND="AT+QSCAN=${SCAN_MODE},${SCAN_EXT}"
		PHASE="排队启动"
		write_json "running" "开始基站扫描" "通常需要 1-3 分钟，最多等待约 ${TIMEOUT} 秒；扫描期间蜂窝连接可能短暂不可用。"
		CELLSCAN_RUN=1 "$0" run > "$OUT_LOG" 2>&1 &
		cat "$OUT_JSON"
		exit 0
	;;
	stop)
		if is_running; then
			kill "$(cat "$LOCK_DIR/pid")" 2>/dev/null || true
			sleep 1
		fi
		rm -rf "$LOCK_DIR"
		START_TS="$(now_ts)"
		write_json "stopped" "已停止页面等待" "已停止本次页面等待；如果模组已经开始 QSCAN，底层 AT 命令无法立即取消，可能还会继续几分钟，请稍后再重新扫描。"
		cat "$OUT_JSON"
		exit 0
	;;
	status)
		[ -s "$OUT_JSON" ] || write_idle
		cat "$OUT_JSON"
		exit 0
	;;
	run)
		run_scan
	;;
	*)
		echo "Usage: $0 {start|stop|status}" >&2
		exit 1
	;;
esac
