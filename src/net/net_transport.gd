extends RefCounted

## 传输层（联机线批C·2026-07-12）：统一鸭子接口 send(Dictionary) / poll() -> Array[Dictionary]。
## - LoopbackTransport：进程内成对队列。用途：GUT 整局测试（单测不碰网络）+ 未来"主机侧本地玩家"
##   （房主进程 = 房间 + 本地环回 + 对外 ENet，两端同一协议）。
## - ENetTransport：局域网/直连 1v1（JSON-UTF8 可靠有序包·点对点单对端）。
##   ⚠ 真网络行为由 tools/net_probe 验证（单元测试禁网络依赖·tests/ 规则）。
##   ⚠ 明文 JSON 仅限开发期；上线走加密通道 = ADR-004 M3。


## 进程内环回：make_pair() 产两端，A.send 进 B 收件箱，反之亦然。
class LoopbackTransport extends RefCounted:
	var _inbox: Array = []
	var _outbox: Array = []   # 即对端的 _inbox（共享引用）

	static func make_pair() -> Array:
		var qa: Array = []
		var qb: Array = []
		var a := LoopbackTransport.new()
		var b := LoopbackTransport.new()
		a._inbox = qa
		a._outbox = qb
		b._inbox = qb
		b._outbox = qa
		return [a, b]

	func send(d: Dictionary) -> bool:
		# 深拷隔离两端 + 模拟真网络的 JSON 降级（int→float），让测试路径=真实路径
		var wire: Variant = JSON.parse_string(JSON.stringify(d))
		if not (wire is Dictionary):
			return false
		_outbox.append(wire)
		return true

	func poll() -> Array:
		var out := _inbox.duplicate()
		_inbox.clear()
		return out


## ENet 点对点（1v1 单对端）：host() 开门等一个客户端；join() 连主机。
## 可靠有序传输；对端 id 经 peer_connected 信号捕获。需定期调 poll()（驱动 ENet 泵+收包）。
class ENetTransport extends RefCounted:
	var peer := ENetMultiplayerPeer.new()
	var remote_id: int = 0   # 对端 peer id（0=尚未连上）

	func _init() -> void:
		peer.peer_connected.connect(func(id: int) -> void: remote_id = id)
		peer.peer_disconnected.connect(func(_id: int) -> void: remote_id = 0)

	func host(port: int) -> bool:
		return peer.create_server(port, 1) == OK

	func join(ip: String, port: int) -> bool:
		return peer.create_client(ip, port) == OK

	func is_ready() -> bool:
		return remote_id != 0 and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

	func send(d: Dictionary) -> bool:
		if not is_ready():
			return false
		peer.set_target_peer(remote_id)
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
		return peer.put_packet(JSON.stringify(d).to_utf8_buffer()) == OK

	func poll() -> Array:
		peer.poll()
		var out: Array = []
		while peer.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if parsed is Dictionary:   # 非法包直接丢弃（入包校验一道门在协议层）
				out.append(parsed)
		return out

	func close() -> void:
		peer.close()
