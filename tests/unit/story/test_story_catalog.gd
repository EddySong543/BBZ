extends GutTest

## 故事模式关卡目录 + 通关进度 行为锁定测试（任务 B 壳·2026-07-12）。
## 目录侧=锁 levels.json 数据质量（结构校验/分组排序/英雄资源存在）；
## 进度侧=纯内存逻辑（通关/解锁/幂等），零文件系统依赖。

const StoryCatalog := preload("res://src/story/story_catalog.gd")
const StoryProgress := preload("res://src/story/story_progress.gd")


func test_story_catalog_load_levels_returns_nonempty() -> void:
	# Arrange + Act
	var levels: Array = StoryCatalog.load_levels()
	# Assert
	assert_gt(levels.size(), 0, "关卡表应至少有 1 关")


func test_story_catalog_levels_pass_validation() -> void:
	# Arrange
	var levels: Array = StoryCatalog.load_levels()
	# Act
	var errs: Array = StoryCatalog.validate(levels)
	# Assert
	assert_eq(errs.size(), 0, "关卡表校验错误: %s" % [errs])


func test_story_catalog_team_hero_resources_exist() -> void:
	# Arrange
	var levels: Array = StoryCatalog.load_levels()
	# Act + Assert
	for lv in levels:
		for id in (lv["player_team"] as Array) + (lv["enemy_team"] as Array):
			assert_true(ResourceLoader.exists("res://assets/data/heroes/%s.tres" % id),
				"关卡 %s 引用了不存在的英雄资源 %s" % [lv["id"], id])


func test_story_catalog_by_category_covers_all_and_sorted() -> void:
	# Arrange
	var levels: Array = StoryCatalog.load_levels()
	# Act
	var cols: Dictionary = StoryCatalog.by_category(levels)
	# Assert：四类键齐全 + 组内 order 升序
	for cat in StoryCatalog.CATEGORIES:
		assert_true(cols.has(cat), "缺类别 %s" % cat)
		var prev := 0
		for lv in cols[cat]:
			assert_true(int(lv["order"]) >= prev, "%s 类 order 未升序" % cat)
			prev = int(lv["order"])


func test_story_catalog_validate_flags_bad_level() -> void:
	# Arrange：空 id / 非法类别 / 队伍人数错 / requires 断链
	var bad: Array = [
		{id = "", category = "main", title = "x", intro_lines = ["x"],
			player_team = ["h01", "h02", "h03"], enemy_team = ["h01", "h02", "h03"], order = 1},
		{id = "b1", category = "nope", title = "x", intro_lines = ["x"],
			player_team = ["h01"], enemy_team = ["h01", "h02", "h03"], requires = "ghost", order = 0},
	]
	# Act
	var errs: Array = StoryCatalog.validate(bad)
	# Assert
	assert_gt(errs.size(), 3, "应报出多条结构错误·实际: %s" % [errs])


func test_story_progress_mark_cleared_is_idempotent() -> void:
	# Arrange
	var pg := StoryProgress.new()
	# Act
	pg.mark_cleared("main_01")
	pg.mark_cleared("main_01")
	# Assert
	assert_true(pg.is_cleared("main_01"))
	assert_eq(pg.cleared_count(), 1)


func test_story_progress_unlock_requires_prerequisite_cleared() -> void:
	# Arrange
	var pg := StoryProgress.new()
	var gated: Dictionary = {id = "main_02", requires = "main_01"}
	var open: Dictionary = {id = "main_01", requires = ""}
	# Act + Assert：前置未通=锁·通关后=开
	assert_true(pg.is_unlocked(open), "无前置关应直接解锁")
	assert_false(pg.is_unlocked(gated), "前置未通关应锁定")
	pg.mark_cleared("main_01")
	assert_true(pg.is_unlocked(gated), "前置通关后应解锁")
