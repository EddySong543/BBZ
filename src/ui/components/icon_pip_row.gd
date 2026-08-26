@tool
class_name IconPipRow
extends Control

## 横排"图标点"组件：用一张逐帧精灵图(spritesheet)画一排图标点。
## 战斗 HUD 的血量(心形)与能量(金币)用它显示，替换旧 ArcHealthBar / EnergyBar。
##
## **idle 行为**：每个图标点平时停在第 0 帧（静止），**偶尔**才播一次完整动画
## （心跳一下 / 金币转一圈），间隔随机、每个点错峰 → 活而不呆，绝非持续 loop。
##
## 美术换素材：在 Inspector 换 sheet + 改 hframes/vframes/fps 即可，无需改代码。
##
## 取值（半点制小数 OK）：
##  - 血量：set_value(hp, max_hp, shield)。allow_half=true 末尾半血裁半颗；show_empty=true
##    身后用暗色空心补到 max_hp（空心不跳动）；shield 作青色"额外心"追加。
##  - 能量：set_value(energy, energy)。allow_half=false / show_empty=false → 画 energy 枚金币。
##  - 纯图标：set_value(1, 1) → 画 1 个图标（待选英雄头像下的心形标记用）。
##
## 排布：从节点原点(0,0)起横排；right_to_left=true 时从原点往**左**排（P2 对手镜像，
## 此时把节点 offset_left 摆在"右锚点"）。per_row_cap>0 时超出换行。

@export_group("精灵图")
@export var sheet: Texture2D:
	set(v):
		sheet = v
		_rebuild_gray_tex()
		queue_redraw()
## 横向帧数（heart_idle=4，energy_idle=4）。
@export var hframes: int = 1:
	set(v):
		hframes = maxi(v, 1)
		queue_redraw()
## 纵向帧数（heart_idle=1，energy_idle=4）。
@export var vframes: int = 1:
	set(v):
		vframes = maxi(v, 1)
		queue_redraw()
## 播放一次动画时的速度（帧/秒）。
@export var fps: float = 8.0

@export_group("idle 节奏")
## 两次播放之间的静止时长（秒）下限，每个点在 [min,max] 间随机取。
@export var idle_rest_min: float = 2.5
## 两次播放之间的静止时长（秒）上限。
@export var idle_rest_max: float = 6.0

@export_group("波纹律动")
## 开启=按索引依次跳动的"波"(血条用)；关闭=随机偶发(金币/标记用，默认)。
## 绘制方向天然镜像：左侧(LTR)从左到右、右侧(right_to_left)从右到左。
@export var wave_idle: bool = false
## 波纹相邻图标点起跳间隔(秒)，越小波传播越快。
@export var wave_stagger: float = 0.12
## 血量越少波越快：以「当前值/上限」插值波速 → 满血=1.0、濒死(→0)按 wave_low_speed 倍加速(心跳加快感)。
@export var wave_speed_by_hp: bool = false
## 濒死(值→0)时的波速倍率（满血基准=1.0）。
@export var wave_low_speed: float = 3.0

@export_group("排布")
## 单个图标点的绘制边长（物理像素，正方形）。
@export var pip_size: float = 26.0:
	set(v):
		pip_size = v
		queue_redraw()
## 相邻图标点间距（像素）。
@export var spacing: float = 3.0:
	set(v):
		spacing = v
		queue_redraw()
## 从右往左排（P2 对手镜像用；节点 offset_left 摆右锚点）。
@export var right_to_left: bool = false:
	set(v):
		right_to_left = v
		queue_redraw()
## 每行最多几个，超出换行；0 = 不换行。
@export var per_row_cap: int = 0:
	set(v):
		per_row_cap = maxi(v, 0)
		queue_redraw()
## 换行时的行间距（像素）。
@export var row_spacing: float = 6.0:
	set(v):
		row_spacing = v
		queue_redraw()

@export_group("满/空/半")
## 是否在当前值之后用暗色空心补到 max（血量 true；能量 false）。
@export var show_empty: bool = true:
	set(v):
		show_empty = v
		queue_redraw()
## 是否支持半颗（血量半点制 true；能量整数 false）。
@export var allow_half: bool = true:
	set(v):
		allow_half = v
		queue_redraw()
## 满图标点色调（默认白=原图色）。
@export var full_modulate: Color = Color.WHITE:
	set(v):
		full_modulate = v
		queue_redraw()
