class_name ConstellationOverlay
extends Control

## 星座连线层(真星座·生长动画版)：从 ConstellationShapes 真实星座库随机抽若干座，
## 每座的星用像素十字星画(和背景散星同风格 → 看起来就是几颗现有的星)，动态"生长"：
## 一颗星闪亮 → 一串像素点延伸到下一颗 → 下一颗亮 → … → 连成星座 → 停留 → 淡出 → 重生。
##
## 生命周期(本版重点)：
##  · 洗牌袋(_bag)：17 座轮完再重洗 → 不短期重复同一座、每座都能出现。
##  · 换座换位重生：每座走完完整周期就换"新星座 + 新位置"，并在座间留出空窗(gap_min/max)。
##  · 进场无连线：每座有 birth 出生时刻(错开 0.4~spawn_spread 秒)，进场时全"尚未出现"，
##    之后陆续从零生长 → 刚进对局绝不会看到已连好的星座。
##
## 由 battle_stage 程序化创建并插在 Stars 之上(不改 scene1.tscn)。全 _draw 绘制，无贴图。

const Shapes := preload("res://src/ui/components/constellation_shapes.gd")

@export var count: int = 1                                  # 同时存在的星座数(全场最多几座·1=任意时刻只 1 座)
@export var line_color: Color = Color(0.62, 0.76, 1.0, 1.0)
@export var star_color: Color = Color(0.92, 0.96, 1.0, 1.0)
@export var line_alpha: float = 0.5                         # 连线相对透明(比主星淡)
@export var dot_px: float = 2.0                             # 连线像素点边长(比主星小→细像素虚线感)
@export var dot_gap: float = 5.0                            # 连线像素点中心间距(留空隙=点列而非实线)
@export var star_unit: float = 3.0                         # 星=像素块拼的十字·单个"大像素"块边长(≈背景散星格→风格统一)
@export var star_arm: int = 1                               # 星芒每个方向延伸几个像素块(0=单点·越大十字越长)
@export var star_arm_dim: float = 0.5                       # 星芒臂相对中心的亮度(匹配背景星 spike_strength·臂比核心暗)
@export var scale_min: float = 0.14                         # 星座占屏高比例(下限·控制不抢视野)
@export var scale_max: float = 0.22
@export var period_min: float = 18.0                        # 单座完整周期(生长+停留+淡出+空白)·越大生长越慢
@export var period_max: float = 28.0
@export var gap_min: float = 2.0                            # 座与座之间的纯空窗(秒·一座彻底结束→下座出现)
@export var gap_max: float = 4.0
@export var spawn_spread: float = 2.5                       # 进场首座出现的延迟窗口(秒)·保证进场无已连线星座
@export var sky_top: float = 0.16                           # 星座中心可分布天区(UV.y·已留出星座半高)
@export var sky_bottom: float = 0.42
@export var aspect_hw: float = 0.5625                       # 屏幕 高/宽(1080/1920)，修正星座横向不被拉扁
@export var moon_pos: Vector2 = Vector2(0.774, 0.385)
@export var moon_avoid: float = 0.44                        # 离月亮最小距(屏幕高为单位·aspect 修正·覆盖月盘+星座余量)

# 周期内各阶段分界(归一时间 0..1)：0..GROW 生长 / GROW..HOLD 停留 / HOLD..FADE 淡出 / FADE..1 空白
const GROW := 0.45
const HOLD := 0.65
const FADE := 0.85

var _shapes: Array = []
var _bag: Array[int] = []
var _consts: Array = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shapes = Shapes.all()
	for i in count:
		# birth>0 → 进场第一帧起所有星座尚未出现 → 保证"刚进对局无已连线星座"，并错开陆续生长
		_consts.append(_make_one(randf_range(0.4, spawn_spread)))


## 洗牌袋取下一个星座索引：17 座轮完再重洗，避免短期重复同一座、保证每座都能出现。
func _next_shape_index() -> int:
	if _bag.is_empty():
		for i in _shapes.size():
			_bag.append(i)
		_bag.shuffle()
	return _bag.pop_back()


## 抽一个星座模板，归一化 → 放置到天区(避月·可水平翻转)；birth=该实例开始生长的 _time。
func _make_one(birth: float) -> Dictionary:
	var tpl: Dictionary = _shapes[_next_shape_index()]
	var local := _fit_unit(tpl["stars"])
	var edges: Array = tpl["edges"]

	var scl := randf_range(scale_min, scale_max)
	var center := _pick_center()
	var flip := randf() < 0.5
	var stars: Array[Vector2] = []
	for p: Vector2 in local:
		var lx := (1.0 - p.x) if flip else p.x
		stars.append(Vector2(
			center.x + (lx - 0.5) * scl * aspect_hw,    # aspect 修正：x 跨度按屏比缩回，星座不被拉扁
			center.y + (p.y - 0.5) * scl))

	return {
		"stars": stars,
		"edges": edges,
		"appear": _compute_appear(stars.size(), edges),
		"period": randf_range(period_min, period_max),
		"birth": birth,
	}


## bbox 归一化：把星座最长边缩到 1、短边居中，落入单位正方形(保持纵横比、形状不变)。
func _fit_unit(pts: Array) -> Array:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	var span := maxf(maxf(mx.x - mn.x, mx.y - mn.y), 0.0001)
	var pad := (Vector2(span, span) - (mx - mn)) * 0.5
	var out: Array = []
	for p: Vector2 in pts:
		out.append((p - mn + pad) / span)
	return out


