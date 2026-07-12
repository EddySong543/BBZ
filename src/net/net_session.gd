extends RefCounted

## 联机会话（M1·2026-07-12）：一场联机局的"接线盒"——传输 + 房间（房主侧）+ 本端协议客户端。
## 寄存在 BattleSetup.net_session（沿用跨场景总线模式·零新 autoload/零 project.godot 改动），
## 由大厅屏创建、battle_screen 每帧 pump()、battle_screen 退场时 close() 并置空。
##
## 拓扑（与 tools/net_probe 实测一致）：
##   房主进程：MatchRoom + 本端走 Loopback（玩家0）+ 对外 ENet 服务器（玩家1）
##   加入进程：仅 ENet 客户端（玩家1）——权威核不在本机=作弊面最小

const NetTransport := preload("res://src/net/net_transport.gd")
const MatchRoom := preload("res://src/net/match_room.gd")
const MatchClient := preload("res://src/net/match_client.gd")

const DEFAULT_PORT := 47777

var role := ""                        # "host" / "join"
var enet: NetTransport.ENetTransport
var room: MatchRoom = null            # 仅房主
var _loop_room_end: Variant = null    # 房主：房间侧环回端（收本地玩家包）
var client: MatchClient


## 建房：开 ENet 门 + 本地环回接自己的客户端。失败返回 null。
static func create_host(port: int = DEFAULT_PORT) -> RefCounted:
	var s := new()
	s.role = "host"
	s.enet = NetTransport.ENetTransport.new()
	if not s.enet.host(port):
		return null
	var pair: Array = NetTransport.LoopbackTransport.make_pair()
	s._loop_room_end = pair[0]
	s.client = MatchClient.new(pair[1])
	return s


## 加入：拨号房主。失败返回 null（真正连上与否看 is_link_ready()）。
static func create_join(ip: String, port: int = DEFAULT_PORT) -> RefCounted:
	var s := new()
	s.role = "join"
	s.enet = NetTransport.ENetTransport.new()
	if not s.enet.join(ip, port):
		return null
	s.client = MatchClient.new(s.enet)
	return s


## ENet 链路是否建立（对端已握手）。
func is_link_ready() -> bool:
	enet.poll()
	return enet.is_ready()


## 房主开局（对端连上后调用一次）：t0=房主队 t1=加入方队。
func start_room(t0: Array, t1: Array, seed_v: int) -> void:
	room = MatchRoom.new()
	room.start(t0, t1, seed_v, func(p: int, msg: Dictionary) -> void:
		if p == 0:
			_loop_room_end.send(msg)
		else:
			enet.send(msg))


## 每帧泵：房主=收双路包喂房间；双方=消化本端客户端消息。
func pump() -> void:
	if role == "host" and room != null:
		for msg in _loop_room_end.poll():
			room.handle(0, msg)
		for msg in enet.poll():
			room.handle(1, msg)
	client.poll()


func close() -> void:
	if enet != null:
		enet.close()
