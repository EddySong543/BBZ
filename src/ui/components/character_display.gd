@tool
class_name CharacterDisplay
extends SubViewportContainer

## Self-contained character display: SubViewport + AnimatedSprite2D.
## Drop into any scene, set spritesheet_path, see idle animation in editor.
## Supports attack/hit/defend via additional spritesheets.
##
## 【可视化调整·2026-06-27】加 @tool 后，在编辑器选中本节点(如 battle_screen 的
## P1CharDisplay/P2CharDisplay)，直接在 Inspector 改 sprite_scale(大小) / sprite_offset(位置)，
## 视口里立绘**实时**更新；每个实例可各自 override → 每个英雄独立站位/大小。
## (旧 bug：sprite_scale 之前是死值——_ready 没应用它、场景里 AnimatedSprite2D.scale 才生效，
##  且非 @tool 脚本在编辑器不跑 setter，所以改了"没反应、还是原来大小"。现已修。)

@export var spritesheet_path: String = "":
	set(v):
		spritesheet_path = v
		if is_node_ready() and _sprite:
			if v == "":
				_sprite.sprite_frames = null
			else:
				_load_spritesheet()

@export var sprite_frames: SpriteFrames = null:
	set(v):
		sprite_frames = v
		if is_node_ready() and _sprite and v:
			_sprite.sprite_frames = v
			_apply_idle_speed()
			_sprite.play("idle")

## 立绘缩放（所见即所得·@tool 实时）。⚠ 立绘像素尺寸 = idle 帧尺寸(256) × scale，
## 不得超过 SubViewport.size（当前 768 → 支持 scale ≤ 3.0），否则立绘被 viewport 边界裁切。
## 要更大立绘：先把 character_display.tscn 的 SubViewport size 调大、并同步 battle 容器 offset。
@export var sprite_scale: Vector2 = Vector2(2.2, 2.2):
	set(v):
		sprite_scale = v
		if is_node_ready() and _sprite:
			_sprite.scale = v

@export var sprite_offset: Vector2 = Vector2(384, 384):
	set(v):
		sprite_offset = v
		if is_node_ready() and _sprite:
			_sprite.position = v

## 水平翻转（P2 对手立绘朝左用）。
@export var flip_h: bool = false:
	set(v):
		flip_h = v
		if is_node_ready() and _sprite:
			_sprite.flip_h = v

@export var anim_fps: float = 8.0:
	set(v):
		anim_fps = v
		if is_node_ready() and _sprite and _sprite.sprite_frames:
			for anim_name in _sprite.sprite_frames.get_animation_names():
				_sprite.sprite_frames.set_animation_speed(anim_name, v)
			_apply_idle_speed()   # idle 不跟 anim_fps，按帧数动态覆盖（少帧放慢）

@export_group("Idle 动态调速")
## idle 满帧时的播放帧率（基准）。帧数 ≥ idle_ref_frames 的 idle 用此值。
@export var idle_base_fps: float = 12.0:
	set(v):
		idle_base_fps = v
		_apply_idle_speed()
## idle 基准帧数（满帧）。帧数 < 此值的 idle 按比例放慢、循环时长与满帧一致；
## 帧数 ≥ 此值不加速（封顶 base_fps）。多数英雄 idle = 5~6 帧，个别 12 帧。
@export var idle_ref_frames: int = 6:
	set(v):
		idle_ref_frames = maxi(1, v)
		_apply_idle_speed()


@export var sprite_frames_path: String = "":
	set(v):
		sprite_frames_path = v
		if is_node_ready() and _sprite:
			if v == "":
				_sprite.sprite_frames = null
			else:
				_load_frames_resource(v)

@export var attack_spritesheet_path: String = "":
	set(v):
		attack_spritesheet_path = v
		if is_node_ready() and _sprite and v != "":
			_ensure_animation("attack", v)

@export var hit_spritesheet_path: String = "":
	set(v):
		hit_spritesheet_path = v
		if is_node_ready() and _sprite and v != "":
			_ensure_animation("hit", v)

@export var defend_spritesheet_path: String = "":
	set(v):
		defend_spritesheet_path = v
		if is_node_ready() and _sprite and v != "":
			_ensure_animation("defend", v)

@export var defeat_spritesheet_path: String = "":
	set(v):
		defeat_spritesheet_path = v
		if is_node_ready() and _sprite and v != "":
			_ensure_animation("defeat", v)

@export var frame_size: int = 256
@export var frame_cols: int = 4
@export var frame_rows: int = 4

@export_group("环境光照 (Backlight / Rim)")
## 月光描边颜色（冷蓝白）。
@export var rim_color: Color = Color(0.62, 0.78, 1.0, 1.0):
	set(v):
		rim_color = v
		_apply_light()
