extends GutTest

## GameSettings 纯逻辑段单元测试（2026-07-17 技术债#4）。
## ⚠ 只测不碰盘的段：parse_resolution / 未知键拒绝 / 默认值回退——
## set_value 合法键会 save() 落盘、load_from_disk 读真实 user:// cfg=外部状态（test-standards 禁），
## 显示链路（窗口模式/分辨率应用）由 tools/display_probe 真窗口 6 项覆盖，不在单测面。

const Settings := preload("res://src/core/game_settings.gd")


func before_each() -> void:
	# 注入内存态（player_profile 测试同范式）：跳过读盘=测试不依赖本机 cfg 内容
	Settings._data = Settings.DEFAULTS.duplicate(true)
	Settings._loaded = true


func after_all() -> void:
	# 还原静态态：置未加载·下次访问重新读真实存档（不污染同进程后续）
	Settings._loaded = false
	Settings._data = {}


func test_game_settings_parse_resolution_valid_string() -> void:
	# Act / Assert
	assert_eq(Settings.parse_resolution("1920x1080"), Vector2i(1920, 1080))
	assert_eq(Settings.parse_resolution("1280x720"), Vector2i(1280, 720))


func test_game_settings_parse_resolution_invalid_falls_back_to_design_size() -> void:
	# Act / Assert：畸形/零/负数全部回退设计画布
	assert_eq(Settings.parse_resolution("abc"), Settings.DESIGN_SIZE)
	assert_eq(Settings.parse_resolution(""), Settings.DESIGN_SIZE)
	assert_eq(Settings.parse_resolution("0x1080"), Settings.DESIGN_SIZE)
	assert_eq(Settings.parse_resolution("-100x200"), Settings.DESIGN_SIZE)
	assert_eq(Settings.parse_resolution("1920x1080x60"), Settings.DESIGN_SIZE)


func test_game_settings_set_value_unknown_key_rejected_no_write() -> void:
	# Act：未知键（白名单外）
	Settings.set_value("不存在的设置键", 42)

	# Assert：内存态未被污染（拒收在 save 之前=不落盘）
	assert_false(Settings._data.has("不存在的设置键"))


func test_game_settings_get_value_missing_key_falls_back_to_default() -> void:
	# Arrange：内存态删掉一个键（模拟旧版本 cfg 缺新键）
	Settings._data.erase("music_volume")

	# Act / Assert：回退 DEFAULTS
	assert_eq(float(Settings.get_value("music_volume")), float(Settings.DEFAULTS["music_volume"]))


func test_game_settings_resolution_presets_all_parseable() -> void:
	# Assert：预设分辨率表每项解析后能往返回原串（防手滑往表里加坏串）
	for s: String in Settings.RESOLUTION_PRESETS:
		var v := Settings.parse_resolution(s)
		assert_eq("%dx%d" % [v.x, v.y], s, "预设 '%s' 应可解析往返" % s)
