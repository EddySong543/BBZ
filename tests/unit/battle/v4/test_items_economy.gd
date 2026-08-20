extends GutTest

## 道具经济状态机（M1·ADR-003 §2；2026-07-03 经济重做=免入场税）行为锁定测试。
## 三格第 3/4/5 回合(显示)自动解锁免费 / slot0 自带随机 T1 / slot1/2 解锁当回合 T1 池 3 选 1 /
## 统一锁定(新道具出现回合锁·下回合可用) / 一次性用后 EMPTY / 补充 1 能 / 升级统一 1 能。
## 注：「测机制」用例走 _battle_ready()(自带件已就绪夹具)，「测时序」用例走 _battle()(真实态·自带件锁住)。

const A := ActionDef.Action
const SEED := 777
const SS := BattleCore.SlotState
const ITEM_GALLERY_SCREEN := preload("res://src/ui/item_gallery_screen.gd")


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	b.setup([_hero("test_a", 10), _hero("test_b", 10), _hero("test_c", 10)],
		[_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)], SEED)
	b.energy = [energy, energy]
	b.econ_init()
	return b


## 开局件已就绪的 battle（绕开「部署延迟」便于测机制；真实首回合开局件是锁住的·时序见 test_starter_*）。
func _battle_ready(energy: int = 20) -> BattleCore:
	var b := _battle(energy)
	b.slots[0][0]["since"] = b.turn_number - 1   # slot0 立即就绪
	return b


func _advance(b: BattleCore, n: int = 1) -> void:
	for _i in range(n):
		b.select_action(0, A.CHARGE)
		b.select_action(1, A.CHARGE)
		b.resolve()


# === slot0 自带件 ===

func test_starter_locked_until_turn_after_unlock() -> void:
	# 统一锁定规则：自带件开局公开亮相，第 3 回合(turn 2)解锁当回合仍锁，turn 3（显示回合 4）才可用。
	var b := _battle()
	assert_eq(b.slot_state(0, 0), SS.CHARGING, "slot0 自带件（CHARGING·公开电报）")
	assert_not_null(b.slot_item(0, 0))
	assert_eq(b.slot_item(0, 0).tier, 1, "自带件 = T1")
	for t in range(3):
		assert_false(b.slot_ready(0, 0), "turn%d（显示回合%d）锁住·不可用" % [t, t + 1])
		_advance(b, 1)
	assert_true(b.slot_ready(0, 0), "turn3（显示回合4）自带件可用（解锁+1 回合）")


func test_other_slots_sealed_and_locked_early() -> void:
	var b := _battle()
	assert_eq(b.slot_state(0, 1), SS.SEALED)
	assert_false(b.can_draw_slot(0, 1), "未到解锁回合 slot1 不可抽")


# === 自动解锁（免费）→ 3 选 1 → 锁 1 回合 → 可用 ===

func test_slot_auto_opens_free_at_unlock_turn() -> void:
	var b := _battle_ready(10)           # 低于能量上限 → 攒的增量可观测
	_advance(b, 2)                       # → turn_number = 2（显示回合 3）
	assert_eq(b.slot_state(0, 1), SS.SEALED, "slot1 显示回合 3 仍未解锁（解锁=回合4）")
	var e0 := b.energy[0]
	_advance(b, 1)                       # → turn_number = 3（显示回合 4）
	assert_eq(b.slot_state(0, 1), SS.OPENED, "slot1 显示回合 4 自动解锁")
	assert_true(b.can_draw_slot(0, 1), "解锁当回合即可 3 选 1")
	assert_eq(b.slot_state(0, 2), SS.SEALED, "slot2 要到显示回合 5（错峰）")
	assert_eq(b.energy[0] - e0, 2, "解锁免费（本回合只有攒 +1 能·无开格扣费）")