## 月光描边强度。
@export_range(0.0, 2.0) var rim_strength: float = 0.5:
	set(v):
		rim_strength = v
		_apply_light()
## 描边检测宽度（纹理像素）。
@export_range(1.0, 8.0) var rim_width: float = 3.0:
	set(v):
		rim_width = v
		_apply_light()
## 背光强度（背月侧压暗程度）。
@export_range(0.0, 1.0) var backlight: float = 0.25:
	set(v):
		backlight = v
		_apply_light()
## 背光阴影色（冷）。
@export var shadow_tint: Color = Color(0.45, 0.55, 0.8, 1.0):
	set(v):
		shadow_tint = v
		_apply_light()
## 朝月方向（UV 空间，右上；P2 flip_h 时自动镜像 x）。
@export var light_dir: Vector2 = Vector2(0.6, -0.6):
	set(v):
		light_dir = v
		_apply_light()
## 皮肤暖补偿色（抵消全屏冷滤镜，让皮肤回正）。
@export var skin_warmth: Color = Color(1.08, 1.0, 0.9, 1.0):
	set(v):
		skin_warmth = v
		_apply_light()
## 暖补偿强度（越大皮肤越暖、越抵消夜色蓝；0=不补偿）。
@export_range(0.0, 1.0) var warmth_amount: float = 0.3:
	set(v):
		warmth_amount = v
		_apply_light()

var _sprite: AnimatedSprite2D
var _return_to_idle: bool = false

static var _sprite_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_child_count() > 0 and get_child(0) is SubViewport:
		var vp: SubViewport = get_child(0) as SubViewport
		for c in vp.get_children():
			if c is AnimatedSprite2D:
				_sprite = c as AnimatedSprite2D
	if not _sprite:
		_build_nodes()

	# Load base animation first
	if _sprite.sprite_frames and not _sprite.sprite_frames.get_animation_names().is_empty():
		_sprite.play("idle")
	elif sprite_frames_path != "":
		_load_frames_resource(sprite_frames_path)
	elif spritesheet_path != "":
		_load_spritesheet()

	# Load additional animations
	if attack_spritesheet_path != "":
		_ensure_animation("attack", attack_spritesheet_path)
	if hit_spritesheet_path != "":
		_ensure_animation("hit", hit_spritesheet_path)
	if defend_spritesheet_path != "":
		_ensure_animation("defend", defend_spritesheet_path)
	if defeat_spritesheet_path != "":
		_ensure_animation("defeat", defeat_spritesheet_path)

	if not _sprite.animation_finished.is_connected(_on_anim_finished):
		_sprite.animation_finished.connect(_on_anim_finished)

	_sprite.flip_h = flip_h
	# 应用导出的 sprite_scale / sprite_offset（修旧 bug：原先这俩 export 不生效·只有场景里
	# AnimatedSprite2D 的值生效）→ 现在它们是唯一真相源，Inspector 改值即所见即所得（@tool 实时）。
	_sprite.scale = sprite_scale
	_sprite.position = sprite_offset
	# 像素清晰：SubViewport 内默认是 Linear 过滤会把精灵放大糊掉，强制 Nearest（容器 + 精灵）
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 角色光照 shader（背光 + 月光边缘光 rim + 受击白闪）。
	if _sprite.material == null:
		var fmat := ShaderMaterial.new()
		fmat.shader = preload("res://assets/shaders/character_light.gdshader")
		fmat.set_shader_parameter("flash_amount", 0.0)
		_sprite.material = fmat
	_apply_light()  # 应用 rim/背光 export 参数（含 flip_h 朝向）
	_apply_idle_speed()  # 按 idle 帧数动态设循环速度（少帧放慢·见函数注释）


func _build_nodes() -> void:
	for c in get_children():
		c.queue_free()
	var vp := SubViewport.new()
	vp.size = Vector2i(frame_size, frame_size)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)

	_sprite = AnimatedSprite2D.new()
	_sprite.position = sprite_offset
	_sprite.scale = sprite_scale
	vp.add_child(_sprite)


func _load_spritesheet() -> void:
	if not _sprite or spritesheet_path == "":
		return
	if not ResourceLoader.exists(spritesheet_path):
		push_warning("CharacterDisplay: spritesheet not found: " + spritesheet_path)
		return

	if _sprite_cache.has(spritesheet_path):
		_sprite.sprite_frames = _sprite_cache[spritesheet_path]
	else:
		var tex: Texture2D = load(spritesheet_path)
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.set_animation_speed("idle", anim_fps)
		frames.set_animation_loop("idle", true)
		for row in range(frame_rows):
			for col in range(frame_cols):
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(col * frame_size, row * frame_size, frame_size, frame_size)
				frames.add_frame("idle", atlas)
		_sprite_cache[spritesheet_path] = frames
		_sprite.sprite_frames = frames
	_apply_idle_speed()
	_sprite.play("idle")


