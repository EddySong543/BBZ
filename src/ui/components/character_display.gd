class_name CharacterDisplay
extends SubViewportContainer

## Self-contained character display: SubViewport + AnimatedSprite2D.
## Drop into any scene, set spritesheet_path, see idle animation in editor.
## Supports attack/hit/defend via additional spritesheets.

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
			_sprite.play("idle")

@export var sprite_scale: Vector2 = Vector2(2.0, 2.0):
	set(v):
		sprite_scale = v
		if is_node_ready() and _sprite:
			_sprite.scale = v

@export var sprite_offset: Vector2 = Vector2(64, 120):
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

## Universal defend shield spritesheet (shared across all heroes).
## When a hero uses 防/大防, this shield overlay appears on top of the character.
@export var shield_spritesheet_path: String = "":
	set(v):
		shield_spritesheet_path = v
		if is_node_ready() and _shield_sprite and v != "":
			_load_shield_spritesheet()

## Shield overlay transparency (0 = invisible, 1 = fully opaque). Tune in Inspector.
@export var shield_opacity: float = 0.5
@export var frame_size: int = 256
@export var frame_cols: int = 4
@export var frame_rows: int = 4

var _sprite: AnimatedSprite2D
var _shield_sprite: AnimatedSprite2D
var _return_to_idle: bool = false

static var _sprite_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_child_count() > 0 and get_child(0) is SubViewport:
		var vp: SubViewport = get_child(0) as SubViewport
		for c in vp.get_children():
			if c is AnimatedSprite2D:
				if c.name == "DefendShield":
					_shield_sprite = c as AnimatedSprite2D
				else:
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

	# Load universal defend shield spritesheet
	if _shield_sprite and shield_spritesheet_path != "":
		_load_shield_spritesheet()

	if not _sprite.animation_finished.is_connected(_on_anim_finished):
		_sprite.animation_finished.connect(_on_anim_finished)

	_sprite.flip_h = flip_h
	# 受击白闪 shader（A 方案 juice）
	if _sprite.material == null:
		var fmat := ShaderMaterial.new()
		fmat.shader = preload("res://assets/shaders/hit_flash.gdshader")
		fmat.set_shader_parameter("flash_amount", 0.0)
		_sprite.material = fmat


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

	_shield_sprite = AnimatedSprite2D.new()
	_shield_sprite.name = "DefendShield"
	_shield_sprite.position = sprite_offset
	_shield_sprite.scale = sprite_scale
	_shield_sprite.visible = false
	vp.add_child(_shield_sprite)


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
	_sprite.play("idle")


func _load_frames_resource(path: String) -> void:
	if not _sprite or path == "":
		return
	if not ResourceLoader.exists(path):
		push_warning("CharacterDisplay: frames resource not found: " + path)
		return
	var sf: SpriteFrames = load(path)
	_sprite.sprite_frames = sf
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


func _load_shield_spritesheet() -> void:
	if not _shield_sprite or shield_spritesheet_path == "":
		return
	if not ResourceLoader.exists(shield_spritesheet_path):
		push_warning("CharacterDisplay: shield spritesheet not found: " + shield_spritesheet_path)
		return

	var tex: Texture2D = load(shield_spritesheet_path)
	var frames := SpriteFrames.new()
	frames.add_animation("appear")
	frames.set_animation_speed("appear", anim_fps)
	frames.set_animation_loop("appear", false)
	for row in range(frame_rows):
		for col in range(frame_cols):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * frame_size, row * frame_size, frame_size, frame_size)
			frames.add_frame("appear", atlas)
	_shield_sprite.sprite_frames = frames
	_shield_sprite.visible = false


## Show or hide the universal defend shield overlay.
## Call with true when hero uses 防/大防, false to hide.
func show_defend_shield(on: bool) -> void:
	if not _shield_sprite or not _shield_sprite.sprite_frames:
		return
	if on:
		_shield_sprite.visible = true
		_shield_sprite.modulate = Color(1, 1, 1, shield_opacity)
		_shield_sprite.play("appear")
	else:
		_shield_sprite.visible = false
		_shield_sprite.stop()
