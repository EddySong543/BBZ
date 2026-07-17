extends Control

## 对波撞点特效层（boot_screen 专用）—— 角力光墙上的能量火花 + 偶发电弧。
##
## 对波演出语法（Beam-O-War）：撞点是全场主角——僵持期持续迸溅细碎火花、
## 电弧沿光墙攀爬；连击每击一股火花砸向败方侧；决堤瞬间大迸发。
## 火花 = 像素方块（与标题「攒」积聚块同语言），白热芯 → 阵营余温 → 熄灭。
##
## 实现：纯 _draw + 预分配池（swap-remove），零子节点、零逐帧分配、不走 GPU 粒子。
## boot_screen 每帧喂 set_seam()（撞点像素 x）；burst() 加戏；随 boot 场景释放自灭。
##
## 用法：
##   var fx := ClashFx.new()          # const ClashFx := preload(".../clash_fx.gd")
##   add_child(fx)
##   fx.set_active(true)              # 撞击后开启：僵持自然迸溅 + 偶发电弧
##   fx.set_seam(clash_pos * size.x)  # 每帧同步撞点
##   fx.burst(10, dir, 1.5)          # 连击：一股火花砸向 dir 侧（-1 蓝 / +1 红）

const MAX_SPARKS := 48            # 火花池上限（僵持期活跃 ~4-6，决堤瞬间 ~30）
const DRIP_RATE := 10.0           # 僵持期每秒自然迸溅数
const SPARK_LIFE := 0.55          # 火花基准寿命（秒）
const SPARK_SPEED := 340.0        # 火花基准初速（px/s·要能飞出光墙亮区才看得见）
const SPARK_DAMP := 2.2           # 速度指数阻尼（/s·能量散逸感·射程 ≈ 初速/阻尼）
const SPARK_ANG := 0.96           # 出射角相对水平的最大偏角（弧度 ≈ 55°）
const SPARK_SIZES: Array[float] = [12.0, 16.0, 22.0]  # 方块尺寸档（标题积聚块同语言）
const HOT_PHASE := 0.55           # 寿命前 55% 为白热芯，之后转阵营余温
const ARC_MIN_GAP := 1.4          # 电弧最短间隔（秒）
const ARC_MAX_GAP := 3.0          # 电弧最长间隔（秒）
const ARC_LIFE := 0.12            # 电弧存续（秒·闪现 2-3 帧）
const ARC_SEG := 26.0             # 电弧单段纵向步长（px）
const ARC_JAG := 55.0             # 电弧横向抖折幅度（px·必须甩出光墙亮区否则白弧埋白墙）
const ARC_W := 9.0                # 电弧笔宽（px）
const COL_HOT := Color("#f2f7ff")   # 白热芯（标题接缝白闪同源）
const COL_BLUE := Color("#cfe6ff")  # 蓝侧余温
const COL_RED := Color("#ffd9c4")   # 红侧余温

var _seam_x := 960.0
var _active := false
var _drip_acc := 0.0
var _arc_wait := 2.0
var _arc_life := 0.0
var _arc_pts := PackedVector2Array()

# 火花池（预分配·前 _alive 个为活跃·亡者与末位 swap-remove）
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _alive := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 绝不吞 boot 的进入点击
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pos.resize(MAX_SPARKS)
	_vel.resize(MAX_SPARKS)
	_life.resize(MAX_SPARKS)
	_max_life.resize(MAX_SPARKS)
	_size.resize(MAX_SPARKS)


## 每帧同步撞点像素 x（boot 的 clash_pos × 屏宽）——火花/电弧全部从这里出生。
func set_seam(x: float) -> void:
	_seam_x = x


## 开关僵持期演出（自然迸溅 + 偶发电弧）。撞击瞬间开启，boot 释放时无需关闭。
func set_active(on: bool) -> void:
	_active = on


## 一股火花：count 颗，dir_bias∈[-1,1] 朝蓝(-)/红(+)侧偏压（0=对称），speed_scale 劲度。
func burst(count: int, dir_bias: float, speed_scale: float = 1.0) -> void:
	for i in count:
		_spawn_one(dir_bias, speed_scale)


## 立即闪一道电弧（连击每击 + 自然间隔都走这里）。
func fire_arc() -> void:
	_arc_pts.clear()
	var up := randf() < 0.5
	var y := randf_range(0.25, 0.75) * size.y
	var x := _seam_x + randf_range(-10.0, 10.0)
	_arc_pts.append(Vector2(x, y))
	for i in randi_range(4, 7):
		y += (-ARC_SEG if up else ARC_SEG) * randf_range(0.7, 1.3)
		x = _seam_x + randf_range(-ARC_JAG, ARC_JAG)
		_arc_pts.append(Vector2(x, y))
	_arc_life = ARC_LIFE


func _spawn_one(dir_bias: float, speed_scale: float) -> void:
	if _alive >= MAX_SPARKS:
		return
	var idx := _alive
	_alive += 1
	var ang := randf_range(-SPARK_ANG, SPARK_ANG)
	var spd := SPARK_SPEED * speed_scale * randf_range(0.6, 1.4)
	# 出射侧：偏压把火花砸向败方（dir_bias=+1 → 大概率飞向红侧）
	var dirx := 1.0 if randf() < 0.5 + dir_bias * 0.35 else -1.0
	_pos[idx] = Vector2(
		_seam_x + randf_range(-8.0, 8.0),
		randf_range(0.10, 0.90) * size.y)
	_vel[idx] = Vector2(cos(ang) * spd * dirx, sin(ang) * spd)
	var life := SPARK_LIFE * randf_range(0.7, 1.3)
	_life[idx] = life
	_max_life[idx] = life
	_size[idx] = SPARK_SIZES[randi_range(0, SPARK_SIZES.size() - 1)]


func _process(delta: float) -> void:
	if _active:
		_drip_acc += delta * DRIP_RATE
		while _drip_acc >= 1.0:
			_drip_acc -= 1.0
			_spawn_one(0.0, 1.0)
		_arc_wait -= delta
		if _arc_wait <= 0.0:
			fire_arc()
			_arc_wait = randf_range(ARC_MIN_GAP, ARC_MAX_GAP)
	# 火花推进（活跃段·亡者 swap-remove·无分配）
	var i := 0
	while i < _alive:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_alive -= 1
			_pos[i] = _pos[_alive]
			_vel[i] = _vel[_alive]
			_life[i] = _life[_alive]
			_max_life[i] = _max_life[_alive]
			_size[i] = _size[_alive]
			continue
		_vel[i] *= exp(-SPARK_DAMP * delta)
		_pos[i] += _vel[i] * delta
		i += 1
	if _arc_life > 0.0:
		_arc_life -= delta
	if _active or _alive > 0 or _arc_life > 0.0:
		queue_redraw()


func _draw() -> void:
	for i in _alive:
		var u := _life[i] / _max_life[i]   # 1 → 0
		var col: Color
		if u > HOT_PHASE:
			col = COL_HOT
		else:
			col = COL_BLUE if _pos[i].x < _seam_x else COL_RED
		col.a = clampf(u * 1.6, 0.0, 1.0)
		var half := _size[i] * 0.5
		draw_rect(Rect2(_pos[i] - Vector2(half, half), Vector2(_size[i], _size[i])), col)
	if _arc_life > 0.0 and _arc_pts.size() >= 2:
		var c := COL_HOT
		c.a = clampf(_arc_life / ARC_LIFE, 0.0, 1.0)
		for i in _arc_pts.size() - 1:
			draw_line(_arc_pts[i], _arc_pts[i + 1], c, ARC_W)
