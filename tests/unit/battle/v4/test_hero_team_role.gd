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
	assert_eq(h.skill_description, "山河借骨回天法", "牛金应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"牛金【牛】挡下「波」或「大波」后，我方下次「波」升级为「大波」。",
		"牛金描述应准确表达挡招后团队波升级")


func test_h03_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h03.tres") as HeroData
	assert_not_null(h, "h03 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "尾火生命应为 5")
	assert_eq(h.skill_description, "白额雷音", "尾火应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"双方均使用「波」或「大波」时，尾火【虎】优先攻击；若击杀敌方出战英雄，取消其此次攻击。",
		"尾火描述应准确表达基础攻击对攻先制与致死断招")


func test_h04_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h04.tres") as HeroData
	assert_not_null(h, "h04 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "房日生命保持 5")
	assert_eq(h.team_role, "进攻", "房日的新主定位应为进攻")
	assert_eq(h.skill_description, "十方无次第", "房日应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"房日【兔】的「波」和「大波」可以指定任一敌方英雄。",
		"房日描述应准确表达基础攻击自由选敌")


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
