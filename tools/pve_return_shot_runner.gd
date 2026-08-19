extends Node

## 远征公共战斗回图链路截图 runner。
## 手工注入一个由真实 HeroData 表示的标准遭遇，伪造胜利结果后验证：
## 地图状态恢复 + 遭遇格清除 + 战利品入拾取区 + 队伍/时钟回写。

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")
const Layout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")

const OUT := "D:/Game/BoBoZan/_probe_output/pve_return.png"


func _ready() -> void:
	var map: MapState = MapState.new()
	map.setup(777)
	var leader := load("res://assets/data/heroes/h01.tres") as HeroData
	map.team = [{
		"hero_id": leader.hero_id,
		"name": leader.hero_name,
		"hp": float(leader.max_hp),
		"hp_max": float(leader.max_hp),
	}]
	var c: Vector2i = Layout.MONSTER_ANCHORS[0]
	var encounter := {
		"name": "手工注入遭遇",
		"opponents": [{"hero_id": "h02", "hp": 5.0, "hp_max": 5.0}],
		"loot": [{"id": "test_reward", "name": "测试战利品", "cat": "gold", "tier": 0,
			"shape": [Vector2i.ZERO], "gold": 20, "note": "回图链路测试", "icon": "gem"}],
	}
	if not map.inject_encounter(c, encounter):
		push_error("pve_return_shot_runner: 标准遭遇注入失败")
		get_tree().quit(1)
		return
	map.player = c
	BattleSetup.expedition_state = {"map": map, "bp": Backpack.new(), "pending": [],
		"log": ["踏入迷雾（种子 777）。", "遭遇 %s → 进公共战斗！" % String(encounter["name"])],
		"seed": 777, "tile": c, "flee_from": map.start_pos,
		"hero_portrait": leader.portrait_path}
	BattleSetup.pve_result = {"outcome": "win", "beats": 9, "team_hp": [6], "opponent_hp": [0]}
	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.6).timeout
	await _shot(OUT)
	print("恢复校验：遭遇格已清=%s ｜ 拾取区件数=%d ｜ 刻=%.1f（应 4.5）｜ 前排 HP=%.1f（应 3.0）" % [
		str(not screen.map.monsters.has(c)), screen.pending.size(), screen.map.ticks(), float(screen.map.team[0]["hp"])])
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
