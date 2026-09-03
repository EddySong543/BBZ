extends GutTest

## Tier-1 道具行为锁定测试（ADR-003）。
## 无特别说明时使用无技能英雄，隔离道具效果与英雄逻辑。半点制：1HP=2 半点、1能量=2 半能。

const A := ActionDef.Action
const SEED := 777


func _display_desc(raw: String) -> String:
	var displayed := raw.strip_edges()
	if displayed.ends_with("。") or displayed.ends_with("！") or displayed.ends_with("？"):
		return displayed
	return displayed + "。"


func _hero(id: String, hp_value: int = 10) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp_value
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy_value: int = 20, p0_id: String = "test_a") -> BattleCore:
	var b := BattleCore.new()
	b.setup(
		[_hero(p0_id), _hero("test_b"), _hero("test_c")],
		[_hero("test_x"), _hero("test_y"), _hero("test_z")],
		SEED)
	b.energy = [energy_value, energy_value]
	return b


func _give(b: BattleCore, player: int, id: String) -> int:
	return b.give_item(player, ItemCatalog.make(id))


func _use_and_resolve(b: BattleCore, id: String, action0: int, action1: int) -> Dictionary:
	assert_true(b.use_item(0, _give(b, 0, id)))
	assert_true(b.select_action(0, action0))
	assert_true(b.select_action(1, action1))
	return b.resolve()


func _energy_after(id: String, action0: int, action1: int, start: int = 6) -> int:
	var b := _battle(start)
	if id != "":
		assert_true(b.use_item(0, _give(b, 0, id)))
	assert_true(b.select_action(0, action0))
	assert_true(b.select_action(1, action1))
	b.resolve()
	return b.energy[0]


# === 正式池 / 玩家文案 ===

func test_catalog_has_current_t1_items_and_no_guike() -> void:
	assert_eq(ItemCatalog.all_tier1().size(), 34)
	assert_false(ItemCatalog.ids().has("t1_guike"))
	for item in ItemCatalog.all_tier1():
		assert_gte(item.ev_half, 2, "%s 不应继续按旧 0.5 基准估值" % item.item_id)


func test_t1_player_copy_matches_approved_text() -> void:
	var expected := {
		"t1_xianshou": "本回合内，我方下一次攻击造成的伤害增加1点。",
		"t1_dutu_yingbi": "本回合内，我方下一次攻击造成的伤害增加2点，或使敌方下一次攻击造成的伤害增加2点。",
		"t1_podun_zhou": "本回合内，若敌方使用「防」，我方「波」的伤害增加1点并穿防。",
		"t1_houshou": "本回合内，若敌方攻击，我方出战英雄存活获得1.5点护甲。",
		"t1_yaohuo": "点燃敌方出战英雄，下回合结束前，若该英雄仍在场上则失去1.5点生命。",
		"t1_xiangjiaopi": "本回合内，若敌方攻击，该攻击的总伤害减少1点。",
		"t1_xixie_yaya": "本回合的下次攻击命中时，我方出战英雄回复等同于伤害的生命。",
		"t1_moli_yuanquan": "本回合内，若成功防御，我方获得1点能量。",
		"t1_siyecao": "本回合内，我方下一次攻击的总伤害增加1.5点；若这次攻击没有击败目标，我方出战英雄失去1点生命。",
		"t1_qipao": "本回合内，若敌方本回合使用「大波」且我方使用「防」，该「防」可以挡下这次「大波」。",
		"t1_hushenfu": "本回合内，敌方对我方施加的第一个非伤害道具效果无效。",
		"t1_fengzhixue": "本回合内，我方若「切换」，下回合第一次攻击的总伤害增加1.5点。",
		"t1_weihouzhen": "本回合内，我方出战英雄若死亡，对当时的敌方出战英雄造成2点伤害。",
		"t1_ronglu": "选择并烧掉另一件可使用的道具，立即获得2点能量。",
		"t1_deneng_hufu": "本回合内，我方第一次获得非回合被动能量时，出战英雄获得1点护甲。",
		"t1_fentong_mupai": "本回合内，我方出战英雄受到的下一次伤害中，1点改由生命最高的另一名存活队友承受。",
		"t1_huanfang_kou": "本回合内，我方切换后，登场英雄获得1点护甲。",
		"t1_houzhen_qian": "选择我方一名未出战英雄，本回合结束时令其登场。",
		"t1_jijiu_ling": "本回合内，我方下一次攻击命中时，生命最低的存活英雄回复1点生命。",
		"t1_yazhen_zhui": "本回合内，我方用「大防」挡下「波」时，敌方失去1点能量。",
		"t1_huifeng_qiao": "本回合内，我方下一次「波」被成功防御时，出战英雄获得1.5点护甲。",
		"t1_xuzhen_qi": "本回合内，我方出战英雄若死亡，下一名登场英雄获得2点护甲。",
		"t1_xuedu_jie": "我方出战英雄失去1点生命，生命最低的另一名存活英雄回复2点生命。",
		"t1_tengman_xianjing": "本回合内，敌方切换后，换下的英雄受到1点伤害。",
		"t1_jiedu_yaoshui": "清除我方出战英雄的毒素；若没有毒素则清除脆弱。成功清除后，其回复1点生命。",
		"t1_xunxing_zhui": "本回合内，我方下一次「波」可以指定任意一名敌方英雄，但总伤害减少0.5点。",
		"t1_jicun_pai": "选择另一件可使用的道具，将其随机放回背包，立即获得1点能量。",
		"t1_tingxia_tong": "随机揭示敌方背包中至多3件道具，直到本场战斗结束。",
		"t1_gufeng_zhui": "仅当我方没有其他可使用的道具时使用；本回合内，我方下一次攻击的总伤害增加2点。",
	}
	for id in expected:
		assert_eq(ItemCatalog.make(id).description, _display_desc(expected[id]), id)
	assert_eq(ItemCatalog.make("t1_feibiao").flavor,
		"虚日【鼠】再三强调，这可不是M9刺刀（★） | 外表生锈")


