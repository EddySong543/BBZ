extends RefCounted

## 匹配流程骨架（2026-07-17 打地基批·任务11「匹配画面」的逻辑层——画面/动画待 Eddy 出方向）。
## 快速匹配状态机（局域网版·公网选型落地后=换 backend 适配器·状态机不变）：
##
##   begin() → SEARCHING（扫信标 search_window_s 秒）
##     ├─ 找到合格房（开放·版本一致）→ CONNECTING（拨号·connect_timeout_s 内等链路）
##     │    ├─ 链路通 → MATCHED（role="join"·session 交调用方）
##     │    └─ 超时 → 拉黑该房回 SEARCHING（窗口耗尽转 HOSTING）
##     └─ 窗口内没房 → HOSTING（建房+信标广播·等对端上门）
##          └─ 链路通 → MATCHED（role="host"）
##   任意时刻 cancel() → CANCELLED；总时长 total_timeout_s 耗尽 → TIMED_OUT。
##
## ⚠ 已知局限（骨架级·记录在案）：双方同时开匹配且都没等到对方信标时会双双建房干等
##   （对称建房竞态）——公网 backend 天然解决；LAN 版靠 search_window 拉开概率，不另修。
## 纯逻辑可注入（GUT 零 socket）：browser/beacon/建房拨号全走鸭子接口/Callable，
##   真实件=LanDiscovery.Browser/Beacon + NetSession.create_host/create_join（create_lan 装配）。
## MATCHED 后 session 所有权移交调用方（本机不再 close）；其余终态自动清场。
##
## 用法（匹配画面 UI 挂法）：
##   var mm := Matchmaker.create_lan("玩家1 的房间")   # preload 引用
##   mm.begin()
##   每帧: mm.tick(delta)；UI 读 mm.state / mm.status_text()；取消钮 → mm.cancel()
##   mm.state == Matchmaker.State.MATCHED → 拿 mm.session（NetSession·链路已通）走 hello/BP 流程

const NetSession := preload("res://src/net/net_session.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")
const LanDiscovery := preload("res://src/net/lan_discovery.gd")

enum State { IDLE, SEARCHING, CONNECTING, HOSTING, MATCHED, CANCELLED, TIMED_OUT, FAILED }

const SEARCH_WINDOW_S := 2.5      # 扫信标窗口（信标间隔 1s → 两拍富余）
const CONNECT_TIMEOUT_S := 5.0    # 单次拨号等链路上限
const TOTAL_TIMEOUT_S := 60.0     # 匹配总时长上限（挂机保护·UI 可另给旋钮）

signal state_changed(new_state: int)

var state: int = State.IDLE
var role := ""                    # MATCHED 后："host" / "join"
var session: Variant = null       # MATCHED 后=已通链路的 NetSession（所有权移交调用方）
var port: int = NetSession.DEFAULT_PORT
var room_name := ""
var search_window_s := SEARCH_WINDOW_S
var connect_timeout_s := CONNECT_TIMEOUT_S
var total_timeout_s := TOTAL_TIMEOUT_S

# 可注入件（GUT 假件口）：browser/beacon=鸭子接口·host_fn(port)->session·join_fn(ip,port)->session
var browser: Variant = null       # start()->bool / poll() / list()->Array / stop()
var beacon: Variant = null        # start(payload) / tick(delta) / stop()
var host_fn: Callable
var join_fn: Callable

var _t_total := 0.0
var _t_state := 0.0
var _tried_ips: Dictionary = {}   # 拨号失败拉黑（本次匹配内）
var _dial_ip := ""                # 当前拨号目标（连接超时拉黑用）


## 真实件装配（局域网快速匹配）。测试用 new() 后自行注入假件。
static func create_lan(name_v: String, port_v: int = NetSession.DEFAULT_PORT) -> RefCounted:
	var m := new()
	m.room_name = name_v
	m.port = port_v
	m.browser = LanDiscovery.Browser.new()
	m.beacon = LanDiscovery.Beacon.new()
	m.host_fn = func(p: int) -> Variant: return NetSession.create_host(p)
	m.join_fn = func(ip: String, p: int) -> Variant: return NetSession.create_join(ip, p)
	return m


