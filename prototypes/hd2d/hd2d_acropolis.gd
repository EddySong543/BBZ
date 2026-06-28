extends Node3D
## HD-2D 创意原型 · 场景 2：卫城宫殿月夜对垒。
## 要求：夜景 / 背景单建筑（帕特农式神殿）/ h38 vs h30 左右对垒 / 宫殿后一轮明月 /
## 柔和光照 / 场景内无可见光源道具（光全部来自月亮）/ 每角色单一影子（仅月光投影）。
## 截图模式：godot --path . --resolution 1280x720 res://prototypes/hd2d/hd2d_acropolis.tscn -- --screenshot

const SPRITE_SHADER := "res://prototypes/hd2d/shaders/hd2d_sprite.gdshader"
const STONE_SHADER := "res://prototypes/hd2d/shaders/pixel_stone.gdshader"
const MOON_SHADER := "res://prototypes/hd2d/shaders/moon_disc.gdshader"

const FRAME_FPS := 8.0
const HERO_SIZE := 3.0

# 每个英雄：图集路径 / 帧数 / 列数 / 单帧 UV 尺寸 / 站位 / 是否镜像
const HEROES := [
	{
		"sheet": "res://assets/sprites/heroes/h38/h38_idle.png",
		"frames": 6, "cols": 4, "uv": Vector2(0.25, 0.5),
		"x": -2.4, "flip": false,
	},
	{
		"sheet": "res://assets/sprites/heroes/h30/h30_idle.png",
		"frames": 12, "cols": 4, "uv": Vector2(0.25, 1.0 / 3.0),
		"x": 2.4, "flip": true,
	},
]

var _hero_mats: Array[ShaderMaterial] = []
var _anim_time := 0.0

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_temple()
	_build_moon()
	_build_heroes()
	_build_dust()
	_build_camera()
	if "--screenshot" in OS.get_cmdline_user_args():
		_screenshot_and_quit()

func _process(delta: float) -> void:
	_anim_time += delta
	for i in _hero_mats.size():
		var cfg: Dictionary = HEROES[i]
		var frames: int = cfg["frames"]
		var cols: int = cfg["cols"]
		var uv: Vector2 = cfg["uv"]
		var idx := int(_anim_time * FRAME_FPS) % frames
		@warning_ignore("integer_division")
		var off := Vector2(float(idx % cols) * uv.x, float(idx / cols) * uv.y)
		if cfg["flip"]:
			off.x += uv.x  # frame_scale.x 为负，起点移到帧右缘
		_hero_mats[i].set_shader_parameter("frame_offset", off)

# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.024, 0.055)
	# 柔和：环境光抬高、整体低对比
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.34, 0.5)
	env.ambient_light_energy = 0.32
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.13)
	env.fog_density = 0.016
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 月光：全场唯一投影光源（单一影子的保证），方向与月亮圆盘位置一致
	var moon_light := DirectionalLight3D.new()
	moon_light.light_color = Color(0.78, 0.82, 1.0)
	moon_light.light_energy = 1.35
	moon_light.shadow_enabled = true
	moon_light.light_angular_distance = 1.2  # 半影柔但边界可辨
	add_child(moon_light)
	# 高位右侧打光（艺术手法：与月亮圆盘构图位置解耦）：
	# ①方位够侧 → 神殿自身影子扫向画外左侧，不再罩住舞台（纯逆光时全场都在殿影里）
	# ②保留指向镜头的分量 → 影子朝左前方，视觉仍与"月在右上后方"自洽
	moon_light.look_at_from_position(Vector3(20.0, 18.0, -6.0), Vector3.ZERO)

	# 神殿立面塑形光（无阴影方向光：纯逆光下立面死平的补救）
	var facade := DirectionalLight3D.new()
	facade.light_color = Color(0.55, 0.62, 0.85)
	facade.light_energy = 0.35
	facade.shadow_enabled = false
	add_child(facade)
	facade.look_at_from_position(Vector3(-3.0, 6.0, 14.0), Vector3(0.0, 3.0, -10.0))

	# 正面柔补光（无阴影，纯可读性，不产生第二影子）
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.8, 0.84, 1.0)
	fill.light_energy = 0.4
	fill.omni_range = 14.0
	add_child(fill)
	fill.position = Vector3(0.0, 4.0, 7.0)

# --------------------------------------------------------------------- stage

