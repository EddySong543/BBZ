extends GutTest

## 道具经济状态机（M1·ADR-003 §2）行为锁定测试。
## 开局带1走部署延迟(slot0·turn2才可用·非首回合) / 三步部署锁(开格→抽→可用) / 一次性用后 EMPTY / refill / 解锁回合门 / 能量成本。
## 注：「测机制」用例走 _battle_ready()(开局件已就绪夹具)，「测时序」用例走 _battle()(真实态·开局件锁住)。

const A := ActionDef.Action
const SEED := 777
const SS := BattleCore.SlotState


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


# === 开局带 1 ===

func test_starter_deploys_with_delay_not_first_turn() -> void:
	# 设计 §2 部署时序：开局带件也走部署延迟 → turn_number 2（显示回合 3）才可用，前两回合锁住（公开电报）。
	var b := _battle()
	assert_eq(b.slot_state(0, 0), SS.CHARGING, "slot0 开局带件（CHARGING·公开）")
	assert_not_null(b.slot_item(0, 0))
	assert_false(b.slot_ready(0, 0), "turn0（显示回合1）锁住·不可用")
	_advance(b, 1)
	assert_false(b.slot_ready(0, 0), "turn1（显示回合2）仍锁")
	_advance(b, 1)
	assert_true(b.slot_ready(0, 0), "turn2（显示回合3）开局件可用（设计时序）")


func test_other_slots_sealed_and_locked_early() -> void:
	var b := _battle()
	assert_eq(b.slot_state(0, 1), SS.SEALED)
	assert_false(b.can_open_slot(0, 1), "第 3 回合前 slot1 不可开格")


# === 三步部署锁：开格 → 抽 → 可用 ===

func test_open_costs_energy_and_locks() -> void:
	var b := _battle_ready(20)
	_advance(b, 2)                       # → turn_number = 2（第 3 回合）
	assert_true(b.can_open_slot(0, 1), "第 3 回合 slot1 可开格")
	var e0 := b.energy[0]
	assert_true(b.open_slot(0, 1))
	assert_eq(e0 - b.energy[0], 2, "开格花 1 能")
	assert_eq(b.slot_state(0, 1), SS.OPENED)
	assert_false(b.can_draw_slot(0, 1), "开格当回合不能抽（锁）")


func test_draw_next_turn_then_charging() -> void:
	var b := _battle_ready(20)
	_advance(b, 2)
	b.open_slot(0, 1)
	_advance(b, 1)                       # 下一回合
	assert_true(b.can_draw_slot(0, 1), "下回合可抽")
	var opts: Array = b.begin_draft(0, 1)
	assert_eq(opts.size(), 3, "3 选 1")
	assert_true(b.pick_draft(0, 1, 0))
	assert_eq(b.slot_state(0, 1), SS.CHARGING)
	assert_false(b.slot_ready(0, 1), "抽道具当回合仍锁（电报）")


func test_usable_turn_after_draw() -> void:
	var b := _battle_ready(20)
	_advance(b, 2)
	b.open_slot(0, 1)
	_advance(b, 1)
	b.pick_draft(0, 1, 0)
	_advance(b, 1)                       # 抽后下回合
	assert_true(b.slot_ready(0, 1), "抽道具下回合可用")


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
	assert_eq(b.hp[1][0], 19, "槽内飞镖照常 0.5 伤")


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
	assert_eq(row._labels[1].text, "—", "未到解锁回合显示锁占位")


# === M3：道具栏交互层 ===

