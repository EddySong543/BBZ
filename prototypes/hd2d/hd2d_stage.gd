extends Node3D
## HD-2D 创意原型（一次性，prototypes/ 隔离，不依赖 src/）。
## 验证目标：光照（月光+火把+伪光照立绘）与纵深感（立柱透视+雾+景深+尘埃）。
## 直接运行本场景即可观看；截图模式（自动存图并退出）：
##   godot --path . --resolution 1280x720 res://prototypes/hd2d/hd2d_stage.tscn -- --screenshot

const HERO_SHEET := "res://assets/sprites/heroes/h38/h38_idle.png"
const SPRITE_SHADER := "res://prototypes/hd2d/shaders/hd2d_sprite.gdshader"
const STONE_SHADER := "res://prototypes/hd2d/shaders/pixel_stone.gdshader"
const FLAME_SHADER := "res://prototypes/hd2d/shaders/torch_flame.gdshader"

const FRAME_COUNT := 6
const FRAME_FPS := 8.0
const ATLAS_COLS := 4
const HERO_SIZE := 3.0  # 256px 帧 → 3m 见方的广告牌

var _hero_mat: ShaderMaterial
var _torch_lights: Array[OmniLight3D] = []
var _flicker_seeds: Array[float] = []
var _anim_time := 0.0

func _ready() -> void:
	_build_environment()
	_build_stage()
	_build_hero()
	_build_torches()
	_build_dust()
	_build_camera()
	if "--screenshot" in OS.get_cmdline_user_args():
		_screenshot_and_quit()

func _process(delta: float) -> void:
	_anim_time += delta
	# 立绘逐帧动画（图集 4 列 × 2 行）
	var idx := int(_anim_time * FRAME_FPS) % FRAME_COUNT
	@warning_ignore("integer_division")
	_hero_mat.set_shader_parameter("frame_offset",
		Vector2(float(idx % ATLAS_COLS) * 0.25, float(idx / ATLAS_COLS) * 0.5))
	# 火把闪烁（双正弦拍频，避免机械感）
	for i in _torch_lights.size():
		var s := _flicker_seeds[i]
		_torch_lights[i].light_energy = 2.2 \
			+ 0.45 * sin(_anim_time * 11.0 + s) * sin(_anim_time * 5.3 + s * 2.0)

# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.42)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.16)
	env.fog_density = 0.045
	env.glow_enabled = true
	env.glow_intensity = 0.55  # 4.6 默认 0.3，原型加强
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 月光：背右上方逆光，给立柱/英雄轮廓冷色 rim，投长影
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	add_child(moon)
	moon.look_at_from_position(Vector3(4.0, 8.0, -6.0), Vector3.ZERO)

# ---------------------------------------------------------------------- stage

func _stone_mat(tile: float, base: Color, px: float = 16.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(STONE_SHADER)
	m.set_shader_parameter("tile_size", tile)
	m.set_shader_parameter("base_color", Vector3(base.r, base.g, base.b))
	m.set_shader_parameter("px_per_meter", px)
	return m

func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	mi.position = pos

func _build_stage() -> void:
	# 地面
	var floor_mi := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 40.0)
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = _stone_mat(1.1, Color(0.15, 0.16, 0.21))
	add_child(floor_mi)

	# 英雄站立的圆形高台
	var plat := MeshInstance3D.new()
	var plat_mesh := CylinderMesh.new()
	plat_mesh.top_radius = 1.5
	plat_mesh.bottom_radius = 1.7
	plat_mesh.height = 0.35
	plat.mesh = plat_mesh
	plat.material_override = _stone_mat(0.45, Color(0.20, 0.20, 0.26), 24.0)
	add_child(plat)
	plat.position = Vector3(0.0, 0.175, 0.0)

	# 两列残破立柱，向远处退去制造透视纵深（高度参差）
	var pillar_mat := _stone_mat(0.55, Color(0.18, 0.19, 0.25))
	var heights: Array[float] = [4.6, 3.1, 4.2, 2.4, 3.8]
	for i in heights.size():
		var h := heights[i]
		var z := 1.8 - 2.6 * float(i)
		_add_box(Vector3(0.9, h, 0.9), Vector3(-3.4, h * 0.5, z), pillar_mat)
		var h2 := heights[heights.size() - 1 - i]
		_add_box(Vector3(0.9, h2, 0.9), Vector3(3.4, h2 * 0.5, z), pillar_mat)
		# 柱础
		_add_box(Vector3(1.2, 0.3, 1.2), Vector3(-3.4, 0.15, z), pillar_mat)
		_add_box(Vector3(1.2, 0.3, 1.2), Vector3(3.4, 0.15, z), pillar_mat)