func test_draw_at_unlock_turn_then_charging() -> void:
	var b := _battle_ready(20)
	_advance(b, 3)                       # slot1 已自动解锁
	var opts: Array = b.begin_draft(0, 1)
	assert_eq(opts.size(), 3, "3 选 1")
	for o in opts:
		assert_eq((o as ItemData).tier, 1, "解锁抽卡池 = T1 only（T2/T3 走升级线）")
	assert_true(b.pick_draft(0, 1, 0))
	assert_eq(b.slot_state(0, 1), SS.CHARGING)
	assert_false(b.slot_ready(0, 1), "抽道具当回合仍锁（电报）")


func test_usable_turn_after_draw() -> void:
	var b := _battle_ready(20)
	_advance(b, 3)
	b.pick_draft(0, 1, 0)
	_advance(b, 1)                       # 抽后下回合
	assert_true(b.slot_ready(0, 1), "抽道具下回合可用（显示回合 5）")


# === 一次性用后 EMPTY + refill ===

func test_use_slot_commits_and_empties() -> void:
	var b := _battle_ready(20)
	# 用开局带的 slot0
	assert_true(b.use_slot(0, 0))
	assert_eq(b.item_uses[0].size(), 1, "提交到盲选 item_uses")
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.slot_state(0, 0), SS.EMPTY, "用后置空（一次性）")
	assert_null(b.slot_item(0, 0))


func test_refill_after_empty() -> void:
	var b := _battle_ready(20)
	b.use_slot(0, 0)
	_advance(b, 1)                       # slot0 → EMPTY
	assert_eq(b.slot_state(0, 0), SS.EMPTY)
	assert_true(b.can_refill(0, 0))
	var e0 := b.energy[0]
	var opts: Array = b.start_refill(0, 0)
	assert_eq(e0 - b.energy[0], 2, "refill 花 1 能")
	assert_eq(opts.size(), 3)
	assert_true(b.pick_draft(0, 0, 0))
	assert_eq(b.slot_state(0, 0), SS.CHARGING)


# === 不影响既有结算 / clone ===

func test_use_slot_item_resolves() -> void:
	var b := _battle_ready(20)
	# 强制 slot0 = 飞镖以验证结算（绕过随机起手）
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.use_slot(0, 0)
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18, "槽内生锈暗器照常造成 1 点伤害")


func test_clone_copies_slots_independently() -> void:
	var b := _battle_ready(20)
	var c := b.clone()
	assert_eq(c.slots[0].size(), 3)
	c.slots[0][0]["state"] = SS.EMPTY
	assert_eq(b.slot_state(0, 0), SS.CHARGING, "改 clone 槽态不动原局")


# === M2：道具栏组件刷新不崩 ===

func test_item_slot_row_refreshes() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")   # 固定起手便于断言
	var row := ItemSlotRow.new()
	add_child_autofree(row)   # 触发 _ready 建子节点
	row.refresh(b, 0)
	assert_eq(row._labels.size(), 3, "3 个槽")
	# t1_feibiao（生锈的暗器）已有图标 → 走图标路径：图标层显示、文字位让给图标（见 item_slot_row 220-234）。
	assert_true(row._icons[0].visible, "带图标道具 → 显示图标层")
	assert_eq(row._labels[0].text, "", "有图标 → 文字位空出给图标（无图才回退显示名）")
	# 未解锁 = 封条无文字（2026-07-13 状态语言重做）：斜贴封条可见 + 圆点=剩余回合。
	assert_eq(row._labels[1].text, "", "未解锁不再显示文字电报")
	assert_true(row._seals[1].visible, "未解锁 = 斜贴封条")
	var remain: int = clampi(int(BattleCore.SLOT_UNLOCK_TURN[1]) - b.turn_number, 0, 3)
	var shown := 0
	for p in row._seal_pips[1]:
		if (p as ColorRect).visible:
			shown += 1
	assert_eq(shown, remain, "封条圆点数 = 剩余解锁回合数")


# === M3：道具栏交互层 ===

