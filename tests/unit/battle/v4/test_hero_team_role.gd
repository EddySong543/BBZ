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
