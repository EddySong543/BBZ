extends SceneTree

## 道具框 vs 头像框 对比预览（开发调试用·点 1 A1 自检）：
##   godot --path . -s tools/item_frame_preview.gd
## 摆出 出战头像框(72) + 替补头像框(68) + 道具行(58 锐角芯片·多种槽态)，截一帧。
## 自检：道具框是否「明显小于头像框」+「锐角芯片」一眼区分于「圆角立绘框」。
## 输出：D:/Game/BoBoZan/item_frame_preview.png（仓库外）

const OUT_PATH := "D:/Game/BoBoZan/item_frame_preview.png"
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
	# slot0 = 就绪进攻件（红底 + 金边 + 升角标）
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
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
	lbl2.text = "道具行：58 圆角 jelly 芯片（就绪=维度色+金边+升 / 可抽 / 可补）"
	lbl2.position = Vector2(80, 188)
	root.add_child(lbl2)

	await process_frame   # 等所有节点 _ready 跑完（_initialize 阶段 add_child 后 _ready 尚未触发）
	row.refresh(b, 0)     # _bgs 已建好后再刷，否则提前 return 留空槽
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	quit()
