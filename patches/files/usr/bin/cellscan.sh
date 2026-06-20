#!/bin/sh

LOCK_DIR="/tmp/cellscan.lock"
OUT_JSON="/tmp/cellscan.json"
OUT_TEXT="/tmp/cellinfo"
OUT_LOG="/tmp/cellscan.log"
TIMEOUT="${CELLSCAN_TIMEOUT:-180}"
TMP_CELLS=""

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g'
}

finish_json() {
	local status="$1"
	local message="$2"

	{
		printf '{'
		printf '"status":"%s",' "$(json_escape "$status")"
		printf '"message":"%s",' "$(json_escape "$message")"
		printf '"port":"%s",' "$(json_escape "$PORT")"
		printf '"updated":"%s",' "$(date '+%Y-%m-%d %H:%M:%S')"
		printf '"cells":['
		if [ -s "$TMP_CELLS" ]; then
			sed '$!s/$/,/' "$TMP_CELLS"
		fi
		printf ']}'
		printf '\n'
	} > "$OUT_JSON"
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

PORT="$(uci -q get sms_tool.general.atport || uci -q get sms_tool.general.readport || echo /dev/ttyUSB2)"
case "$PORT" in
	/dev/ttyUSB[0-9]*|/dev/ttyACM[0-9]*) ;;
	*) PORT="/dev/ttyUSB2" ;;
esac

case "$1" in
	start)
		if [ -d "$LOCK_DIR" ]; then
			finish_json "busy" "基站扫描正在运行"
			echo "基站扫描正在运行"
			exit 0
		fi
		CELLSCAN_RUN=1 "$0" run > "$OUT_LOG" 2>&1 &
		finish_json "running" "开始基站扫描"
		echo "开始基站扫描"
		exit 0
	;;
	stop)
		if [ -f "$LOCK_DIR/pid" ]; then
			kill "$(cat "$LOCK_DIR/pid")" 2>/dev/null || true
		fi
		rm -rf "$LOCK_DIR"
		finish_json "stopped" "基站扫描已停止"
		echo "基站扫描已停止"
		exit 0
	;;
	status)
		[ -s "$OUT_JSON" ] || finish_json "idle" "尚未扫描"
		cat "$OUT_JSON"
		exit 0
	;;
esac

append_cell() {
	local line="$1"
	local mode mcc mnc earfcn pci signal operator_code operator

	line="$(printf '%s' "$line" | tr -d '\r')"
	line="${line#"+QSCAN:"}"
	line="$(printf '%s' "$line" | tr -d '" ')"

	mode="$(printf '%s' "$line" | awk -F, '{print $1}')"
	mcc="$(printf '%s' "$line" | awk -F, '{print $2}')"
	mnc="$(printf '%s' "$line" | awk -F, '{print $3}')"
	earfcn="$(printf '%s' "$line" | awk -F, '{print $4}')"
	pci="$(printf '%s' "$line" | awk -F, '{print $5}')"
	signal="$(printf '%s' "$line" | awk -F, '{print $6}')"
	operator_code="${mcc}${mnc}"
	operator="$(operator_name "$operator_code")"

	[ -n "$mode" ] || return 0

	printf 'Mode:%s Operator:%s earfcn:%s pci:%s signal:%s\n' \
		"$mode" "$operator" "$earfcn" "$pci" "$signal" >> "$OUT_TEXT"

	printf '{"mode":"%s","operator":"%s","mcc":"%s","mnc":"%s","earfcn":"%s","pci":"%s","signal":"%s","raw":"%s"}\n' \
		"$(json_escape "$mode")" \
		"$(json_escape "$operator")" \
		"$(json_escape "$mcc")" \
		"$(json_escape "$mnc")" \
		"$(json_escape "$earfcn")" \
		"$(json_escape "$pci")" \
		"$(json_escape "$signal")" \
		"$(json_escape "$line")" >> "$TMP_CELLS"
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
	finish_json "busy" "基站扫描正在运行"
	echo "基站扫描正在运行"
	exit 1
fi

TMP_CELLS="$(mktemp /tmp/cellscan.cells.XXXXXX)"
trap 'rm -rf "$LOCK_DIR"; rm -f "$TMP_CELLS"' EXIT INT TERM
echo "$$" > "$LOCK_DIR/pid"

>"$OUT_TEXT"
finish_json "running" "开始基站扫描"
echo "开始基站扫描，请等待..."

if [ ! -c "$PORT" ]; then
	finish_json "error" "模块端口不存在：$PORT"
	echo "模块端口不存在：$PORT"
	exit 1
fi

printf 'AT+QSCAN=3,0\r\n' > "$PORT"

START_TIME="$(date +%s)"
exec 3< "$PORT"
while :; do
	NOW_TIME="$(date +%s)"
	ELAPSED=$((NOW_TIME - START_TIME))
	[ "$ELAPSED" -ge "$TIMEOUT" ] && break

	if ! IFS= read -r -t 1 line <&3; then
		continue
	fi

	case "$line" in
		+QSCAN*) append_cell "$line" ;;
	esac

	case "$line" in
		*OK*)
			finish_json "done" "基站扫描完成"
			echo "基站扫描完成"
			awk '{print NR, $0}' "$OUT_TEXT"
			exit 0
		;;
		*ERROR*)
			finish_json "error" "模组返回 ERROR"
			echo "模组返回 ERROR"
			exit 1
		;;
	esac
done
exec 3<&-

if [ -s "$TMP_CELLS" ]; then
	finish_json "done" "基站扫描完成"
	awk '{print NR, $0}' "$OUT_TEXT"
else
	finish_json "timeout" "基站扫描超时或无结果"
	echo "基站扫描超时或无结果"
fi
