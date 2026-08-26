@tool
class_name HpSlantBar
extends Control

## 斜切分段血条：一格一格的斜平行四边形拼贴成一条长平行四边形
## （2026-07-18 Eddy 立项·取代出战血量的心形 IconPipRow）。
##
## **取值 API 与 IconPipRow 完全一致**（set_value / low_hp_flash / right_to_left /
## wave_* 同名同义）→ 换节点即可，battle_screen 调用侧零改动。
##
## **一格 = 一滴血**（Eddy 2026-07-18 定 A 案）：6 血英雄就是 6 格，半滴血裁半格。
## max_cells=10 = 可拓展上限（护甲往外接时才够得着·英雄本身 4~7 血）。
##
## **排布**（自原点向外）：血量 [0, hp) → 空槽补到 max；护甲**自格 0（靠头像那头）起
## 覆盖式压在血量上**，盖满整条（sh ≥ max）之后多出来的部分才往外接新格，总长封顶 max_cells
## （Eddy 2026-07-18 二改：先覆盖后接长·取代"接在血量尖端外"）。
##
## **绘制层次**（自底向上）：长平行四边形暗底（含内缝）→ 空槽 → 血量（身/顶高光/底压暗
## 三段材质·同底部按钮派生规则）→ 护甲银灰。
##
## 颜色取自 design/ui-design-system.md §2.7 功能色（HUD）。

# ── 取值 ──────────────────────────────────────────────
@export_group("格数与取值")
## 可拓展的总格数上限（血量+护甲）。英雄自身 4~7 血，余量留给护甲往外接。
@export var max_cells: int = 10:
	set(v):
		max_cells = maxi(v, 1)
		queue_redraw()

# ── 几何 ──────────────────────────────────────────────
@export_group("几何")
## 单格宽度（不含缝）。50:12 ≈ 4.2:1（Eddy 2026-07-18 三改·对齐 ref10 黄条细长度）。
@export var cell_w: float = 50.0:
	set(v):
		cell_w = maxf(v, 1.0)
		queue_redraw()
## 血条高度（=单格高度）。整条长高比：5血 22:1 / 6血 27:1，夹住 ref10 黄条实测 24.8:1。
@export var cell_h: float = 12.0:
	set(v):
		cell_h = maxf(v, 1.0)
		queue_redraw()
## 相邻格之间的缝宽（露出暗底 → 拼贴感）。
@export var gap: float = 4.0:
	set(v):
		gap = maxf(v, 0.0)
		queue_redraw()
## 斜切量：顶边相对底边的水平偏移。正=向右斜（P2/敌方）·负=向左斜（P1/我方·两侧镜像对称）。
## ⚠像素纪律：取 cell_h 的整数分之一（4/12=1:3）→ 斜边台阶等宽 3px 规整；
## 非整比（如 9/30）台阶会时宽时窄、放大后发毛。
@export var slant: float = 4.0:
	set(v):
		slant = v
		queue_redraw()
## 暗底相对块区的外扩（长平行四边形的"边框厚度"）。
@export var backing_pad: float = 2.0:
	set(v):
		backing_pad = maxf(v, 0.0)
		queue_redraw()
## 顶部高光带高度。
@export var band_top: float = 2.0:
	set(v):
		band_top = maxf(v, 0.0)
		queue_redraw()
## 底部压暗带高度。
@export var band_bottom: float = 2.0:
	set(v):
		band_bottom = maxf(v, 0.0)
		queue_redraw()
## 从右往左排（P2 对手镜像用；节点 offset_left 摆右锚点·同 IconPipRow 约定）。
@export var right_to_left: bool = false:
	set(v):
		right_to_left = v
		queue_redraw()

# ── 配色（design-system §2.7）─────────────────────────
@export_group("配色")
## 血量块身（满 HP 色）。
@export var col_fill: Color = Color("#e5443c"):
	set(v):
		col_fill = v
		queue_redraw()
## 顶部高光带。
@export var col_fill_top: Color = Color("#ff6a5c"):
	set(v):
		col_fill_top = v
		queue_redraw()
## 底部压暗带。
@export var col_fill_bottom: Color = Color("#a5312b"):
	set(v):
		col_fill_bottom = v
		queue_redraw()
## 空槽（已失去的血量）。
@export var col_empty: Color = Color("#0b101f"):
	set(v):
		col_empty = v
		queue_redraw()
## 长条暗底（缝与外框都是它）。
@export var col_backing: Color = Color(0.06, 0.05, 0.05, 0.9):
	set(v):
		col_backing = v
		queue_redraw()