# ----------------------------------------------------------------------- hero

func _build_hero() -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(HERO_SIZE, HERO_SIZE)
	mi.mesh = quad
	_hero_mat = ShaderMaterial.new()
	_hero_mat.shader = load(SPRITE_SHADER)
	_hero_mat.set_shader_parameter("tex_albedo", load(HERO_SHEET))
	mi.material_override = _hero_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	# 高台顶 0.35，帧内角色脚底约在帧高 88% 处 → 中心抬升补偿
	mi.position = Vector3(0.0, 0.35 + HERO_SIZE * 0.38, 0.0)
	# 正面柔补光：保证立绘可读（月光是逆光、火把是侧暖光）
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.85, 0.88, 1.0)
	fill.light_energy = 0.9
	fill.omni_range = 5.5
	add_child(fill)
	fill.position = Vector3(0.0, 2.6, 3.2)

# --------------------------------------------------------------------- torches

func _build_torches() -> void:
	var pole_mat := _stone_mat(0.3, Color(0.13, 0.12, 0.13), 24.0)
	for sx: float in [-2.1, 2.1]:
		var pos := Vector3(sx, 0.0, 1.6)
		# 火把杆
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.09
		pole_mesh.height = 1.7
		pole.mesh = pole_mesh
		pole.material_override = pole_mat
		add_child(pole)
		pole.position = pos + Vector3(0.0, 0.85, 0.0)
		# 火苗广告牌
		var flame := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(0.6, 0.85)
		flame.mesh = fq
		var fm := ShaderMaterial.new()
		fm.shader = load(FLAME_SHADER)
		flame.material_override = fm
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		flame.position = pos + Vector3(0.0, 1.95, 0.0)
		# 暖色点光
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.68, 0.42)
		lt.light_energy = 2.2
		lt.omni_range = 8.0
		lt.omni_attenuation = 1.4
		lt.shadow_enabled = true
		add_child(lt)
		lt.position = pos + Vector3(0.0, 2.0, 0.0)
		_torch_lights.append(lt)
		_flicker_seeds.append(absf(sx) + sx * 1.7)

# ----------------------------------------------------------------------- dust

func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 7.0
	p.preprocess = 7.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5.0, 2.5, 5.0)
	pm.gravity = Vector3(0.0, 0.02, 0.0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.18
	pm.direction = Vector3(0.3, 0.1, 0.0)
	pm.spread = 180.0
	p.process_material = pm
	var dm := QuadMesh.new()
	dm.size = Vector2(0.035, 0.035)
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.emission_enabled = true
	dmat.emission = Color(1.0, 0.85, 0.6)
	dmat.emission_energy_multiplier = 1.6
	dmat.albedo_color = Color(1.0, 0.9, 0.7, 0.7)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	add_child(p)
	p.position = Vector3(0.0, 2.0, -1.0)

# --------------------------------------------------------------------- camera

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 32.0
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 9.0
	attrs.dof_blur_far_transition = 6.0
	attrs.dof_blur_amount = 0.12
	cam.attributes = attrs
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.7, 6.6), Vector3(0.0, 1.45, 0.0))
	cam.current = true

# ----------------------------------------------------------------- screenshot

func _screenshot_and_quit() -> void:
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://prototypes/hd2d/screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/shot.png")
	# 主角特写裁切（检查立绘光照细节用）
	var w := img.get_width()
	var h := img.get_height()
	var crop := img.get_region(Rect2i(w / 2 - 200, h / 6, 400, h * 2 / 3))
	crop.save_png(dir + "/shot_hero.png")
	get_tree().quit()
