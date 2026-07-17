extends GutTest

## AudioEvents（音频事件系统骨架·2026-07-17 打地基批）单元测试。
## AudioServer 在 headless（Dummy 驱动）下可用——总线增删/音量读写全成立；
## 播放路径只验"不崩不刷屏"（无资产期=静默降级契约）。

const AudioEventsT := preload("res://src/core/audio_events.gd")


func after_all() -> void:
	# 还原总线音量（总线本体留着无害·同进程后续测试不受影响）
	for bus_name: String in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, 0.0)
			AudioServer.set_bus_mute(idx, false)


func test_audio_events_ensure_buses_creates_music_and_sfx() -> void:
	# Act
	AudioEventsT.ensure_buses()

	# Assert
	assert_true(AudioServer.get_bus_index("Music") >= 0, "Music 总线应存在")
	assert_true(AudioServer.get_bus_index("SFX") >= 0, "SFX 总线应存在")


func test_audio_events_ensure_buses_repeat_call_no_duplicate() -> void:
	# Arrange
	AudioEventsT.ensure_buses()
	var count_before := AudioServer.bus_count

	# Act
	AudioEventsT.ensure_buses()

	# Assert
	assert_eq(AudioServer.bus_count, count_before, "重复调用不得新增总线（幂等）")


func test_audio_events_buses_route_to_master() -> void:
	# Arrange
	AudioEventsT.ensure_buses()

	# Act / Assert
	assert_eq(String(AudioServer.get_bus_send(AudioServer.get_bus_index("Music"))), "Master")
	assert_eq(String(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX"))), "Master")


func test_audio_events_play_unknown_event_no_crash() -> void:
	# Act：未知事件 + 二次调用（走 warn-once 去重路径）
	AudioEventsT.play("test_不存在的事件")
	AudioEventsT.play("test_不存在的事件")
	AudioEventsT.play_music("test_不存在的音乐")

	# Assert：静默降级不崩
	assert_true(true)


func test_audio_events_table_skips_doc_keys() -> void:
	# Act
	AudioEventsT.reload_events()

	# Assert："_" 开头键=文档保留·不得成为事件
	assert_false(AudioEventsT.has_event("_doc"))
	assert_false(AudioEventsT.has_event("_example"))


func test_game_settings_apply_bus_volume_sets_db_and_mute() -> void:
	# Arrange
	AudioEventsT.ensure_buses()
	var idx := AudioServer.get_bus_index("Music")

	# Act / Assert：半音量 → dB 换算 + 不静音
	GameSettings._apply_bus_volume("Music", 0.5)
	assert_false(AudioServer.is_bus_mute(idx))
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.01)

	# Act / Assert：零音量 → 静音
	GameSettings._apply_bus_volume("Music", 0.0)
	assert_true(AudioServer.is_bus_mute(idx), "0 音量应静音总线")

	# 复位
	GameSettings._apply_bus_volume("Music", 1.0)
