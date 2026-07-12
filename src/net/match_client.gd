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
var winner: int = -99
var errors: Array[String] = []       # 服务器拒绝记录（UI 提示/调试）
var snapshot: Dictionary = {}        # resync 收到的重连快照


func _init(t: Variant) -> void:
	transport = t


## 泵：传输层收包 → 按 kind 消化。每帧/每逻辑拍调用。
func poll() -> void:
	for msg in transport.poll():
		_on_msg(msg)


func _on_msg(d: Dictionary) -> void:
	match String(d.get("kind", "")):
		"match_start":
			you = int(d["you"])
			turn = int(d["turn"])
			heroes = d.get("heroes", [])
			view = d["view"]
			phase = "select"
		"turn_begin":
			turn = int(d["turn"])
			view = d["view"]
			phase = "select"
			draft_offer = {}
		"draft_offer":
			draft_offer = d
		"resolve":
			view = d["view"]
			turn = int(view.get("turn", turn))
			events_log.append(d.get("events", []))
			var pending: Array = d.get("pending", [false, false])
			if you >= 0 and bool(pending[you]):
				phase = "death_switch"
			elif bool(pending[0]) or bool(pending[1]):
				phase = "waiting"   # 对手在选替补
		"view":
			view = d["view"]
		"game_over":
			phase = "over"
			winner = int(d["winner"])
		"snapshot":
			snapshot = d
		"error":
			errors.append(String(d.get("code", "")))


# —— 玩家操作面（全部按当前 turn 打包·服务器二道门校验）——

func submit(action: int, target: int = -1, item_slots: Array = []) -> void:
	transport.send(NetProtocol.msg_submit_turn(turn, action, target, item_slots))


func request_draft(slot: int, upgrade: bool = false) -> void:
	transport.send(NetProtocol.msg_econ_draft(turn, slot, upgrade))


func pick(slot: int, choice: int, upgrade: bool = false) -> void:
	transport.send(NetProtocol.msg_econ_pick(turn, slot, choice, upgrade))


func death_switch(slot: int) -> void:
	transport.send(NetProtocol.msg_death_switch(turn, slot))


func request_resync() -> void:
	transport.send(NetProtocol.msg_resync())


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