## 护甲覆盖块身（银灰）。
@export var col_shield: Color = Color("#dcdfe6"):
	set(v):
		col_shield = v
		queue_redraw()
## 护甲顶部高光。
@export var col_shield_top: Color = Color("#f4f6fa"):
	set(v):
		col_shield_top = v
		queue_redraw()
## 护甲底部压暗。
@export var col_shield_bottom: Color = Color("#9ea4ae"):
	set(v):
		col_shield_bottom = v
		queue_redraw()

@export_group("Battle HUD 定向阴影")
@export var bottom_shadow_enabled := false:
	set(v):
		bottom_shadow_enabled = v
		queue_redraw()
@export var bottom_shadow_offset := Vector2(2.0, 4.0):
	set(v):
		bottom_shadow_offset = v
		queue_redraw()
@export var bottom_shadow_color := Color(0.02, 0.012, 0.008, 0.34):
	set(v):
		bottom_shadow_color = v
		queue_redraw()

# ── 波纹律动（沿用心条同名旋钮）────────────────────────
@export_group("波纹律动")
## 开启=一道亮波沿块序依次扫过（绘制方向天然镜像：LTR 左→右、RTL 右→左）。
@export var wave_idle: bool = false
## 相邻块起亮间隔（秒），越小波传播越快。
@export var wave_stagger: float = 0.1
## 单块被波扫过时的亮起时长（秒）。
@export var wave_pulse: float = 0.26
## 波峰叠加的提亮量（0~1，向顶部高光色混合）。
@export_range(0.0, 1.0) var wave_amount: float = 0.55
## 两道波之间的静止时长（秒）。
@export var idle_rest_min: float = 2.0
## 血量越少波越快：满血=1.0、濒死按 wave_low_speed 倍加速（心跳加快感）。
@export var wave_speed_by_hp: bool = false
## 濒死（值→0）时的波速倍率。
@export var wave_low_speed: float = 3.0

# ── 低血闪烁（沿用心条同名旋钮）────────────────────────
@export_group("低血闪烁")
## 开启=剩余血量在低血时警示色呼吸。
@export var low_hp_flash: bool = false
## 触发阈值：当前值/上限 ≤ 此值时开始闪。
@export var low_hp_ratio: float = 0.3
## 闪烁峰值色（design-system §2.7 低血警示橘——红条上再闪红≈看不见，故用橘）。
@export var low_hp_flash_color: Color = Color("#ff9442")
## 闪烁速度（rad/s·仅无波纹时用；有波纹时与波同拍）。
@export var low_hp_flash_speed: float = 6.0
## 闪烁强度（0~1，警示色混入比例峰值）。
@export_range(0.0, 1.0) var low_hp_flash_amount: float = 0.8

# ── 编辑器预览 ────────────────────────────────────────
@export_group("编辑器预览")
## @tool 下无数据时用这组值预览摆位；运行时被实际值覆盖。
@export var preview_cur: float = 3.5:
	set(v):
		preview_cur = v
		queue_redraw()
@export var preview_max: float = 5.0:
	set(v):
		preview_max = v
		queue_redraw()
@export var preview_extra: float = 0.0:
	set(v):
		preview_extra = v
		queue_redraw()

var _cur: float = 0.0
var _max: float = 0.0
var _extra: float = 0.0

var _slot_count: int = 0
var _glow: PackedFloat32Array = PackedFloat32Array()   # 每块当前波纹亮度 0~1
var _glow_q: PackedInt32Array = PackedInt32Array()     # 量化后的亮度（只在跳档时重绘）
var _wave_time: float = 0.0
var _wave_cycle: float = 1.0                           # 一个波循环时长·供低血闪同步
var _flash_phase: float = 0.0
var _flash_on: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return                       # 编辑器里静止预览，避免无谓重绘
	if low_hp_flash:
		_process_low_hp_flash(delta)
	if wave_idle and _slot_count > 0:
		_process_wave(delta)


## 低血警示：当前值/上限 ≤ low_hp_ratio 时推进相位并每帧重绘；恢复后重绘一次复位。
func _process_low_hp_flash(delta: float) -> void:
	var lowhp := _max > 0.0 and _cur > 0.0 and (_cur / _max) <= low_hp_ratio
	if lowhp:
		_flash_phase += delta
		_flash_on = true
		queue_redraw()
	elif _flash_on:
		_flash_on = false
		queue_redraw()


