@tool
class_name CommandSequenceSlotSkin
extends Control

signal tuning_changed

## 顺序序列单格只保留一个小型丝滑四尖十字星底座。
## 轮廓按 res/十字星.png 的深收腰四尖星重建；米白主色和暗衬复用顶部倒计时菱形。
## 不绘制外框、空槽轮廓、托片或连接轨道。

const SHADOW_COLOR := Color(0.07, 0.09, 0.09, 0.90)
const STAR_COLOR := Color("#F2E8CC")
const STAR_UNDERLAY_COLOR := Color(0.07, 0.04, 0.02, 0.88)
const STAMP_COLOR := Color("#FFF9E8")
const SUPERSAMPLED_STAR_SHADER := preload(
	"res://assets/shaders/canvas_ui_command_cross_star_ssaa.gdshader")
const DEFAULT_STAR_CENTER := Vector2(33.0, 64.5)
const DEFAULT_STAR_RADII := Vector2(9.0, 13.0)
const STAR_CURVE_SAMPLES := 96
const SSAA_SAMPLES_PER_AXIS := 9
const DEFAULT_STAR_PROFILE_POWER := 4.0
const DEFAULT_EMPTY_PULSE_DURATION := 6.0
const DEFAULT_EMPTY_PULSE_MIN_ALPHA := 0.30

@export_group("十字星手动调整")
@export var editor_preview: bool = false:
	set(value):
		editor_preview = value
		_update_editor_preview_state()
@export var tuning_center_offset: Vector2 = Vector2.ZERO:
	set(value):
		tuning_center_offset = value
		_notify_tuning_changed()
@export_range(4.0, 20.0, 0.25) var tuning_horizontal_radius: float = 9.0:
	set(value):
		tuning_horizontal_radius = maxf(value, 1.0)
		_notify_tuning_changed()
@export_range(4.0, 24.0, 0.25) var tuning_vertical_radius: float = 13.0:
	set(value):
		tuning_vertical_radius = maxf(value, 1.0)
		_notify_tuning_changed()
@export_range(2.0, 6.0, 0.1) var tuning_waist_power: float = 4.0:
	set(value):
		tuning_waist_power = clampf(value, 2.0, 6.0)
		_notify_tuning_changed()
@export_range(1.0, 12.0, 0.25) var tuning_pulse_duration: float = 6.0:
	set(value):
		tuning_pulse_duration = maxf(value, 0.25)
		_notify_tuning_changed()
@export_range(0.05, 0.80, 0.05) var tuning_idle_alpha: float = 0.30:
	set(value):
		tuning_idle_alpha = clampf(value, 0.05, 1.0)
		_notify_tuning_changed()
@export_group("十字星底投影")
@export var tuning_shadow_offset: Vector2 = Vector2(3.0, 6.0):
	set(value):
		tuning_shadow_offset = value
		_notify_tuning_changed()
@export var tuning_shadow_color: Color = Color(0.02, 0.012, 0.008, 0.52):
	set(value):
		tuning_shadow_color = value
		_notify_tuning_changed()
@export_range(0.0, 4.0, 0.25) var tuning_shadow_expand: float = 0.0:
	set(value):
		tuning_shadow_expand = maxf(value, 0.0)
		_notify_tuning_changed()
@export_group("")

var ornament_color: Color = STAR_COLOR
var pulse_phase: float = 0.0
var pulse_strength: float = 0.0

var empty: bool = false:
	set(value):
		empty = value
		queue_redraw()

var hot: bool = false:
	set(value):
		if hot == value:
			return
		hot = value
		queue_redraw()

var lock_progress: float = 1.0:
	set(value):
		lock_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var flash_strength: float = 0.0:
	set(value):
		flash_strength = clampf(value, 0.0, 1.0)
		flash_peak = maxf(flash_peak, flash_strength)
		queue_redraw()

var flash_peak: float = 0.0
var _supersampled_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_supersampled_material()
	_sync_supersampled_material()
	_update_editor_preview_state()
	set_process(empty and (not editor_preview or Engine.is_editor_hint()))
	queue_redraw()


func _notify_tuning_changed() -> void:
	queue_redraw()
	if is_inside_tree():
		_sync_supersampled_material()
	if is_inside_tree():
		tuning_changed.emit()


func _update_editor_preview_state() -> void:
	if not editor_preview:
		return
	empty = true
	visible = Engine.is_editor_hint()
	set_process(Engine.is_editor_hint())


