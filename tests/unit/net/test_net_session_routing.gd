extends GutTest

## net_session BP 期路由层单元测试（2026-07-17 技术债#5）。
## 只测纯路由段（pump_bp 的 kind 分拣 + ensure_bp_client 幂等）——零 socket：
## 裸 new() 会话（不走 create_host/join=不开 ENet）·client.transport=环回端假"服务器"。
## host 侧收包路径依赖真 ENet·由 tools/lan_probe / lan_duo_probe E2E 覆盖，不在单测面。

const NetSession := preload("res://src/net/net_session.gd")
const NetTransport := preload("res://src/net/net_transport.gd")
const MatchClient := preload("res://src/net/match_client.gd")


## 裸会话桌：pair[0]=假服务器端·pair[1]=本端客户端传输。
func _bare_session() -> Dictionary:
	var s: RefCounted = NetSession.new()
	var pair: Array = NetTransport.LoopbackTransport.make_pair()
	s.client = MatchClient.new(pair[1])
	s.ensure_bp_client()
	return {s = s, server_end = pair[0]}


func test_net_session_pump_bp_routes_bp_kinds_to_bp_client() -> void:
	# Arrange
	var t := _bare_session()

	# Act：服务器端混发 bp 包与战斗包 → 一次泵
	t["server_end"].send({v = 1, kind = "bp_progress", n = 2})
	t["server_end"].send({v = 1, kind = "game_over", winner = 0})
	(t.s as RefCounted).pump_bp()

	# Assert：bp_* 进 bp_client·其余进 MatchClient（match_start 无缝转战斗的同一条路）
	assert_eq(t.s.bp_client.opp_progress, 2, "bp_progress 应路由进 bp_client")
	assert_eq(t.s.client.phase, "over", "非 bp 包应路由进 MatchClient")
	assert_eq(t.s.client.winner, 0)


func test_net_session_pump_bp_bp_start_reaches_bp_client_not_match_client() -> void:
	# Arrange
	var t := _bare_session()

	# Act
	t["server_end"].send({v = 1, kind = "bp_start", you = 1, pool = ["h01", "h02"]})
	(t.s as RefCounted).pump_bp()

	# Assert：bp_client 进 draft·MatchClient 状态不被 bp 包污染
	assert_eq(t.s.bp_client.phase, "draft")
	assert_eq(t.s.bp_client.you, 1)
	assert_eq(t.s.client.phase, "waiting", "bp 包不得漏进 MatchClient")


func test_net_session_ensure_bp_client_idempotent() -> void:
	# Arrange
	var t := _bare_session()
	var first: RefCounted = t.s.bp_client

	# Act
	(t.s as RefCounted).ensure_bp_client()

	# Assert：不重建（重建会丢已收的 BP 状态）
	assert_eq(t.s.bp_client, first)