func begin() -> void:
	if state != State.IDLE:
		return
	_t_total = 0.0
	_tried_ips = {}
	# 发现端口被占（同机双开等）= 搜不了 → 直接建房等人（LanDiscovery 同款降级思路）
	if browser != null and browser.start():
		_set_state(State.SEARCHING)
	else:
		_start_hosting()


## 每帧驱动（匹配画面 _process 调）。终态/未开始=空转（热路径零分配·不建数组判态）。
func tick(delta: float) -> void:
	if state != State.SEARCHING and state != State.CONNECTING and state != State.HOSTING:
		return
	_t_total += delta
	_t_state += delta
	if _t_total >= total_timeout_s:
		_cleanup()
		_set_state(State.TIMED_OUT)
		return
	match state:
		State.SEARCHING:
			browser.poll()
			var target := _pick_room()
			if not target.is_empty():
				_dial(target)
			elif _t_state >= search_window_s:
				_start_hosting()
		State.CONNECTING:
			if session != null and session.is_link_ready():
				_matched("join")
			elif _t_state >= connect_timeout_s:
				# 拨不通：拉黑此房回搜索（窗口已耗尽会立刻转建房）
				_tried_ips[_dial_ip] = true
				_dial_ip = ""
				if session != null:
					session.close()
				session = null
				if browser != null and browser.start():
					_set_state(State.SEARCHING)
				else:
					_start_hosting()
		State.HOSTING:
			beacon.tick(delta)
			if session != null and session.is_link_ready():
				_matched("host")


## 玩家取消（匹配画面取消钮）。MATCHED 后无效（对局已成·走正常退出流程）。
func cancel() -> void:
	if state == State.MATCHED:
		return
	_cleanup()
	_set_state(State.CANCELLED)


## 匹配画面状态行（占位文案·正式文案随任务11 画面来）。
func status_text() -> String:
	match state:
		State.SEARCHING:
			return tr("正在寻找对手…")
		State.CONNECTING:
			return tr("找到对手·连接中…")
		State.HOSTING:
			return tr("等待对手加入…")
		State.MATCHED:
			return tr("对手已就位！")
		State.TIMED_OUT:
			return tr("暂时没有对手·稍后再试")
		State.CANCELLED:
			return tr("已取消")
		State.FAILED:
			return tr("匹配失败")
	return ""


## 合格房：开放（无口令）+ 版本一致 + 没拉黑。取 ip 序首个（Browser.list 已排序）。
func _pick_room() -> Dictionary:
	for r in browser.list():
		var d: Dictionary = r
		if bool(d.get("has_pass", false)):
			continue
		if String(d.get("gv", "")) != NetProtocol.game_version():
			continue
		if _tried_ips.has(String(d.get("ip", ""))):
			continue
		return d
	return {}


func _dial(room: Dictionary) -> void:
	var ip := String(room["ip"])
	browser.stop()   # 拨号期间不占发现端口（对端若同机双开要用）
	var s: Variant = join_fn.call(ip, int(room.get("port", port)))
	if s == null:
		_tried_ips[ip] = true
		if browser.start():
			_set_state(State.SEARCHING)
		else:
			_start_hosting()
		return
	session = s
	_dial_ip = ip
	_set_state(State.CONNECTING)


func _start_hosting() -> void:
	if browser != null:
		browser.stop()   # ⚠ 发现端口独占：建房广播前必须让出（同机双开测试先例）
	var s: Variant = host_fn.call(port)
	if s == null:
		_cleanup()
		_set_state(State.FAILED)   # 对局端口也被占（同机已有房）——UI 提示走手动加入
		return
	session = s
	beacon.start(LanDiscovery.Beacon.make_payload(room_name, port, NetProtocol.game_version(), false))
	_set_state(State.HOSTING)


func _matched(r: String) -> void:
	role = r
	if beacon != null:
		beacon.stop()   # 对局开始必须停信标（LanDiscovery 规矩）
	if browser != null:
		browser.stop()
	_set_state(State.MATCHED)


func _cleanup() -> void:
	if beacon != null:
		beacon.stop()
	if browser != null:
		browser.stop()
	if session != null:
		session.close()
		session = null
	role = ""


func _set_state(s: int) -> void:
	state = s
	_t_state = 0.0
	state_changed.emit(s)