func test_full_deploy_cycle_unlock_draw_use_empty() -> void:
	# 全周期：封印 → 自动解锁 → 抽 → 可用 → 使用 → 置空（M3 点击分派依次驱动的 M1 路径）。
	var b := _battle_ready(40)
	_advance(b, 3)                       # 显示回合 4，slot1 自动解锁
	b.pick_draft(0, 1, 0)                # OPENED→CHARGING
	_advance(b, 1)
	assert_true(b.slot_ready(0, 1), "部署完成本回合可用")
	assert_true(b.use_slot(0, 1))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.slot_state(0, 1), SS.EMPTY, "用后置空，可走补充")


func test_slot_row_interactive_gates_click_signal() -> void:
	var row := ItemSlotRow.new()
	add_child_autofree(row)
	var captured := [-99]
	row.slot_clicked.connect(func(s: int) -> void: captured[0] = s)
	# 非交互（P2）：点击不发信号。
	row.interactive = false
	row._on_slot_pressed(0)
	assert_eq(captured[0], -99, "非交互行吞点击")
	# 交互（P1）：点击发 slot_clicked(槽位)。
	row.interactive = true
	row._on_slot_pressed(2)
	assert_eq(captured[0], 2, "交互行发出点击槽位")


func test_slot_row_staged_highlight() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	var row := ItemSlotRow.new()
	row.interactive = true
	add_child_autofree(row)
	# 已点选使用 → 回纹框保留（不再清除换框——Eddy 2026-07-13 五改）+ 金晕外环 + 图标下沉 3px。
	row.refresh(b, 0, [0])
	assert_true(row._tex_frames[0].visible, "点选 = 回纹阶框保留不清除")
	assert_true(row._frames[0].visible, "点选 = 金晕外环显示")
	assert_eq(row._frame_mats[0].get_shader_parameter("edge_mid"), ItemSlotRow.GOLD_STAGED, "金晕 = 最亮金")
	assert_eq(row._tex_frames[0].modulate, ItemSlotRow.STAGED_TINT, "点选 = 框身提金")
	assert_false(row._up_badges[0].visible, "点选时升箭角标让位金晕")
	assert_eq(row._icons[0].position.y, ItemSlotRow.ICON_INSET + 3.0, "点选 = 图标下沉（按下感）")
	assert_eq(row._labels[0].text, "", "状态文字全退役")
	# 取消点选 → 金晕隐藏 + 图标回弹，回纹阶框一直在。
	row.refresh(b, 0, [])
	assert_true(row._tex_frames[0].visible, "取消点选 = 回纹阶框仍在")
	assert_eq(row._tex_frames[0].texture, ItemSlotRow.ITEM_FRAME_TEX, "三阶共享同一框母版")
	assert_false(row._frames[0].visible, "金晕外环隐藏")
	assert_eq(row._icons[0].position.y, ItemSlotRow.ICON_INSET, "取消点选 = 图标回弹")


