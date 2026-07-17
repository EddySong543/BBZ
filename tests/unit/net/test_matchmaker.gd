extends GutTest

## 匹配流程骨架 行为锁定测试（2026-07-17 打地基批·任务11 逻辑层）。
## 全假件注入（browser/beacon/建房拨号）——单测零 socket（test-standards）。
## 锁：搜到房=拨号入局(join)/没房=建房等人(host)/跳过口令房与版本不合房/
##     取消与总超时清场/发现端口被占降级直接建房/拨不通拉黑回搜。

const Matchmaker := preload("res://src/net/matchmaker.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")


class FakeBrowser extends RefCounted:
	var bind_ok := true
	var rooms: Array = []
	var started := false
	var stop_count := 0

	func start() -> bool:
		started = bind_ok
		return bind_ok

	func poll() -> void:
		pass

	func list() -> Array:
		return rooms.duplicate(true)

	func stop() -> void:
		started = false
		stop_count += 1


class FakeBeacon extends RefCounted:
	var started := false
	var was_started := false
	var payload: Dictionary = {}

	func start(p: Dictionary) -> void:
		started = true
		was_started = true
		payload = p

	func tick(_d: float) -> void:
		pass

	func stop() -> void:
		started = false


class FakeSession extends RefCounted:
	var ready := false
	var closed := false

	func is_link_ready() -> bool:
		return ready

	func close() -> void:
		closed = true


func _room(ip: String, has_pass: bool = false, gv: String = "") -> Dictionary:
	return {"ip": ip, "name": "room", "port": 47777,
		"gv": (NetProtocol.game_version() if gv.is_empty() else gv), "has_pass": has_pass}


func _mm(browser: FakeBrowser, beacon: FakeBeacon, host_s: Variant, join_s: Variant) -> RefCounted:
	var m: RefCounted = Matchmaker.new()
	m.room_name = "测试房"
	m.browser = browser
	m.beacon = beacon
	m.host_fn = func(_p: int) -> Variant: return host_s
	m.join_fn = func(_ip: String, _p: int) -> Variant: return join_s
	return m


func test_matchmaker_finds_room_and_joins() -> void:
	# Arrange：广播里有一间合格房
	var browser := FakeBrowser.new()
	browser.rooms = [_room("192.168.1.5")]
	var beacon := FakeBeacon.new()
	var join_s := FakeSession.new()
	var m := _mm(browser, beacon, FakeSession.new(), join_s)

	# Act：开搜 → 首拍拨号 → 链路通
	m.begin()
	assert_eq(m.state, Matchmaker.State.SEARCHING)
	m.tick(0.1)
	assert_eq(m.state, Matchmaker.State.CONNECTING)
	join_s.ready = true
	m.tick(0.1)

	# Assert：join 成局·信标从未开·发现端口已让出
	assert_eq(m.state, Matchmaker.State.MATCHED)
	assert_eq(m.role, "join")
	assert_eq(m.session, join_s)
	assert_false(beacon.was_started)
	assert_false(browser.started)


func test_matchmaker_hosts_when_no_room_found() -> void:
	# Arrange：空网
	var browser := FakeBrowser.new()
	var beacon := FakeBeacon.new()
	var host_s := FakeSession.new()
	var m := _mm(browser, beacon, host_s, FakeSession.new())

	# Act：窗口耗尽转建房 → 对端上门
	m.begin()
	m.tick(3.0)   # > SEARCH_WINDOW_S
	assert_eq(m.state, Matchmaker.State.HOSTING)
	assert_true(beacon.started, "建房必须开信标")
	host_s.ready = true
	m.tick(0.1)

	# Assert：host 成局·信标已停
	assert_eq(m.state, Matchmaker.State.MATCHED)
	assert_eq(m.role, "host")
	assert_false(beacon.started, "对局开始必须停信标")


func test_matchmaker_skips_passworded_and_version_mismatch_rooms() -> void:
	# Arrange：口令房 + 版本不合房=都不合格
	var browser := FakeBrowser.new()
	browser.rooms = [_room("192.168.1.5", true), _room("192.168.1.6", false, "别的版本")]
	var m := _mm(browser, FakeBeacon.new(), FakeSession.new(), FakeSession.new())

	# Act
	m.begin()
	m.tick(0.5)

	# Assert：没拨号（还在搜）·窗口耗尽转建房
	assert_eq(m.state, Matchmaker.State.SEARCHING)
	m.tick(2.5)
	assert_eq(m.state, Matchmaker.State.HOSTING)


func test_matchmaker_cancel_cleans_up_everything() -> void:
	# Arrange：建房等人中
	var beacon := FakeBeacon.new()
	var host_s := FakeSession.new()
	var m := _mm(FakeBrowser.new(), beacon, host_s, FakeSession.new())
	m.begin()
	m.tick(3.0)

	# Act
	m.cancel()

	# Assert：终态取消·信标停·会话关并置空
	assert_eq(m.state, Matchmaker.State.CANCELLED)
	assert_false(beacon.started)
	assert_true(host_s.closed)
	assert_null(m.session)


func test_matchmaker_total_timeout_while_hosting() -> void:
	# Arrange
	var host_s := FakeSession.new()
	var m := _mm(FakeBrowser.new(), FakeBeacon.new(), host_s, FakeSession.new())
	m.begin()
	m.tick(3.0)
	assert_eq(m.state, Matchmaker.State.HOSTING)

	# Act：拨过总时限
	m.tick(61.0)

	# Assert
	assert_eq(m.state, Matchmaker.State.TIMED_OUT)
	assert_true(host_s.closed)


func test_matchmaker_browser_bind_fail_degrades_to_hosting() -> void:
	# Arrange：发现端口被占（同机双开先例）
	var browser := FakeBrowser.new()
	browser.bind_ok = false
	var m := _mm(browser, FakeBeacon.new(), FakeSession.new(), FakeSession.new())

	# Act
	m.begin()

	# Assert：跳过搜索直接建房
	assert_eq(m.state, Matchmaker.State.HOSTING)


func test_matchmaker_connect_timeout_blacklists_and_rehosts() -> void:
	# Arrange：唯一候选房拨不通（对端假死）
	var browser := FakeBrowser.new()
	browser.rooms = [_room("192.168.1.5")]
	var join_s := FakeSession.new()   # 永不 ready
	var host_s := FakeSession.new()
	var m := _mm(browser, FakeBeacon.new(), host_s, join_s)
	m.begin()
	m.tick(0.1)
	assert_eq(m.state, Matchmaker.State.CONNECTING)

	# Act：拨号超时 → 拉黑回搜 → 同房被跳过 → 窗口耗尽建房
	m.tick(6.0)
	assert_eq(m.state, Matchmaker.State.SEARCHING, "拨不通应拉黑回搜")
	assert_true(join_s.closed)
	m.tick(3.0)

	# Assert
	assert_eq(m.state, Matchmaker.State.HOSTING)
	assert_eq(m.session, host_s)