## 空心占位色调（暗）。
@export var empty_modulate: Color = Color(0.16, 0.14, 0.2, 0.8):
	set(v):
		empty_modulate = v
		queue_redraw()
## 护甲覆盖色（银灰；先把心形去色再 × 本色 → 真银灰，不受红心原色影响）。
@export var extra_modulate: Color = Color(0.92, 0.94, 0.98, 1.0):
	set(v):
		extra_modulate = v
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
@export var bottom_shadow_color := Color(0.02, 0.012, 0.008, 0.32):
	set(v):
		bottom_shadow_color = v
		queue_redraw()

@export_group("低血闪烁")
## 开启=剩余血量（满心/半心）在低血时红色呼吸闪烁（血条用；金币/标记关）。
@export var low_hp_flash: bool = false
## 触发阈值：当前值/上限 ≤ 此值时开始闪。
@export var low_hp_ratio: float = 0.3
## 闪烁峰值叠加的红色（混入 full_modulate）。
@export var low_hp_flash_color: Color = Color(1.7, 0.42, 0.38, 1.0)
## 闪烁速度（rad/s）。
@export var low_hp_flash_speed: float = 6.0
## 闪烁强度（0~1，红色混入比例峰值）。
@export_range(0.0, 1.0) var low_hp_flash_amount: float = 0.85

@export_group("编辑器预览")
## @tool 下无数据时用这组值预览，便于可视化摆位；运行时被实际值覆盖。
@export var preview_cur: float = 4.5:
	set(v):
		preview_cur = v
		queue_redraw()
@export var preview_max: float = 6.0:
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
var _gray_tex: Texture2D = null   # 去色版心形(护甲银灰覆盖用；× extra_modulate = 真银灰)

# 每个图标点独立的 idle 状态（错峰、偶发播放）。索引 = 槽位。
var _phase: PackedFloat32Array = PackedFloat32Array()   # 当前段已过时间
var _dwell: PackedFloat32Array = PackedFloat32Array()   # 本次静止时长（到点后播一遍）
var _playing: PackedByteArray = PackedByteArray()       # 0=静止 1=播放中
var _pip_frame: PackedInt32Array = PackedInt32Array()   # 当前帧
var _slot_count: int = 0                                # 当前绘制的图标点数
var _wave_time: float = 0.0                             # 波纹律动累计时间
var _wave_cycle: float = 1.0                            # 当前波纹一个循环的时长(秒)·供低血红闪同步节奏
var _flash_phase: float = 0.0                           # 低血闪烁相位(无波纹时回退用)
var _flash_on: bool = false                             # 当前是否处于低血闪烁


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _gray_tex == null:
		_rebuild_gray_tex()
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return                                  # 编辑器里静止显示第 0 帧，避免无谓重绘
	if low_hp_flash:
		_process_low_hp_flash(delta)            # 低血红闪独立于帧动画，始终生效
	var total := hframes * vframes
	if total <= 1 or fps <= 0.0 or _slot_count <= 0:
		return
	_ensure_slots(_slot_count)
	if wave_idle:
		_process_wave(delta, total)
	else:
		_process_random(delta, total)


## 低血红闪：当前值/上限 ≤ low_hp_ratio 时推进相位、每帧重绘（满/半心脉动）；
## 恢复后重绘一次复位。空心与护甲不受影响（仅剩余血量爱心闪）。
func _process_low_hp_flash(delta: float) -> void:
	var lowhp := _max > 0.0 and _cur > 0.0 and (_cur / _max) <= low_hp_ratio
	if lowhp:
		_flash_phase += delta
		_flash_on = true
		queue_redraw()
	elif _flash_on:
		_flash_on = false
		queue_redraw()