func test_slot_row_new_frame_palette_and_inner_mask_fit() -> void:
	var b := _battle_ready(20)
	var row := ItemSlotRow.new()
	add_child_autofree(row)
	assert_eq(row._tex_frames[0].position, ItemSlotRow.FRAME_ART_OFFSET,
			"新外框透明边补偿后贴合槽位")
	assert_eq(row._tex_frames[0].size, ItemSlotRow.FRAME_ART_SIZE,
			"新外框按素材实际外沿放大")
	assert_eq(row._cells[0].position, Vector2.ONE * ItemSlotRow.CELL_INSET,
			"格底从新框内孔起点开始")
	assert_eq(row._cells[0].size,
			Vector2(ItemSlotRow.SLOT_W, ItemSlotRow.SLOT_H) - Vector2.ONE * ItemSlotRow.CELL_INSET * 2.0,
			"格底尺寸被限制在新框内孔")
	var tier_items := ["t1_feibiao", "t2_feibiao", "t3_longxi"]
	for tier in range(1, 4):
		b.slots[0][0]["item"] = ItemCatalog.make(tier_items[tier - 1])
		row.refresh(b, 0)
		var mat: ShaderMaterial = row._tex_frame_mats[0]
		var cell_mat: ShaderMaterial = row._cell_mats[0]
		assert_eq(mat.get_shader_parameter("shadow_color"), ItemSlotRow.FRAME_SHADOW_T[tier],
				"第%d阶外框暗部色" % tier)
		assert_eq(mat.get_shader_parameter("mid_color"), ItemSlotRow.FRAME_MID_T[tier],
				"第%d阶外框主色" % tier)
		assert_eq(mat.get_shader_parameter("highlight_color"), ItemSlotRow.FRAME_HIGHLIGHT_T[tier],
				"第%d阶外框高光色" % tier)
		assert_eq(cell_mat.get_shader_parameter("material_lighting"), 0.0,
				"道具格底关闭额外材质光照，与图鉴一致")
		if tier < 3:
			assert_eq(cell_mat.get_shader_parameter("fill_color"), ItemSlotRow.CELL_FILL_T[tier],
					"普通/稀有格底顶部色与图鉴一致")
			assert_eq(cell_mat.get_shader_parameter("inner_color"), ItemSlotRow.CELL_CENTER_T[tier],
					"普通/稀有格底底部色与图鉴一致")
			assert_eq(cell_mat.get_shader_parameter("vertical_gradient"), 1.0,
					"普通/稀有格底使用图鉴的上暗下亮纵向渐变")
			assert_eq(cell_mat.get_shader_parameter("use_tex"), 0.0,
					"普通/稀有格底不误用传说贴图")
		else:
			assert_eq(cell_mat.get_shader_parameter("use_tex"), 1.0,
					"传说格底沿用金色背景贴图")
			assert_eq(cell_mat.get_shader_parameter("tex_top_darkening"),
					ItemSlotRow.LEGENDARY_TOP_DARKENING,
					"传说格底顶部压暗量与图鉴一致")


func test_draft_popup_resolves_choice_once() -> void:
	var popup := ItemDraftPopup.new()
	add_child_autofree(popup)
	popup.setup([ItemCatalog.make("t1_feibiao"), ItemCatalog.make("t1_jiudun"),
		ItemCatalog.make("t1_lzhi_shengming")], true)
	var calls := [0, -99]   # [emit 次数, 最后 choice]
	popup.resolved.connect(func(c: int) -> void:
		calls[0] += 1
		calls[1] = c)
	popup._resolve(1)
	popup._resolve(0)                    # 二次抢答应被去抖忽略
	assert_eq(calls[1], 1, "返回选中 index")
	assert_eq(calls[0], 1, "去抖：只 resolve 一次")