func test_t2_player_copy_and_value_match_approved_rebase() -> void:
	var expected := {
		"t2_baolie": "本回合内，我方「大波」少消耗2点能量。",
		"t2_daishang_san": "选择我方一名未出战英雄；本回合敌方下一次攻击改以其为目标。",
		"t2_dianjiang_gu": "本回合我方下一次攻击命中后，使敌方生命最低的未出战英雄登场。",
		"t2_dianjinshi": "选择另一件可使用的普通道具，将其立即升级为传说道具。",
		"t2_dingshen": "直到下回合结束，敌方的切换无效。",
		"t2_duyao": "使敌方出战英雄获得3层毒素。",
		"t2_feibiao": "对敌方出战英雄造成2点伤害。",
		"t2_fengyin": "敌方下回合使用的第一件道具无效。",
		"t2_guiying_pai": "我方下一次切换时，换下的英雄回复2点生命。",
		"t2_huanhundan": "直到本局结束，使用该道具的英雄免疫1次致命伤害。每名英雄限用1次。",
		"t2_jieyin_pei": "选择我方一名未出战英雄；本回合我方下一次攻击命中时，也结算该英雄的「印记」。",
		"t2_huizhao_jing": "本回合内，反制敌方对我方使用的第一件道具。",
		"t2_jiandun": "我方出战英雄获得2点护甲。",
		"t2_daijia": "本回合内，我方「波」和「大波」的伤害增加2点，本回合结束我方出战英雄死亡。",
		"t2_lieyin": "敌方出战英雄获得3层脆弱。",
		"t2_huoshou": "本回合内，我方下一次攻击命中时，获得1.5点能量。",
		"t2_miwu_doupeng": "我方道具栏对敌方隐藏，直到我方使用一件道具。",
		"t2_jike": "本回合内，我方下一次攻击命中时，我方所有存活英雄各回复1点生命。",
		"t2_nuanyu": "本回合内，若成功防御，我方所有存活英雄各回复1点生命。",
		"t2_pomoshi": "本回合内，我方下一次「波」的总伤害增加1点并穿防。",
		"t2_fali": "本回合内，若我方使用「攒」，我方额外获得2点能量。",
		"t2_shengming": "我方出战英雄回复2点生命。",
		"t2_mojing": "我方立即获得3点能量，下回合开始时失去1点能量。",
		"t2_shitiechong": "本回合内，敌方的「防」「大防」降低一级。",
		"t2_shizhi_jiasuo": "选择敌方一件锁定中的道具，使其延迟1回合可用。",
		"t2_shuangsheng": "本回合内，我方下一次攻击的总伤害增加1点；由命中触发的英雄技能额外触发1次。",
		"t2_caoren": "本回合内，我方切换后，敌方本回合攻击落空。",
		"t2_xingjun_yaonang": "选择我方一名未出战英雄，使其回复2点生命。",
		"t2_qiubite": "本回合内，我方下一次攻击改为造成真实伤害。",
		"t2_difeng_kou": "移除我方出战英雄至多2点护甲；本回合内，我方下一次攻击的总伤害增加等量。",
		"t2_fuying_suo": "锁定敌方出战英雄；本回合内，我方下一次攻击仍以该英雄为目标，即使其切换下场。",
		"t2_ningxue_gao": "本回合内，我方所有生命回复改为获得等量护甲。",
		"t2_zhenwen_zhen": "本回合内，敌方由「波」或「大波」命中触发的英雄技能无效。",
		"t2_lianxin_suo": "本回合内，我方出战英雄受到的下一次攻击伤害由我方所有存活英雄平均承受。",
		"t2_fencun_chi": "本回合内，双方每次攻击的总伤害最多为1点。",
		"t2_yijia_huan": "选择我方一名存活英雄，将我方全队的护甲转移给该英雄。",
		"t2_huzhen_ding": "选择我方一名未出战英雄，使其获得2点护甲。",
		"t2_fengmai_zhen": "本回合内，双方无法回复生命。",
		"t2_suoquan_sai": "下回合，敌方无法获得能量。",
		"t2_yawu_piao": "押注敌方一件可使用的道具；本回合其若被使用，我方获得2点能量。",
		"t2_huigou_quan": "选择本场已经使用的一件普通道具，将1件同名临时道具随机放入背包。",
		"t2_baojia_feng": "选择另一件可使用的道具；本回合它若被反制，则不消耗并随机放回背包。",
		"t2_yingji_xiang": "从自己的背包随机抽取1件普通道具，填入本物腾出的道具框并立即可用。",
		"t2_huanqian_tong": "选择另一件道具，将其随机放回背包，随后免费抽取一次道具。",
		"t2_chenglu_zhan": "本回合内，我方溢出的生命回复转为等量能量。",
		"t2_naying_hulu": "本回合内，我方获得的溢出能量转为回复生命最低的存活英雄。",
		"t2_cuiyong_pai": "选择敌方一件可使用的道具；本回合结束时若仍未使用，将其锁定1回合。",
		"t2_dingming_wan": "我方出战英雄的生命不足3点时，回复至3点。",
		"t2_duyong_feng": "本回合内，双方只有首件道具生效。",
		"t2_pianfeng_jia": "本回合内，敌方「波」无法对我方造成伤害，但其「大波」的总伤害增加2点。",
		"t2_jingwen_zhou": "清除双方所有由攻击命中产生、尚未结算的英雄技能效果。",
		"t2_huiliu_zhu": "本回合内，我方行动若正好耗尽能量，行动结算后获得2点能量。",
	}
	assert_eq(ItemCatalog.all_tier2().size(), expected.size())
	assert_eq(ItemCatalog.all().size(), 114)
	for deleted_id in ["t2_shaizi", "t2_wudouwawa", "t2_xiongyao"]:
		assert_false(ItemCatalog.ids().has(deleted_id), "%s 已移出正式目录" % deleted_id)
	for id in expected:
		var item := ItemCatalog.make(id)
		assert_eq(item.description, _display_desc(expected[id]), id)
		assert_eq(item.ev_half, 4, "%s 应按稀有道具新基准估值" % id)


