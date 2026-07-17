class_name AudioEvents
extends RefCounted

## 音频事件系统骨架（2026-07-17 打地基批·Eddy 圈选）。
## 全静态类 = GameSettings 同范式（免 autoload·不动 project.godot）。
##
## 契约（ui-code 规则：UI 音效不得直接触发·一律走事件）：
##   AudioEvents.play("ui_click")      —— 音效（SFX 总线·轮转池并发播放）
##   AudioEvents.play_music("menu")    —— 音乐（Music 总线·单路·同事件重复点播幂等）
##   AudioEvents.stop_music()
##
## 事件表 = assets/data/audio/audio_events.json（数据驱动·禁在代码里硬编码流路径）：
##   "事件id": {"stream": "res://...", "bus": "SFX"|"Music", "volume_db": 0.0}
##   "_" 开头的键 = 文档保留（加载时跳过）。循环与否在流资源的导入设置上定（loop 属性）。
## 无资产期优雅降级：未知事件 / 流文件缺失 = 静默跳过（每键只警告一次·不刷屏）。
##
## 总线：Master（引擎自带）← Music / SFX（ensure_buses 运行时建·幂等）——
##   免 default_bus_layout.tres = 不动仓库顶层，headless/GUT 同样成立。
##   boot_screen 启动时调 ensure_buses()；play 路径懒调兜底（探针直进战斗屏也成立）。
##   音量 = GameSettings master/music/sfx_volume（建完总线回调 apply_volumes 即生效）。
## 播放器宿主挂树根（转场幸存者先例）→ change_scene 不打断音乐。

const EVENTS_PATH := "res://assets/data/audio/audio_events.json"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const SFX_POOL_SIZE := 8

static var _events: Dictionary = {}
static var _events_loaded: bool = false
static var _host: Node = null
static var _sfx_pool: Array[AudioStreamPlayer] = []
static var _sfx_next: int = 0
static var _music: AudioStreamPlayer = null
static var _music_event: String = ""
static var _warned: Dictionary = {}


# ============================================================
# 总线
# ============================================================

## 确保 Music/SFX 总线存在（幂等·可反复调）。新建后回灌持久化音量。
static func ensure_buses() -> void:
	var created := false
	for bus_name: String in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			created = true
	if created:
		GameSettings.apply_volumes()


# ============================================================
# 播放
# ============================================================

## 播一个音效事件。未知事件/缺流 = 静默降级。
static func play(event_id: String) -> void:
	var ev := _event(event_id)
	if ev.is_empty():
		return
	var stream := _stream_of(ev, event_id)
	if stream == null or not _ensure_host():
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	if not p.is_inside_tree():
		return   # 宿主还在 deferred 入树途中（仅首帧极端情形）——丢一声胜过报错
	p.bus = String(ev.get("bus", BUS_SFX))
	p.volume_db = float(ev.get("volume_db", 0.0))
	p.stream = stream
	p.play()


## 点播音乐事件（单路）。同事件已在播 = 幂等不重启（转场重复点播安全）。
static func play_music(event_id: String) -> void:
	if event_id == _music_event and _music != null and is_instance_valid(_music) and _music.playing:
		return
	var ev := _event(event_id)
	if ev.is_empty():
		return
	var stream := _stream_of(ev, event_id)
	if stream == null or not _ensure_host():
		return
	if not _music.is_inside_tree():
		return
	_music.bus = String(ev.get("bus", BUS_MUSIC))
	_music.volume_db = float(ev.get("volume_db", 0.0))
	_music.stream = stream
	_music.play()
	_music_event = event_id


static func stop_music() -> void:
	_music_event = ""
	if _music != null and is_instance_valid(_music):
		_music.stop()


# ============================================================
# 事件表
# ============================================================

static func has_event(event_id: String) -> bool:
	_load_events()
	return _events.has(event_id)


## 强制重读事件表（改 json 后热更用）。
static func reload_events() -> void:
	_events_loaded = false
	_load_events()


static func _load_events() -> void:
	if _events_loaded:
		return
	_events_loaded = true
	_events = {}
	if not FileAccess.file_exists(EVENTS_PATH):
		push_warning("AudioEvents: 事件表缺失 " + EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if not parsed is Dictionary:
		push_warning("AudioEvents: 事件表 JSON 解析失败 " + EVENTS_PATH)
		return
	for k: String in (parsed as Dictionary).keys():
		if not k.begins_with("_"):
			_events[k] = parsed[k]


## 事件 id → 定义字典；未知/畸形 = 空字典（每键一次性警告）。
static func _event(event_id: String) -> Dictionary:
	_load_events()
	var ev: Variant = _events.get(event_id)
	if ev is Dictionary:
		return ev
	if _events.has(event_id):
		_warn_once(event_id, "事件 '%s' 的值不是对象（检查 audio_events.json）" % event_id)
	else:
		_warn_once(event_id, "未知音频事件 '%s'（事件表没这键）" % event_id)
	return {}


## 事件定义 → 音频流；缺流 = null（每键一次性警告·无资产期属正常降级）。
static func _stream_of(ev: Dictionary, event_id: String) -> AudioStream:
	var path := String(ev.get("stream", ""))
	if path == "" or not ResourceLoader.exists(path):
		_warn_once("stream:" + event_id, "事件 '%s' 流文件缺失: %s（无资产期=正常·静默降级）" % [event_id, path])
		return null
	return load(path) as AudioStream


static func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("AudioEvents: " + msg)


## 播放器宿主（挂树根活过 change_scene）。无 SceneTree（纯 headless 工具脚本）= false。
static func _ensure_host() -> bool:
	ensure_buses()
	if _host != null and is_instance_valid(_host):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	_host = Node.new()
	_host.name = "AudioEventsHost"
	_sfx_pool = []
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		_host.add_child(p)
		_sfx_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	_host.add_child(_music)
	tree.root.add_child.call_deferred(_host)   # 场景 _ready 流程中直挂会撞 busy parent
	return true
