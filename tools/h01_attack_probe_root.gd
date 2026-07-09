extends Node

## h01 攻击动画对位探针（带窗口跑）：左=idle 基准·右=attack 播放中，
## 两个时间点截屏 → 目检 128→256 放大后帧对位（脚底/身位应与 idle 一致）。
##   godot --path . res://tools/h01_attack_probe.tscn
## 输出：D:/Game/BoBoZan/h01_attack_mid.png / h01_attack_late.png（仓库外）

const FRAMES := "res://assets/sprites/heroes/h01/h01_idle.tres"
const OUT_MID := "D:/Game/BoBoZan/h01_attack_mid.png"
const OUT_LATE := "D:/Game/BoBoZan/h01_attack_late.png"


func _ready() -> void:
	var scene: PackedScene = load("res://src/ui/components/character_display.tscn")
	var idle_cd: Control = scene.instantiate()
	var atk_cd: Control = scene.instantiate()
	idle_cd.sprite_frames_path = FRAMES
	atk_cd.sprite_frames_path = FRAMES
	add_child(idle_cd)
	add_child(atk_cd)
	idle_cd.position = Vector2(60, 150)
	atk_cd.position = Vector2(900, 150)
	await get_tree().create_timer(0.5).timeout
	atk_cd.play_animation("attack")
	await get_tree().create_timer(0.28).timeout   # 打击帧附近（0.6s 动画中段）
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_MID)
	print("saved: ", OUT_MID)
	await get_tree().create_timer(0.22).timeout   # 动画尾段
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_LATE)
	print("saved: ", OUT_LATE)
	get_tree().quit()
