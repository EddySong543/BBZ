extends GutTest

## PlayerProfile（个人资料存档·2026-07-16 地基）单元测试。
## save_enabled=false 全程关落盘——单测禁碰文件系统（test-standards）；
## reset() 在关落盘时=纯内存回默认，作为每例的干净起点。

const ProfileStore := preload("res://src/core/player_profile.gd")


func before_each() -> void:
	ProfileStore.save_enabled = false
	ProfileStore.reset()


func after_all() -> void:
	# 还原静态态：开回落盘 + 置未加载，避免污染同进程后续（下次访问重新读真实存档）
	ProfileStore.save_enabled = true
	ProfileStore._loaded = false


func test_player_profile_defaults_name_and_avatar() -> void:
	# Arrange: before_each 已重置

	# Act
	var n := ProfileStore.get_player_name()
	var a := ProfileStore.get_avatar_hero()

	# Assert
	assert_eq(n, ProfileStore.DEFAULT_NAME)
	assert_eq(a, ProfileStore.DEFAULT_AVATAR)


func test_player_profile_set_name_trims_and_clamps_length() -> void:
	# Arrange
	var long_name := "  一二三四五六七八九十  "

	# Act
	ProfileStore.set_player_name(long_name)

	# Assert: 去首尾空白 + 截 8 字
	assert_eq(ProfileStore.get_player_name(), "一二三四五六七八")


func test_player_profile_set_name_empty_keeps_old() -> void:
	# Arrange
	ProfileStore.set_player_name("老大")

	# Act
	ProfileStore.set_player_name("   ")

	# Assert
	assert_eq(ProfileStore.get_player_name(), "老大")


func test_player_profile_set_avatar_updates_value() -> void:
	# Arrange: 默认 h01

	# Act
	ProfileStore.set_avatar_hero("h07")

	# Assert
	assert_eq(ProfileStore.get_avatar_hero(), "h07")


func test_player_profile_avatar_path_falls_back_on_missing_hero() -> void:
	# Arrange: 指向不存在的英雄目录
	ProfileStore.set_avatar_hero("h99")

	# Act
	var p := ProfileStore.avatar_portrait_path()

	# Assert: 回落默认英雄立绘
	assert_eq(p, "res://assets/sprites/heroes/h01/h01_portrait.png")


func test_player_profile_record_result_increments_counter() -> void:
	# Arrange: 全零起点

	# Act
	ProfileStore.record_result("match", "win")
	ProfileStore.record_result("match", "win")
	ProfileStore.record_result("match", "lose")
	ProfileStore.record_result("net", "draw")

	# Assert
	assert_eq(ProfileStore.get_stat("match", "win"), 2)
	assert_eq(ProfileStore.get_stat("match", "lose"), 1)
	assert_eq(ProfileStore.get_stat("match", "draw"), 0)
	assert_eq(ProfileStore.get_stat("net", "draw"), 1)


func test_player_profile_record_result_rejects_unknown_keys() -> void:
	# Arrange: 全零起点

	# Act: 白名单外的 mode / outcome 应被忽略（不炸不计）
	ProfileStore.record_result("unknown", "win")
	ProfileStore.record_result("match", "crash")

	# Assert
	for m: String in ProfileStore.MODES:
		for o: String in ProfileStore.OUTCOMES:
			assert_eq(ProfileStore.get_stat(m, o), 0)


func test_player_profile_mode_total_sums_outcomes() -> void:
	# Arrange
	ProfileStore.record_result("net", "win")
	ProfileStore.record_result("net", "lose")
	ProfileStore.record_result("net", "draw")

	# Act / Assert
	assert_eq(ProfileStore.mode_total("net"), 3)
	assert_eq(ProfileStore.mode_total("match"), 0)


func test_player_profile_win_rate_pct_rounds_and_handles_empty() -> void:
	# Arrange
	ProfileStore.record_result("match", "win")
	ProfileStore.record_result("match", "win")
	ProfileStore.record_result("match", "lose")

	# Act / Assert: 2/3 → 67%；没打过 = -1
	assert_eq(ProfileStore.win_rate_pct("match"), 67)
	assert_eq(ProfileStore.win_rate_pct("net"), -1)