## 波纹律动：一道波沿索引(0→N)依次点亮 → 停顿(idle_rest_min) → 循环。
## 索引顺序天然给出 左血条"左→右"、右血条(right_to_left)"右→左"。
func _process_wave(delta: float, total: int) -> void:
	# 动态速度：血量越少波越快。speed 由「当前值/上限」插值，每帧用实时血量重算
	# （每滴血独立反映到速度上）；满血=1.0 不变，濒死≈wave_low_speed 倍（心跳加快）。
	var speed := 1.0
	if wave_speed_by_hp and _max > 0.0:
		var frac := clampf(_cur / _max, 0.0, 1.0)
		speed = lerpf(maxf(wave_low_speed, 1.0), 1.0, frac)
	_wave_time += delta * speed
	var anim_dur := float(total) / fps
	var cycle := maxf(float(_slot_count - 1) * wave_stagger + anim_dur + maxf(idle_rest_min, 0.1), 0.1)
	_wave_cycle = cycle   # 供低血红闪同步同一节奏(见 _draw)
	var cyc := fmod(_wave_time, cycle)
	var changed := false
	for i in range(_slot_count):
		var local := cyc - float(i) * wave_stagger
		var nf := 0
		if local >= 0.0 and local < anim_dur:
			nf = int(local * fps)
			if nf >= total:
				nf = 0
		if _pip_frame[i] != nf:
			_pip_frame[i] = nf
			changed = true
	if changed:
		queue_redraw()


## 随机偶发：每个点平时停第 0 帧，间隔随机各自播一遍(金币/标记用)。
func _process_random(delta: float, total: int) -> void:
	var changed := false
	for i in range(_slot_count):
		_phase[i] += delta
		var nf := 0
		if _playing[i] == 0:
			if _phase[i] >= _dwell[i]:           # 静止到点 → 开播
				_playing[i] = 1
				_phase[i] = 0.0
		else:
			var f := int(_phase[i] * fps)
			if f >= total:                       # 播完一遍 → 回静止，抽新的静止时长
				_playing[i] = 0
				_phase[i] = 0.0
				_dwell[i] = _rand_dwell()
			else:
				nf = f
		if _pip_frame[i] != nf:
			_pip_frame[i] = nf
			changed = true
	if changed:
		queue_redraw()


## 设置显示值（半点制小数）。能量用 set_value(e, e)；纯图标用 set_value(1, 1)。
func set_value(cur: float, max_val: float, extra: float = 0.0) -> void:
	_cur = maxf(cur, 0.0)
	_max = maxf(max_val, 0.0)
	_extra = maxf(extra, 0.0)
	queue_redraw()


func _rand_dwell() -> float:
	return randf_range(idle_rest_min, maxf(idle_rest_max, idle_rest_min))


## 扩容每点状态数组，新点给随机初相位（错峰）+ 随机静止时长。
func _ensure_slots(n: int) -> void:
	while _phase.size() < n:
		var dw := _rand_dwell()
		_dwell.append(dw)
		_phase.append(randf() * dw if not Engine.is_editor_hint() else 0.0)
		_playing.append(0)
		_pip_frame.append(0)


func _draw() -> void:
	var cur := _cur
	var maxv := _max
	var extra := _extra
	if Engine.is_editor_hint() and maxv <= 0.0 and cur <= 0.0:   # 编辑器无数据 → 预览值
		cur = preview_cur
		maxv = preview_max
		extra = preview_extra
	if sheet == null:
		return

	var full_n := int(floor(cur + 0.0001))
	var has_half := allow_half and (cur - float(full_n)) >= 0.49
	var filled := full_n + (1 if has_half else 0)
	var empties := 0
	if show_empty:
		empties = maxi(int(ceil(maxv - 0.0001)) - filled, 0)

	var extra_full := int(floor(extra + 0.0001))
	var extra_half := allow_half and (extra - float(extra_full)) >= 0.49

	# 总宽取「血量段」与「护甲段」较大者：护甲灰色覆盖叠在血量爱心上(从最左起)，
	# 仅当护甲多于血量槽位时才向右延伸。空心不跳但仍占槽位以对齐索引。
	var extra_slots := extra_full + (1 if extra_half else 0)
	_slot_count = maxi(filled + empties, extra_slots)
	_ensure_slots(_slot_count)

	# 每个槽只画一次第 0 帧轮廓阴影；血量/空槽/护甲覆盖不会重复叠黑。
	if bottom_shadow_enabled:
		for shadow_index in range(_slot_count):
			_draw_pip_shadow(shadow_index)

	# 剩余血量爱心的颜色：低血时红色脉动（仅满/半心，空心不变）。
	# 节奏与血条波浪一致：用同一 _wave_time 时钟·每个波循环红光脉动一次(峰值对齐波起点)；
	# 无波纹(wave_idle=false)时回退独立正弦呼吸。
	var live_mod := full_modulate
	if low_hp_flash and _flash_on:
		var pulse: float
		if wave_idle and _wave_cycle > 0.0:
			var ph := fmod(_wave_time, _wave_cycle) / _wave_cycle
			pulse = 0.5 + 0.5 * cos(ph * TAU)   # ph=0(波循环起点)→红光峰值，与波同拍
		else:
			pulse = 0.5 + 0.5 * sin(_flash_phase * low_hp_flash_speed)
		live_mod = full_modulate.lerp(low_hp_flash_color, pulse * low_hp_flash_amount)

	# 第一层：血量（满 / 半 / 暗色空心）
	var slot := 0
	for _i in range(full_n):                 # 满
		_draw_pip(slot, 1.0, live_mod, true)
		slot += 1
	if has_half:                             # 半
		_draw_pip(slot, 0.5, live_mod, true)
		slot += 1
	for _i in range(empties):                # 暗色空心占位（不跳动）
		_draw_pip(slot, 1.0, empty_modulate, false)
		slot += 1

	# 第二层：护甲银灰覆盖。从最左(slot 0)起叠在血量爱心之上；用去色心形 ×
	# 银灰 extra_modulate → 真银灰(不受红心原色影响)；半格/整格同血量；不跳动。
	var shield_tex: Texture2D = _gray_tex if _gray_tex != null else sheet
	var sslot := 0
	for _i in range(extra_full):             # 护甲满格
		_draw_pip(sslot, 1.0, extra_modulate, false, shield_tex)
		sslot += 1
	if extra_half:                           # 护甲半格
		_draw_pip(sslot, 0.5, extra_modulate, false, shield_tex)
		sslot += 1


