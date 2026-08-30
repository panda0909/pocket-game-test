#!/usr/bin/env bash
# 完整驗證：語法檢查 → 單元測試 → 整合測試。
#
# 整合測試需要真正的算繪視窗（要驗證輸入路由與 UI），不能用 --headless。
# 這裡刻意不加 --quit-after：強制結束的結束碼是 0，會讓中途卡住的測試
# 看起來像通過。讓腳本自己 quit()。

set -uo pipefail

GODOT="${GODOT:-/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

status=0

echo "== 重新掃描專案 =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 語法檢查 =="
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	if ! "$GODOT" --headless --path . --check-only -s "$f" >/dev/null 2>&1; then
		echo "語法錯誤: $f"
		status=1
	fi
done
[ "$status" -eq 0 ] && echo "全部通過"

echo
echo "== 單元測試 =="
if ! tools/run_tests.sh; then
	status=1
fi

echo
echo "== 整合測試 =="
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
"$GODOT" --path . tools/integration_check.tscn >"$LOG" 2>&1
integration_exit=$?
grep -E "^(通過|失敗)|^整合測試|^環境|^---" "$LOG"
if [ "$integration_exit" -ne 0 ]; then
	echo "整合測試結束碼 ${integration_exit}"
	grep -iE "SCRIPT ERROR|Parse Error" "$LOG" | head -10
	status=1
fi

echo
if [ "$status" -eq 0 ]; then
	echo "=== 全部驗證通過 ==="
else
	echo "=== 有驗證項目失敗 ==="
fi
exit "$status"