func configure(is_empty: bool, normal_color: Color = STAR_COLOR,
		normal_underlay_color: Color = STAR_UNDERLAY_COLOR,
		normal_underlay_width: float = 3.0,
		tuning_center_offset: Vector2 = Vector2.ZERO,
		tuning_radii: Vector2 = DEFAULT_STAR_RADII,
		tuning_profile_power: float = DEFAULT_STAR_PROFILE_POWER,
		tuning_pulse_duration: float = DEFAULT_EMPTY_PULSE_DURATION,
		tuning_pulse_min_alpha: float = DEFAULT_EMPTY_PULSE_MIN_ALPHA,
		tuning_shadow_color: Color = Color(0.02, 0.012, 0.008, 0.52),
		tuning_shadow_offset: Vector2 = Vector2(3.0, 6.0),
		tuning_shadow_spread: float = 0.0) -> void:
	empty = is_empty
	ornament_color = normal_color
	# 十字星不再复用倒计时暗衬；暗衬是环绕描边，和右下定向底投影语义不同。
	var _unused_underlay_color: Color = normal_underlay_color
	var _unused_underlay_width: float = normal_underlay_width
	self.tuning_center_offset = tuning_center_offset
	tuning_horizontal_radius = tuning_radii.x
	tuning_vertical_radius = tuning_radii.y
	tuning_waist_power = tuning_profile_power
	self.tuning_pulse_duration = tuning_pulse_duration
	tuning_idle_alpha = tuning_pulse_min_alpha
	self.tuning_shadow_color = tuning_shadow_color
	self.tuning_shadow_offset = tuning_shadow_offset
	tuning_shadow_expand = tuning_shadow_spread
	lock_progress = 1.0
	flash_strength = 0.0
	flash_peak = 0.0
	pulse_phase = 0.0
	pulse_strength = 0.0
	set_process(empty)


func set_hot(value: bool) -> void:
	hot = value
	if hot:
		pulse_strength = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if not empty or hot:
		return
	pulse_phase = fmod(pulse_phase + delta / tuning_pulse_duration, 1.0)
	# 余弦缓入缓出比三角波自然；呼吸只改变微小尺寸与亮度，不产生闪屏。
	pulse_strength = 0.5 - 0.5 * cos(pulse_phase * TAU)
	queue_redraw()


func prepare_lock_animation() -> void:
	# 沿用公共调用名；现在代表十字星由中心向四端落印展开。
	lock_progress = 0.0
	flash_strength = 1.0
	flash_peak = 1.0


func set_landing_progress(progress: float) -> void:
	var normalized: float = clampf(progress, 0.0, 1.0)
	lock_progress = normalized
	flash_strength = 1.0 - normalized
	flash_peak = maxf(flash_peak, flash_strength)
	queue_redraw()


func _star_radii() -> Vector2:
	# Base 预览节点是唯一轮廓源。等待呼吸、吸附与落印只改变明暗，绝不再改写
	# 横纵半径，否则相同 Inspector 参数在正式场景的不同帧会呈现成另一种比例。
	return Vector2(tuning_horizontal_radius, tuning_vertical_radius)


func _star_points(radii: Vector2) -> PackedVector2Array:
	return _star_points_at(DEFAULT_STAR_CENTER + tuning_center_offset, radii)


func _star_points_at(center: Vector2, radii: Vector2) -> PackedVector2Array:
	# 参考图的截面接近 sqrt(|x|)+sqrt(|y|)=1，等价于 cos⁴/sin⁴ 参数曲线。
	# 相比旧版 cos³/sin³，它在中心外迅速深收腰，同时保留连续曲线和清晰尖端。
	var points := PackedVector2Array()
	for index: int in range(STAR_CURVE_SAMPLES):
		var angle: float = TAU * float(index) / float(STAR_CURVE_SAMPLES)
		var cosine: float = cos(angle)
		var sine: float = sin(angle)
		var profile_x: float = signf(cosine) * pow(absf(cosine), tuning_waist_power)
		var profile_y: float = signf(sine) * pow(absf(sine), tuning_waist_power)
		points.append(center + Vector2(
			profile_x * radii.x,
			profile_y * radii.y))
	return points