func test_draft_popup_new_frame_size_position_and_palette() -> void:
	var popup := ItemDraftPopup.new()
	add_child_autofree(popup)
	popup.setup([ItemCatalog.make("t2_feibiao")], false, "升级道具（3 选 1）")
	var frame := popup.find_child("ItemFrame", true, false) as TextureRect
	var cell := popup.find_child("ItemCell", true, false) as ColorRect
	var shadow := popup.find_child("BottomShadow", true, false) as TextureRect
	var art_shadow := popup.find_child("ItemArtShadow", true, false) as TextureRect
	var slot_pos := Vector2(ItemDraftPopup.CARD_W * 0.5 - 64.0, 92.0)
	var slot_size := Vector2(128.0, 128.0)
	var inset := slot_size.x * ItemDraftPopup.CELL_INSET_RATIO
	assert_eq(frame.position, slot_pos + slot_size * ItemDraftPopup.FRAME_OFFSET_RATIO,
			"升级三选一外框位置补偿透明边")
	assert_eq(frame.size, slot_size * ItemDraftPopup.FRAME_ART_SCALE,
			"升级三选一外框按新素材放大")
	assert_not_null(shadow, "升级三选一道具框补上共享右下阴影")
	assert_eq(shadow.position, frame.position + ItemFrameStyle.DROP_SHADOW_OFFSET,
			"升级三选一阴影与战斗道具栏同向偏移")
	assert_eq(shadow.size, frame.size, "阴影严格沿用外框 alpha 轮廓")
	assert_not_null(art_shadow, "升级三选一道具美术补上右下 alpha 投影")
	assert_lt(art_shadow.get_index(), frame.get_index(),
			"升级三选一图案投影落在格底上且由外框收边")
	assert_eq(cell.position, slot_pos + Vector2.ONE * inset,
			"升级三选一格底限制在内孔起点")
	assert_almost_eq(cell.size.x, slot_size.x - inset * 2.0, 0.001,
			"升级三选一格底宽度限制在内孔尺寸")
	assert_almost_eq(cell.size.y, slot_size.y - inset * 2.0, 0.001,
			"升级三选一格底高度限制在内孔尺寸")
	assert_eq(ItemDraftPopup.CELL_INSET_RATIO, ItemFrameStyle.CELL_INSET_RATIO,
			"升级三选一与图鉴/战斗栏共用填充内边距，避免格底水平偏移")
	assert_eq((cell.material as ShaderMaterial).get_shader_parameter("corner_radius"), 0.0,
			"升级三选一格底取消旧圆角，填充色覆盖四角")
	assert_eq((cell.material as ShaderMaterial).get_shader_parameter("vertical_gradient"), 1.0,
			"升级三选一普通/稀有格底使用共享的上暗下亮渐变")
	assert_eq((cell.material as ShaderMaterial).get_shader_parameter("fill_color"),
			ItemFrameStyle.CELL_TOP[2], "升级三选一顶部色读取共享样式")
	assert_eq((cell.material as ShaderMaterial).get_shader_parameter("inner_color"),
			ItemFrameStyle.CELL_BOTTOM[2], "升级三选一底部色读取共享样式")
	assert_eq((frame.material as ShaderMaterial).get_shader_parameter("mid_color"),
			ItemDraftPopup.FRAME_MID[2], "升级三选一稀有框恢复紫色")


func test_item_frame_style_is_the_single_palette_source() -> void:
	assert_eq(ITEM_GALLERY_SCREEN.CELL_FILL, ItemFrameStyle.CELL_TOP)
	assert_eq(ITEM_GALLERY_SCREEN.CELL_CENTER, ItemFrameStyle.CELL_BOTTOM)
	assert_eq(ItemSlotRow.CELL_FILL_T, ItemFrameStyle.CELL_TOP)
	assert_eq(ItemSlotRow.CELL_CENTER_T, ItemFrameStyle.CELL_BOTTOM)
	assert_eq(ItemDraftPopup.CELL_FILL, ItemFrameStyle.CELL_TOP)
	assert_eq(ItemDraftPopup.CELL_CENTER, ItemFrameStyle.CELL_BOTTOM)
	assert_eq(ITEM_GALLERY_SCREEN.FRAME_MID, ItemFrameStyle.FRAME_MID)
	assert_eq(ItemSlotRow.FRAME_MID_T, ItemFrameStyle.FRAME_MID)
	assert_eq(ItemDraftPopup.FRAME_MID, ItemFrameStyle.FRAME_MID)
	assert_eq(ItemFrameStyle.CELL_TOP[1], Color("6E9BD2"),
			"普通填充回退为原蓝色")
	assert_eq(ItemFrameStyle.CELL_TOP[2], Color("9A7FD0"),
			"稀有填充回退为原紫色")
	assert_eq(ItemFrameStyle.LEGENDARY_TINT, Color.WHITE,
			"传说填充回退为原金底贴图色")


func test_battle_screen_script_compiles_with_m3_wiring() -> void:
	# 回归守卫：battle_screen.gd 在含 autoload 的 GUT 环境能编译（含 M3 道具栏点击分派 / draft 接线引用）。
	# 仅 load 脚本（= 触发编译），不实例化整场景——headless 下子组件字体资源缺失会刷 rp_font 噪声、与 M3 无关。
	assert_not_null(load("res://src/ui/battle_screen.gd"), "battle_screen.gd 编译通过（M3 引用解析）")
	assert_not_null(load("res://src/ui/components/item_draft_popup.gd"), "ItemDraftPopup 编译通过")
	assert_not_null(load("res://src/ui/components/item_slot_row.gd"), "ItemSlotRow 编译通过")