## 波纹律动：一道亮波沿块序依次扫过 → 停顿 → 循环。血少波快（心跳加速）。
## 亮度量化到 1/16 档，只在跳档时 queue_redraw（避免每帧无谓重绘）。
func _process_wave(delta: float) -> void:
	var speed := 1.0
	if wave_speed_by_hp and _max > 0.0:
		var frac := clampf(_cur / _max, 0.0, 1.0)
		speed = lerpf(maxf(wave_low_speed, 1.0), 1.0, frac)
	_wave_time += delta * speed
	var cycle := maxf(float(_slot_count - 1) * wave_stagger + wave_pulse + maxf(idle_rest_min, 0.1), 0.1)
	_wave_cycle = cycle
	var cyc := fmod(_wave_time, cycle)
	_ensure_slots(_slot_count)
	var changed := false
	for i in range(_slot_count):
		var local := cyc - float(i) * wave_stagger
		var g := 0.0
		if local >= 0.0 and local < wave_pulse and wave_pulse > 0.0:
			g = sin(local / wave_pulse * PI)     # 0 → 1 → 0 单峰
		_glow[i] = g
		var q := int(g * 16.0)
		if _glow_q[i] != q:
			_glow_q[i] = q
			changed = true
	if changed or _flash_on:
		queue_redraw()


## 设置显示值（半点制小数）。extra = 护甲/护甲（银灰覆盖层）。
func set_value(cur: float, max_val: float, extra: float = 0.0) -> void:
	_cur = maxf(cur, 0.0)
	_max = maxf(max_val, 0.0)
	_extra = maxf(extra, 0.0)
	queue_redraw()


func _ensure_slots(n: int) -> void:
	while _glow.size() < n:
		_glow.append(0.0)
		_glow_q.append(0)


# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var cur := _cur
	var maxv := _max
	var extra := _extra
	if Engine.is_editor_hint() and maxv <= 0.0 and cur <= 0.0:
		cur = preview_cur
		maxv = preview_max
		extra = preview_extra
	if maxv <= 0.0:
		return

	# 一格 = 一滴血 → 下面全部用「格」为单位算（cap 之外一律不画）
	var cap := float(max_cells)
	var hp := clampf(cur, 0.0, cap)
	var sh := clampf(extra, 0.0, cap)      # 护甲：自头像侧（格 0）起覆盖，盖满整条才往外加格
	var span := minf(maxf(maxv, sh), cap)  # 条身总长：盾多于血量上限时才撑出去
	var total := maxi(int(ceil(span - 0.0001)), 1)
	_slot_count = total
	_ensure_slots(total)

	# 整条斜切轮廓先落一层轻量定向阴影，保留格间暗缝而不增加模糊矩形底板。
	if bottom_shadow_enabled:
		draw_colored_polygon(
				_offset_polygon(_backing_quad(total), bottom_shadow_offset),
				bottom_shadow_color)

	# ① 长平行四边形暗底：格与格之间的缝、外框都由它露出 → "拼贴成一条"的读法
	draw_colored_polygon(_backing_quad(total), col_backing)

	# ② 空槽打底（已失去的血量·安静不跳动）；上面再依次盖血量与护甲
	_draw_span(0.0, span, col_empty, col_empty, col_empty)

	# ③ 血量：整格 + 末尾半格（半滴血裁半格）·逐格取实时色（低血警示 + 波纹）
	_draw_span_live(0.0, hp)

	# ④ 护甲：自格 0（靠头像那头）起覆盖式压在血量上；盖满 max 后多出来的部分往外接新格
	_draw_span(0.0, sh, col_shield, col_shield_top, col_shield_bottom)


## 画 [from, to) 这一段固定色（单位=格，可含小数 → 两端自动裁半格）。
func _draw_span(from: float, to: float, body: Color, top: Color, bottom: Color) -> void:
	for cell in _span_cells(from, to):
		_draw_material_cell(int(cell.x), cell.y, cell.z, body, top, bottom)


## 同上，但逐格取实时血色（低血警示 + 波纹律动）。
func _draw_span_live(from: float, to: float) -> void:
	for cell in _span_cells(from, to):
		var i := int(cell.x)
		_draw_material_cell(i, cell.y, cell.z, _live_fill(i), _live_top(i), _live_bottom())


