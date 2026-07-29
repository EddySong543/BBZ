extends Node

## 远征 PvE 真战斗截图 runner（任务 D 自检·完整引擎模式）：
##   godot --path . res://tools/pve_battle_shot_runner.tscn
## 模拟 expedition_screen 的交接：设 BattleSetup pve_* → 实例化 battle_screen → 截图
## （验：明牌概率表 / 脱离按钮 / 队伍 HP 带入 / 怪物名+血量 / 装备道具入槽）。

const OUT := "D:/Game/BoBoZan/_probe_output/pve_battle.png"


func _ready() -> void:
	var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/expedition/monsters.json"))
	BattleSetup.pve_mode = true
	BattleSetup.pve_monster = defs["b3_maskFox"]   # 变脸狐 T2·双表博弈系（明牌显示最直观）
	BattleSetup.pve_monster_hp = 20                # 10.0 HP
	BattleSetup.pve_team = [
		{"name": "先锋·占位", "hp": 7, "hp_max": 10},   # 3.5/5.0 带伤进场（验跨战 HP）
		{"name": "游侠·占位", "hp": 10, "hp_max": 10},
	]
	BattleSetup.pve_equipment = ["t1_feibiao", "t1_jiudun"]
	var screen := (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(3.2).timeout   # 等入场动画+回合开始横幅过去（明牌已挂出）
	await _shot(OUT)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