# === C：升级线 1→2→3（ADR D5）===

func test_catalog_upgrade_chain_links() -> void:
	# 4 条升级线（设计：T2 升级线4 + T3 顶2）：飞镖/护盾 T1→T2；生命/法力药水 T1→T2→T3。
	assert_eq(ItemCatalog.make("t1_feibiao").upgrade_to, "t2_feibiao")
	assert_eq(ItemCatalog.make("t1_jiudun").upgrade_to, "t2_jiandun")
	assert_eq(ItemCatalog.make("t1_lzhi_shengming").upgrade_to, "t2_shengming")
	assert_eq(ItemCatalog.make("t2_shengming").upgrade_to, "t3_shengming")
	assert_eq(ItemCatalog.make("t1_lzhi_fali").upgrade_to, "t2_fali")
	assert_eq(ItemCatalog.make("t2_fali").upgrade_to, "t3_fali")
	assert_eq(ItemCatalog.make("t2_feibiao").upgrade_to, "", "飞镖线 T2 封顶")
	assert_eq(ItemCatalog.make("t3_shengming").upgrade_to, "", "生命药水 T3 封顶")
	assert_eq(ItemCatalog.make("t3_shengming").params, {heal = 6}, "上等生命药水回复3点")
	assert_eq(ItemCatalog.make("t3_fali").params, {energy = 8}, "上等法力药水立即获得4点能量")
	assert_eq(ItemCatalog.make("t3_shengming").ev_half, 6, "T3 升级目标采用统一新估值")
	assert_eq(ItemCatalog.make("t3_fali").ev_half, 6, "T3 升级目标采用统一新估值")


func test_upgrade_draft_3_from_next_tier_then_swap_and_relock() -> void:
	# 新模型（B2）：升级 = 下一级池 3 选 1 → 换件 + 重新锁本回合。
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")   # 就绪可升（T1）
	assert_true(b.can_upgrade(0, 0))
	var opts := b.begin_upgrade_draft(0, 0)
	assert_eq(opts.size(), 3, "升级 3 选 1")
	for o in opts:
		assert_eq((o as ItemData).tier, 2, "候选全部来自下一级（T2）池")
	var e0 := b.energy[0]
	assert_true(b.pick_upgrade(0, 0, 0))
	assert_eq(e0 - b.energy[0], BattleCore.UPGRADE_COST, "1→2 花 1 能")
	assert_eq(b.slot_item(0, 0).tier, 2, "换成下一级件")
	assert_false(b.slot_ready(0, 0), "升级后重新锁本回合（电报）")
	_advance(b, 1)
	assert_true(b.slot_ready(0, 0), "下回合可用")


func test_upgrade_tier2_to_3_costs_same_flat() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t2_shengming")
	assert_true(b.can_upgrade(0, 0))
	var opts := b.begin_upgrade_draft(0, 0)
	for o in opts:
		assert_eq((o as ItemData).tier, 3, "候选全部来自 T3 池")
	var e0 := b.energy[0]
	b.pick_upgrade(0, 0, 0)
	assert_eq(e0 - b.energy[0], BattleCore.UPGRADE_COST, "2→3 同价 1 能（统一升级费·2026-07-03）")
	assert_eq(b.slot_item(0, 0).tier, 3)


func test_upgrade_draft_caches_then_clears_on_pick() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	var first := b.begin_upgrade_draft(0, 0)
	assert_eq(b.begin_upgrade_draft(0, 0), first, "同回合重复调用沿用同组候选（防 reroll）")
	assert_true(b.pick_upgrade(0, 0, 0))
	assert_eq((b.slots[0][0]["upg_draft"] as Array).size(), 0, "选定后清空升级候选缓存")


func test_upgrade_draft_candidates_are_distinct() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	var opts := b.begin_upgrade_draft(0, 0)
	var ids := {}
	for o in opts:
		ids[(o as ItemData).item_id] = true
	assert_eq(ids.size(), opts.size(), "升级 3 选 1 候选互不重复")


