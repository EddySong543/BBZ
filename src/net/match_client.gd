extends RefCounted

## 客户端协议端（联机线批D·2026-07-12）：吃 S2C 消息维护本地对局视图，产 C2S 提交。
## 不含任何 UI/场景依赖——未来 battle_screen 的远程驱动（ADR-004 M1 MatchDriver）挂在这上面：
## UI 读 view/events_log 演出，玩家操作走 submit()/request_draft()/pick()/death_switch()。
##
## 用法：
##   var client := MatchClient.new(transport)   # transport = LoopbackTransport / ENetTransport
##   client.poll()                              # 每帧/每拍：泵传输层+消化消息
##   if client.phase == "select": client.submit(action, target, item_slots)

const NetProtocol := preload("res://src/net/net_protocol.gd")

var transport: Variant               # 鸭子接口：send(Dictionary) / poll() -> Array（Variant=容许任一传输实现）
var you: int = -1                    # 本端玩家位（match_start 分配）
var turn: int = -1
var phase := "waiting"               # waiting / select / death_switch / over
var view: Dictionary = {}            # 服务器最新公开视图（UI 只读）
var heroes: Array = []               # 双方阵容 [{id,name,max_hp}...]×2（match_start 快照）
var draft_offer: Dictionary = {}     # 本端最近 3 选 1 {slot, upgrade, options:[item_id]}
var events_log: Array = []           # 每拍事件批（UI 演出按序消费·消费掉可 pop）
var resolves: Array = []             # 结算消息队列（M1·battle_screen 逐条弹出播动画·含 snap）
var snap: Dictionary = {}            # 服务器最新权威快照（镜像同步源·match_start/turn_begin/resolve/view 均更新）
var snap_rev: int = 0                # 快照版本号（UI 检测"有新快照要上镜"）
var winner: int = -99
var errors: Array[String] = []       # 服务器拒绝记录（UI 提示/调试）
var snapshot: Dictionary = {}        # resync 收到的重连快照


func _init(t: Variant) -> void:
	transport = t


## 泵：传输层收包 → 按 kind 消化。每帧/每逻辑拍调用。
func poll() -> void:
	for msg in transport.poll():
		_on_msg(msg)


## 单包注入（net_session.pump_bp 路由用——BP 期统一收包·避免与 BpClient 抢 poll）。
func feed(msg: Dictionary) -> void:
	_on_msg(msg)


func _on_msg(d: Dictionary) -> void:
	match String(d.get("kind", "")):
		"match_start":
			you = int(d["you"])
			turn = int(d["turn"])
			heroes = d.get("heroes", [])
			view = d["view"]
			_take_snap(d)
			phase = "select"
		"turn_begin":
			turn = int(d["turn"])
			view = d["view"]
			_take_snap(d)
			phase = "select"
			draft_offer = {}
		"draft_offer":
			draft_offer = d
		"resolve":
			view = d["view"]
			turn = int(view.get("turn", turn))
			events_log.append(d.get("events", []))
			resolves.append(d)
			_take_snap(d)
			var pending: Array = d.get("pending", [false, false])
			if you >= 0 and bool(pending[you]):
				phase = "death_switch"
			elif bool(pending[0]) or bool(pending[1]):
				phase = "waiting"   # 对手在选替补
		"view":
			view = d["view"]
			_take_snap(d)
		"game_over":
			phase = "over"
			winner = int(d["winner"])
		"snapshot":
			snapshot = d
			you = int(d.get("you", you))   # 重连路径：snapshot 即"入场券"（大厅凭 you>=0 放行进战斗）
			_take_snap(d)
			if snap.has("turn_number"):
				turn = int(snap["turn_number"])
			# 重连相位恢复（2026-07-17 审计修复·房间 Phase{0=SELECT,1=DEATH_SWITCH,2=OVER}）：
			# DEATH_SWITCH 期没有 turn_begin 可跟——不恢复=UI 干等服务器超时代选。
			# pending 数组为绝对视角（本层不翻转）·you 直接索引。
			match int(d.get("phase", 0)):
				1:
					var pend: Array = snap.get("pending_death_switch", [false, false])
					phase = "death_switch" if (you >= 0 and bool(pend[you])) else "waiting"
				2:
					phase = "over"
					winner = int(snap.get("winner", winner))
				_:
					pass   # SELECT：房间随后必补发 turn_begin → phase="select"（原路径不动）
		"error":
			var detail := String(d.get("detail", ""))   # 可选附加信息（如 bad_version 附房主版本）
			errors.append(String(d.get("code", "")) + ("" if detail.is_empty() else ":" + detail))


