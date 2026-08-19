extends GutTest

const BattleScreenScript := preload("res://src/ui/battle_screen.gd")
const SS := BattleCore.SlotState


func _hero(id: String) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = 10
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _ready_slot(item_id: String) -> Dictionary:
	return {
		state = SS.CHARGING,
		item = ItemCatalog.make(item_id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


func _battle(ids: Array[String], energy: int = 0) -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("a"), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 7319)
	battle.econ_init()
	battle.energy[0] = energy
	for slot: int in range(ids.size()):
		battle.slots[0][slot] = _ready_slot(ids[slot])
	return battle


func _screen(battle: BattleCore) -> Control:
	var screen: Control = autofree(BattleScreenScript.new())
	screen.battle = battle
	return screen


func _ids(options: Array) -> Array[String]:
	var out: Array[String] = []
	for item_variant in options:
		out.append((item_variant as ItemData).item_id)
	return out


func test_pointstone_requires_another_ready_t1_and_a_legendary_choice() -> void:
	var screen := _screen(_battle(["t2_dianjinshi", "t2_jiandun", "t1_feibiao"]))
	assert_true(screen._toggle_ready_item_selection(0))
	assert_eq(screen._pending_item_target_slot, 0)
	assert_false(screen._is_valid_item_slot_target(0, 1), "T2 不能作为点金石目标")
	assert_true(screen._is_valid_item_slot_target(0, 2))

	var options: Array = screen.battle.begin_pointstone_draft(0, 0, 2)
	assert_eq(options.size(), 3)
	for item_variant in options:
		assert_eq((item_variant as ItemData).tier, 3, "点金石必须从传说道具池提供候选")
	assert_true(screen._complete_pointstone_pair(0, 2, 1, _ids(options)))
	assert_eq(screen.selected_item_targets.get(0, -1), 2)
	assert_eq(screen.selected_item_choices.get(0, -1), 1)
	assert_eq(screen.selected_item_slots, [0], "升级目标不能在同回合再次提交使用")


func test_pointstone_preview_replaces_target_with_locked_t3() -> void:
	var screen := _screen(_battle(["t2_dianjinshi", "t1_jiudun", "t2_feibiao"]))
	var options: Array = screen.battle.begin_pointstone_draft(0, 0, 1)
	assert_true(screen._complete_pointstone_pair(0, 1, 0, _ids(options)))

	var preview: BattleCore = screen._battle_after_selected_items()
	assert_eq(preview.slot_item(0, 1).item_id, (options[0] as ItemData).item_id)
	assert_eq(preview.slot_item(0, 1).tier, 3)
	assert_false(preview.slot_ready(0, 1), "升级后的传说道具锁定一回合")
	assert_false(bool(preview.slots[0][1]["used"]), "目标只是换件，不应被当作本回合已使用")
	assert_false(screen._toggle_ready_item_selection(1), "锁定目标不能被追加为同回合使用件")
	assert_eq(screen.selected_item_slots, [0])


func test_pointstone_candidates_are_cached_and_target_cannot_chain() -> void:
	var screen := _screen(_battle(["t2_dianjinshi", "t1_ronglu", "t1_jiudun"]))
	var first: Array = screen.battle.begin_pointstone_draft(0, 0, 1)
	var second: Array = screen.battle.begin_pointstone_draft(0, 0, 2)
	assert_eq(_ids(first), _ids(second), "更换普通道具目标不能重掷传说候选")
	assert_true(screen._complete_pointstone_pair(0, 1, 0, _ids(first)))
	assert_false(screen._toggle_ready_item_selection(1),
		"原熔炉槽升级后锁定，不能在本回合形成点金石链")
	assert_eq(screen.selected_item_targets, {0: 1})


func test_furnace_retargets_pointstone_pair_as_consumed_fuel() -> void:
	var screen := _screen(_battle(["t2_dianjinshi", "t1_jiudun", "t1_ronglu"]))
	var options: Array = screen.battle.begin_pointstone_draft(0, 0, 1)
	assert_true(screen._complete_pointstone_pair(0, 1, 0, _ids(options)))

	assert_true(screen._toggle_ready_item_selection(2), "熔炉进入待选燃料")
	assert_true(screen._toggle_ready_item_selection(1), "同一目标改作燃料时清理旧点金石整组")
	assert_eq(screen.selected_item_slots, [2])
	assert_eq(screen.selected_item_targets, {2: 1})
	assert_true(screen.selected_item_choices.is_empty())
	assert_eq(screen._highlighted_item_slots(), [2, 1])


func test_selected_magic_crystal_and_burst_scroll_refresh_action_affordability() -> void:
	var crystal_screen := _screen(_battle(["t2_mojing"], 2))
	assert_true(crystal_screen._toggle_ready_item_selection(0))
	var crystal_preview: BattleCore = crystal_screen._battle_after_selected_items()
	assert_true(crystal_preview.can_afford(0, ActionDef.Action.BIG_ATTACK),
		"魔晶即时产能后，原本付不起的大波在 UI 预览中可选")

	var scroll_screen := _screen(_battle(["t2_baolie"], 2))
	assert_true(scroll_screen._toggle_ready_item_selection(0))
	var scroll_preview: BattleCore = scroll_screen._battle_after_selected_items()
	assert_true(scroll_preview.can_afford(0, ActionDef.Action.BIG_ATTACK),
		"爆裂卷轴即时减费后，原本付不起的大波在 UI 预览中可选")


func test_friendly_target_items_require_and_preview_an_explicit_hero() -> void:
	var armor_screen := _screen(_battle(["t2_huzhen_ding"], 8))
	assert_true(armor_screen._toggle_ready_item_selection(0))
	assert_eq(armor_screen._pending_item_hero_target_slot, 0)
	assert_false(armor_screen._complete_friendly_item_target(0, 0),
		"护阵钉不能选择当前出战英雄")
	assert_true(armor_screen._complete_friendly_item_target(0, 2))
	assert_eq(armor_screen.selected_item_hero_targets, {0: 2})
	var armor_preview: BattleCore = armor_screen._battle_after_selected_items()
	armor_preview.select_action(0, ActionDef.Action.CHARGE)
	armor_preview.select_action(1, ActionDef.Action.CHARGE)
	armor_preview.resolve()
	assert_eq(armor_preview.shield[0][2], 4)

	var move_screen := _screen(_battle(["t2_yijia_huan"], 8))
	move_screen.battle.shield[0] = [1, 2, 3]
	assert_true(move_screen._toggle_ready_item_selection(0))
	assert_true(move_screen._complete_friendly_item_target(0, 1))
	var move_preview: BattleCore = move_screen._battle_after_selected_items()
	move_preview.select_action(0, ActionDef.Action.CHARGE)
	move_preview.select_action(1, ActionDef.Action.CHARGE)
	move_preview.resolve()
	assert_eq(move_preview.shield[0], [0, 6, 0])


func test_new_friendly_reserve_items_reject_the_active_hero() -> void:
	for item_id in ["t1_houzhen_qian", "t2_jieyin_pei", "t2_daishang_san", "t2_xingjun_yaonang"]:
		var screen := _screen(_battle([item_id], 8))
		assert_true(screen._toggle_ready_item_selection(0))
		assert_eq(screen._pending_item_hero_target_slot, 0)
		assert_false(screen._complete_friendly_item_target(0, 0),
			"%s 只能选择未出战英雄" % item_id)
		assert_true(screen._complete_friendly_item_target(0, 2))


func test_shizhi_jiasuo_uses_an_enemy_locked_item_slot_target() -> void:
	var screen := _screen(_battle(["t2_shizhi_jiasuo"], 8))
	screen.battle.slots[1][1] = _ready_slot("t2_feibiao")
	screen.battle.slots[1][1]["since"] = screen.battle.turn_number
	assert_true(screen._toggle_ready_item_selection(0))
	assert_eq(screen._pending_enemy_item_target_slot, 0)
	assert_true(screen._is_valid_enemy_item_slot_target(0, 1))
	assert_true(screen._complete_enemy_item_slot_target(0, 1))
	assert_eq(screen.selected_item_targets, {0: 1})


func test_selected_xunxing_pendant_arms_enemy_targeting_for_wave_only() -> void:
	var screen := _screen(_battle(["t1_xunxing_zhui"], 8))
	assert_false(screen._can_choose_enemy_attack_target(ActionDef.Action.ATTACK),
		"未点选寻星坠时，白板英雄的波保持标准出战目标")

	assert_true(screen._toggle_ready_item_selection(0))
	screen.selected_action = ActionDef.Action.ATTACK
	assert_true(screen._can_choose_enemy_attack_target(ActionDef.Action.ATTACK),
		"寻星坠应通过已选道具预览授权波选敌")
	assert_false(screen._can_choose_enemy_attack_target(ActionDef.Action.BIG_ATTACK),
		"寻星坠不得越权授权大波选敌")

	screen.selected_action = -1
	assert_true(screen._toggle_ready_item_selection(0))
	assert_false(screen._can_choose_enemy_attack_target(ActionDef.Action.ATTACK),
		"取消寻星坠后应立即撤销临时选敌权")


func test_xunxing_target_permission_follows_item_when_wave_was_selected_first() -> void:
	var screen := _screen(_battle(["t1_xunxing_zhui"], 8))
	screen.selected_action = ActionDef.Action.ATTACK
	assert_true(screen._toggle_ready_item_selection(0))
	assert_true(screen._can_choose_enemy_attack_target(ActionDef.Action.ATTACK),
		"先选波再点寻星坠也应立即获得临时选敌权")
	assert_true(screen._toggle_ready_item_selection(0))
	assert_false(screen._can_choose_enemy_attack_target(ActionDef.Action.ATTACK),
		"同回合取消道具后不得遗留自由选敌权限")


func test_long_term_public_item_states_are_queryable_from_hero_hover() -> void:
	var battle := _battle([])
	battle.set_status(0, 1, "fatal_damage_immunity", 1)
	battle.set_status(0, 0, "huanhun_used", 1)
	battle.item_buffs[1]["switch_lock_until_turn"] = battle.turn_number + 1
	battle.item_buffs[0]["energy_gain_lock_turn"] = battle.turn_number
	battle.item_buffs[0]["return_camp_heal"] = 4
	battle.info_distortion[0]["hide_item_bar"] = true
	var screen := _screen(battle)
	screen.p1_frame_slots.assign([0, 1, 2])
	screen.p2_frame_slots.assign([0, 1, 2])

	var protected_tip: String = screen._hero_status_tip(0, 1)
	assert_true(protected_tip.contains("还魂丹"))
	assert_true(protected_tip.contains("可免疫1次致命伤害"), "还魂丹只显示一份英雄保险")
	assert_true(screen._hero_status_tip(0, 0).contains("本局已使用"),
		"保险消耗后仍应能查询该英雄本局不能再次使用还魂丹")
	assert_true(screen._hero_status_tip(0, 0).contains("锁泉塞：本回合无法获得能量"),
		"团队禁能状态应挂在实时出战头像供悬停查询")
	assert_true(screen._hero_status_tip(0, 0).contains("归营牌：下次切换时换下英雄回复2点生命"),
		"跨回合的切换治疗应能从实时出战头像查询")
	assert_true(screen._hero_status_tip(0, 0).contains("迷雾斗篷：道具栏对敌方隐藏"),
		"持续的信息隐藏应能从持有方实时出战头像查询")
	assert_true(screen._hero_status_tip(1, 0).contains("剩余2回合"),
		"敌方出战头像也应公开显示定身期限")
	battle.active_index[0] = 1
	screen.p1_frame_slots.assign([1, 0, 2])
	assert_true(screen._hero_status_tip(0, 0).contains("可免疫1次致命伤害"),
		"换位后还魂丹保险仍绑定原英雄槽")
	assert_true(screen._hero_status_tip(0, 0).contains("锁泉塞"),
		"团队禁能状态应跟随实时出战头像而不是绑定原英雄")
	assert_true(screen._hero_status_tip(0, 1).contains("本局已使用"),
		"换位后已用记录仍绑定原英雄槽")

	battle.turn_number += 1
	assert_true(screen._hero_status_tip(1, 0).contains("剩余1回合"),
		"定身提示应随回合推进显示真实剩余期限")


func test_t3_relics_and_free_big_window_are_visible_only_on_active_hero_hover() -> void:
	var battle := _battle([])
	battle.relics[0] = [
		{data = ItemCatalog.make("t3_budongmingwang"), state = {charges = 2}},
		{data = ItemCatalog.make("t3_hedinghong"), state = {charges = 1}},
		{data = ItemCatalog.make("t3_judingsanhua"), state = {charges = 3}},
		{data = ItemCatalog.make("t3_jubao_pen"), state = {active = true}},
		{data = ItemCatalog.make("t3_morihuozhong"), state = {}},
		{data = ItemCatalog.make("t3_qingyuanbaolian"), state = {remaining_turns = 2}},
		{data = ItemCatalog.make("t3_shixinding"), state = {}},
		{data = ItemCatalog.make("t3_xumingxiang"), state = {remaining_turns = 3}},
		{data = ItemCatalog.make("t3_yemingzhu"), state = {charges = 1}},
	]
	battle.item_buffs[0]["free_big_attack_until_turn"] = battle.turn_number
	battle.item_buffs[0]["exhausted_turn"] = battle.turn_number + 1
	var screen := _screen(battle)
	screen.p1_frame_slots.assign([0, 1, 2])
	screen.p2_frame_slots.assign([0, 1, 2])

	var active_tip: String = screen._hero_status_tip(0, 0)
	assert_true(active_tip.contains("不动明王甲：剩余2次"))
	assert_true(active_tip.contains("鹤顶红") and active_tip.contains("剩余1次"))
	assert_true(active_tip.contains("聚鼎三花：剩余3次"))
	assert_true(active_tip.contains("聚宝盆：每回合结束时为空槽补入普通道具"))
	assert_true(active_tip.contains("末日火种：等待"))
	assert_true(active_tip.contains("青元宝莲：剩余2回合"))
	assert_true(active_tip.contains("噬心钉：本回合必须攻击"), "必须公开反噬规划压力")
	assert_true(active_tip.contains("续命香：剩余3回合"))
	assert_true(active_tip.contains("夜明珠：剩余1次"))
	assert_true(active_tip.contains("第一次「大波」不消耗能量"))
	assert_true(active_tip.contains("赊命券：下回合无法行动"))
	assert_eq(screen._hero_status_tip(0, 1), "", "团队遗物不得在替补头像重复显示")

	battle.active_index[0] = 1
	screen.p1_frame_slots.assign([1, 0, 2])
	assert_true(screen._hero_status_tip(0, 0).contains("噬心钉"),
		"切换后团队遗物应跟随实时出战头像")
	assert_eq(screen._hero_status_tip(0, 1), "")
	battle.hp[0][0] = 0
	battle.hp[0][2] = 0
	assert_true(screen._hero_status_tip(0, 0).contains("末日火种：残局攻击与防御强化已生效"),
		"末日火种提示应区分等待条件与当前已生效")
	battle.turn_number += 1
	assert_false(screen._hero_status_tip(0, 0).contains("至臻剑意"), "免费大波窗口过期后不显示")


func test_cancelled_free_switch_repairs_resolution_slot_and_hp_baselines() -> void:
	var screen := _screen(_battle([]))
	var active_before: Array[int] = [1, 0]
	var hp_before: Array[float] = [4.0, 5.0]
	var corrected: Dictionary = screen._correct_cancelled_free_switch_baselines([
		{id = "free_switch_cancelled", player = 0, from = 0, hp_before = 13},
	], active_before, hp_before)
	assert_eq(corrected["active"], [0, 0],
		"天罗揭示后演出应回到免费切换前的原出战槽")
	assert_eq(corrected["hp"], [6.5, 5.0],
		"事件携带的半点血量必须换算为 UI 点数，供治疗差值与延迟伤害注解使用")
