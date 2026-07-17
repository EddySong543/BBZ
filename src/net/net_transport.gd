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
## M3a 加密：默认 DTLS——主机每次开房现生成自签证书（密钥不落盘·不进仓库·每局一换），
## 客户端 client_unsafe=只加密不验证身份（防局域网抓包/篡改；防不了主动中间人——
## 正经证书链等专用服务器=M2b·ADR-004）。加密初始化失败=拒绝开房/拨号（fail-closed 不降级明文）。
## M3a 包体上限：入包超限直接丢（JSON 炸弹/内存放大防护）；服务器侧收 C2S 小包·上限另调更紧（net_session）。
class ENetTransport extends RefCounted:
	const DEFAULT_MAX_PACKET := 262144   # 256KB（客户端要收全量快照）

	var peer := ENetMultiplayerPeer.new()
	var remote_id: int = 0               # 对端 peer id（0=尚未连上）
	var max_packet_bytes: int = DEFAULT_MAX_PACKET

	func _init() -> void:
		# weakref 捕获（2026-07-17 审计修复）：lambda 直接捕获 self 会经成员 peer 的信号形成
		# transport→peer→signal→lambda→transport 引用环——RefCounted 无 GC·每次建房/拨号泄一对
		# （close 断信号只救走 close 的路径·弱引用救全部路径）。
		var wself: WeakRef = weakref(self)
		peer.peer_connected.connect(func(id: int) -> void:
			var s: RefCounted = wself.get_ref()
			if s != null:
				s.remote_id = id)
		peer.peer_disconnected.connect(func(_id: int) -> void:
			var s: RefCounted = wself.get_ref()
			if s != null:
				s.remote_id = 0)

	func host(port: int, encrypted: bool = true) -> bool:
		if peer.create_server(port, 1) != OK:
			return false
		if encrypted:
			var crypto := Crypto.new()
			var key := crypto.generate_rsa(2048)
			var cert := crypto.generate_self_signed_certificate(key, "CN=bobozan-lan")
			if peer.host.dtls_server_setup(TLSOptions.server(key, cert)) != OK:
				push_warning("ENetTransport: DTLS 服务端初始化失败 → 拒绝开房（不降级明文）")
				peer.close()
				return false
		return true

	func join(ip: String, port: int, encrypted: bool = true) -> bool:
		if peer.create_client(ip, port) != OK:
			return false
		if encrypted:
			if peer.host.dtls_client_setup(ip, TLSOptions.client_unsafe()) != OK:
				push_warning("ENetTransport: DTLS 客户端初始化失败 → 拒绝拨号（不降级明文）")
				peer.close()
				return false
		return true

	func is_ready() -> bool:
		return remote_id != 0 and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

	## 只驱动 ENet 泵（推进连接/DTLS 握手·处理连断信号），⛔ 不取业务包——包留在内部队列等 poll()。
	## 2026-07-14 修：链路探测（is_link_ready）以前直接调 poll()=收到的包被整批丢弃（"吃包"）；
	## 现役大厅纯靠帧序运气没踩中，探针在同拍先探后泵=必吃 match_start。探测一律走本口。
	func pump_only() -> void:
		peer.poll()

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
			var pkt: PackedByteArray = peer.get_packet()
			if pkt.size() > max_packet_bytes:   # M3a：超限包直接丢（JSON 炸弹防护）
				continue
			var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if parsed is Dictionary:   # 非法包直接丢弃（入包校验一道门在协议层）
				out.append(parsed)
		return out

	## 踢掉当前对端（好友房准入·2026-07-14）：礼貌断开=已排队的可靠包（如 error 提示）先送达。
	## 用途：口令/版本不合的连接占着唯一席位 → 踢掉腾位（防陌生人卡死好友的加入/重连）。
	func kick() -> void:
		if remote_id != 0:
			peer.disconnect_peer(remote_id)

	func close() -> void:
		peer.close()
