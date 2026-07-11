extends Node

## 加时赛日食「烛阴之眼」演出探针（作为主场景跑 → 正常加载 autoload）：
##   godot --path . res://tools/eclipse_probe.tscn
## 直接组白板加时局（跳过主局）→ 定时两截图：①眼珠右看途中 ②flash 后紫日食定格。
## 输出到 session scratchpad（不落仓库目录）。

const OUT_LOOK := "C:/Users/Edzzz/AppData/Local/Temp/claude/D--Game-BoBoZan-Claude-Code-Game-Studios-cn-localization/cf36fe78-6059-4d01-bcba-909e48747428/scratchpad/eclipse_look.png"
const OUT_DONE := "C:/Users/Edzzz/AppData/Local/Temp/claude/D--Game-BoBoZan-Claude-Code-Game-Studios-cn-localization/cf36fe78-6059-4d01-bcba-909e48747428/scratchpad/eclipse_done.png"


func _ready() -> void:
	var pool: Array = HeroData.create_pool_heroes()
	var team_a: Array = [pool[0], pool[1], pool[2]]
	var team_b: Array = [pool[3], pool[4], pool[5]]
	BattleSetup.p1_heroes = BattleCore.overtime_roster(team_a, 0)
	BattleSetup.p2_heroes = BattleCore.overtime_roster(team_b, 0)
	BattleSetup.overtime = true
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(0.8).timeout   # 裂缝挂住期（0.3 静置+0.22 裂缝伸展后）
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_LOOK)
	print("saved: ", OUT_LOOK)
	await get_tree().create_timer(1.5).timeout   # 咔嚓吞尽+成相后紫日食定格（总时序 ≈1.3s+回落）
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DONE)
	print("saved: ", OUT_DONE)
	get_tree().quit()
