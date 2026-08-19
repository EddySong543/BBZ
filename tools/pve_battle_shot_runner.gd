extends Node

## 远征 PvE 公共战斗截图 runner。
## 模拟通用遭遇交接：完整 HeroData + 跨战 HP → 当前 battle_screen。
## 验证 PvE 保留英雄技能、战斗立绘、标准 BattleAI 和本地 PvP 道具经济。

const OUT := "D:/Game/BoBoZan/_probe_output/pve_battle.png"


func _ready() -> void:
	var player_team: Array[HeroData] = [
		load("res://assets/data/heroes/h05.tres") as HeroData,
		load("res://assets/data/heroes/h07.tres") as HeroData,
	]
	var opponent_team: Array[HeroData] = [
		load("res://assets/data/heroes/h13.tres") as HeroData,
		load("res://assets/data/heroes/h17.tres") as HeroData,
	]
	BattleSetup.configure_pve(player_team, opponent_team, [7, 10], [9, 12], 2468)
	var screen := (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(3.2).timeout   # 等入场动画与回合开始横幅结束
	await _shot(OUT)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