## 画第 index 个图标点。fill<1 = 半颗（裁靠内一侧）；animate=false 强制第 0 帧（空心用）。
func _draw_pip(index: int, fill: float, mod: Color, animate: bool, tex: Texture2D = null) -> void:
	var t: Texture2D = tex if tex != null else sheet
	if t == null:
		return
	var step := pip_size + spacing
	var col := index
	var row := 0
	if per_row_cap > 0:
		col = index % per_row_cap
		row = index / per_row_cap
	var x := col * step
	if right_to_left:
		x = -step * float(col + 1) + spacing   # 从右锚点往左排
	var y := row * (pip_size + row_spacing)

	var frame := 0
	if animate and index < _pip_frame.size():
		frame = _pip_frame[index]
	var fw := t.get_width() / hframes
	var fh := t.get_height() / vframes
	var fcol := frame % hframes
	var frow := frame / hframes
	var src := Rect2(fcol * fw, frow * fh, fw, fh)
	var dst := Rect2(x, y, pip_size, pip_size)
	if fill < 0.999:
		# 半颗：裁靠"内侧/满侧"的半边（LTR 留左半，RTL 留右半）
		if right_to_left:
			src.position.x += fw * 0.5
			src.size.x *= 0.5
			dst.position.x += pip_size * 0.5
			dst.size.x *= 0.5
		else:
			src.size.x *= 0.5
			dst.size.x *= 0.5
	draw_texture_rect_region(t, dst, src, mod)


func _draw_pip_shadow(index: int) -> void:
	if sheet == null:
		return
	var step := pip_size + spacing
	var col := index
	var row := 0
	if per_row_cap > 0:
		col = index % per_row_cap
		row = index / per_row_cap
	var x := col * step
	if right_to_left:
		x = -step * float(col + 1) + spacing
	var y := row * (pip_size + row_spacing)
	var frame_w := sheet.get_width() / hframes
	var frame_h := sheet.get_height() / vframes
	var source := Rect2(0.0, 0.0, frame_w, frame_h)
	var destination := Rect2(
			Vector2(x, y) + bottom_shadow_offset,
			Vector2(pip_size, pip_size))
	draw_texture_rect_region(sheet, destination, source, bottom_shadow_color)


## 生成去色版心形纹理：护甲用它 × 银灰 extra_modulate 得到真银灰
## （红心原色经乘法只会变暗红，必须先去色为灰度再上色）。sheet 变更时重建一次。
func _rebuild_gray_tex() -> void:
	if sheet == null:
		_gray_tex = null
		return
	var img := sheet.get_image()
	if img == null:
		_gray_tex = null
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var lb := clampf(l * 1.1 + 0.5, 0.0, 1.0)   # 整体提亮到银白区，保留相对明暗
			img.set_pixel(xx, yy, Color(lb, lb, lb, c.a))
	_gray_tex = ImageTexture.create_from_image(img)
