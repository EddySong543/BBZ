class_name BattleStage
extends Control

## 多层视差对战舞台（屋顶夜战）。
##
## 各子节点通过 metadata `parallax_factor` 声明视差强度：
## 0 = 静止背景（天空），1 = 与舞台地面同步，>1 = 前景（飘叶等）。
## 脚本在 _ready 缓存各层基准位置，随后按 idle 漂移 / 命中抖动 / 可选鼠标视差
## 偏移各层位置。素材到位后，在编辑器里直接替换对应 TextureRect 的 texture
## 即可，无需改动脚本。
##
## 用法示例：
## [codeblock]
## @onready var stage: BattleStage = $BattleStage
## stage.shake(14.0)              # 命中/大招时抖屏（各层按视差强度分摊）
## stage.pointer_parallax = true  # 开启鼠标视差（战斗屏 Stage 实例已默认开启）
## [/codeblock]

## 是否启用明月/前景的缓慢 idle 漂移（让静态画面有呼吸感）。
@export var idle_drift: bool = true
## idle 漂移幅度（像素，乘以各层视差强度）。
@export var idle_amplitude: float = 6.0
## idle 漂移速度。
@export var idle_speed: float = 0.35
## 视为"静止参考平面"的视差强度（= 角色站立的地面层，通常 1.0）。
## idle 漂移与鼠标视差都以此层为零点：该层不漂移、与脚下角色同参考系，越远的层相对漂移越大。
## 注意：shake（受击震屏）不受此影响，仍全层按 parallax_factor 缩放跟抖。
@export var ground_parallax: float = 1.0
## 是否随鼠标做视差（相机横移模型：全层同向随鼠标平移，天空最少、近景最多，分层错动出纵深；
## 地面层的平移量由 battle_screen 经 pointer_ground_offset() 同步给立绘/阴影组 → 角色零滑动）。
@export var pointer_parallax: bool = false
## 鼠标视差最大偏移（像素，× 各层 parallax_factor：地面层满偏移这么多，近景更多、天空按系数递减）。
@export var pointer_strength: float = 4.0
## 鼠标视差跟随缓动速度（越大越跟手；8 ≈ 0.15s 内到位，鼠标急停画面缓缓归位）。
@export var pointer_smooth: float = 8.0
## 鼠标侧缩放偏置峰值：满偏时近景层额外放大的比例（× max(parallax_factor - ground_parallax, 0)，
## 仅比地面更近的层参与 → 角色与地面零缩放、无需同步）。
@export var pointer_zoom: float = 0.008
## 缩放不动点向鼠标侧的最大水平偏移（像素）：鼠标偏左 → 绕左侧放大 =「头凑近左边看」。
@export var pointer_pivot_reach: float = 480.0
## 命中抖动衰减速度（越大停得越快）。
@export var shake_decay: float = 6.0
## 方向性后坐踢幅（× shake amp）：受击瞬间镜头朝受击方向"踢一脚"再弹回（Vlambeer 式镜头语言），
## 只做水平（纵向踢会让建筑上下跳=呼吸禁令）；0 = 退化为纯随机抖。
@export var shake_kick_scale: float = 1.1
## 在 standalone 预览中点击鼠标触发一次抖动演示（集成进战斗后可关）。
@export var demo_click_shake: bool = true

# ── 镜头对焦推近（hover 底部按钮触发·非 idle·P2）──
## 各层缩放绕这个"对焦点"（本舞台/屏幕坐标·推近的不动点，通常 = 对战中心）。
@export var focus_point: Vector2 = Vector2(960, 600)
## 对焦最大额外缩放，× 各层 parallax_factor → 近景缩放多、远景少 = 多图层 dolly（克制·~2-3%）。
@export var focus_zoom: float = 0.025
## 对焦推近的缓动速度（越大越快跟上出招）。
@export var focus_speed: float = 9.0
## 对焦回正（缩小）的缓动速度——独立于推近：动作结束后场上没有别的运动掩护，
## 单独的缩小很显眼，放慢 ~3× 让镜头"缓缓退出"与推近一样丝滑（Eddy 2026-07-09）。
@export var focus_release_speed: float = 3.2
## 大波命中"前推顿帧"的额外缩放峰值，× parallax_factor（payoff·比 hover 略强·与 hover 叠加）。
@export var punch_zoom: float = 0.04
## 对焦点水平偏置（像素）× dir：攻击 dir+1 焦点右移=聚焦敌人 / 防御 dir-1 左移=聚焦自身 / 技能 0 居中。
@export var focus_bias_x: float = 300.0

# idle 呼吸漂移对远景层（idle_f<0）的限幅：月亮/远山挂上视差系数后仍几乎不参与 idle 漂
# （≤ idle_amplitude×0.2 ≈ 1px·保持挂层前的静谧夜空），近景层不受影响。
const IDLE_FAR_CAP := -0.2

