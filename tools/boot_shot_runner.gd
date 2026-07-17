extends Node

## boot 屏整屏截图器（作为主场景跑 → 正常加载 autoload·对波+标题+撞点演出自检）：
##   godot --path . res://tools/boot_shot_runner.tscn
## 时间轴：推进/撞击/落定/待机四截 → 强制电弧一截 → 触发盖过（连击×2 + 决堤）三截。
## 决堤 ~1.18s 后 boot 会切主菜单，最后一截落在决堤中段、随后立即退出。
## 输出：D:/Game/BoBoZan/boot_shot_*.png（仓库外·勿入库）

const OUT_DIR := "D:/Game/BoBoZan/"
const IDLE_SHOTS: Array = [
	[0.45, "boot_shot_1_advance.png"],
	[0.70, "boot_shot_2_impact.png"],
	[1.45, "boot_shot_3_settled.png"],
	[1.60, "boot_shot_4_idle.png"],
]


func _ready() -> void:
	var s: Node = load("res://src/ui/boot_screen.tscn").instantiate()
	add_child(s)
	for shot: Array in IDLE_SHOTS:
		await get_tree().create_timer(shot[0] as float).timeout
		await _snap(shot[1] as String)
	# 电弧存续仅 0.12s、间隔随机——直接触发再截，保证截中
	var fx: Object = s.get("_fx")
	fx.call("fire_arc")
	await get_tree().process_frame
	await _snap("boot_shot_5_arc.png")
	# 点击盖过：连击(约 0.84s)→决堤(0.34s)→~1.18s 切场景，三截全落在切换前
	s.call("_trigger_sweep")
	await get_tree().create_timer(0.15).timeout
	await _snap("boot_shot_6_combo1.png")
	await get_tree().create_timer(0.45).timeout
	await _snap("boot_shot_7_combo2.png")
	await get_tree().create_timer(0.42).timeout
	await _snap("boot_shot_8_burst.png")
	get_tree().quit()


func _snap(fname: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + fname)
	print("saved: ", OUT_DIR + fname)