func _take_snap(d: Dictionary) -> void:
	if d.has("snap"):
		snap = d["snap"]
		snap_rev += 1


# —— 玩家操作面（全部按当前 turn 打包·服务器二道门校验）——

func submit(action: int, target: int = -1, item_slots: Array = [], double: bool = false) -> void:
	transport.send(NetProtocol.msg_submit_turn(turn, action, target, item_slots, double))


func request_draft(slot: int, upgrade: bool = false) -> void:
	transport.send(NetProtocol.msg_econ_draft(turn, slot, upgrade))


func request_refill(slot: int) -> void:
	transport.send(NetProtocol.msg_econ_refill(turn, slot))


func pick(slot: int, choice: int, upgrade: bool = false) -> void:
	transport.send(NetProtocol.msg_econ_pick(turn, slot, choice, upgrade))


func death_switch(slot: int) -> void:
	transport.send(NetProtocol.msg_death_switch(turn, slot))


func request_resync() -> void:
	transport.send(NetProtocol.msg_resync())


## room_pass=房间口令（好友房准入）·gv=版本串（默认空=构造器取本机版本）。
func send_hello(team: Array, room_pass: String = "", gv: String = "") -> void:
	transport.send(NetProtocol.msg_hello(team, room_pass, gv))


# —— 视角翻转（M1·加入方=服务器眼中的玩家 1·战斗屏恒以"玩家 0=自己"渲染）——
# 快照顶层每个 per-player 字段都是长度 2 的数组 → 通用交换即完成 0↔1 翻转；
# winner 常量 P1↔P2 互换；双翻=恒等（test_match_room 锁定）。

## 翻转快照视角（深拷·不动入参）。仅加入方（you==1）需要。
static func flip_snapshot(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	for k in out:
		var v: Variant = out[k]
		if v is Array and (v as Array).size() == 2:
			var a: Array = v
			var tmp: Variant = a[0]
			a[0] = a[1]
			a[1] = tmp
	out["winner"] = flip_winner(int(out.get("winner", BattleCore.WINNER_UNDECIDED)))
	return out


## 翻转事件批视角（player 字段 0↔1·victory 事件 winner 互换）。深拷。
static func flip_events(events: Array) -> Array:
	var out: Array = []
	for e in events:
		var ev: Dictionary = (e as Dictionary).duplicate(true)
		if ev.has("player"):
			ev["player"] = 1 - int(ev["player"])
		if ev.has("winner"):
			ev["winner"] = flip_winner(int(ev["winner"]))
		out.append(ev)
	return out


static func flip_winner(w: int) -> int:
	if w == BattleCore.WINNER_P1:
		return BattleCore.WINNER_P2
	if w == BattleCore.WINNER_P2:
		return BattleCore.WINNER_P1
	return w


## 我方存活替补槽（死亡换人可选项·从公开视图推导）。
func living_reserves() -> Array[int]:
	var out: Array[int] = []
	if you < 0 or view.is_empty():
		return out
	var my_hp: Array = view["hp"][you]
	var active := int((view["active_index"] as Array)[you])
	for s in my_hp.size():
		if s != active and int(my_hp[s]) > 0:
			out.append(s)
	return out