var _layers: Array[CanvasItem] = []   # Control 或 Node2D（粒子等）·两者都有 position/scale·经 set/get 驱动
var _bases: PackedVector2Array = PackedVector2Array()
var _factors: PackedFloat32Array = PackedFloat32Array()
var _base_scales: PackedVector2Array = PackedVector2Array()   # 各层基准 scale（保留 .tscn 预设）
var _time: float = 0.0
var _shake_amp: float = 0.0
var _shake_kick: float = 0.0      # 当前水平后坐量（正=向右·比随机抖衰减稍快·静止=0 零像素差）
var _pnx: float = 0.0             # 平滑后的鼠标水平偏移（-1..1·0=屏幕中心·驱动视差偏移+缩放偏置）
var _focus: float = 0.0           # 当前对焦量（0=静止·1=推近·_process 缓动）
var _focus_target: float = 0.0    # 目标（hover 底部按钮=1·离开=0）
var _punch: float = 0.0           # 大波命中前推（0→1→0·由 battle_screen 同步命中时刻 tween）
var _focal: Vector2 = Vector2.ZERO        # 当前对焦点（缩放不动点·随动作左右偏置·_process 缓动）
var _focal_target: Vector2 = Vector2.ZERO # 目标对焦点（攻击右 / 防御左 / 居中）


func _ready() -> void:
	_randomize_sky_seed()
	# 一次性缓存所有带 parallax_factor 的层及其基准位置 + 基准 scale（避免热路径查询/分配）。
	# Control 与 Node2D（GPUParticles2D 等）都收：两者各自定义了 position/scale，经 set/get 统一驱动。
	# ⚠ 粒子节点须在 .tscn 设 local_coords = true——全局空间模拟的粒子挪节点不挪已发射粒子。
	for child in get_children():
		if (child is Control or child is Node2D) and child.has_meta("parallax_factor"):
			_layers.append(child)
			_bases.append(child.get(&"position"))
			_factors.append(float(child.get_meta("parallax_factor")))
			_base_scales.append(child.get(&"scale"))
	# 镜头推近用动态对焦点（显式 position 数学绕 _focal 缩放·见 _process）→ 焦点可随动作左右偏置。
	_focal = focus_point
	_focal_target = focus_point


## 每次进场景给星空 shader 随机 seed → 每次打开星图都不同。
## Godot 4 启动默认已 randomize，randf() 每次进程不同。
func _randomize_sky_seed() -> void:
	var s: float = randf() * 1000.0
	_apply_seed("Stars", s)


func _apply_seed(node_name: String, s: float) -> void:
	var node := get_node_or_null(NodePath(node_name))
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		((node as CanvasItem).material as ShaderMaterial).set_shader_parameter("seed", s)


## 触发一次命中抖动；amp 为像素幅度（取较大值，不打断更强的抖动）。
## kick_dir_x：受击方向（-1=向左踢/+1=向右踢/0=无方向纯抖·双方同拍受击=对撞不偏向）。
func shake(amp: float, kick_dir_x: float = 0.0) -> void:
	_shake_amp = maxf(_shake_amp, amp)
	if kick_dir_x != 0.0:
		_shake_kick = clampf(kick_dir_x, -1.0, 1.0) * amp * shake_kick_scale


## 设置镜头对焦（on=推近；dir 水平偏置：+1 攻击=焦点右移聚焦敌人 / -1 防御=左移聚焦自身 / 0 技能居中）。
## hover 底部按钮时由 battle_screen 调用；内部缓动 _focus 与 _focal。离开则回零、焦点回正中。
func set_focus(on: bool, dir: float = 0.0) -> void:
	_focus_target = 1.0 if on else 0.0
	_focal_target = Vector2(focus_point.x + dir * focus_bias_x, focus_point.y) if on else focus_point


## 大波命中前推强度（0=无·1=峰值）；由 battle_screen 在大波结算时 tween，命中瞬间达峰 → 顿帧合拍。
func set_punch(v: float) -> void:
	_punch = v


## 地面层（站立平面·factor = ground_parallax）当前的推近缩放系数（hover 对焦 + 大波前推叠加）。
## 立绘 / 阴影（不在本舞台、由 battle_screen 归组）按此整体缩放 → 与脚下屋顶层统一推近移动。
func ground_dolly() -> float:
	return 1.0 + (_focus * focus_zoom + _punch * punch_zoom) * ground_parallax


## 当前对焦点（缓动后）；供 battle_screen 给立绘/阴影组做同焦点缩放（统一移动）。
func focal() -> Vector2:
	return _focal


