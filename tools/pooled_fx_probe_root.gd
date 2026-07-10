extends Node

## 命中特效对象池探针（性能优化 A 验证）：boot 战斗屏 → 连打 _impact 触发池环形复用 →
## 两张截图（特效在飞 / 连打后）+ 池状态断言打印（预分配数/复用/归池/time_scale 复位）。
## 带窗口跑（主场景模式·autoload 正常注册）：
##   godot --path . res://tools/pooled_fx_probe.tscn
## 输出：D:/Game/BoBoZan/pooled_fx_mid.png / pooled_fx_after.png（仓库外）

const OUT_MID := "D:/Game/BoBoZan/pooled_fx_mid.png"
const OUT_AFTER := "D:/Game/BoBoZan/pooled_fx_after.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await _rt(2.2)   # 等进入选择态
	var fails: Array[String] = []

	# ① 池已预分配且全部待机
	if s._dmg_pool.size() != 4:
		fails.append("dmg_pool size=%d" % s._dmg_pool.size())
	if s._slash_pool.size() != 4:
		fails.append("slash_pool size=%d" % s._slash_pool.size())
	if s._spark_pool_big.size() != 2 or s._spark_pool_small.size() != 2:
		fails.append("spark pools size")
	for l in s._dmg_pool:
		if l.visible:
			fails.append("飘字待机时可见")

	# ② 单发命中（重/轻各一）→ 特效在飞截图
	s._impact(1, 4)
	s._impact(0, 2)
	await _rt(0.18)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_MID)
	var vis := 0
	for l in s._dmg_pool:
		if l.visible:
			vis += 1
	if vis != 2:
		fails.append("在飞飘字=%d 应为 2" % vis)

	# ③ 连打 6 发（超池容量）→ 环形回收 + tween kill 路径（不应有报错/属性残留）
	for i in 6:
		s._impact(i % 2, 4 if i % 3 == 0 else 2)
		await _rt(0.05)
	await _rt(0.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_AFTER)

	# ④ 静置 → 全部归池：飘字全隐/斩击停播停帧/火花烧完/time_scale 复位
	await _rt(1.5)
	for l in s._dmg_pool:
		if l.visible:
			fails.append("飘字未归池")
	for sl in s._slash_pool:
		if sl.visible or sl.is_processing():
			fails.append("斩击未归池")
	for p in (s._spark_pool_big + s._spark_pool_small):
		if p.emitting:
			fails.append("火花仍在发射")
	if Engine.time_scale != 1.0:
		fails.append("time_scale=%.3f 未复位" % Engine.time_scale)

	print("POOLED_FX_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	print("saved: ", OUT_MID, " / ", OUT_AFTER)
	get_tree().quit()


## 真实时长等待（ignore_time_scale：hitstop 慢放不拖探针节奏）。
func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