func _stone_mat(tile: float, base: Color, px: float = 16.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(STONE_SHADER)
	m.set_shader_parameter("tile_size", tile)
	m.set_shader_parameter("base_color", Vector3(base.r, base.g, base.b))
	m.set_shader_parameter("px_per_meter", px)
	m.set_shader_parameter("groove_dark", 0.32)
	return m

func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	mi.position = pos

func _build_ground() -> void:
	var floor_mi := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60.0, 60.0)
	floor_mi.mesh = floor_mesh
	var floor_mat := _stone_mat(1.2, Color(0.17, 0.18, 0.24))
	floor_mat.set_shader_parameter("color_jitter", 0.15)  # 砖色差调低，避免伪装角色影子
	floor_mi.material_override = floor_mat
	add_child(floor_mi)

	# 双方各一座低台
	var dais_mat := _stone_mat(0.45, Color(0.2, 0.2, 0.27), 24.0)
	for cfg in HEROES:
		var dais := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 1.3
		dm.bottom_radius = 1.5
		dm.height = 0.3
		dais.mesh = dm
		dais.material_override = dais_mat
		add_child(dais)
		dais.position = Vector3(cfg["x"], 0.15, 0.0)

func _build_temple() -> void:
	# 月光下的大理石：偏亮冷灰
	var marble := _stone_mat(0.6, Color(0.42, 0.44, 0.55))
	var z := -10.5
	# 三级台基
	_add_box(Vector3(16.0, 0.4, 8.0), Vector3(0.0, 0.2, z - 2.0), marble)
	_add_box(Vector3(15.0, 0.4, 7.2), Vector3(0.0, 0.6, z - 2.0), marble)
	_add_box(Vector3(14.0, 0.4, 6.4), Vector3(0.0, 1.0, z - 2.0), marble)
	# 前排 8 根立柱
	for i in 8:
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.36
		cm.height = 3.8
		col.mesh = cm
		col.material_override = marble
		add_child(col)
		col.position = Vector3(-5.25 + 1.5 * float(i), 1.2 + 1.9, z)
	# 内殿墙体：压暗 + 拉远，和亮柱拉开层次（否则糊成一面平墙）
	_add_box(Vector3(11.0, 4.2, 4.0), Vector3(0.0, 1.2 + 2.1, z - 3.5),
		_stone_mat(0.8, Color(0.1, 0.11, 0.16)))
	# 檐部 + 三角山花
	_add_box(Vector3(13.0, 0.7, 1.2), Vector3(0.0, 5.35, z), marble)
	var ped := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(13.0, 1.9, 1.2)
	ped.mesh = pm
	ped.material_override = marble
	add_child(ped)
	ped.position = Vector3(0.0, 5.7 + 0.95, z)

func _build_moon() -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.8, 3.8)
	mi.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = load(MOON_SHADER)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(6.5, 12.0, -24.0)  # 与月光方向一致，山花斜脊上方

# --------------------------------------------------------------------- heroes

func _build_heroes() -> void:
	for cfg: Dictionary in HEROES:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(HERO_SIZE, HERO_SIZE)
		mi.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = load(SPRITE_SHADER)
		mat.set_shader_parameter("tex_albedo", load(cfg["sheet"]))
		var uv: Vector2 = cfg["uv"]
		var flip: bool = cfg["flip"]
		mat.set_shader_parameter("frame_scale",
			Vector2(-uv.x if flip else uv.x, uv.y))
		mat.set_shader_parameter("flip_sign", -1.0 if flip else 1.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		mi.position = Vector3(cfg["x"], 0.3 + HERO_SIZE * 0.38, 0.0)
		_hero_mats.append(mat)

# ----------------------------------------------------------------------- dust

func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 7.0
	p.preprocess = 7.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 2.8, 5.0)
	pm.gravity = Vector3(0.0, 0.02, 0.0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.16
	pm.direction = Vector3(0.3, 0.1, 0.0)
	pm.spread = 180.0
	p.process_material = pm
	var dm := QuadMesh.new()
	dm.size = Vector2(0.035, 0.035)
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.emission_enabled = true
	dmat.emission = Color(0.82, 0.86, 1.0)  # 月夜冷色尘埃
	dmat.emission_energy_multiplier = 1.4
	dmat.albedo_color = Color(0.9, 0.93, 1.0, 0.65)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	add_child(p)
	p.position = Vector3(0.0, 2.0, 0.0)

# --------------------------------------------------------------------- camera

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 36.0
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 14.0
	attrs.dof_blur_far_transition = 10.0
	attrs.dof_blur_amount = 0.05
	cam.attributes = attrs
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 3.0, 8.8), Vector3(0.0, 2.9, -4.0))
	cam.current = true

# ----------------------------------------------------------------- screenshot

func _screenshot_and_quit() -> void:
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://prototypes/hd2d/screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/acropolis.png")
	# 地面裁切：检查影子数量
	var w := img.get_width()
	var h := img.get_height()
	var crop := img.get_region(Rect2i(w / 2 - 420, h / 2, 840, h / 2))
	crop.save_png(dir + "/acropolis_ground.png")
	get_tree().quit()