## 把 [from, to)（格为单位·可含小数）拆成逐格的 (格号, 格内起比例, 格内止比例)。
func _span_cells(from: float, to: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if to - from <= 0.001:
		return out
	var i := int(floor(from + 0.0001))
	while float(i) < to - 0.0001:
		var f0 := clampf(from - float(i), 0.0, 1.0)
		var f1 := clampf(to - float(i), 0.0, 1.0)
		if f1 - f0 > 0.001:
			out.append(Vector3(float(i), f0, f1))
		i += 1
	return out


## 单格三段材质：身 + 顶高光 + 底压暗（同底部按钮 top/bottom/edge 派生语言）。
## top/bottom 与 body 同色时跳过该带（空槽走这条 → 一格一次 draw call）。
func _draw_material_cell(i: int, f0: float, f1: float, body: Color, top: Color, bottom: Color) -> void:
	draw_colored_polygon(_cell_quad(i, f0, f1, 0.0, cell_h), body)
	if band_top > 0.0 and top != body:
		draw_colored_polygon(_cell_quad(i, f0, f1, 0.0, minf(band_top, cell_h)), top)
	if band_bottom > 0.0 and bottom != body:
		draw_colored_polygon(_cell_quad(i, f0, f1, maxf(cell_h - band_bottom, 0.0), cell_h), bottom)


## 第 i 块的实时身色：低血警示 + 波纹提亮。
func _live_fill(i: int) -> Color:
	var c := col_fill
	if low_hp_flash and _flash_on:
		c = c.lerp(low_hp_flash_color, _flash_pulse() * low_hp_flash_amount)
	if wave_idle and i < _glow.size():
		c = c.lerp(col_fill_top, _glow[i] * wave_amount)
	return c


## 第 i 块的实时顶高光色（同步吃低血警示，波纹不再叠加·避免糊成一片）。
func _live_top(i: int) -> Color:
	var c := col_fill_top
	if low_hp_flash and _flash_on:
		c = c.lerp(low_hp_flash_color, _flash_pulse() * low_hp_flash_amount)
	return c


## 底部压暗带实时色：同吃低血警示——只闪身/顶会在底部留一条不动的红边（踩过）。
func _live_bottom() -> Color:
	if low_hp_flash and _flash_on:
		return col_fill_bottom.lerp(low_hp_flash_color.darkened(0.28), _flash_pulse() * low_hp_flash_amount)
	return col_fill_bottom


## 低血脉动相位：有波纹时与波同拍（波起点=警示峰值），否则独立正弦呼吸。
func _flash_pulse() -> float:
	if wave_idle and _wave_cycle > 0.0:
		var ph := fmod(_wave_time, _wave_cycle) / _wave_cycle
		return 0.5 + 0.5 * cos(ph * TAU)
	return 0.5 + 0.5 * sin(_flash_phase * low_hp_flash_speed)


## 第 i 格的四边形。f0/f1 = 格内**逻辑**裁切比例（0=靠原点那侧·半格与错位都走它）；
## y0/y1 = 竖直范围（材质带用）。RTL 时逻辑比例在此镜像成几何比例，调用方无须分左右。
## 斜切：顶边(y=0)偏 slant，底边(y=cell_h)不偏，中间线性 → 每格都是平行四边形。
func _cell_quad(i: int, f0: float, f1: float, y0: float, y1: float) -> PackedVector2Array:
	if right_to_left:
		var m0 := 1.0 - f1
		f1 = 1.0 - f0
		f0 = m0
	var step := cell_w + gap
	var x0 := -step * float(i + 1) + gap if right_to_left else step * float(i)
	var xa := x0 + cell_w * f0
	var xb := x0 + cell_w * f1
	var sa := _shift(y0)
	var sb := _shift(y1)
	return PackedVector2Array([
		Vector2(xa + sa, y0), Vector2(xb + sa, y0),
		Vector2(xb + sb, y1), Vector2(xa + sb, y1)])


## 整条暗底（比块区四周各外扩 backing_pad·与块同斜率 → 整体仍是一个长平行四边形）。
func _backing_quad(total: int) -> PackedVector2Array:
	var step := cell_w + gap
	var left := -step * float(total) + gap if right_to_left else 0.0
	var right := 0.0 if right_to_left else step * float(total) - gap
	var p := backing_pad
	var y0 := -p
	var y1 := cell_h + p
	var sa := _shift(y0)
	var sb := _shift(y1)
	return PackedVector2Array([
		Vector2(left - p + sa, y0), Vector2(right + p + sa, y0),
		Vector2(right + p + sb, y1), Vector2(left - p + sb, y1)])


func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted


func _shift(y: float) -> float:
	return slant * (1.0 - y / maxf(cell_h, 0.001))