func test_full_deploy_cycle_open_draw_use_empty() -> void:
	# 全周期：封印 → 开格 → 抽 → 可用 → 使用 → 置空（M3 点击分派依次驱动的 M1 路径）。
	var b := _battle_ready(40)
	_advance(b, 2)                       # 第 3 回合，slot1 可开
	assert_true(b.open_slot(0, 1))
	_advance(b, 1)
	b.pick_draft(0, 1, 0)                # OPENED→CHARGING
	_advance(b, 1)
	assert_true(b.slot_ready(0, 1), "部署完成本回合可用")
	assert_true(b.use_slot(0, 1))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.slot_state(0, 1), SS.EMPTY, "用后置空，可走 refill")


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
	# 已点选使用 → 芯片金高光边转最亮金 + 「✓用」标记。
	row.refresh(b, 0, [0])
	assert_eq(row._chip_mats[0].get_shader_parameter("edge_inner"), ItemSlotRow.GOLD_STAGED, "暂存 = 亮金边")
	assert_true(row._labels[0].text.ends_with("✓用"), "暂存槽标 ✓用")
	# 未点选但本回合可用（interactive·道具就绪）→ 金高光边、无 ✓用。
	row.refresh(b, 0, [])
	assert_eq(row._chip_mats[0].get_shader_parameter("edge_inner"), ItemSlotRow.GOLD_READY, "可用 = 金高光边")
	assert_false(row._labels[0].text.ends_with("✓用"))


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
	assert_eq(e0 - b.energy[0], BattleCore.UPGRADE_COST_T1, "1→2 花 1 能")
	assert_eq(b.slot_item(0, 0).tier, 2, "换成下一级件")
	assert_false(b.slot_ready(0, 0), "升级后重新锁本回合（电报）")
	_advance(b, 1)
	assert_true(b.slot_ready(0, 0), "下回合可用")


func test_upgrade_tier2_to_3_costs_more() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t2_shengming")
	assert_true(b.can_upgrade(0, 0))
	var opts := b.begin_upgrade_draft(0, 0)
	for o in opts:
		assert_eq((o as ItemData).tier, 3, "候选全部来自 T3 池")
	var e0 := b.energy[0]
	b.pick_upgrade(0, 0, 0)
	assert_eq(e0 - b.energy[0], BattleCore.UPGRADE_COST_T2, "2→3 花 2 能")
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
	b.slots[0][0]["item"] = ItemCatalog.make("t1_xianshou")    # 无 upgrade_to
	assert_eq(b.slot_item(0, 0).upgrade_to, "", "该件无预设升级款")
	assert_true(b.can_upgrade(0, 0), "无预设升级款的 T1 件也能升级")


func test_cannot_upgrade_without_energy() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.energy[0] = BattleCore.UPGRADE_COST_T1 - 1
	assert_false(b.can_upgrade(0, 0), "能量不足不可升")
	assert_false(b.pick_upgrade(0, 0, 0))
	assert_eq(b.slot_item(0, 0).item_id, "t1_feibiao", "失败不换件")


func test_cannot_upgrade_when_not_ready() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.slots[0][0]["since"] = b.turn_number   # 锁本回合（刚抽/刚升）
	assert_false(b.slot_ready(0, 0))
	assert_false(b.can_upgrade(0, 0), "未就绪不可升")


func test_slot_row_shows_upgrade_badge_when_upgradeable() -> void:
	var b := _battle_ready(20)
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	var row := ItemSlotRow.new()
	row.interactive = true
	add_child_autofree(row)
	row.refresh(b, 0)
	assert_true(row._upgrade_btns[0].visible, "就绪可升级 → 显示升级角标")
	b.slots[0][0]["item"] = ItemCatalog.make("t3_shengming")   # 顶级不可升
	row.refresh(b, 0)
	assert_false(row._upgrade_btns[0].visible, "顶级不可升 → 角标隐藏")


func test_slot_row_upgrade_signal_gated_by_interactive() -> void:
	var row := ItemSlotRow.new()
	add_child_autofree(row)
	var captured := [-99]
	row.slot_upgrade_clicked.connect(func(s: int) -> void: captured[0] = s)
	row.interactive = false
	row._on_upgrade_pressed(1)
	assert_eq(captured[0], -99, "非交互行不发升级信号")
	row.interactive = true
	row._on_upgrade_pressed(2)
	assert_eq(captured[0], 2, "交互行发升级信号")