func test_t3_player_copy_value_and_params_match_approved_rebase() -> void:
	var expected_copy := {
		"t3_budongmingwang": "我方接下来3次成功防御时，出战英雄获得等同于该攻击总伤害的护甲。",
		"t3_yujin": "本回合内，我方下一次攻击时，若出战英雄生命不超过1点，该攻击的总伤害增加3点并穿大防。",
		"t3_hedinghong": "我方接下来引爆毒素时，每层毒素伤害额外增加1点。",
		"t3_judingsanhua": "我方接下来3次攻击若命中，由命中触发的英雄技能各额外触发1次。",
		"t3_longxi": "本回合内，我方「大波」的基础伤害翻倍；若该「大波」被「大防」挡下，我方下回合无法行动。",
		"t3_mengdie": "将我方与敌方的能量，道具栏整体对调。",
		"t3_morihuozhong": "若我方仅剩1名英雄存活，则其所有攻击额外造成1点伤害，所有防御额外获得1点护甲，直到对局结束。",
		"t3_sanqi_zhong": "结束双方所有已生效的道具效果。",
		"t3_zhaohun_fan": "选择我方一名已死亡英雄，使其以1点生命复活并成为未出战英雄。",
		"t3_lianhuan_gu": "本回合内，我方依次执行两个不同的行动（不含切换和英雄技能）。",
		"t3_jubao_pen": "直到对局结束，每回合结束时，若我方道具栏有空位，随机补入1件普通道具。",
		"t3_sheming_quan": "立即获得6点能量；下回合我方无法行动。",
		"t3_huanming_qi": "选择我方一名未出战英雄，交换其与出战英雄的当前生命和护甲。",
		"t3_jieming_deng": "我方能量补满，然后出战英雄的生命降至1点。",
		"t3_qingnang_huopen": "本回合结束时，双方烧掉所有仍可使用的道具；每烧掉1件，所属玩家获得1点能量。",
		"t3_junneng_dou": "合并双方当前能量，再平均分配。",
		"t3_qingyuanbaolian": "本回合起的3回合内，我方每回合额外获得1.5点能量",
		"t3_fali": "我方立即获得4点能量。",
		"t3_shengming": "我方出战英雄回复3点生命。",
		"t3_shixinding": "从本回合起，我方攻击的总伤害增加1点，若我方有一回合没有攻击，回合结束时出战英雄失去3点生命并结束此效果。",
		"t3_tianluodiwang": "本回合内，敌方的首件道具和「切换」无效",
		"t3_tinglong": "耗尽我方全部能量，每1点能量对敌方出战英雄造成0.5点伤害并穿大防。",
		"t3_xumingxiang": "本回合起的3回合内，我方出战英雄每回合回复1.5点生命",
		"t3_yemingzhu": "我方接下来3次切换时，对敌方出战英雄造成1点伤害，切换登场的英雄获得1点护甲。",
		"t3_jianyi": "本回合内，我方「波」若命中，下回合第一次「大波」不消耗能量。",
		"t3_yiqi": "本回合无敌。",
		"t3_xiling_ling": "本回合内，双方所有英雄技能无效。",
		"t3_yiyuan_deng": "使我方出战英雄死亡；死亡结算成功后，选择我方一名未出战英雄，使其回复至生命上限并登场。本回合我方无法行动。",
	}
	var expected_params := {
		"t3_budongmingwang": {relic = true, charges = 3, stack_mode = "extend_charges"},
		"t3_yujin": {threshold = 2, bonus = 6},
		"t3_hedinghong": {relic = true, charges = 1, bonus_per_layer = 2, stack_mode = "extend_charges"},
		"t3_judingsanhua": {relic = true, hits = 1, charges = 3, stack_mode = "extend_charges"},
		"t3_longxi": {},
		"t3_mengdie": {},
		"t3_morihuozhong": {relic = true, atk = 2, armor = 2, stack_mode = "unique"},
		"t3_sanqi_zhong": {},
		"t3_zhaohun_fan": {hp = 2},
		"t3_lianhuan_gu": {},
		"t3_jubao_pen": {relic = true, stack_mode = "unique"},
		"t3_sheming_quan": {energy = 12},
		"t3_huanming_qi": {},
		"t3_jieming_deng": {hp = 2},
		"t3_qingnang_huopen": {energy = 2},
		"t3_junneng_dou": {},
		"t3_qingyuanbaolian": {relic = true, energy = 3, turns = 3, stack_mode = "extend_turns"},
		"t3_fali": {energy = 8},
		"t3_shengming": {heal = 6},
		"t3_shixinding": {relic = true, bonus = 2, backlash = 6, stack_mode = "unique"},
		"t3_tianluodiwang": {},
		"t3_tinglong": {},
		"t3_xumingxiang": {relic = true, heal = 3, turns = 3, stack_mode = "extend_turns"},
		"t3_yemingzhu": {relic = true, charges = 3, dmg = 2, armor = 2, stack_mode = "extend_charges"},
		"t3_jianyi": {},
		"t3_yiqi": {},
		"t3_xiling_ling": {},
		"t3_yiyuan_deng": {},
	}
	assert_eq(ItemCatalog.all_tier3().size(), 28)
	for id in expected_copy:
		var item := ItemCatalog.make(id)
		assert_eq(item.description, _display_desc(expected_copy[id]), id)
		assert_eq(item.ev_half, 6, "%s 应按传说道具新基准估值" % id)
		assert_eq(item.params, expected_params[id], "%s 参数应与结算契约一致" % id)


