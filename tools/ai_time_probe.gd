extends Node

## AI 决策耗时探针（2026-07-09·查"点击确认→结算"主线程卡顿·纯引擎层无 UI）：
##   godot --headless --path . res://tools/ai_time_probe.tscn
## 复现 _on_confirm_pressed 里同步跑的 _ai_pick(AI) 路径（plan_economy + choose_action），
## 用战斗屏默认双方阵容 + econ_init 道具经济，攒对攒推进回合逼近真实局中期搜索空间。
## 若量级 ~数百 ms 即卡顿实锤 = AI 搜索主线程同步，与立绘缩放无关。

const HERO_DATA_DIR := "res://assets/data/heroes/"
const P0_IDS := ["h01", "h05", "h06"]
const P1_IDS := ["h02", "h09", "h12"]


func _ready() -> void:
	var b := BattleCore.new()
	b.setup(_team(P0_IDS), _team(P1_IDS), 777)
	b.econ_init()
	var ai := BattleAI.new(0, 2, 0, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	for round_i in range(8):
		var t0: int = Time.get_ticks_usec()
		ai.plan_economy(b, 1, rng)
		var t1: int = Time.get_ticks_usec()
		var choice: Dictionary = ai.choose_action(b, 1)
		var t2: int = Time.get_ticks_usec()
		print("回合 %d: plan_economy=%.1fms  choose_action=%.1fms  合计=%.1fms  (能量=%s 选招=%s)" % [
			round_i + 1, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t2 - t0) / 1000.0,
			str(b.energy), str(choice.get("action"))])
		b.select_action(0, ActionDef.Action.CHARGE)
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()

	get_tree().quit()


func _team(ids: Array) -> Array:
	var t: Array = []
	for id in ids:
		t.append(load(HERO_DATA_DIR + str(id) + ".tres"))
	return t