func _active_star_color() -> Color:
	var hot_mix: float = 0.16 if hot else 0.0
	var base: Color = ornament_color.lerp(STAMP_COLOR, hot_mix)
	base = base.lerp(STAMP_COLOR, flash_strength)
	if empty and not hot:
		# 峰值必须与已有行动底座同色同亮；暗部只承担等待提示，不再压暗高光。
		base.a *= lerpf(tuning_idle_alpha, 1.0, pulse_strength)
	return base


func debug_geometry() -> Dictionary:
	var radii: Vector2 = _star_radii()
	return {
		"star_center": DEFAULT_STAR_CENTER + tuning_center_offset,
		"base_radii": Vector2(tuning_horizontal_radius, tuning_vertical_radius),
		"star_radii": radii,
		"star_radius": maxf(radii.x, radii.y),
		"star_points": _star_points(radii),
		"star_color": _active_star_color(),
		"outline_enabled": false,
		"underlay_color": Color.TRANSPARENT,
		"underlay_width": 0.0,
		"curve_samples": STAR_CURVE_SAMPLES,
		"profile_power": tuning_waist_power,
		"pulse_duration": tuning_pulse_duration,
		"pulse_min_alpha": tuning_idle_alpha,
		"geometry_locked_to_preview": true,
		"smooth_vector_rendering": true,
		"analytic_antialiasing": true,
		"geometry_antialiasing": false,
		"ssaa_samples_per_axis": SSAA_SAMPLES_PER_AXIS,
		"render_path": "analytic_ssaa_9x9",
		"bottom_shadow_color": tuning_shadow_color,
		"bottom_shadow_offset": tuning_shadow_offset,
		"bottom_shadow_expand": tuning_shadow_expand,
		"pulse_strength": pulse_strength,
		"processing": is_processing(),
		"lock_progress": lock_progress,
		"flash_peak": flash_peak,
	}


func _ensure_supersampled_material() -> void:
	# 旧 Polygon2D 与外扩羽化只改变低分辨率像素块的颜色，不能计算曲线穿过
	# 每个屏幕像素的真实面积。统一改为 9×9 子像素覆盖；奇数网格包含轴心，
	# 不会漏掉深收腰十字星的极细尖端。Base 与 F6 都直接按
	# 当前物理像素 footprint 重新采样，同一轮廓在不同窗口倍率下不会固化成贴图。
	for child_name: String in [
		"SmoothShadow", "SmoothShadowFeather", "SmoothStar", "SmoothStarFeather"]:
		var legacy := get_node_or_null(child_name) as CanvasItem
		if legacy != null:
			legacy.visible = false
	if _supersampled_material == null:
		_supersampled_material = ShaderMaterial.new()
		_supersampled_material.shader = SUPERSAMPLED_STAR_SHADER
	material = _supersampled_material


func _sync_supersampled_material() -> void:
	_ensure_supersampled_material()
	var radii: Vector2 = _star_radii()
	var shadow_alpha: float = 1.0
	if empty and not hot:
		shadow_alpha = lerpf(tuning_idle_alpha, 1.0, pulse_strength)
	var active_shadow := tuning_shadow_color
	active_shadow.a *= shadow_alpha
	var center: Vector2 = DEFAULT_STAR_CENTER + tuning_center_offset
	_supersampled_material.set_shader_parameter("star_center", center)
	_supersampled_material.set_shader_parameter("star_radii", radii)
	_supersampled_material.set_shader_parameter("profile_power", tuning_waist_power)
	_supersampled_material.set_shader_parameter("star_color", _active_star_color())
	_supersampled_material.set_shader_parameter("shadow_offset", tuning_shadow_offset)
	_supersampled_material.set_shader_parameter("shadow_expand", tuning_shadow_expand)
	_supersampled_material.set_shader_parameter("shadow_color", active_shadow)


func _supersampled_draw_region(radii: Vector2) -> Rect2:
	var center: Vector2 = DEFAULT_STAR_CENTER + tuning_center_offset
	var shadow_radii := radii + Vector2.ONE * tuning_shadow_expand
	var shadow_center := center + tuning_shadow_offset
	var padding := Vector2.ONE * 2.0
	var minimum := Vector2.ZERO.min(center - radii - padding).min(
		shadow_center - shadow_radii - padding)
	var maximum := size.max(center + radii + padding).max(
		shadow_center + shadow_radii + padding)
	return Rect2(minimum, maximum - minimum)


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	_sync_supersampled_material()
	draw_rect(_supersampled_draw_region(_star_radii()), Color.WHITE)