func test_t1_items_keep_only_live_fixed_t2_upgrade_targets() -> void:
	var expected := {
		"t1_qipao": "",
		"t1_xiangjiaopi": "t2_dingshen",
		"t1_moli_yuanquan": "t2_huoshou",
		"t1_dutu_yingbi": "",
		"t1_houshou": "t2_nuanyu",
		"t1_fengzhixue": "t2_caoren",
		"t1_lzhi_fali": "t2_fali",
		"t1_lzhi_shengming": "t2_shengming",
		"t1_jiudun": "t2_jiandun",
		"t1_hushenfu": "t2_fengyin",
		"t1_feibiao": "t2_feibiao",
		"t1_tongqian": "t2_mojing",
		"t1_ronglu": "t2_dianjinshi",
		"t1_weihouzhen": "t2_lieyin",
		"t1_xianshou": "t2_shuangsheng",
		"t1_xixie_yaya": "t2_jike",
		"t1_yaohuo": "t2_duyao",
		"t1_podun_zhou": "t2_pomoshi",
		"t1_siyecao": "",
		"t1_deneng_hufu": "",
		"t1_fentong_mupai": "",
		"t1_huanfang_kou": "",
		"t1_houzhen_qian": "",
		"t1_jijiu_ling": "",
		"t1_yazhen_zhui": "",
		"t1_huifeng_qiao": "",
		"t1_xuzhen_qi": "",
		"t1_xuedu_jie": "",
		"t1_tengman_xianjing": "",
		"t1_jiedu_yaoshui": "",
		"t1_xunxing_zhui": "",
		"t1_jicun_pai": "",
		"t1_tingxia_tong": "",
		"t1_gufeng_zhui": "",
	}
	assert_eq(ItemCatalog.all_tier1().size(), expected.size())
	for id in expected:
		assert_eq(ItemCatalog.make(id).upgrade_to, expected[id], id)


