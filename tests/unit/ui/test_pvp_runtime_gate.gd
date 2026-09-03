extends GutTest

const RuntimeFeatures := preload("res://src/core/runtime_features.gd")
const ProfileStore := preload("res://src/core/player_profile.gd")


class FakeSession extends RefCounted:
	var closed: bool = false

	func close() -> void:
		closed = true


func before_each() -> void:
	ProfileStore.save_enabled = false


func after_each() -> void:
	BattleSetup.close_net_session()
	BattleSetup.reset()
	ProfileStore.save_enabled = true


func test_stage_zero_disables_pvp_runtime() -> void:
	assert_false(RuntimeFeatures.PVP_ENABLED)


func test_disabled_lobby_never_starts_discovery_or_session() -> void:
	var stale := FakeSession.new()
	BattleSetup.net_session = stale
	var packed := load("res://src/ui/net_lobby_screen.tscn") as PackedScene
	var lobby := packed.instantiate() as Control
	add_child_autofree(lobby)
	await get_tree().process_frame
	assert_null(lobby.get("_browser"), "休眠大厅不得绑定局域网发现端口")
	assert_null(lobby.get("_beacon"), "休眠大厅不得广播房间")
	assert_null(lobby.get("_session"), "休眠大厅不得创建联机会话")
	assert_true(stale.closed, "直接进入休眠大厅时也必须释放残留 peer")
	assert_null(BattleSetup.net_session)


func test_disabled_bp_does_not_start_draft() -> void:
	var packed := load("res://src/ui/bp_screen.tscn") as PackedScene
	var bp := packed.instantiate() as Control
	add_child_autofree(bp)
	await get_tree().process_frame
	assert_true((bp.get_node("BPTimer") as Timer).is_stopped())
	assert_true((bp.get("all_heroes") as Array).is_empty(),
			"休眠 BP 不得初始化本地对战阵容")


func test_profile_hides_pvp_rank_and_stats_but_keeps_profile_data() -> void:
	var packed := load("res://src/ui/profile_screen.tscn") as PackedScene
	var profile := packed.instantiate() as Control
	add_child_autofree(profile)
	await get_tree().process_frame
	assert_false((profile.get_node("StatsArea") as Control).visible)
	for label: Node in profile.find_children("*", "Label", true, false):
		assert_ne((label as Label).text, "段位 · 未定级")


func test_configure_pve_closes_stale_network_session() -> void:
	var stale := FakeSession.new()
	BattleSetup.net_session = stale
	BattleSetup.net_rtk = "stale-token"
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	assert_true(BattleSetup.configure_pve([hero], [hero]))
	assert_true(stale.closed)
	assert_null(BattleSetup.net_session)
	assert_eq(BattleSetup.net_rtk, "")