func test_upgrade_draft_weights_favored_upgrade() -> void:
	# 加权（B2）：预设升级款(t1_feibiao→t2_feibiao)出现应远多于普通 T2 件（权重 5×·稳健于池大小）。
	var b := _battle_ready(20)
	var trials := 300
	var fav := 0
	var other := 0
	for _i in range(trials):
		b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
		b.slots[0][0]["upg_draft"] = []
		for o in b.begin_upgrade_draft(0, 0):
			var id: String = (o as ItemData).item_id
			if id == "t2_feibiao":
				fav += 1
			elif id == "t2_jiandun":   # 任一非升级款 T2 件作对照
				other += 1
	assert_gt(fav, other * 2, "升级款(%d) 出现应远多于普通 T2 件(%d)" % [fav, other])


func test_cannot_upgrade_top_tier_but_can_upgrade_non_family() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t3_shengming")   # 顶级·无更高 tier
	assert_false(b.can_upgrade(0, 0), "顶级（T3）不可升")
	assert_false(b.pick_upgrade(0, 0, 0))
	# 新模型：无预设升级款的 T1 件也可升（候选来自下一级池·B2 的核心动机）。
	b.slots[0][0]["item"] = ItemCatalog.make("t1_dutu_yingbi") # 删除命运骰子后无 upgrade_to
	assert_eq(b.slot_item(0, 0).upgrade_to, "", "该件无预设升级款")
	assert_true(b.can_upgrade(0, 0), "无预设升级款的 T1 件也能升级")


func test_cannot_upgrade_without_energy() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.energy[0] = BattleCore.UPGRADE_COST - 1
	assert_false(b.can_upgrade(0, 0), "能量不足不可升")
	assert_false(b.pick_upgrade(0, 0, 0))
	assert_eq(b.slot_item(0, 0).item_id, "t1_feibiao", "失败不换件")


func test_cannot_upgrade_when_not_ready() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.slots[0][0]["since"] = b.turn_number   # 锁本回合（刚抽/刚升）
	assert_false(b.slot_ready(0, 0))
	assert_false(b.can_upgrade(0, 0), "未就绪不可升")


func test_slot_row_tracks_upgradeable_state() -> void:
	# 费用章已退役（Eddy 2026-07-13：槽顶费用章不合适）——升级入口=升箭角标点击/右键。
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	var row := ItemSlotRow.new()
	row.interactive = true
	add_child_autofree(row)
	row.refresh(b, 0)
	assert_true(row._can_up[0], "就绪可升级 → 可升级标记（升级入口判据）")
	assert_true(row._up_badges[0].visible, "就绪可升级 → 右上升箭角标显示")
	b.slots[0][0]["item"] = ItemCatalog.make("t3_shengming")   # 顶级不可升
	row.refresh(b, 0)
	assert_false(row._can_up[0], "顶级不可升 → 标记清除")
	assert_false(row._up_badges[0].visible, "顶级不可升 → 角标隐藏")


func test_slot_row_upgrade_signal_gated_by_interactive() -> void:
	var row := ItemSlotRow.new()
	add_child_autofree(row)
	var captured := [-99]
	row.slot_upgrade_clicked.connect(func(s: int) -> void: captured[0] = s)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	row.interactive = false
	row._can_up[1] = true
	row._on_slot_gui_input(ev, 1)
	assert_eq(captured[0], -99, "非交互行不发升级信号")
	row.interactive = true
	row._can_up[2] = true
	row._on_slot_gui_input(ev, 2)
	assert_eq(captured[0], 2, "交互行右键发升级信号")
	# 升箭角标点击 = 同一升级信号（主入口·右键降为快捷）。
	row._can_up[0] = true
	row._on_up_badge_pressed(0)
	assert_eq(captured[0], 0, "角标点击发升级信号")
	captured[0] = -99
	row.interactive = false
	row._on_up_badge_pressed(0)
	assert_eq(captured[0], -99, "非交互行角标点击不发信号")