func test_catalog_uses_tier_then_toneless_full_pinyin_order() -> void:
	var expected := [
		"t1_qipao", "t1_xiangjiaopi", "t1_moli_yuanquan", "t1_deneng_hufu",
		"t1_dutu_yingbi", "t1_fentong_mupai", "t1_gufeng_zhui", "t1_houshou", "t1_houzhen_qian", "t1_huanfang_kou",
		"t1_huifeng_qiao", "t1_fengzhixue", "t1_jicun_pai", "t1_jiedu_yaoshui", "t1_jijiu_ling",
		"t1_lzhi_fali", "t1_lzhi_shengming", "t1_jiudun", "t1_hushenfu",
		"t1_feibiao", "t1_tongqian", "t1_ronglu", "t1_tengman_xianjing", "t1_tingxia_tong",
		"t1_weihouzhen", "t1_xianshou", "t1_xuedu_jie", "t1_xixie_yaya",
		"t1_xunxing_zhui", "t1_xuzhen_qi", "t1_yaohuo", "t1_yazhen_zhui",
		"t1_podun_zhou", "t1_siyecao",
		"t2_baojia_feng", "t2_baolie", "t2_chenglu_zhan", "t2_cuiyong_pai", "t2_daishang_san", "t2_dianjiang_gu", "t2_dianjinshi", "t2_difeng_kou", "t2_dingming_wan", "t2_dingshen", "t2_duyao", "t2_duyong_feng",
		"t2_fencun_chi", "t2_feibiao", "t2_fengmai_zhen", "t2_fengyin", "t2_fuying_suo",
		"t2_guiying_pai", "t2_huanhundan", "t2_huanqian_tong", "t2_huigou_quan", "t2_huiliu_zhu", "t2_huizhao_jing", "t2_huzhen_ding", "t2_jiandun", "t2_jieyin_pei", "t2_jingwen_zhou",
		"t2_lianxin_suo", "t2_lieyin", "t2_daijia", "t2_miwu_doupeng", "t2_huoshou", "t2_naying_hulu", "t2_ningxue_gao", "t2_jike", "t2_nuanyu",
		"t2_pianfeng_jia", "t2_pomoshi", "t2_fali", "t2_shengming", "t2_mojing", "t2_shitiechong",
		"t2_shizhi_jiasuo", "t2_shuangsheng", "t2_suoquan_sai", "t2_caoren", "t2_xingjun_yaonang",
		"t2_qiubite", "t2_yawu_piao", "t2_yijia_huan", "t2_yingji_xiang", "t2_zhenwen_zhen",
		"t3_budongmingwang", "t3_yujin", "t3_hedinghong", "t3_huanming_qi",
		"t3_jieming_deng", "t3_jubao_pen", "t3_judingsanhua", "t3_junneng_dou",
		"t3_lianhuan_gu", "t3_longxi", "t3_mengdie", "t3_morihuozhong",
		"t3_qingnang_huopen", "t3_qingyuanbaolian", "t3_sanqi_zhong",
		"t3_fali", "t3_shengming", "t3_sheming_quan", "t3_shixinding",
		"t3_tianluodiwang", "t3_tinglong", "t3_xiling_ling", "t3_xumingxiang", "t3_yemingzhu", "t3_yiyuan_deng",
		"t3_zhaohun_fan", "t3_jianyi", "t3_yiqi",
	]
	assert_eq(ItemCatalog.ids(), expected)
	assert_eq(ItemCatalog.all().map(func(item: ItemData) -> String: return item.item_id), expected)
	assert_eq(ItemCatalog.all_tier1().map(func(item: ItemData) -> String: return item.item_id), expected.slice(0, 34))


# === 基础价值抬升 ===

func test_feibiao_deals_one_damage_and_is_still_blockable() -> void:
	var hit := _battle()
	_use_and_resolve(hit, "t1_feibiao", A.CHARGE, A.CHARGE)
	assert_eq(hit.hp[1][0], 18)

	var blocked := _battle()
	_use_and_resolve(blocked, "t1_feibiao", A.CHARGE, A.DEFEND)
	assert_eq(blocked.hp[1][0], 20)


func test_jiudun_and_life_potion_are_one_point() -> void:
	var shield_battle := _battle()
	_use_and_resolve(shield_battle, "t1_jiudun", A.CHARGE, A.CHARGE)
	assert_eq(shield_battle.shield[0][0], 2)

	var heal_battle := _battle()
	heal_battle.hp[0][0] = 10
	_use_and_resolve(heal_battle, "t1_lzhi_shengming", A.CHARGE, A.CHARGE)
	assert_eq(heal_battle.hp[0][0], 12)


func test_mana_potion_and_copper_are_one_point() -> void:
	assert_eq(
		_energy_after("t1_lzhi_fali", A.CHARGE, A.CHARGE)
		- _energy_after("", A.CHARGE, A.CHARGE), 2)
	assert_eq(
		_energy_after("t1_tongqian", A.CHARGE, A.CHARGE)
		- _energy_after("", A.CHARGE, A.CHARGE), 2)

	var shield_battle := _battle()
	_use_and_resolve(shield_battle, "t1_tongqian", A.CHARGE, A.ATTACK)
	assert_eq(shield_battle.hp[0][0], 20)
	assert_eq(shield_battle.shield[0][0], 0)


# === 一次攻击的总伤害 ===

func test_xianshou_adds_one_to_wave_total() -> void:
	var b := _battle()
	_use_and_resolve(b, "t1_xianshou", A.ATTACK, A.CHARGE)
	assert_eq(b.hp[1][0], 16)


