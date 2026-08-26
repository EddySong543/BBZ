extends GutTest

## ============================================================================
## 玩家面三分类 team_role（经济/进攻/防守·2026-07-18 Eddy 组队标签线）数据校验。
##
## team_role = HeroData 新字段（.tres 逐英雄裁定·BP 框色用），真相源=heroes-schools.md §3.3。
## 本测试锁：①全 24 英雄字段齐且值合法；②与 6 维的「规则映射」一致
## （进攻→进攻 / 防御→防守 / 能量→经济 三个维度是硬规则；节奏/状态/干扰=逐英雄裁定不锁）。
## ============================================================================

const VALID_ROLES := ["经济", "进攻", "防守"]
# 6 维中映射无歧义的三维（其余三维按技能实效逐英雄裁定，不在此锁）
const DIM_LOCKED := {"进攻": "进攻", "防御": "防守", "能量": "经济"}


func test_h01_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h01.tres") as HeroData
	assert_not_null(h, "h01 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "虚日生命应为 5")
	assert_eq(h.skill_description, "步虚无有乡", "虚日应使用已定稿技能名")
	assert_eq(h.skill_detail, "虚日【鼠】在场时，获得的能量增加 0.5 点（回合被动能量除外）。",
		"虚日描述应明确回合被动能量不受加成")


func test_h02_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h02.tres") as HeroData
	assert_not_null(h, "h02 数据资源必须可加载")
	assert_eq(h.max_hp, 7, "牛金生命保持 7")
	assert_eq(h.skill_description, "玄金不动相", "牛金应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"牛金【牛】成功防御时，我方下一次的「波」升级为「大波」。",
		"牛金短文案应使用统一的成功防御术语")


func test_h03_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h03.tres") as HeroData
	assert_not_null(h, "h03 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "尾火生命应为 5")
	assert_eq(h.skill_description, "白额雷音", "尾火应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"双方同时攻击时，尾火【虎】的攻击优先结算。",
		"尾火短文案应使用统一的攻击术语")


func test_h04_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h04.tres") as HeroData
	assert_not_null(h, "h04 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "房日生命保持 5")
	assert_eq(h.team_role, "进攻", "房日的新主定位应为进攻")
	assert_eq(h.skill_description, "十方无次第", "房日应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"房日【兔】的攻击可以指定任意一名敌方英雄。",
		"房日短文案应使用统一的攻击术语")


func test_h05_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h05.tres") as HeroData
	assert_not_null(h, "h05 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "亢金生命保持 5")
	assert_eq(h.team_role, "进攻", "亢金的主定位应为进攻")
	assert_eq(h.skill_type, HeroData.SkillType.ENHANCED_ACTION,
		"龙御极由玩家选择强化波，应标记为主动强化")
	assert_eq(h.skill_description, "龙御极", "亢金应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"亢金【龙】在队时，我方的「波」可以额外消耗1点能量，使伤害增加1点。",
		"亢金短文案应明确强化波是团队可选的额外消耗")


func test_h06_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h06.tres") as HeroData
	assert_not_null(h, "h06 数据资源必须可加载")
	assert_eq(h.max_hp, 4, "翼火生命保持 4")
	assert_eq(h.team_role, "进攻", "翼火的主定位应为进攻")
	assert_eq(h.skill_description, "神打", "翼火应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"翼火【蛇】命中敌方英雄时，使其获得1层毒素。\n毒素：可叠加。中毒英雄再次被「波」或「大波」命中时，引爆并清除全部毒素，每层造成0.5点伤害。",
		"翼火文案应使用已定稿的毒素与引爆术语")


func test_h15_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h15.tres") as HeroData
	assert_not_null(h, "h15 数据资源必须可加载")
	assert_eq(h.max_hp, 7, "穷奇生命保持 7")
	assert_eq(h.team_role, "进攻", "穷奇的主定位应为进攻")
	assert_eq(h.skill_description, "七杀战鬼", "穷奇应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"穷奇【虎】的「波」穿防，但无法使用「防」和「大防」。",
		"穷奇文案应使用已定稿的穿防与禁防表述")


func test_h16_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h16.tres") as HeroData
	assert_not_null(h, "h16 数据资源必须可加载")
	assert_eq(h.max_hp, 4, "广寒生命保持 4")
	assert_eq(h.team_role, "经济", "广寒暂沿用当前组队标签")
	assert_eq(h.skill_description, "白虹", "广寒应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"队友攻击命中时，立刻登场并追击同一目标1点伤害。",
		"h16 文案应为已批准的替补追击版本")


func test_h08_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h08.tres") as HeroData
	assert_not_null(h, "h08 数据资源必须可加载")
	assert_eq(h.max_hp, 6, "鬼金生命保持 6")
	assert_eq(h.team_role, "防守", "鬼金的主定位应为防守")
	assert_eq(h.skill_description, "不坠神言", "鬼金应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"鬼金【羊】的「大防」未挡到攻击时，由我方保留至下一回合结束。",
		"鬼金短文案应明确保留大防只持续到下一回合结束")


func test_h13_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h13.tres") as HeroData
	assert_not_null(h, "h13 数据资源必须可加载")
	assert_eq(h.max_hp, 4, "玄冥生命保持 4")
	assert_eq(h.team_role, "进攻", "玄冥的新主定位应为进攻")
	assert_eq(h.skill_type, HeroData.SkillType.ENHANCED_ACTION,
		"暗潮由玩家选择大波形态，应标记为主动强化")
	assert_eq(h.skill_description, "暗潮", "玄冥应使用最新定稿技能名")
	assert_eq(h.skill_detail,
		"玄冥【鼠】的「大波」可以改为连续两次「波」。",
		"玄冥短文案应明确大波的可选双波形态")


func test_h14_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h14.tres") as HeroData
	assert_not_null(h, "h14 数据资源必须可加载")
	assert_eq(h.max_hp, 6, "蚩尤生命保持 6")
	assert_eq(h.team_role, "经济", "生命替代能量支付的主定位应为经济")
	assert_eq(h.dimension, "能量", "蚩尤应归入能量维度")
	assert_eq(h.skill_type, HeroData.SkillType.ENHANCED_ACTION, "蚩尤的新技能应标记为主动强化")
	assert_eq(h.skill_description, "天不葬", "蚩尤应使用最新定稿技能名")
	assert_eq(h.skill_detail,
		"本回合，我方消耗的能量改为消耗蚩尤【牛】的血量。",
		"蚩尤短文案应与定稿措辞完全一致")


func test_h18_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h18.tres") as HeroData
	assert_not_null(h, "h18 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "对称战场规则较强，相柳生命应收紧为 5")
	assert_eq(h.team_role, "经济", "旧 UI 三分类按全池兼容规则暂不逐只迁移")
	assert_eq(h.skill_type, HeroData.SkillType.PASSIVE, "相柳的新技能应标记为被动")
	assert_eq(h.skill_description, "游丝引", "h18 应沿用 Eddy 定稿的技能名")
	assert_eq(h.skill_detail,
		"相柳【蛇】出战时，双方「波」与「大波」的基础伤害均视为1点。",
		"相柳短文案应与定稿措辞完全一致")


func test_h19_published_data_matches_damage_transfer_rule() -> void:
	var h := load("res://assets/data/heroes/h19.tres") as HeroData
	assert_not_null(h, "h19 数据资源必须可加载")
	assert_eq(h.skill_description, "奔雷", "乌骓技能名保持奔雷")
	assert_eq(h.skill_detail,
		"乌骓【马】攻击命中时，目标最多受到1点伤害；溢出伤害转移给生命最高的另一名存活敌方英雄。",
		"乌骓短文案应准确说明伤害守恒与确定性转移目标")


func test_h23_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h23.tres") as HeroData
	assert_not_null(h, "h23 数据资源必须可加载")
	assert_eq(h.max_hp, 6, "天狗生命保持 6")
	assert_eq(h.skill_detail,
		"天狗【狗】的「波」或「大波」造成伤害时，等量降低敌方能量上限（最低到3点）。",
		"天狗短文案应与本轮定稿措辞完全一致")


func test_h24_published_data_states_full_turn_discount_and_floor() -> void:
	var h := load("res://assets/data/heroes/h24.tres") as HeroData
	assert_not_null(h, "h24 数据资源必须可加载")
	assert_eq(h.skill_detail,
		"并封【猪】在队时，我方可以降低1点能量上限，使本回合所有行动少消耗1点能量（最低到3点）。",
		"并封文案必须明确减费覆盖本回合所有行动，且上限只能降到3点")


func test_hero_data_launch_pool_all_have_valid_team_role() -> void:
	# Arrange
	var pool := HeroData.create_launch_pool()

	# Act / Assert
	assert_eq(pool.size(), 24, "首发池应为 24 英雄")
	for h in pool:
		assert_true(h.team_role in VALID_ROLES,
			"%s team_role=「%s」不在合法集 %s" % [h.hero_id, h.team_role, VALID_ROLES])


func test_hero_data_team_role_matches_locked_dimension_mapping() -> void:
	# Arrange
	var pool := HeroData.create_launch_pool()

	# Act / Assert：进攻维→进攻 / 防御维→防守 / 能量维→经济（规则映射·无逐英雄裁定空间）
	for h in pool:
		if DIM_LOCKED.has(h.dimension):
			assert_eq(h.team_role, DIM_LOCKED[h.dimension],
				"%s 维度=%s 应锁定分类=%s（实际=%s）" %
				[h.hero_id, h.dimension, DIM_LOCKED[h.dimension], h.team_role])