func _load_frames_resource(path: String) -> void:
	if not _sprite or path == "":
		return
	if not ResourceLoader.exists(path):
		push_warning("CharacterDisplay: frames resource not found: " + path)
		return
	var sf: SpriteFrames = load(path)
	_sprite.sprite_frames = sf
	_apply_idle_speed()
	_sprite.play("idle")


func _ensure_animation(anim_name: String, path: String) -> void:
	if not _sprite or path == "":
		return
	if not ResourceLoader.exists(path):
		push_warning("CharacterDisplay: spritesheet not found: " + path)
		return

	var tex: Texture2D = load(path)
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf == null:
		sf = SpriteFrames.new()
		_sprite.sprite_frames = sf

	if sf.has_animation(anim_name):
		sf.remove_animation(anim_name)
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, anim_fps)
	sf.set_animation_loop(anim_name, false)
	for row in range(frame_rows):
		for col in range(frame_cols):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * frame_size, row * frame_size, frame_size, frame_size)
			sf.add_frame(anim_name, atlas)


## Play a one-shot animation, then return to idle.
func play_animation(anim_name: String, return_to_idle: bool = true) -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	if not _sprite.sprite_frames.has_animation(anim_name):
		return
	_return_to_idle = return_to_idle
	_sprite.sprite_frames.set_animation_loop(anim_name, false)
	_sprite.play(anim_name)



## Return how long animation [anim_name] lasts in seconds (frame_count / speed).
## Falls back to 0.5 s when the animation or sprite data is missing.
func _on_anim_finished() -> void:
	if _return_to_idle and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
		_return_to_idle = false


func set_hit_flash(on: bool) -> void:
	modulate = Color("#dd2233") if on else Color.WHITE


## 受击白闪（A 方案 juice）：flash_amount 1→0，把立绘瞬间染白再恢复。
func flash_white(duration: float = 0.18) -> void:
	if not _sprite or _sprite.material == null:
		return
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash_amount", 1.0)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, duration).set_trans(Tween.TRANS_SINE)


## A3 juice：月光描边瞬时增强再回落（出招被自己的招式照亮 / 受击被弧光照亮）。
## 以 export 的 rim_strength 为基准，临时拉高 boost 后缓回基准；不改 export 值。
func pulse_rim(boost: float = 0.8, duration: float = 0.25) -> void:
	if not _sprite or _sprite.material == null:
		return
	var mat := _sprite.material as ShaderMaterial
	var base: float = rim_strength
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("rim_strength", v),
		base + boost, base, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 按 idle 帧数动态设循环速度（解决"少帧 idle 播太快显急促"）：
##   fps = idle_base_fps × min(帧数, idle_ref_frames) / idle_ref_frames
##   → 满帧(≥ref)用 base_fps；少帧按比例降速、循环时长与满帧一致；多帧封顶 base_fps 不被加速。
##   例(base 12 / ref 6)：6帧→12fps(0.5s)、5帧→10fps(0.5s)、12帧→12fps(1.0s)。
## ⚠ 改的是共享 SpriteFrames 资源的 speed（同一英雄 .tres 多处实例一致·不同英雄各自独立）。
func _apply_idle_speed() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	if not _sprite.sprite_frames.has_animation("idle"):
		return
	var n: int = _sprite.sprite_frames.get_frame_count("idle")
	if n <= 0 or idle_ref_frames <= 0:
		return
	var fps: float = idle_base_fps * minf(float(n), float(idle_ref_frames)) / float(idle_ref_frames)
	_sprite.sprite_frames.set_animation_speed("idle", fps)


## 把当前光照 export 参数应用到角色 shader（_ready 后建立 / Inspector 实时调用）。
func _apply_light() -> void:
	if not _sprite or _sprite.material == null:
		return
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("rim_color", rim_color)
	mat.set_shader_parameter("rim_strength", rim_strength)
	mat.set_shader_parameter("rim_width", rim_width)
	mat.set_shader_parameter("backlight", backlight)
	mat.set_shader_parameter("shadow_tint", shadow_tint)
	mat.set_shader_parameter("skin_warmth", skin_warmth)
	mat.set_shader_parameter("warmth_amount", warmth_amount)
	var ldx: float = -light_dir.x if flip_h else light_dir.x
	mat.set_shader_parameter("light_dir", Vector2(ldx, light_dir.y))
