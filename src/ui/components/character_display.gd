class_name CharacterDisplay
extends SubViewportContainer

## Self-contained character display: SubViewport + AnimatedSprite2D.
## Drop into any scene, set spritesheet_path, see idle animation in editor.

@export var spritesheet_path: String = "":
	set(v):
		spritesheet_path = v
		if is_node_ready() and _sprite:
			_load_spritesheet()

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

@export var anim_fps: float = 8.0:
	set(v):
		anim_fps = v
		if is_node_ready() and _sprite and _sprite.sprite_frames:
			_sprite.sprite_frames.set_animation_speed("idle", v)

@export var frame_size: int = 128

var _sprite: AnimatedSprite2D
static var _sprite_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_child_count() > 0 and get_child(0) is SubViewport:
		var vp: SubViewport = get_child(0) as SubViewport
		if vp.get_child_count() > 0 and vp.get_child(0) is AnimatedSprite2D:
			_sprite = vp.get_child(0) as AnimatedSprite2D
	if not _sprite:
		_build_nodes()
	if spritesheet_path != "":
		_load_spritesheet()


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
		for row in range(4):
			for col in range(4):
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(col * frame_size, row * frame_size, frame_size, frame_size)
				frames.add_frame("idle", atlas)
		_sprite_cache[spritesheet_path] = frames
		_sprite.sprite_frames = frames
	_sprite.play("idle")


func set_hit_flash(on: bool) -> void:
	modulate = Color("#663355") if on else Color.WHITE
