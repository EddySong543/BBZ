#!/usr/bin/env bash
# T1 测量面板·并行版（A 档·2026-07-03）：三份分部（v1 内战/v2 内战/v1×v2 交叉）三进程并行，
# 全部完成后合并出 panel_summary.md。约 50 分钟 → ~20 分钟（结果与串行 --panel 完全一致：
# 三份本就相互独立、种子确定）。
#
# 用法（git bash·项目根或任意处）：
#   bash tools/sim/run_panel_parallel.sh <改动名> [seed=42] [depth=2] [games(冒烟用·默认 50/50/60)]
# 输出：tools/sim/out_panel_<改动名>/panel_summary.md + 三份完整报表（out_* 已被 gitignore 挡住）
set -e
NAME="${1:?用法: run_panel_parallel.sh <改动名> [seed] [depth] [games]}"
SEED="${2:-42}"
DEPTH="${3:-2}"
GAMES="${4:-}"
GODOT="${GODOT_BIN:-/d/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"

GAMES_ARG=()
[ -n "$GAMES" ] && GAMES_ARG=(--games "$GAMES")

OUT="$PROJ/tools/sim/out_panel_$NAME"
mkdir -p "$OUT"

run_part() {
	"$GODOT" --headless --path "$PROJ" --script res://tools/sim/run_sim.gd -- \
		--panel "$NAME" --panel-part "$1" --seed "$SEED" --depth "$DEPTH" "${GAMES_ARG[@]}" \
		> "$OUT/part_$1.log" 2>&1
}

echo "面板「$NAME」三份并行启动（seed=$SEED depth=$DEPTH）..."
run_part v1eco &
run_part v2eco &
run_part cross &
wait

"$GODOT" --headless --path "$PROJ" --script res://tools/sim/run_sim.gd -- \
	--panel "$NAME" --panel-merge 1 2>&1 | tail -2
echo "完成：tools/sim/out_panel_$NAME/panel_summary.md"
