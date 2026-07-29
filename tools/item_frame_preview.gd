extends SceneTree

## 道具框 vs 头像框 对比预览（开发调试用·点 1 A1 自检）：
##   godot --path . -s tools/item_frame_preview.gd
## 摆出 出战头像框(72) + 替补头像框(68) + 道具行(58 锐角芯片·多种槽态)，截一帧。
## 自检：道具框是否「明显小于头像框」+「锐角芯片」一眼区分于「圆角立绘框」。
## 输出：D:/Game/BoBoZan/_probe_output/item_frame_preview.png（仓库外）

const OUT_PATH := "D:/Game/BoBoZan/_probe_output/item_frame_preview.png"
const HERO_FRAME := preload("res://src/ui/components/hero_frame.tscn")


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1a2230")   # 近似战斗 HUD 暗底
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# --- 头像框：出战 72 + 替补 68（蓝方）---
	var f_active = HERO_FRAME.instantiate()
	root.add_child(f_active)
	f_active.position = Vector2(80, 80)
	f_active.frame_size = Vector2(72, 72)
	f_active.player_color = Color("#3f86c8")
	f_active.is_active = true

	var f_bench = HERO_FRAME.instantiate()
	root.add_child(f_bench)
	f_bench.position = Vector2(170, 84)
	f_bench.frame_size = Vector2(68, 68)
	f_bench.player_color = Color("#3f86c8")

	var lbl1 := Label.new()
	lbl1.text = "头像框：出战 72 / 替补 68（圆角 + 四角宝石）"
	lbl1.position = Vector2(80, 16)
	root.add_child(lbl1)

	# --- 道具行：58 锐角芯片，覆盖 可抽/就绪/可补 ---
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], 777)
	b.energy = [20, 20]
	b.econ_init()
	# slot0 = 就绪进攻件（阶框全彩 + 升箭角标 + 升阶呼吸；行② 同槽点选态）
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.slots[0][0]["state"] = BattleCore.SlotState.CHARGING
	b.slots[0][0]["since"] = b.turn_number - 1   # 上回合部署 → 本回合就绪（否则锁中盖小封条）
	# slot1 = OPENED 可抽
	b.slots[0][1]["state"] = BattleCore.SlotState.OPENED
	b.slots[0][1]["since"] = b.turn_number - 1
	# slot2 = EMPTY 可补
	b.slots[0][2]["state"] = BattleCore.SlotState.EMPTY

	var row := ItemSlotRow.new()
	row.interactive = true
	root.add_child(row)
	row.position = Vector2(80, 220)

	var lbl2 := Label.new()
	lbl2.text = "道具行①：就绪可升级（升箭角标+升阶呼吸）/ 可抽（锦囊）/ 可补（锦囊）"
	lbl2.position = Vector2(80, 188)
	root.add_child(lbl2)

	# 第二行：slot0 点选使用态（金晕外环+框身提金+图标下沉·回纹框保留）。
	var row2 := ItemSlotRow.new()
	row2.interactive = true
	root.add_child(row2)
	row2.position = Vector2(80, 360)

	var lbl3 := Label.new()
	lbl3.text = "道具行②：slot0 点选使用（金晕外环+框身提金+图标下沉）"
	lbl3.position = Vector2(80, 328)
	root.add_child(lbl3)

	await process_frame   # 等所有节点 _ready 跑完（_initialize 阶段 add_child 后 _ready 尚未触发）
	row.refresh(b, 0)     # _bgs 已建好后再刷，否则提前 return 留空槽
	row2.refresh(b, 0, [0])
	await create_timer(0.35).timeout   # 等点选 pop 收拢到位（0.14s）再截
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	quit()