## 地面层（角色站立面）当前的鼠标视差平移量。battle_screen 每帧加到立绘/阴影组（WorldGroup）
## 位置上 → 角色与脚下屋脊同步平移、零滑动。鼠标居中/关闭时为零向量。
func pointer_ground_offset() -> Vector2:
	return Vector2(-_pnx * pointer_strength * ground_parallax, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if demo_click_shake and event is InputEventMouseButton and event.pressed:
		shake(16.0)


func _process(delta: float) -> void:
	_time += delta
	# 推近快（跟上出招）、回正慢（结束时无其他运动掩护·缓退才丝滑）——非对称缓动。
	var fspd: float = focus_speed if _focus_target > _focus else focus_release_speed
	var k_ease: float = 1.0 - exp(-fspd * delta)
	_focus = lerpf(_focus, _focus_target, k_ease)
	_focal = _focal.lerp(_focal_target, k_ease)
	if _shake_amp > 0.0:
		_shake_amp = maxf(0.0, _shake_amp - shake_decay * delta * _shake_amp)
		if _shake_amp < 0.05:
			_shake_amp = 0.0
	if _shake_kick != 0.0:
		_shake_kick *= exp(-shake_decay * 1.5 * delta)   # 后坐比随机抖收得更快：一脚踢出即弹回
		if absf(_shake_kick) < 0.05:
			_shake_kick = 0.0

	# 鼠标视差目标值（关闭或鼠标回中时缓动归零，不跳变）。
	var target_nx: float = 0.0
	if pointer_parallax:
		var vp: Vector2 = get_viewport_rect().size
		if vp.x > 0.0:
			target_nx = clampf((get_local_mouse_position().x / vp.x - 0.5) * 2.0, -1.0, 1.0)
	_pnx = lerpf(_pnx, target_nx, 1.0 - exp(-pointer_smooth * delta))

	# idle 漂移仅水平——垂直起伏会让檐角/屋顶"呼吸"（建筑不该呼吸·Eddy 2026-07-09 去除）；
	# 雾带的纵向生命感由其 shader 内部流动负责，不靠节点位移。
	var drift_x: float = (sin(_time * idle_speed) * idle_amplitude) if idle_drift else 0.0
	var shake_x: float = sin(_time * 57.0) * _shake_amp
	var shake_y: float = cos(_time * 43.0) * _shake_amp

	# idle 漂移以 ground_parallax（地面层）为静止参考：地面 idle_f=0 不漂、与脚下角色同参考系；
	# 远景层（idle_f<0）限幅 IDLE_FAR_CAP → 月亮/远山不跟 idle 呼吸大幅飘（保持挂视差层前的静态观感）。
	# 鼠标视差 / shake 则全层按 factor 缩放（相机横移模型：天空动最少、近景最多；角色由
	# battle_screen 按 pointer_ground_offset() 同步平移）。
	# 鼠标侧缩放不动点：随 _pnx 向鼠标侧偏移（鼠标偏左 → 绕左侧微放大）。
	var pivot_m := Vector2(focus_point.x + _pnx * pointer_pivot_reach, focus_point.y)
	var zoom_m: float = pointer_zoom * absf(_pnx)

	for i in _layers.size():
		var f: float = _factors[i]
		var idle_w: float = maxf(f - ground_parallax, IDLE_FAR_CAP)
		var off := Vector2(
			drift_x * idle_w + (shake_x + _shake_kick - _pnx * pointer_strength) * f,
			shake_y * f)
		# 镜头推近：绕动态对焦点 _focal 缩放（显式 position 数学·焦点随动作左右偏置=聚焦敌/我）。
		# k=1（静止）时退化为 position=base+off、scale=base → 与原始画面一像素不差。
		var k: float = 1.0 + (_focus * focus_zoom + _punch * punch_zoom) * f
		# 鼠标缩放偏置只给比地面更近的层（地面/远景 km=1 → 角色零缩放；近景微放大出「凑近看」）。
		# ⚠只做横向：均匀缩放的纵向分量会让底部檐角随鼠标上下起伏 1-2px（"建筑呼吸"·
		# Eddy 2026-07-09 否）——横向 0.3~0.8% 拉伸像素上不可见，纵向不缩不挪。
		# _pnx=0（鼠标居中/关闭）时 km=1 → 与原始画面一像素不差。
		var km: float = 1.0 + zoom_m * maxf(f - ground_parallax, 0.0)
		var p: Vector2 = _focal + (_bases[i] - _focal) * k + off
		_layers[i].set(&"position", Vector2(pivot_m.x + (p.x - pivot_m.x) * km, p.y))
		_layers[i].set(&"scale", Vector2(_base_scales[i].x * k * km, _base_scales[i].y * k))