func test_total_attack_bonus_and_penalty_apply_once_to_h13_split_wave() -> void:
	var bonus := _battle(20, "h13")
	assert_true(bonus.use_item(0, _give(bonus, 0, "t1_xianshou")))
	assert_true(bonus.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(bonus.select_action(1, A.CHARGE))
	bonus.resolve()
	assert_eq(bonus.hp[1][0], 14, "双波总计2点基础伤害，只额外增加1点")

	var penalty := _battle(20, "h13")
	assert_true(penalty.use_item(1, _give(penalty, 1, "t1_xiangjiaopi")))
	assert_true(penalty.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(penalty.select_action(1, A.CHARGE))
	penalty.resolve()
	assert_eq(penalty.hp[1][0], 18, "双波总计2点基础伤害，只减少1点")


func test_attack_total_modifiers_apply_to_h10_jianqi_wave_as_base_attack() -> void:
	var b := _battle(20, "h10")
	b.set_team_status(0, "jianqi", 2)
	assert_true(b.use_item(0, _give(b, 0, "t1_xianshou")))
	assert_true(b.apply_choice(0, {
		action = A.ATTACK,
		target = -1,
		jianqi_attack = true,
	}))
	assert_true(b.select_action(1, A.DEFEND))
	b.resolve()
	assert_eq(b.hp[1][0], 16,
			"飞洒天星强化的仍是基础波，应穿防并正常获得先手的整次攻击加伤")


func test_dutu_coin_has_both_two_point_outcomes() -> void:
	var own_bonus_seen := false
	var enemy_bonus_seen := false
	for seed in range(1, 80):
		var b := _battle()
		b.rng.seed = seed
		assert_true(b.use_item(0, _give(b, 0, "t1_dutu_yingbi")))
		assert_true(b.select_action(0, A.ATTACK))
		assert_true(b.select_action(1, A.ATTACK))
		b.resolve()
		own_bonus_seen = own_bonus_seen or b.hp[1][0] == 14
		enemy_bonus_seen = enemy_bonus_seen or b.hp[0][0] == 14
		if own_bonus_seen and enemy_bonus_seen:
			break
	assert_true(own_bonus_seen)
	assert_true(enemy_bonus_seen)


func test_silver_arrow_only_empowers_wave_when_enemy_defends() -> void:
	var b := _battle()
	_use_and_resolve(b, "t1_podun_zhou", A.ATTACK, A.DEFEND)
	assert_eq(b.hp[1][0], 16, "波增加1点并穿防")

	var inert := _battle()
	_use_and_resolve(inert, "t1_podun_zhou", A.ATTACK, A.CHARGE)
	assert_eq(inert.hp[1][0], 18, "敌方未使用防时没有额外伤害")


func test_egg_reduces_enemy_attack_total_to_zero_floor() -> void:
	var b := _battle()
	_use_and_resolve(b, "t1_xiangjiaopi", A.CHARGE, A.ATTACK)
	assert_eq(b.hp[0][0], 20)


# === 战后、命中与延迟判定 ===

func test_houshou_grants_shield_only_after_surviving_enemy_attack() -> void:
	var survived := _battle()
	_use_and_resolve(survived, "t1_houshou", A.CHARGE, A.ATTACK)
	assert_eq(survived.hp[0][0], 18, "护甲不能倒过来吸收触发它的攻击")
	assert_eq(survived.shield[0][0], 3)

	var defeated := _battle()
	defeated.hp[0][0] = 2
	_use_and_resolve(defeated, "t1_houshou", A.CHARGE, A.BIG_ATTACK)
	assert_lte(defeated.hp[0][0], 0)
	assert_eq(defeated.shield[0][0], 0)


func test_fang_heals_actual_damage_dealt_by_the_next_attack() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	_use_and_resolve(b, "t1_xixie_yaya", A.BIG_ATTACK, A.CHARGE)
	assert_eq(b.hp[1][0], 16)
	assert_eq(b.hp[0][0], 14, "大波实际造成2点，回复2点")

	var blocked := _battle()
	blocked.hp[0][0] = 10
	_use_and_resolve(blocked, "t1_xixie_yaya", A.ATTACK, A.BIG_DEFEND)
	assert_eq(blocked.hp[0][0], 10)

	var shielded := _battle()
	shielded.hp[0][0] = 10
	shielded.shield[1][0] = 2
	_use_and_resolve(shielded, "t1_xixie_yaya", A.BIG_ATTACK, A.CHARGE)
	assert_eq(shielded.shield[1][0], 0)
	assert_eq(shielded.hp[1][0], 18)
	assert_eq(shielded.hp[0][0], 14, "护甲与生命实际减少合计2点，回复2点")

	var doubled := _battle()
	doubled.hp[0][0] = 6
	assert_true(doubled.use_item(0, _give(doubled, 0, "t1_xixie_yaya")))
	assert_true(doubled.use_item(0, _give(doubled, 0, "t2_shuangsheng")))
	assert_true(doubled.select_action(0, A.ATTACK))
	assert_true(doubled.select_action(1, A.CHARGE))
	doubled.resolve()
	assert_eq(doubled.hp[1][0], 16, "双生令波的总伤害增加到2点")
	assert_eq(doubled.hp[0][0], 10,
		"双生只额外触发英雄技能；獠牙每次攻击仍只按整次2点伤害回复一次")


func test_taiji_rewards_only_successful_defense_against_attack() -> void:
	assert_eq(
		_energy_after("t1_moli_yuanquan", A.DEFEND, A.ATTACK)
		- _energy_after("", A.DEFEND, A.ATTACK), 2)

	var item_only := _battle(6)
	assert_true(item_only.use_item(1, _give(item_only, 1, "t1_feibiao")))
	assert_true(item_only.use_item(0, _give(item_only, 0, "t1_moli_yuanquan")))
	assert_true(item_only.select_action(0, A.DEFEND))
	assert_true(item_only.select_action(1, A.CHARGE))
	item_only.resolve()
	assert_eq(item_only.energy[0], 8, "挡下独立道具伤害不算成功防御，只获得回合被动1能量")


func test_last_arrow_rewards_kill_and_punishes_failure() -> void:
	var failed := _battle()
	_use_and_resolve(failed, "t1_siyecao", A.ATTACK, A.CHARGE)
	assert_eq(failed.hp[1][0], 15)
	assert_eq(failed.hp[0][0], 18)

	var killed := _battle()
	killed.hp[1][0] = 5
	_use_and_resolve(killed, "t1_siyecao", A.ATTACK, A.CHARGE)
	assert_lte(killed.hp[1][0], 0)
	assert_eq(killed.hp[0][0], 20)


func test_last_arrow_fatal_life_loss_triggers_tail_needle() -> void:
	var b := _battle()
	b.hp[0][0] = 2
	assert_true(b.use_item(0, _give(b, 0, "t1_siyecao")))
	assert_true(b.use_item(0, _give(b, 0, "t1_weihouzhen")))
	assert_true(b.select_action(0, A.ATTACK))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_lte(b.hp[0][0], 0)
	assert_eq(b.hp[1][0], 11, "最后一箭致死后，尾后针应再造成2点普通伤害")


func test_huanhundan_cancels_last_arrow_fatal_loss_and_prevents_tail_needle() -> void:
	var b := _battle()
	b.hp[0][0] = 2
	assert_true(b.use_item(0, _give(b, 0, "t2_huanhundan")))
	assert_true(b.use_item(0, _give(b, 0, "t1_siyecao")))
	assert_true(b.use_item(0, _give(b, 0, "t1_weihouzhen")))
	assert_true(b.select_action(0, A.ATTACK))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_eq(b.hp[0][0], 2, "还魂丹应令最后一箭的致命生命失去整次无效")
	assert_eq(b.hp[1][0], 15, "英雄未死亡时尾后针不得触发")


func test_strength_price_execution_triggers_tail_needle() -> void:
	var b := _battle()
	assert_true(b.use_item(0, _give(b, 0, "t1_weihouzhen")))
	assert_true(b.use_item(0, _give(b, 0, "t2_daijia")))
	assert_true(b.select_action(0, A.ATTACK))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_lte(b.hp[0][0], 0)
	assert_eq(b.hp[1][0], 10,
		"力量代价的波造成3点伤害，规则处决后尾后针再造成2点伤害")


func test_last_arrow_backlashes_when_the_attack_is_nullified() -> void:
	var b := _battle()
	assert_true(b.use_item(0, _give(b, 0, "t1_siyecao")))
	assert_true(b.use_item(1, _give(b, 1, "t2_caoren")))
	assert_true(b.select_action(0, A.ATTACK))
	assert_true(b.select_switch(1, 1))
	b.resolve()
	assert_eq(b.hp[1][0], 20, "草人使攻击落空")
	assert_eq(b.hp[0][0], 18, "攻击没有击败目标，最后一箭仍应反噬")


func test_qipao_is_not_consumed_by_an_earlier_item_hit() -> void:
	var b := _battle()
	assert_true(b.use_item(0, _give(b, 0, "t1_qipao")))
	assert_true(b.use_item(1, _give(b, 1, "t1_feibiao")))
	assert_true(b.select_action(0, A.DEFEND))
	assert_true(b.select_action(1, A.BIG_ATTACK))
	b.resolve()
	assert_eq(b.hp[0][0], 20, "飞镖被防挡下后，佛像仍应挡下大波")


func test_book_blocks_first_non_damage_item_effect_but_not_direct_damage() -> void:
	var blocked := _battle()
	assert_true(blocked.use_item(0, _give(blocked, 0, "t1_hushenfu")))
	assert_true(blocked.use_item(1, _give(blocked, 1, "t1_yaohuo")))
	assert_true(blocked.select_action(0, A.CHARGE))
	assert_true(blocked.select_action(1, A.CHARGE))
	blocked.resolve()
	assert_true(blocked.timed_item_effects[0].is_empty())

	var direct := _battle()
	assert_true(direct.use_item(0, _give(direct, 0, "t1_hushenfu")))
	assert_true(direct.use_item(1, _give(direct, 1, "t1_feibiao")))
	assert_true(direct.select_action(0, A.CHARGE))
	assert_true(direct.select_action(1, A.CHARGE))
	direct.resolve()
	assert_eq(direct.hp[0][0], 18)


func test_yaohuo_loses_life_at_end_of_next_turn_and_does_not_block_healing() -> void:
	var b := _battle()
	b.hp[1][0] = 10
	assert_true(b.use_item(0, _give(b, 0, "t1_yaohuo")))
	assert_true(b.select_action(0, A.CHARGE))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_true(b.use_item(1, _give(b, 1, "t1_lzhi_shengming")))
	assert_true(b.select_action(0, A.CHARGE))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_eq(b.hp[1][0], 9, "先回复1点，再于回合结束失去1.5点")


func test_yaohuo_does_not_burn_a_target_that_is_no_longer_on_field() -> void:
	var b := _battle()
	b.hp[1][0] = 10
	assert_true(b.use_item(0, _give(b, 0, "t1_yaohuo")))
	assert_true(b.select_action(0, A.CHARGE))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_true(b.select_action(0, A.CHARGE))
	assert_true(b.select_switch(1, 1))
	b.resolve()
	assert_eq(b.hp[1][0], 10)


func test_return_spear_buffs_next_turn_attack_total() -> void:
	var b := _battle()
	assert_true(b.use_item(0, _give(b, 0, "t1_fengzhixue")))
	assert_true(b.select_switch(0, 1))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_eq(int(b.item_buffs[0].get("next_atk_total_bonus", 0)), 3)
	assert_true(b.select_action(0, A.ATTACK))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_eq(b.hp[1][0], 15)
	assert_false(b.item_buffs[0].has("next_atk_total_bonus"))


func test_return_spear_recognizes_actual_switch_instead_of_selected_action() -> void:
	var free := _battle(20, "h07")
	assert_true(free.free_switch(0, 1), "星日免费切换应算实际发生的「切换」")
	assert_true(free.use_item(0, _give(free, 0, "t1_fengzhixue")))
	assert_true(free.select_action(0, A.CHARGE))
	assert_true(free.select_action(1, A.CHARGE))
	free.resolve()
	assert_eq(int(free.item_buffs[0].get("next_atk_total_bonus", 0)), 3)

	var locked := _battle()
	assert_true(locked.use_item(0, _give(locked, 0, "t1_fengzhixue")))
	assert_true(locked.use_item(1, _give(locked, 1, "t2_dingshen")))
	assert_true(locked.select_switch(0, 1))
	assert_true(locked.select_action(1, A.CHARGE))
	locked.resolve()
	assert_eq(locked.active_index[0], 0, "定身应取消这次切换")
	assert_false(locked.item_buffs[0].has("next_atk_total_bonus"),
		"没有实际发生切换时，回马枪不能白拿下一回合加伤")


func test_tail_needle_is_one_turn_death_retaliation_and_uses_normal_damage() -> void:
	var b := _battle()
	b.hp[0][0] = 2
	b.shield[1][0] = 2
	_use_and_resolve(b, "t1_weihouzhen", A.CHARGE, A.BIG_ATTACK)
	assert_lte(b.hp[0][0], 0)
	assert_eq(b.shield[1][0], 0)
	assert_eq(b.hp[1][0], 18, "2点普通伤害先被1点护甲吸收")

	var expired := _battle()
	_use_and_resolve(expired, "t1_weihouzhen", A.CHARGE, A.CHARGE)
	expired.hp[0][0] = 2
	assert_true(expired.select_action(0, A.CHARGE))
	assert_true(expired.select_action(1, A.BIG_ATTACK))
	expired.resolve()
	assert_eq(expired.hp[1][0], 20, "尾后针不能无限期保留")


# === 随身熔炉：明确目标、立即结算、可支付本回合行动 ===

func _ready_slot(id: String) -> Dictionary:
	return {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make(id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


func test_furnace_requires_an_explicit_ready_fuel_slot() -> void:
	var b := _battle(0)
	b.slots[0] = [_ready_slot("t1_ronglu"), _ready_slot("t1_feibiao"), _ready_slot("t1_jiudun")]
	assert_false(b.use_slot(0, 0), "未指定燃料时不能自动烧第一件")
	assert_false(b.use_slot(0, 0, -1, 0), "不能烧自己")
	assert_eq(b.energy[0], 0)
	assert_false(bool(b.slots[0][0]["used"]))
	assert_false(bool(b.slots[0][1]["used"]))


func test_furnace_burns_chosen_item_and_grants_energy_immediately() -> void:
	var b := _battle(2)
	b.slots[0] = [_ready_slot("t1_ronglu"), _ready_slot("t1_feibiao"), _ready_slot("t1_jiudun")]
	assert_true(b.use_slot(0, 0, -1, 2))
	assert_eq(b.energy[0], 6, "立即获得2点能量")
	assert_true(bool(b.slots[0][0]["used"]))
	assert_false(bool(b.slots[0][1]["used"]), "未选择的飞镖保留")
	assert_true(bool(b.slots[0][2]["used"]), "明确选择护甲作为燃料")
	assert_true(b.select_action(0, A.BIG_ATTACK), "熔炉产能可支付同回合大波")


# === 基建 ===

func test_item_does_not_occupy_action_slot() -> void:
	var b := _battle()
	assert_true(b.use_item(0, _give(b, 0, "t1_feibiao")))
	assert_true(b.select_action(0, A.ATTACK))
	assert_true(b.select_action(1, A.CHARGE))
	b.resolve()
	assert_eq(b.hp[1][0], 16)


func test_clone_copies_item_state_independently() -> void:
	var b := _battle()
	_give(b, 0, "t1_feibiao")
	assert_true(b.use_item(0, 0))
	var c := b.clone()
	assert_eq(c.items[0].size(), 1)
	assert_eq(c.item_uses[0].size(), 1)
	c.item_uses[0].clear()
	assert_eq(b.item_uses[0].size(), 1)