## 每颗星淡入阈值(0..1) = 它首次作为某条边端点的边序号 / 边数；起点星(边0)=0、孤立星=1。
func _compute_appear(n: int, edges: Array) -> PackedFloat32Array:
	var m := edges.size()
	var appear := PackedFloat32Array()
	appear.resize(n)
	for i in n:
		appear[i] = 1.0
	for e in m:
		var ed: Vector2i = edges[e]
		var f := float(e) / float(maxi(m, 1))
		appear[ed.x] = minf(appear[ed.x], f)
		appear[ed.y] = minf(appear[ed.y], f)
	return appear


## 选一个天区中心(UV)，避开月亮(重试若干次找不撞月盘的位置)。
func _pick_center() -> Vector2:
	var c := Vector2(randf_range(0.12, 0.86), randf_range(sky_top, sky_bottom))
	for _a in 16:
		if not _near_moon(c):
			break
		c = Vector2(randf_range(0.12, 0.86), randf_range(sky_top, sky_bottom))
	return c


## 星座中心是否离月亮太近：UV 距离按 aspect 修正成"屏幕高为单位"(月盘在屏幕上是圆，
## 但 UV 空间被宽高比拉成椭圆 → 不修正则横向避让严重不足、星座仍压在月盘上)。
func _near_moon(c: Vector2) -> bool:
	var dx := (c.x - moon_pos.x) / maxf(aspect_hw, 0.001)   # UV x → 屏幕高单位(x 距离按 宽/高 放大)
	var dy := c.y - moon_pos.y
	return sqrt(dx * dx + dy * dy) < moon_avoid


func _process(delta: float) -> void:
	_time += delta
	# 走完一个完整周期(生长→停留→淡出→空白)的星座：换一个新星座 + 新位置重生
	for i in _consts.size():
		var con: Dictionary = _consts[i]
		if _time - float(con["birth"]) >= float(con["period"]):
			# 重生：换新座新位，birth 推到未来 gap 秒 → 座与座之间留出空窗
			_consts[i] = _make_one(_time + randf_range(gap_min, gap_max))
	queue_redraw()


func _draw() -> void:
	var sz := size
	for con in _consts:
		var local_t := _time - float(con["birth"])
		if local_t < 0.0:
			continue                                  # 尚未出现(进场错开/未到出生)
		var t := local_t / float(con["period"])
		if t >= 1.0:
			continue                                  # 已走完·待 _process 重生

		# 整体淡出 alpha：停留后渐隐，空白期不画
		var alpha := 1.0
		if t >= FADE:
			alpha = 0.0
		elif t >= HOLD:
			alpha = 1.0 - (t - HOLD) / (FADE - HOLD)
		if alpha <= 0.01:
			continue

		var stars: Array[Vector2] = con["stars"]
		var edges: Array = con["edges"]
		var appear: PackedFloat32Array = con["appear"]
		var m := edges.size()
		var grow_t := clampf(t / GROW, 0.0, 1.0)
		var lc := Color(line_color.r, line_color.g, line_color.b, line_color.a * alpha * line_alpha)

		# 连线：边 e 在 grow [e/m,(e+1)/m] 区间从 A 向 B 动态延伸
		for e in m:
			var ea := clampf((grow_t - float(e) / float(m)) * float(m), 0.0, 1.0)
			if ea <= 0.0:
				continue
			var ed: Vector2i = edges[e]
			var a: Vector2 = stars[ed.x] * sz
			var b: Vector2 = stars[ed.y] * sz
			_draw_pixel_line(a, a.lerp(b, ea), lc)

		# 主星：grow 过 appear[s] 后约半条边时长内淡入；亮后轻微闪烁(融入背景散星)
		for s in stars.size():
			var sa := clampf((grow_t - appear[s]) * float(maxi(m, 1)) * 2.0, 0.0, 1.0)
			if sa <= 0.0:
				continue
			var sb := sa
			if sa >= 1.0:
				sb = 0.72 + 0.28 * sin(_time * 3.0 + float(s) * 1.7)
			_draw_pixel_star(stars[s] * sz, Color(star_color.r, star_color.g, star_color.b, star_color.a * sb * alpha))


## 画像素点列连线：沿 a→b 等距铺一串对齐整数像素的小方块，替代矢量 draw_line，和像素十字星统一。
func _draw_pixel_line(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	var dist := d.length()
	if dist < 0.001:
		return
	var dir := d / dist
	var rs := Vector2(dot_px, dot_px)
	var hs := dot_px * 0.5
	var t := 0.0
	while t <= dist:
		var p := a + dir * t
		var tl := Vector2(round(p.x - hs), round(p.y - hs))     # 左上角吸附整数像素 → 不糊
		draw_rect(Rect2(tl, rs), col)
		t += dot_gap


## 画一颗像素十字星：由统一的"大像素"块拼成十字(中心块 + 四向各延伸 star_arm 个块)，
## 所有块吸附到同一 star_unit 像素网格 → 真正的像素画风格、与背景散星统一(而非矢量方块+细线)。
func _draw_pixel_star(c: Vector2, col: Color) -> void:
	var u := maxf(1.0, roundf(star_unit))
	var bx := roundf(c.x / u) * u                        # 块左上吸附到 u 像素栅格(全星共用同一网格)
	var by := roundf(c.y / u) * u
	var us := Vector2(u, u)
	draw_rect(Rect2(Vector2(bx, by), us), col)               # 中心块(全亮)
	var arm_col := Color(col.r, col.g, col.b, col.a * star_arm_dim)   # 星芒臂偏暗→匹配背景星(臂比核心暗)
	for k in star_arm:
		var d := float(k + 1) * u
		draw_rect(Rect2(Vector2(bx, by - d), us), arm_col)   # 上
		draw_rect(Rect2(Vector2(bx, by + d), us), arm_col)   # 下
		draw_rect(Rect2(Vector2(bx - d, by), us), arm_col)   # 左
		draw_rect(Rect2(Vector2(bx + d, by), us), arm_col)   # 右
