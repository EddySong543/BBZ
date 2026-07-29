extends Node

## 远征真战斗回图链路截图 runner（任务 D 自检）：
##   godot --path . res://tools/pve_return_shot_runner.tscn
## 伪造"刚打完一场胜仗"的交接状态 → 实例化 expedition_screen → 验 _resume_from_battle：
## 地图状态恢复 + 怪物格清除 + 战利品入拾取区 + 日志战报 + 刻回写。

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")

const OUT := "D:/Game/BoBoZan/_probe_output/pve_return.png"


func _ready() -> void:
	var map: MapState = MapState.new()
	map.setup(777)
	var c: Vector2i = map.monsters.keys()[0]
	map.resolve_encounter(c)
	BattleSetup.expedition_state = {"map": map, "bp": Backpack.new(), "pending": [],
		"log": ["踏入迷雾（种子 777）。", "遭遇 %s → 进真战斗！" % String(map.monsters[c]["name"])],
		"seed": 777, "tile": c, "wanderer": false, "flee_from": map.start_pos}
	BattleSetup.pve_result = {"outcome": "win", "beats": 9, "team_hp": [6], "monster_hp": 0}
	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.6).timeout
	await _shot(OUT)
	print("恢复校验：怪物格已清=%s ｜ 拾取区件数=%d ｜ 刻=%.1f（应 4.5）｜ 前排 HP=%.1f（应 3.0）" % [
		str(not screen.map.monsters.has(c)), screen.pending.size(), screen.map.ticks(), float(screen.map.team[0]["hp"])])
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
