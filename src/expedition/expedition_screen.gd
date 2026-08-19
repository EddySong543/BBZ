## 远征模式主界面 —— 全屏大地图探索（2026-07-07 Eddy 定形态重构）。
##
## 流程：进入 → 选初始英雄（浮层）→ 进图（选地图步骤=待世界观拍板后加）。
## 形态：全屏=地图本身（⛔背景/衬底），进图后不显示旧四角调试 HUD，
## 背包=按 B 唤出的整理浮层（背包格+拾取区+装备栏+保险槽同屏整理），
## 玩家=所选英雄的 idle 像素人物 token 在高密度全屏格视窗中探索（柔和跟随·逐格起伏·驻足轻摆）。
## 设计规范：design/ui-design-system.md（全暖色系·暖骨框·Ark Pixel·⛔夜色衬底）。
## 规则源：design/expedition-map.md / expedition-backpack.md。逻辑层 = expedition_map_state / expedition_backpack_state。
##
## 操作：WASD/方向键移动 ｜ E/F 互动 ｜ B 背包浮层 ｜ 浮层内：左键拾/放·R 旋转·右键放回·U 用消耗品·X 丢弃 ｜ ESC 关浮层/返回。
extends Control

signal movement_finished(cell: Vector2i, completed: bool)

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const GridPathfinderScript := preload("res://src/expedition/grid_pathfinder.gd")
const QingfengLayout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")
const SearchState := preload("res://src/expedition/expedition_search_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")
const PixelArt := preload("res://src/expedition/expedition_pixel_art.gd")
const ItemCatalog := preload("res://src/battle/item_catalog.gd")
const HeroDataScript := preload("res://src/battle/hero_data.gd")   # class_name 在 headless 可能未注册→走 preload
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const TERRAIN_SHADER := preload("res://assets/shaders/canvas_ui_expedition_terrain.gdshader")
const GROUND_CELL_SHADER := preload("res://assets/shaders/canvas_ui_expedition_ground_cell.gdshader")
const ATMOSPHERE_SHADER := preload("res://assets/shaders/canvas_ui_qingfeng_atmosphere.gdshader")
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")           # 按钮果冻底（与战斗/道具弹窗同语言）
const ITEM_CELL_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")    # 道具格底（与 PvP 道具格同源·圆角径向渐变）
const GOLDEN_WAVE_GROUND_TEXTURE := preload("res://assets/tilesets/qingfeng_ricefield/golden_wave_ground_v1.png")
const QINGFENG_VISUAL_MAP_SCENE := preload("res://src/expedition/maps/qingfeng_ricefield_visual_map.tscn")

const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 布局（1920×1080·完整13×7视窗 / 32×18 晴风稻田）──
# 逻辑格仍为120px，屏幕显示为144px；奇数行列让静止镜头始终对齐完整格。
# 地图区1872×1008，四周留24/36px边距，不裁半格。
const MAP_CELL: int = 120
const MAP_VIEW_COLS: int = 13
const MAP_VIEW_ROWS: int = 7
const MAP_RENDER_SCALE: float = 1.2
const MAP_VIEW_SIZE := Vector2(
		MAP_VIEW_COLS * MAP_CELL, MAP_VIEW_ROWS * MAP_CELL) * MAP_RENDER_SCALE
const MAP_WORLD_SIZE := Vector2(MapState.WIDTH * MAP_CELL, MapState.HEIGHT * MAP_CELL)
const MAP_VIEW_WORLD_SIZE := MAP_VIEW_SIZE / MAP_RENDER_SCALE
const MAP_VIEW_ORIGIN := Vector2(24, 36)
# h01 原图双脚是全部 idle 资产的公共骨架基准：左脚(116.5,182)、右脚(139.5,182)。
# 所有英雄使用同一原图缩放和同一坐标变换，不再被武器、披风或透明轮廓改变大小/锚点。
const H01_SOURCE_LEFT_FOOT := Vector2(116.5, 182.0)
const H01_SOURCE_RIGHT_FOOT := Vector2(139.5, 182.0)
const H01_SOURCE_FOOT_MIDPOINT := Vector2(128.0, 182.0)
const TOKEN_CONTENT_SCALE: float = 1.125
const TOKEN_SIZE := Vector2(208, 208)
const TOKEN_FOOT_ANCHOR := Vector2(104, 156)
# 落脚线从格底上移到格内75%高度，人物站在格子内部而不是贴住下边。
const TOKEN_CELL_FOOT_POINT := Vector2(60, 90)
const TOKEN_OFFSET := TOKEN_CELL_FOOT_POINT - TOKEN_FOOT_ANCHOR
const TOKEN_RENDER_COMPENSATION: float = 1.0
const TOKEN_IDLE_BASE_FPS: float = 8.0
const TOKEN_IDLE_REF_FRAMES: float = 6.0
const TOKEN_STEP_LOGICAL_PX: float = 5.0
const TOKEN_STEP_HOP_STEPS: float = 2.0
const TOKEN_STEP_WOBBLE_AMPLITUDE: float = 0.026
const TOKEN_TURN_SWITCH_PROGRESS: float = 0.38
const TOKEN_TURN_SQUEEZE_MIN: float = 0.82
const TOKEN_TURN_SCALE_STEP: float = 0.05
# 镜头与 token 共用这一份连续视觉坐标；临界阻尼不会过冲，连续输入也不会重启两条 Tween。
const CAMERA_CRITICAL_DAMPING: float = 18.0
const CAMERA_MAX_STEP: float = 1.0 / 20.0
const CAMERA_SNAP_DISTANCE: float = 0.05
# 镜头只在32×18真实逻辑地图范围内移动，不以不可交互浓雾假格补边。
const CAMERA_FOG_PADDING_COLS: int = 0
const CAMERA_FOG_PADDING_ROWS: int = 0
# 背包浮层（居中·B 唤出）
const OV_PANEL := Rect2(340, 110, 1240, 860)
const BP_ORIGIN := Vector2(400, 240)
const BP_CELL: int = 52
# 选英雄浮层
const SEL_PANEL := Rect2(440, 140, 1040, 800)

# ── 色板（§2 令牌：暖骨框 / 暖米白字 / 语义色·全暖色系=Eddy 定·⛔夜色衬底）──
const COL_BG := Color("0b1c18")            # 选人/浮层之外的兜底色；进图后由16×9地图完全覆盖
const COL_PANEL := Color("241c12")         # 暖色深底面板
const COL_TEXT := Color(0.95, 0.91, 0.80)  # 暖米白（禁纯白）
const COL_TEXT_DIM := Color(0.72, 0.68, 0.58)
const COL_FLOOR := Color("2e2417")         # 地表/迷雾全色板已入 terrain shader uniform 默认值
const COL_MONSTER := Color("d24a44")       # 阵营红系（角宝石红）
const COL_EVENT := Color("9b86d8")         # 干扰紫提亮档
const COL_CHEST := Color("dca12e")         # 传说金
const COL_EXT_OPEN := Color("5cb863")      # 确认绿
const COL_EXT_CLOSED := Color("8a8f98")    # 随机灰
const COL_PLAYER := Color("f2e08a")        # 亮金
const COL_BONE := Color("b3a386")          # 暖骨
const COL_GOLD_ITEM := Color("b08a3a")
const COL_COMBAT_ITEM := Color("4a7bc0")   # 普通蓝（稀有度语义）
const COL_CONSUM_ITEM := Color("4f9d52")   # 状态绿
const COL_RARE_ITEM := Color("8a4fc4")     # 稀有紫
const COL_OK := Color(0.4, 0.9, 0.5, 0.55)
const COL_BAD := Color(0.95, 0.35, 0.3, 0.55)
const GROUND_GRASS_DARK_INDEX: int = 0
const GROUND_GRASS_LIGHT_INDEX: int = 1
const GROUND_DIRT_INDEX: int = 2
const GROUND_RICE_INDEX: int = 3
const GROUND_GRASS_DARK_TINT := Color("c4d0b7")
const GROUND_GRASS_LIGHT_TINT := Color.WHITE
const GROUND_FILL_GRASS_DARK := Color("5f852c")
const GROUND_FILL_GRASS_LIGHT := Color("7ba33e")
const GROUND_FILL_DIRT := Color("df9f3e")
const GROUND_FILL_RICE := Color("d8a52c")
const GROUND_CELL_GAP: float = 0.0
const GROUND_GAP_COLOR := Color("203a33")
const GROUND_BORDER_PX: float = 2.0
const GROUND_MASK_INSET_PX: float = 1.0
const GROUND_CORNER_RADIUS_PX: float = 16.0
const GROUND_PIXEL_STEP_PX: float = 4.0
const GROUND_BORDER_COLOR := Color("3b5233")
const TELEPORT_GLOW_COLOR := Color("ffd85a")
const TELEPORT_GLOW_CORE := Color("fff0a4")
const TELEPORT_BREATH_SPEED: float = 2.2
const WHEAT_WAVE_DURATION: float = 0.72
const WHEAT_WAVE_RING_DELAY: float = 0.09
const WHEAT_WAVE_RADIUS: int = 3
const WHEAT_WAVE_SOURCE_PIXEL_STEP: int = 2
const WHEAT_WAVE_MAX_SHIFT_STEPS: int = 3
const WHEAT_WAVE_SHIFT_PATTERNS: Array = [
	[0, 0, 0, 0, 0, 0, 0, 0],
	[0, 1, 1, 0, -1, -1, 0, 0],
	[0, 1, 2, 3, 2, 0, -1, -2],
	[2, 3, 2, 0, -2, -3, -2, 0],
	[1, 0, -1, -2, -1, 0, 1, 1],
	[0, 0, 0, 0, 0, 0, 0, 0],
]
const STONE_OBJECT_INSET: float = 10.0
const WHEAT_OBJECT_INSET := Vector2(2.0, 8.0)
const FOG_EXTENSION_SEAM := Color("0b1c18")
const FOG_EXTENSION_FACE := Color("264638")
const FOG_EXTENSION_VEIL := Color(0.025, 0.075, 0.065, 0.78)
const FOG_EXTENSION_SEAM_PX: float = 2.0
const PLAYER_SHADOW_BASE_WIDTH: float = 62.0
const PLAYER_SHADOW_MIN_WIDTH: float = 42.0
const PLAYER_SHADOW_MAIN_COLOR := Color(0.025, 0.070, 0.050, 0.46)
const LIMITED_VISIBILITY_ENABLED: bool = false

var map: MapState
var bp: Backpack
var search_state: SearchState
var open_container_cell: Vector2i = Vector2i(-1, -1)
var pending: Array = []            # 拾取区（待拼放·撤离不计入）
var held: Dictionary = {}          # {item, shape} 手上物品
var log_lines: Array = []
var seed_value: int = 0
var mouse_pos: Vector2
var pending_flee_from: Vector2i
var hero_portrait_path: String = ""   # 仅作旧存档兜底；地图人物正式使用 idle SpriteFrames
var hero_idle_frames_path: String = "" # 初始英雄 idle 帧资源（token 用·跨战斗寄存恢复）

## 默认使用带地图边界夹紧的平滑镜头；关闭后仍可切回固定取景。
@export var camera_follow_enabled: bool = true:
	set(value):
		if camera_follow_enabled == value:
			return
		camera_follow_enabled = value
		_camera_initialized = false
		_camera_visual_velocity = Vector2.ZERO
		if map != null and map_world != null and player_token != null:
			_update_map_camera()

var pend_box: VBoxContainer
var equip_box: VBoxContainer
var insure_btn: Button
var dialog: PopupPanel
var dialog_box: VBoxContainer
var bp_overlay: Control            # 背包整理浮层（B 唤出）
var bp_cells: Control              # 背包格底容器（PvP 道具格同源 shader·扩容时重建）
var _cell_mat: ShaderMaterial      # 格底共享材质（全格同参·一份即可）
var select_overlay: Control        # 选初始英雄浮层（进图前）
var test_controls: Control         # 屏幕空间美术测试按钮，不随地图镜头移动
var test_next_hero_button: Button
var player_backdrop: Control       # 人物脚底粗像素接触影；不参与跳步
var player_token: TextureRect      # 英雄 idle 帧 token；静止时不叠加代码摇摆
var teleport_fx: Control           # 传送点占用态前景动效；必须压在角色之上才不会被头像遮住
var map_view: Control              # 屏幕空间精确13×7完整正方形格裁切窗口
var map_world: Control             # 32×18 世界容器；由镜头在完整格视窗内跟随
var ground_art: Control            # 地表：草地、泥土
var visual_map: Node2D             # Godot 2D面板可直接刷格的分层地图；Ground作为运行时美术数据源
var visual_ground: TileMapLayer
var ground_cell_mat: ShaderMaterial # 统一格体：方形资产在运行时裁成Ref37/Ref39像素圆角
var foliage_art: Control           # 物体子层：草地上独立金色稻穗（后续可单独做拨动/摆动）
var field_chaff: GPUParticles2D     # 大型金色稻壳/断叶，位于麦穗之上、搜索物之下
var object_art: Control            # 物体：田界、搜索容器
var atmosphere_layer: ColorRect    # 当前视野内的斜向日照与缓慢云影
var atmosphere_mat: ShaderMaterial
var marker_art: Control            # 标识：搜索目标等运行时状态
var canvas: Control                # 世界空间地图图签画布
var bp_canvas: Control             # 屏幕空间背包物品/手持幽灵画布

# ── 地形层（数据纹理驱动·地表/迷雾/揭示全在 shader）──
var fx_layer: Control              # 地图动效层（飘字/格闪·压 token 之上·G 任务）
var terrain_mat: ShaderMaterial
var _terrain_img: Image            # WIDTH×HEIGHT RGBAF（R=地形类 G=当前可见 B=进入视野时刻）
var _terrain_tex: ImageTexture
var _reveal_time: Dictionary = {}  # Vector2i -> float 进入当前视野的时刻（离开后擦除）
var _anim_time: float = 0.0        # shader/token 统一时钟
var _camera_initialized: bool = false
var _camera_visual_token_origin: Vector2 = Vector2.ZERO
var _camera_target_token_origin: Vector2 = Vector2.ZERO
var _camera_visual_velocity: Vector2 = Vector2.ZERO
var _token_step_active: bool = false
var _token_step_start_origin: Vector2 = Vector2.ZERO
var _token_step_target_origin: Vector2 = Vector2.ZERO
var _token_step_direction: Vector2 = Vector2.ZERO
var _token_step_side: float = 1.0
var _player_facing_sign: float = 1.0
var _token_turn_from_sign: float = 1.0
var _token_turn_target_sign: float = 1.0
var _token_turn_active: bool = false
var _queued_move_direction: Vector2i = Vector2i.ZERO
var _movement_generation: int = 0
var _click_route_active: bool = false
var _wheat_wave_pulses: Array[Dictionary] = []
var _wheat_wave_runtime_frames: Array[Texture2D] = []
var _hero_idle_frames: SpriteFrames
var _hero_idle_token_frames: Array[Texture2D] = []
var _test_hero_index: int = -1


func _ready() -> void:
	seed_value = randi() % 1000000
	_build_wheat_wave_runtime_frames()
	_build_ui()
	if not BattleSetup.expedition_state.is_empty():
		_resume_from_battle()   # 真战斗打完回图（任务 D）
	else:
		select_overlay.visible = true   # 正常入口：先选初始英雄


## 真战斗回图（任务 D·2026-07-06）：恢复跨场景寄存的跑动状态 + 消费战斗结果回写地图。
func _resume_from_battle() -> void:
	_cancel_click_route()
	var st: Dictionary = BattleSetup.expedition_state
	BattleSetup.expedition_state = {}
	map = st["map"]
	bp = st["bp"]
	search_state = st.get("search_state", SearchState.new())
	open_container_cell = Vector2i(st.get("open_container_cell", Vector2i(-1, -1)))
	pending = st["pending"]
	log_lines = st["log"]
	seed_value = int(st["seed"])
	hero_portrait_path = String(st.get("hero_portrait", ""))
	hero_idle_frames_path = String(st.get("hero_idle_frames", ""))
	held = {}
	_reveal_time.clear()   # 战斗回图：当前视野不重播翻显动画
	for c: Vector2i in map.visible:
		_reveal_time[c] = -10.0
	terrain_mat.set_shader_parameter("seed_f", float(seed_value % 977))
	_apply_token_idle_art()
	_set_player_visual_visible(true)
	_set_atmosphere_active(true)
	var r: Dictionary = BattleSetup.pve_result
	BattleSetup.pve_result = {}
	if r.is_empty():
		_log("战斗结果缺失——本次遭遇作废（防御兜底）。")
		_refresh()
		return
	var res: Dictionary = map.apply_battle_result(
		Vector2i(st["tile"]),
		String(r["outcome"]),
		int(r["beats"]),
		r["team_hp"],
		r.get("opponent_hp", []),
		Vector2i(st["flee_from"]))
	match String(r["outcome"]):
		"win":
			pending.append_array(res["loot"])
			_log("战斗胜利（%d 拍·+%.1f 刻）！掉落 → 拾取区：%s" % [int(r["beats"]), float(int(r["beats"])) * 0.5, _loot_text(res["loot"])])
			_float_text(map.player, "胜利！战利品 ×%d" % (res["loot"] as Array).size(), COL_CHEST)
		"flee":
			_log("成功脱离战斗；遭遇留在原格并保留敌方状态。")
			_float_text(map.player, "成功脱离", Color("ff9442"))
		"lose":
			_log("队伍在战斗中全灭……")
	if map.over:
		_show_settlement()
	_refresh()


# ============================================================
# UI 构建（玩家跟随地图视窗 + 背包/选英雄浮层）
# ============================================================

func _build_ui() -> void:
	_build_map_view()
	_build_test_controls()
	_build_backpack_overlay()
	_build_select_overlay()
	dialog = PopupPanel.new()
	dialog.exclusive = true   # 点外部不可关——防"死亡结算被点掉→movement 封锁看似卡死"
	var sb := StyleBoxFlat.new()   # 弹窗底=暖色深底+暖骨描边（D 任务·对齐 §2.1 语言）
	sb.bg_color = COL_PANEL
	sb.border_color = COL_BONE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	dialog.add_theme_stylebox_override("panel", sb)
	dialog_box = VBoxContainer.new()
	dialog_box.custom_minimum_size = Vector2(560, 0)
	dialog_box.add_theme_constant_override("separation", 10)
	dialog.add_child(dialog_box)
	add_child(dialog)


func _build_map_view() -> void:
	map_view = Control.new()
	map_view.name = "MapView"
	map_view.position = MAP_VIEW_ORIGIN
	map_view.size = MAP_VIEW_SIZE
	map_view.clip_contents = true
	# PASS 让背包开启时未被地图接受的点击继续交给根节点既有整理逻辑。
	map_view.mouse_filter = Control.MOUSE_FILTER_PASS
	map_view.gui_input.connect(_on_map_view_gui_input)
	add_child(map_view)

	map_world = Control.new()
	map_world.name = "MapWorld"
	map_world.size = MAP_WORLD_SIZE
	map_world.scale = Vector2.ONE * MAP_RENDER_SCALE
	map_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(map_world)

	ground_art = _make_map_art_layer("GroundArtLayer", _draw_ground_art)
	ground_cell_mat = ShaderMaterial.new()
	ground_cell_mat.shader = GROUND_CELL_SHADER
	ground_cell_mat.set_shader_parameter("cell_px", float(MAP_CELL))
	ground_cell_mat.set_shader_parameter("cell_inset_px", GROUND_MASK_INSET_PX)
	ground_cell_mat.set_shader_parameter("corner_radius_px", GROUND_CORNER_RADIUS_PX)
	ground_cell_mat.set_shader_parameter("pixel_step_px", GROUND_PIXEL_STEP_PX)
	ground_cell_mat.set_shader_parameter("border_px", GROUND_BORDER_PX)
	ground_cell_mat.set_shader_parameter("gap_color", GROUND_GAP_COLOR)
	ground_cell_mat.set_shader_parameter("border_color", GROUND_BORDER_COLOR)
	ground_art.material = ground_cell_mat
	visual_map = QINGFENG_VISUAL_MAP_SCENE.instantiate() as Node2D
	visual_map.name = "QingfengVisualMap"
	map_world.add_child(visual_map)
	visual_ground = visual_map.get_node("Ground") as TileMapLayer
	visual_ground.visible = false
	_take_visual_map_layer("GroundDetail")
	foliage_art = _make_map_art_layer("RiceFoliageLayer", _draw_rice_foliage)
	_take_visual_map_layer("LowDecoration")
	object_art = _make_map_art_layer("ObjectArtLayer", _draw_object_art)
	_take_visual_map_layer("BlockingObjects")
	_take_visual_map_layer("Containers")
	# 柔边迷雾位于物体层上方，让边缘格中的麦穗与搜索目标一起渐隐。
	# 物体仍只在 map.visible 中绘制，不会借半透明边缘泄露远处目标。
	_make_terrain_layer()
	_build_atmosphere_layer()
	marker_art = _make_map_art_layer("MarkerArtLayer", _draw_marker_art)
	var marker_guides := visual_map.get_node_or_null("MarkerGuides") as TileMapLayer
	if marker_guides != null:
		marker_guides.visible = false
	canvas = Control.new()
	canvas.name = "DrawCanvas"
	canvas.size = MAP_WORLD_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_canvas)
	map_world.add_child(canvas)
	player_backdrop = Control.new()
	player_backdrop.name = "PlayerBackdrop"
	player_backdrop.size = Vector2.ONE * MAP_CELL
	player_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_backdrop.visible = false
	player_backdrop.draw.connect(_draw_player_backdrop)
	map_world.add_child(player_backdrop)
	# 英雄 idle token（逐帧播放）：pivot 设脚底中心；静止时不再叠加代码旋转。
	# 脚底影由上方独立节点绘制，token 不套用整格头像底框。
	player_token = TextureRect.new()
	player_token.name = "PlayerToken"
	player_token.size = TOKEN_SIZE
	player_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_token.pivot_offset = TOKEN_FOOT_ANCHOR
	player_token.scale = Vector2.ONE * TOKEN_RENDER_COMPENSATION
	player_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_token.visible = false   # 进图（_new_run）才现身
	map_world.add_child(player_token)
	# 兼容旧预览探针保留节点引用；占用态四角巡游效果已停用。
	teleport_fx = _make_map_art_layer("TeleportOccupiedFxLayer", _draw_teleport_occupied_fx)
	teleport_fx.visible = false
	# 地图动效层（G 任务）：飘字/格闪都挂这里·IGNORE 不吞点击·清场随 _new_run
	fx_layer = Control.new()
	fx_layer.name = "MapFxLayer"
	fx_layer.size = MAP_WORLD_SIZE
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(fx_layer)
	_sync_atmosphere_to_camera()


## The authored visual-map scene stays editable as one scene, while runtime
## reparents its visible object layers into the established fog-safe draw order.
func _take_visual_map_layer(layer_name: String) -> TileMapLayer:
	var layer := visual_map.get_node_or_null(layer_name) as TileMapLayer
	if layer == null:
		return null
	layer.reparent(map_world)
	layer.z_index = 0
	return layer


## 三层地图美术：地表可复用，物体可替换，标识由状态驱动。
## 迷雾位于地表和可交互物之间；物体/标识仅在探明后绘制，避免透过半透明迷雾泄露。
func _make_map_art_layer(layer_name: String, draw_callback: Callable) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.size = MAP_WORLD_SIZE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(draw_callback)
	map_world.add_child(layer)
	return layer


## 正式地形资产上方的迷雾遮罩：数据纹理只控制探明与全屏光影，地表始终可辨。
func _make_terrain_layer() -> void:
	var t := ColorRect.new()
	t.name = "TerrainLayer"
	t.size = MAP_WORLD_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_img = Image.create(MapState.WIDTH, MapState.HEIGHT, false, Image.FORMAT_RGBAF)
	_terrain_tex = ImageTexture.create_from_image(_terrain_img)
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	terrain_mat.set_shader_parameter("map_data", _terrain_tex)
	terrain_mat.set_shader_parameter("grid_size", Vector2(MapState.WIDTH, MapState.HEIGHT))
	terrain_mat.set_shader_parameter("cell_px", float(MAP_CELL))
	terrain_mat.set_shader_parameter(
			"vision_center_cell", Vector2(MapState.WIDTH, MapState.HEIGHT) * 0.5)
	terrain_mat.set_shader_parameter(
			"vision_logic_center_cell", Vector2(MapState.WIDTH, MapState.HEIGHT) * 0.5)
	terrain_mat.set_shader_parameter("vision_half_extent_cells", Vector2(
			MapState.PLAYER_VISION_HALF_WIDTH, MapState.PLAYER_VISION_HALF_HEIGHT))
	terrain_mat.set_shader_parameter("vision_feather_cells", 0.28)
	t.material = terrain_mat
	map_world.add_child(t)


## 大型稻壳粒子：1个粒子系统、4帧硬像素图集，保持在物体与角色下方。
func _build_field_chaff() -> void:
	field_chaff = GPUParticles2D.new()
	field_chaff.name = "FieldChaff"
	field_chaff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field_chaff.amount = 9
	field_chaff.lifetime = 12.0
	field_chaff.preprocess = 12.0
	field_chaff.randomness = 0.86
	field_chaff.explosiveness = 0.08
	field_chaff.local_coords = true
	field_chaff.fixed_fps = 24
	field_chaff.texture = null
	field_chaff.visibility_rect = Rect2(-MAP_VIEW_SIZE * 0.68, MAP_VIEW_SIZE * 1.36)
	field_chaff.emitting = false

	var atlas_material := CanvasItemMaterial.new()
	atlas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	atlas_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	atlas_material.particles_animation = true
	atlas_material.particles_anim_h_frames = 4
	atlas_material.particles_anim_v_frames = 1
	atlas_material.particles_anim_loop = true
	field_chaff.material = atlas_material

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(MAP_VIEW_SIZE.x * 0.58, MAP_VIEW_SIZE.y * 0.58, 1.0)
	process_material.direction = Vector3(1.0, -0.16, 0.0)
	process_material.spread = 16.0
	process_material.initial_velocity_min = 30.0
	process_material.initial_velocity_max = 48.0
	process_material.gravity = Vector3(2.0, 5.0, 0.0)
	process_material.scale_min = 1.65
	process_material.scale_max = 2.7
	process_material.angle_min = -35.0
	process_material.angle_max = 35.0
	process_material.angular_velocity_min = -18.0
	process_material.angular_velocity_max = 18.0
	process_material.anim_speed_min = 0.35
	process_material.anim_speed_max = 0.72
	process_material.anim_offset_min = 0.0
	process_material.anim_offset_max = 1.0
	var life_gradient := Gradient.new()
	life_gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.78, 1.0])
	life_gradient.colors = PackedColorArray([
		Color(1.0, 0.78, 0.24, 0.0),
		Color(1.0, 0.78, 0.24, 0.72),
		Color(0.94, 0.63, 0.12, 0.62),
		Color(0.88, 0.50, 0.06, 0.0),
	])
	var life_ramp := GradientTexture1D.new()
	life_ramp.gradient = life_gradient
	process_material.color_ramp = life_ramp
	field_chaff.process_material = process_material
	map_world.add_child(field_chaff)


## 光影层抵消相机位移，始终覆盖整屏；shader自行按当前视野裁掉迷雾区域。
func _build_atmosphere_layer() -> void:
	atmosphere_layer = ColorRect.new()
	atmosphere_layer.name = "AtmosphereLayer"
	atmosphere_layer.size = MAP_VIEW_WORLD_SIZE
	atmosphere_layer.color = Color.WHITE
	atmosphere_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atmosphere_layer.visible = false
	atmosphere_mat = ShaderMaterial.new()
	atmosphere_mat.shader = ATMOSPHERE_SHADER
	atmosphere_mat.set_shader_parameter("map_data", _terrain_tex)
	atmosphere_mat.set_shader_parameter("grid_size", Vector2(MapState.WIDTH, MapState.HEIGHT))
	atmosphere_mat.set_shader_parameter("view_size_px", MAP_VIEW_WORLD_SIZE)
	atmosphere_mat.set_shader_parameter("cell_px", float(MAP_CELL))
	atmosphere_layer.material = atmosphere_mat
	map_world.add_child(atmosphere_layer)


func _set_atmosphere_active(active: bool) -> void:
	if field_chaff != null:
		field_chaff.emitting = active
		field_chaff.visible = active
	if atmosphere_layer != null:
		atmosphere_layer.visible = active


func _sync_atmosphere_to_camera() -> void:
	if map_world == null:
		return
	var camera_world_origin: Vector2 = -map_world.position / MAP_RENDER_SCALE
	if field_chaff != null:
		field_chaff.position = camera_world_origin + MAP_VIEW_WORLD_SIZE * 0.5
	if atmosphere_layer != null:
		atmosphere_layer.position = camera_world_origin
	if atmosphere_mat != null:
		atmosphere_mat.set_shader_parameter("camera_world_origin_px", camera_world_origin)


## 背包整理浮层（B 唤出）：背包格 + 拾取区 + 装备栏 + 保险槽/扩容 同屏整理。默认隐藏。
func _build_backpack_overlay() -> void:
	bp_overlay = Control.new()
	bp_overlay.name = "BackpackOverlay"
	bp_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_overlay.visible = false
	add_child(bp_overlay)
	var dim := ColorRect.new()   # 半透暗幕（IGNORE·遮地图不吞点击——格子点击走根 _gui_input）
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.01, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_overlay.add_child(dim)
	_make_panel(OV_PANEL, bp_overlay)
	_label(OV_PANEL.position + Vector2(24, 16), 24, "整理行囊（B 关闭）", bp_overlay).modulate = COL_PLAYER
	_label(Vector2(BP_ORIGIN.x, OV_PANEL.position.y + 66), 16, "―― 背包（撤离只带走包里的）――", bp_overlay).modulate = COL_BONE
	bp_cells = Control.new()   # 格底容器（PvP 道具格同源 shader·_sync_bp_cells 填充）
	bp_cells.name = "BackpackCells"
	bp_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_overlay.add_child(bp_cells)
	insure_btn = _button(Vector2(BP_ORIGIN.x, 620), Vector2(320, 36), "", _on_insure_clicked, bp_overlay)
	_jelly_button(insure_btn, Color("6b5c43"))
	var grow_row := HBoxContainer.new()
	grow_row.position = Vector2(BP_ORIGIN.x, 668)
	bp_overlay.add_child(grow_row)
	for cfg: Array in [["扩容+1行", true], ["扩容+1列", false]]:
		var b := Button.new()
		b.text = String(cfg[0])
		b.custom_minimum_size = Vector2(150, 36)
		FontManager.apply_btn(b, 16)
		_jelly_button(b, Color("6b5c43"))
		var is_row: bool = bool(cfg[1])
		b.pressed.connect(func() -> void:
			var ok: bool = bp.expand_row() if is_row else bp.expand_col()
			_log("修补匠：扩容成功。" if ok else "背包已到 6×6 上限。")
			_refresh())
		grow_row.add_child(b)
	_label(Vector2(790, OV_PANEL.position.y + 66), 16, "―― 拾取区（点击拾起·不拼进包=带不走）――", bp_overlay).modulate = COL_BONE
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(790, OV_PANEL.position.y + 100)
	scroll.size = Vector2(380, OV_PANEL.size.y - 140)
	bp_overlay.add_child(scroll)
	pend_box = VBoxContainer.new()
	pend_box.custom_minimum_size = Vector2(356, 0)
	scroll.add_child(pend_box)
	_label(Vector2(1200, OV_PANEL.position.y + 66), 16, "―― 装备栏（战斗+效率·撤离不带出）――", bp_overlay).modulate = COL_BONE
	var equip_btn := _button(Vector2(1200, OV_PANEL.position.y + 100), Vector2(350, 36), "把手上的战斗道具装上", _on_equip_clicked, bp_overlay)
	_jelly_button(equip_btn, Color("3f6fb0"))   # 防御蓝=战斗道具语义
	equip_box = VBoxContainer.new()
	equip_box.position = Vector2(1200, OV_PANEL.position.y + 148)
	equip_box.custom_minimum_size = Vector2(350, 0)
	bp_overlay.add_child(equip_box)
	bp_canvas = Control.new()
	bp_canvas.name = "BackpackDrawCanvas"
	bp_canvas.position = Vector2.ZERO
	bp_canvas.size = Vector2(1920, 1080)
	bp_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_canvas.draw.connect(_draw_backpack_canvas)
	bp_overlay.add_child(bp_canvas)


## 选初始英雄浮层（进图前·地图选择步骤=世界观拍板后加）。
func _build_select_overlay() -> void:
	select_overlay = Control.new()
	select_overlay.name = "HeroSelectOverlay"
	select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_overlay.visible = false
	add_child(select_overlay)
	var dim := ColorRect.new()   # 全遮幕（STOP·选人前不许操作地图）
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.06, 0.04, 0.02, 0.92)
	select_overlay.add_child(dim)
	_make_panel(SEL_PANEL, select_overlay)
	_label(SEL_PANEL.position + Vector2(32, 24), 24, "选择初始英雄", select_overlay).modulate = COL_PLAYER
	_label(SEL_PANEL.position + Vector2(280, 34), 16, "它将带队踏入迷雾（篝火可再招募 2 名）", select_overlay).modulate = COL_TEXT_DIM
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = SEL_PANEL.position + Vector2(32, 84)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	select_overlay.add_child(grid)
	for h: HeroData in HeroDataScript.create_launch_pool():
		var b := Button.new()
		b.text = h.hero_name
		b.custom_minimum_size = Vector2(232, 100)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if h.portrait_path != "" and ResourceLoader.exists(h.portrait_path):
			b.icon = load(h.portrait_path)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 72)
		FontManager.apply_btn(b, 16)
		var hero: HeroData = h
		b.pressed.connect(func() -> void: _on_hero_selected(hero))
		grid.add_child(b)


## 当前阶段的屏幕空间测试入口；后续测试功能继续收纳在同一容器中。
func _build_test_controls() -> void:
	test_controls = Control.new()
	test_controls.name = "TestControls"
	test_controls.position = Vector2.ZERO
	test_controls.size = Vector2(1920, 1080)
	test_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	test_controls.visible = false
	add_child(test_controls)
	test_next_hero_button = _button(
			Vector2(1680, 26), Vector2(214, 42), "测试·下个角色",
			_on_test_next_hero_pressed, test_controls)
	test_next_hero_button.name = "NextHeroButton"
	_jelly_button(test_next_hero_button, Color("46644d"))


## 选定初始英雄 → 开局。idle 帧动画成为地图 token；完整 hero_id 与当前生命上限进入远征队伍。
func _on_hero_selected(h: HeroData) -> void:
	hero_portrait_path = h.portrait_path
	hero_idle_frames_path = h.sprite_frames_path
	_test_hero_index = _hero_index_by_id(h.hero_id)
	select_overlay.visible = false
	_apply_token_idle_art()
	_new_run(seed_value, h)


## 只替换地图人物的美术预览，不重置地图、队伍或远征进度。
func _on_test_next_hero_pressed() -> void:
	if map == null:
		return
	var pool: Array[HeroData] = HeroDataScript.create_launch_pool()
	if pool.is_empty():
		return
	if _test_hero_index < 0 or _test_hero_index >= pool.size():
		_test_hero_index = _hero_index_by_idle_path(hero_idle_frames_path, pool)
	_test_hero_index = posmod(_test_hero_index + 1, pool.size())
	var hero: HeroData = pool[_test_hero_index]
	hero_portrait_path = hero.portrait_path
	hero_idle_frames_path = hero.sprite_frames_path
	_apply_token_idle_art()
	player_token.rotation = 0.0


func _hero_index_by_id(hero_id: String) -> int:
	var pool: Array[HeroData] = HeroDataScript.create_launch_pool()
	for index: int in pool.size():
		if pool[index].hero_id == hero_id:
			return index
	return -1


func _hero_index_by_idle_path(path: String, pool: Array[HeroData]) -> int:
	for index: int in pool.size():
		if pool[index].sprite_frames_path == path:
			return index
	return -1


func _apply_token_idle_art() -> void:
	_hero_idle_frames = null
	_hero_idle_token_frames.clear()
	if hero_idle_frames_path != "" and ResourceLoader.exists(hero_idle_frames_path):
		var loaded_frames := load(hero_idle_frames_path) as SpriteFrames
		if loaded_frames != null and loaded_frames.has_animation(&"idle") \
				and loaded_frames.get_frame_count(&"idle") > 0:
			_hero_idle_frames = loaded_frames
			_build_token_idle_textures()
			_update_token_idle_frame(0.0)
			return
	# Compatibility only for an in-progress run saved before idle art was stored.
	if hero_portrait_path != "" and ResourceLoader.exists(hero_portrait_path):
		player_token.texture = load(hero_portrait_path)
	else:
		player_token.texture = PixelArt.get_texture("flag", COL_PLAYER, 104)


func _token_idle_frame_index_at(time_seconds: float) -> int:
	if _hero_idle_frames == null or not _hero_idle_frames.has_animation(&"idle"):
		return 0
	var frame_count: int = _hero_idle_frames.get_frame_count(&"idle")
	if frame_count <= 1:
		return 0
	# Match CharacterDisplay: every hero completes an idle loop in 0.75 seconds,
	# independent of whether its source resource contains five or six frames.
	var fps: float = TOKEN_IDLE_BASE_FPS * float(frame_count) / TOKEN_IDLE_REF_FRAMES
	return int(floor(maxf(time_seconds, 0.0) * fps)) % frame_count


func _update_token_idle_frame(time_seconds: float) -> void:
	if _hero_idle_frames == null or player_token == null or _hero_idle_token_frames.is_empty():
		return
	var frame_index: int = _token_idle_frame_index_at(time_seconds)
	player_token.texture = _hero_idle_token_frames[frame_index]


func _build_token_idle_textures() -> void:
	_hero_idle_token_frames.clear()
	if _hero_idle_frames == null:
		return
	var frame_count: int = _hero_idle_frames.get_frame_count(&"idle")
	var target_size := Vector2i(int(TOKEN_SIZE.x), int(TOKEN_SIZE.y))
	var target_origin := Vector2i(
			Vector2(TOKEN_FOOT_ANCHOR - H01_SOURCE_FOOT_MIDPOINT * TOKEN_CONTENT_SCALE).round())
	for frame_index: int in frame_count:
		var source_texture: Texture2D = _hero_idle_frames.get_frame_texture(&"idle", frame_index)
		var source_image: Image = source_texture.get_image()
		source_image.convert(Image.FORMAT_RGBA8)
		var scaled_size := Vector2i(
				Vector2(source_image.get_size()) * TOKEN_CONTENT_SCALE)
		source_image.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
		var centered_frame := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
		centered_frame.blit_rect(source_image, Rect2i(Vector2i.ZERO, scaled_size), target_origin)
		_hero_idle_token_frames.append(ImageTexture.create_from_image(centered_frame))


func _token_canvas_point_for_source(source_point: Vector2) -> Vector2:
	var target_origin := Vector2(
			TOKEN_FOOT_ANCHOR - H01_SOURCE_FOOT_MIDPOINT * TOKEN_CONTENT_SCALE).round()
	return target_origin + source_point * TOKEN_CONTENT_SCALE


# ============================================================
# 地图动效（G 任务·复用战斗屏飘字/pop 手法·UI 面板永不动）
# ============================================================

## 地图格上方飘字：上浮 44px + 淡出 0.9s 自毁。挂 fx_layer（不进面板·不吞点击）。
func _float_text(cell: Vector2i, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	FontManager.apply(l, 16)
	l.modulate = color
	l.z_index = 5
	l.position = Vector2(cell.x * MAP_CELL - 20, cell.y * MAP_CELL - 8)
	l.size = Vector2(MAP_CELL + 40, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 44.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


## 遇敌格闪：所在格红色蒙层 0.35s 淡出（弹窗弹出前的"撞上了"反馈）。
func _flash_cell(cell: Vector2i, color: Color) -> void:
	var r := ColorRect.new()
	r.color = Color(color, 0.45)
	r.position = Vector2(cell.x * MAP_CELL, cell.y * MAP_CELL)
	r.size = Vector2(MAP_CELL - 2, MAP_CELL - 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(r.queue_free)


## token 惊跳（遇敌"!"）：脚底为轴快速弹一下（scale punch·卡通感）。
func _token_bump() -> void:
	var base_scale := Vector2(
			TOKEN_RENDER_COMPENSATION * _player_facing_sign, TOKEN_RENDER_COMPENSATION)
	var tw := create_tween()
	tw.tween_property(player_token, "scale", base_scale * 1.14, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_token, "scale", base_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 按钮果冻底（D 任务·与战斗动作钮/道具弹窗同款 canvas_button_jelly 语言）。
## show_behind_parent 让果冻垫在按钮文字之下；按钮本体样式清空露出果冻。
func _jelly_button(b: Button, base: Color) -> void:
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.99, 0.94))
	b.add_theme_color_override("font_pressed_color", Color(0.92, 0.88, 0.78))
	b.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	var jelly := ColorRect.new()
	jelly.color = Color.WHITE   # jelly shader 乘 COLOR，须白
	jelly.set_anchors_preset(Control.PRESET_FULL_RECT)
	jelly.show_behind_parent = true
	jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = JELLY_SHADER
	m.set_shader_parameter("fill_top", base.lightened(0.12))
	m.set_shader_parameter("fill_bottom", base.darkened(0.32))
	m.set_shader_parameter("edge_inner", base.lightened(0.38))
	m.set_shader_parameter("edge_outer", Color(0.05, 0.045, 0.04))
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 44.0)
	m.set_shader_parameter("corner", 0.16)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", maxf(b.custom_minimum_size.x, b.size.x) / maxf(36.0, maxf(b.custom_minimum_size.y, b.size.y)))
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("wear", 0.18)
	jelly.material = m
	b.add_child(jelly)


## 背包格底同步（E 任务·PvP 道具格同源 shader）：格数变化（扩容）时重建节点。
func _sync_bp_cells() -> void:
	if bp == null or bp_cells == null:
		return
	var want: int = bp.rows * bp.cols
	if bp_cells.get_child_count() == want:
		return
	for child: Node in bp_cells.get_children():
		bp_cells.remove_child(child)
		child.queue_free()
	if _cell_mat == null:
		_cell_mat = ShaderMaterial.new()
		_cell_mat.shader = ITEM_CELL_SHADER
		_cell_mat.set_shader_parameter("fill_color", Color("1c1509"))
		_cell_mat.set_shader_parameter("inner_color", Color("2e2414"))
		_cell_mat.set_shader_parameter("center_glow", 0.45)
		_cell_mat.set_shader_parameter("corner_radius", 0.16)
		_cell_mat.set_shader_parameter("pixel_grid", 10.0)
		_cell_mat.set_shader_parameter("cloud_on", 0.0)
		_cell_mat.set_shader_parameter("use_tex", 0.0)
		_cell_mat.set_shader_parameter("fill_opaque", 1.0)
	for y: int in bp.rows:
		for x: int in bp.cols:
			var cell := ColorRect.new()
			cell.color = Color.WHITE
			cell.position = BP_ORIGIN + Vector2(x * BP_CELL, y * BP_CELL)
			cell.size = Vector2(BP_CELL - 3, BP_CELL - 3)
			cell.material = _cell_mat
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bp_cells.add_child(cell)


## 暖骨框面板 = 暖色深底填充 + 像素框（§2.1 配方·装饰节点必 IGNORE 防吞点击）。
func _make_panel(r: Rect2, parent: Control) -> void:
	var fill := ColorRect.new()
	fill.position = r.position
	fill.size = r.size
	fill.color = COL_PANEL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	var frame := ColorRect.new()
	frame.position = r.position
	frame.size = r.size
	frame.color = Color.TRANSPARENT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = FRAME_SHADER
	mat.set_shader_parameter("edge_outer", Color(0.05, 0.045, 0.04))
	mat.set_shader_parameter("edge_mid", COL_BONE)
	mat.set_shader_parameter("edge_inner", Color(0.42, 0.36, 0.26))
	mat.set_shader_parameter("border_px", 2.0)
	mat.set_shader_parameter("pixel_grid", 24.0)
	mat.set_shader_parameter("corner_radius", 0.25)
	mat.set_shader_parameter("noise_amt", 0.035)
	mat.set_shader_parameter("aspect", r.size.x / r.size.y)
	frame.material = mat
	parent.add_child(frame)


func _label(pos: Vector2, px: int, text: String, parent: Control) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.modulate = COL_TEXT
	FontManager.apply(l, px)
	parent.add_child(l)
	return l


func _button(pos: Vector2, sz: Vector2, text: String, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	FontManager.apply_btn(b, 16)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ============================================================
# 一局流程
# ============================================================

func _new_run(p_seed: int, leader: HeroData = null) -> void:
	_cancel_click_route()
	seed_value = p_seed
	map = MapState.new()
	map.setup(p_seed)
	if leader != null:
		map.team[0] = {
			"hero_id": leader.hero_id,
			"name": leader.hero_name,
			"hp": float(leader.max_hp),
			"hp_max": float(leader.max_hp),
		}
	bp = Backpack.new()
	search_state = SearchState.new()
	open_container_cell = Vector2i(-1, -1)
	pending = []
	held = {}
	log_lines = []
	_reveal_time.clear()   # 开局当前视野在首次 _refresh 盖当前钟 → 起手播一段显现
	_wheat_wave_pulses.clear()
	_camera_initialized = false
	_camera_visual_velocity = Vector2.ZERO
	_token_step_active = false
	for child: Node in fx_layer.get_children():   # 清掉上一局残留的飘字/格闪
		child.queue_free()
	terrain_mat.set_shader_parameter("seed_f", float(p_seed % 977))
	_set_player_visual_visible(true)
	_set_atmosphere_active(true)
	_log("踏入晴风稻田（种子 %d）。" % p_seed)
	_refresh()


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 9:
		log_lines.pop_front()


func _refresh() -> void:
	if map == null:
		return
	for child: Node in pend_box.get_children():
		child.queue_free()
	for i: int in pending.size():
		var it: Dictionary = pending[i]
		var b := Button.new()
		var sz: Vector2i = Loot.shape_size(it["shape"])
		b.text = "%s [%d×%d] %s" % [String(it["name"]), sz.x, sz.y, String(it.get("note", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = _item_texture(it)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_constant_override("icon_max_width", 32)
		FontManager.apply_btn(b, 16)
		var idx: int = i
		b.pressed.connect(func() -> void: _pick_from_pending(idx))
		pend_box.add_child(b)
	for child: Node in equip_box.get_children():
		child.queue_free()
	for i: int in bp.equipment.size():
		var it: Dictionary = bp.equipment[i]
		var b := Button.new()
		b.text = "%s（点击卸下）" % String(it["name"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = _item_texture(it)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_constant_override("icon_max_width", 32)
		FontManager.apply_btn(b, 16)
		var idx: int = i
		b.pressed.connect(func() -> void: _unequip(idx))
		equip_box.add_child(b)
	insure_btn.text = "保险槽（≤2×2·死亡保留）：%s" % (String(bp.insurance["name"]) if not bp.insurance.is_empty() else "空")
	_sync_bp_cells()
	_update_terrain_data()
	_update_map_camera()
	ground_art.queue_redraw()
	foliage_art.queue_redraw()
	object_art.queue_redraw()
	marker_art.queue_redraw()
	canvas.queue_redraw()
	player_backdrop.queue_redraw()
	# 占用态传送格前景效果已停用；传送格地表本体仍由 ground_art 绘制。
	bp_canvas.queue_redraw()


func _is_cell_visible(cell: Vector2i) -> bool:
	return map != null and (not LIMITED_VISIBILITY_ENABLED or map.visible.has(cell))


## 把地图状态写进数据纹理（R=地形类 0地板/1墙 · G=当前可见 · B=进入视野时刻）。
## 当前临时关闭可见范围：全图 G=1 且 B=-10，不播放边界显现。
func _update_terrain_data() -> void:
	if map == null or _terrain_img == null:
		return
	# 判定使用的新mask立即写入；视觉中心仍由镜头插值逐帧推进。
	# shader用两者的差值平移mask，既不延迟玩法，也不会让柔边逐格瞬移。
	terrain_mat.set_shader_parameter(
			"vision_logic_center_cell", Vector2(map.player) + Vector2.ONE * 0.5)
	for y: int in MapState.HEIGHT:
		for x: int in MapState.WIDTH:
			var c := Vector2i(x, y)
			var rev: bool = _is_cell_visible(c)
			if not LIMITED_VISIBILITY_ENABLED:
				_reveal_time[c] = -10.0
			elif rev and not _reveal_time.has(c):
				_reveal_time[c] = _anim_time
			elif not rev:
				_reveal_time.erase(c)
			var tile_v: float = 1.0 if map.grid[y][x] == MapState.Tile.WALL else 0.0
			_terrain_img.set_pixel(x, y, Color(tile_v, 1.0 if rev else 0.0, float(_reveal_time.get(c, 0.0)), 1.0))
	_terrain_tex.update(_terrain_img)


## 静态模式下只更新角色的逻辑格位置；跟随模式使用临界阻尼并限制在真实地图边界内。
func _update_map_camera() -> void:
	if map == null:
		return
	var next_target: Vector2 = _token_origin_for_cell(map.player)
	if camera_follow_enabled and _camera_initialized \
			and next_target.distance_squared_to(_camera_target_token_origin) > 0.01:
		_begin_token_step(_camera_visual_token_origin, next_target, _queued_move_direction)
	_queued_move_direction = Vector2i.ZERO
	_camera_target_token_origin = next_target
	if not camera_follow_enabled:
		_token_step_active = false
		_set_player_visual_origin(_camera_target_token_origin)
		if not _camera_initialized:
			_camera_initialized = true
			_camera_visual_token_origin = _camera_target_token_origin
			_camera_visual_velocity = Vector2.ZERO
			map_world.position = _camera_world_offset_for_visual(_camera_visual_token_origin)
			_sync_atmosphere_to_camera()
		return
	if not _camera_initialized:
		_camera_initialized = true
		_camera_visual_token_origin = _camera_target_token_origin
		_camera_visual_velocity = Vector2.ZERO
		_apply_camera_visual_position()


func _token_origin_for_cell(player_cell: Vector2i) -> Vector2:
	return Vector2(player_cell.x * MAP_CELL, player_cell.y * MAP_CELL) + TOKEN_OFFSET


func _camera_world_offset_for_visual(visual_token_origin: Vector2) -> Vector2:
	var rendered_origin: Vector2 = _quantize_world_pixel(visual_token_origin)
	var rendered_cell_center: Vector2 = (
			rendered_origin - TOKEN_OFFSET + Vector2.ONE * MAP_CELL * 0.5)
	var desired_offset: Vector2 = (
			MAP_VIEW_SIZE * 0.5
			- rendered_cell_center * MAP_RENDER_SCALE)
	var extension_rect: Rect2 = _camera_extension_world_rect()
	return Vector2(
			_camera_axis_offset(desired_offset.x, MAP_VIEW_SIZE.x,
					extension_rect.position.x * MAP_RENDER_SCALE,
					extension_rect.end.x * MAP_RENDER_SCALE),
			_camera_axis_offset(desired_offset.y, MAP_VIEW_SIZE.y,
					extension_rect.position.y * MAP_RENDER_SCALE,
					extension_rect.end.y * MAP_RENDER_SCALE)
	).round()


## 地图大于视窗时，把镜头限制在两条真实边界之间；地图较小时则在该轴居中。
func _camera_axis_offset(desired_offset: float, view_size: float,
		extension_start: float, extension_end: float) -> float:
	var extension_size: float = extension_end - extension_start
	if extension_size <= view_size:
		return (view_size - extension_size) * 0.5 - extension_start
	return clampf(desired_offset, view_size - extension_end, -extension_start)


## 解析式临界阻尼：位置与速度均连续；越界保护保证任何帧率下都不会越过目标后回弹。
func _step_camera_follow(delta: float) -> void:
	if not camera_follow_enabled or not _camera_initialized:
		return
	var remaining: Vector2 = _camera_target_token_origin - _camera_visual_token_origin
	if remaining.length_squared() <= CAMERA_SNAP_DISTANCE * CAMERA_SNAP_DISTANCE:
		_camera_visual_token_origin = _camera_target_token_origin
		_camera_visual_velocity = Vector2.ZERO
		_apply_camera_visual_position()
		_finish_token_step_visuals()
		return
	var step: float = clampf(delta, 0.0, CAMERA_MAX_STEP)
	if step <= 0.0:
		_apply_camera_visual_position()
		return
	var displacement: Vector2 = _camera_visual_token_origin - _camera_target_token_origin
	var decay: float = exp(-CAMERA_CRITICAL_DAMPING * step)
	var velocity_term: Vector2 = (
			_camera_visual_velocity + displacement * CAMERA_CRITICAL_DAMPING) * step
	var next_position: Vector2 = (
			_camera_target_token_origin + (displacement + velocity_term) * decay)
	var next_velocity: Vector2 = (
			_camera_visual_velocity - velocity_term * CAMERA_CRITICAL_DAMPING) * decay
	# 新目标可能在连续输入中改变；若惯性会把视觉坐标送过目标，直接在目标处停稳。
	if remaining.dot(next_position - _camera_target_token_origin) > 0.0:
		next_position = _camera_target_token_origin
		next_velocity = Vector2.ZERO
	_camera_visual_token_origin = next_position
	_camera_visual_velocity = next_velocity
	_apply_camera_visual_position()


func _apply_camera_visual_position() -> void:
	var rendered_origin: Vector2 = _quantize_world_pixel(_camera_visual_token_origin)
	_set_player_visual_origin(rendered_origin)
	map_world.position = _camera_world_offset_for_visual(rendered_origin)
	_sync_atmosphere_to_camera()


func _set_player_visual_origin(origin: Vector2) -> void:
	var step_offset := Vector2.ZERO
	if _token_step_active:
		step_offset = _token_step_offset_at(_token_step_progress_at(origin))
	player_token.position = origin + step_offset
	if player_backdrop != null:
		player_backdrop.position = origin - TOKEN_OFFSET
	_sync_terrain_vision_center(origin)


func _quantize_world_pixel(value: Vector2) -> Vector2:
	# Quantize movement relative to the authored cell anchor. Otherwise TOKEN_OFFSET
	# itself gets rounded and a standing hero shifts the camera off the cell grid.
	return TOKEN_OFFSET + (
			(value - TOKEN_OFFSET) / TOKEN_STEP_LOGICAL_PX).round() * TOKEN_STEP_LOGICAL_PX


func _begin_token_step(from_origin: Vector2, to_origin: Vector2,
		logical_direction: Vector2i = Vector2i.ZERO) -> void:
	var travel: Vector2 = to_origin - from_origin
	if travel.length_squared() <= 0.01:
		_token_step_active = false
		return
	_settle_in_progress_facing()
	_token_step_start_origin = from_origin
	_token_step_target_origin = to_origin
	_token_step_direction = Vector2(logical_direction).normalized() \
			if logical_direction != Vector2i.ZERO else travel.normalized()
	_token_turn_from_sign = _player_facing_sign
	_token_turn_target_sign = signf(float(logical_direction.x)) \
			if logical_direction.x != 0 else _player_facing_sign
	_token_turn_active = not is_equal_approx(_token_turn_target_sign, _player_facing_sign)
	_token_step_side *= -1.0
	_token_step_active = true


## 连续输入开始新步伐时，以屏幕上已经显示出的朝向为新基准。
## 这样快速反向不会先完成旧转身再校正，上下移动也不会凭插值残差误转身。
func _settle_in_progress_facing() -> void:
	if not _token_turn_active:
		return
	var progress: float = _token_step_progress_at(_camera_visual_token_origin)
	_player_facing_sign = _token_turn_target_sign \
			if progress >= TOKEN_TURN_SWITCH_PROGRESS else _token_turn_from_sign
	_token_turn_active = false


func _token_step_progress_at(visual_origin: Vector2) -> float:
	var travel: Vector2 = _token_step_target_origin - _token_step_start_origin
	var length_squared: float = travel.length_squared()
	if length_squared <= 0.01:
		return 1.0
	return clampf((visual_origin - _token_step_start_origin).dot(travel) / length_squared, 0.0, 1.0)


func _token_step_offset_at(progress: float) -> Vector2:
	var arc: float = sin(progress * PI)
	var hop_steps: float = round(arc * TOKEN_STEP_HOP_STEPS)
	var lead_steps: float = round(arc)
	var turn_lean_steps: float = round(arc) if _token_turn_active else 0.0
	return Vector2(
			_token_step_direction.x * (lead_steps + turn_lean_steps) * TOKEN_STEP_LOGICAL_PX,
			-hop_steps * TOKEN_STEP_LOGICAL_PX)


func _token_scale_at_step_progress(progress: float) -> Vector2:
	var facing_sign: float = _player_facing_sign
	var squeeze: float = 1.0
	var lift: float = 1.0
	if _token_turn_active:
		if progress < TOKEN_TURN_SWITCH_PROGRESS:
			squeeze = lerpf(1.0, TOKEN_TURN_SQUEEZE_MIN,
					progress / TOKEN_TURN_SWITCH_PROGRESS)
			facing_sign = _token_turn_from_sign
		else:
			squeeze = lerpf(TOKEN_TURN_SQUEEZE_MIN, 1.0,
					(progress - TOKEN_TURN_SWITCH_PROGRESS)
					/ (1.0 - TOKEN_TURN_SWITCH_PROGRESS))
			facing_sign = _token_turn_target_sign
		lift = 1.0 + sin(progress * PI) * 0.05
		squeeze = round(squeeze / TOKEN_TURN_SCALE_STEP) * TOKEN_TURN_SCALE_STEP
		lift = round(lift / TOKEN_TURN_SCALE_STEP) * TOKEN_TURN_SCALE_STEP
	return Vector2(
			TOKEN_RENDER_COMPENSATION * squeeze * facing_sign,
			TOKEN_RENDER_COMPENSATION * lift)


func _finish_token_step_visuals() -> void:
	if _token_turn_active:
		_player_facing_sign = _token_turn_target_sign
	_token_turn_active = false
	_token_step_active = false
	if player_token != null:
		player_token.rotation = 0.0
		player_token.scale = Vector2(
				TOKEN_RENDER_COMPENSATION * _player_facing_sign,
				TOKEN_RENDER_COMPENSATION)


func _token_step_rotation_at(progress: float) -> float:
	var alternating: float = sin(progress * TAU) * _token_step_side
	var directional: float = sin(progress * PI) * _token_step_direction.x * 0.35
	return (alternating + directional) * TOKEN_STEP_WOBBLE_AMPLITUDE


## 迷雾表现中心跟随角色的平滑视觉坐标；逻辑中心在地形数据刷新时已经立即更新。
func _sync_terrain_vision_center(token_origin: Vector2) -> void:
	if terrain_mat == null:
		return
	var cell_center: Vector2 = token_origin - TOKEN_OFFSET + Vector2.ONE * MAP_CELL * 0.5
	terrain_mat.set_shader_parameter("vision_center_cell", cell_center / float(MAP_CELL))


func _set_player_visual_visible(show_visual: bool) -> void:
	player_token.visible = show_visual
	if player_backdrop != null:
		player_backdrop.visible = show_visual
	if test_controls != null:
		test_controls.visible = show_visual
	if teleport_fx != null:
		teleport_fx.visible = false


func _camera_is_moving() -> bool:
	return camera_follow_enabled and _camera_initialized and (
			_camera_visual_token_origin.distance_squared_to(_camera_target_token_origin)
			> CAMERA_SNAP_DISTANCE * CAMERA_SNAP_DISTANCE)


func _process(delta: float) -> void:
	_anim_time += delta
	_prune_wheat_wave_pulses()
	_step_camera_follow(delta)
	if terrain_mat != null:
		terrain_mat.set_shader_parameter("anim_time", _anim_time)
	if atmosphere_mat != null:
		atmosphere_mat.set_shader_parameter("anim_time", _anim_time)
	if player_token != null and player_token.texture != null:
		_update_token_idle_frame(_anim_time)
		if _token_step_active:
			var step_progress: float = _token_step_progress_at(_camera_visual_token_origin)
			player_token.rotation = _token_step_rotation_at(step_progress)
			player_token.scale = _token_scale_at_step_progress(step_progress)
		else:
			# SpriteFrames已经包含正式idle；静止时不再叠加正弦旋转或扫动。
			player_token.rotation = 0.0
	if map != null and not select_overlay.visible:
		ground_art.queue_redraw()
		foliage_art.queue_redraw()
		object_art.queue_redraw()
		marker_art.queue_redraw()
		canvas.queue_redraw()   # 每帧重绘=驱动撤离点/当前格脉动（144 格 immediate 绘制·开销可忽略）
		player_backdrop.queue_redraw()
		# teleport_fx 是旧预览引用兼容节点，不再参与每帧绘制。


# ============================================================
# 绘制（世界空间地图图签 + 屏幕空间背包物品/手上幽灵）
# ============================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)


## Asset-review baseline: keep only the approved pixel-rounded grid structure.
## Terrain and object art stays disconnected until each replacement is approved.
func _draw_ground_art() -> void:
	_draw_camera_fog_extension()
	ground_art.draw_rect(Rect2(Vector2.ZERO, MAP_WORLD_SIZE), GROUND_GAP_COLOR)
	for y: int in MapState.HEIGHT:
		for x: int in MapState.WIDTH:
			var cell := Vector2i(x, y)
			var rect := _ground_cell_rect(cell)
			var texture := _ground_texture_for(cell)
			if texture != null:
				ground_art.draw_texture_rect(
						_wheat_wave_texture_for(cell, texture), rect, false, Color.WHITE)
			if _ground_asset_id_at(cell) == "teleport_qingfeng":
				_draw_teleport_gold_glow(rect)


func _ground_cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
			Vector2(cell.x * MAP_CELL, cell.y * MAP_CELL) + Vector2.ONE * GROUND_CELL_GAP,
			Vector2.ONE * (MAP_CELL - GROUND_CELL_GAP * 2.0))


func _draw_teleport_gold_glow(rect: Rect2) -> void:
	var occupied: bool = map != null and map.player == QingfengLayout.START
	var strength: float = _teleport_glow_strength_at(_anim_time, occupied)
	var center: Vector2 = rect.get_center()
	# Stepped diamonds and square cores preserve the coarse-pixel language.
	var outer := PackedVector2Array([
		center + Vector2(0.0, -31.0), center + Vector2(31.0, 0.0),
		center + Vector2(0.0, 31.0), center + Vector2(-31.0, 0.0),
	])
	var inner := PackedVector2Array([
		center + Vector2(0.0, -22.0), center + Vector2(22.0, 0.0),
		center + Vector2(0.0, 22.0), center + Vector2(-22.0, 0.0),
	])
	ground_art.draw_colored_polygon(outer, Color(TELEPORT_GLOW_COLOR, 0.10 * strength))
	ground_art.draw_colored_polygon(inner, Color(TELEPORT_GLOW_COLOR, 0.16 * strength))
	ground_art.draw_rect(Rect2(center - Vector2(8.0, 12.0), Vector2(16.0, 24.0)),
			Color(TELEPORT_GLOW_COLOR, 0.36 * strength))
	ground_art.draw_rect(Rect2(center - Vector2(12.0, 8.0), Vector2(24.0, 16.0)),
			Color(TELEPORT_GLOW_COLOR, 0.30 * strength))
	ground_art.draw_rect(Rect2(center - Vector2(4.0, 4.0), Vector2(8.0, 8.0)),
			Color(TELEPORT_GLOW_CORE, 0.72 * strength))


func _teleport_glow_strength_at(time_seconds: float, occupied: bool) -> float:
	if occupied:
		return 1.0
	var breath: float = 0.5 + 0.5 * sin(time_seconds * TELEPORT_BREATH_SPEED)
	return lerpf(0.24, 0.62, breath)


## 旧预览探针仍会引用 TeleportOccupiedFxLayer，因此保留空回调；
## 正式运行时该层始终隐藏，不再绘制四角巡游或闪烁。
func _draw_teleport_occupied_fx() -> void:
	pass


## 镜头可以把逻辑边界移到屏幕中央，但外围只画永久浓雾，不写入 grid，也不响应移动/互动。
func _draw_camera_fog_extension() -> void:
	for y: int in range(-CAMERA_FOG_PADDING_ROWS, MapState.HEIGHT + CAMERA_FOG_PADDING_ROWS):
		for x: int in range(-CAMERA_FOG_PADDING_COLS, MapState.WIDTH + CAMERA_FOG_PADDING_COLS):
			var cell := Vector2i(x, y)
			if not _is_fog_extension_cell(cell):
				continue
			var rect := Rect2(Vector2(x * MAP_CELL, y * MAP_CELL), Vector2(MAP_CELL, MAP_CELL))
			_draw_fog_extension_cell(rect)


func _is_fog_extension_cell(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.y < 0 or cell.x >= MapState.WIDTH or cell.y >= MapState.HEIGHT


func _camera_extension_world_rect() -> Rect2:
	var padding := Vector2(CAMERA_FOG_PADDING_COLS * MAP_CELL, CAMERA_FOG_PADDING_ROWS * MAP_CELL)
	return Rect2(-padding, MAP_WORLD_SIZE + padding * 2.0)


func _draw_fog_extension_cell(rect: Rect2) -> void:
	ground_art.draw_rect(rect, FOG_EXTENSION_FACE)
	ground_art.draw_rect(rect, FOG_EXTENSION_VEIL)
	var seam_color := Color(FOG_EXTENSION_SEAM, 0.42)
	ground_art.draw_rect(Rect2(
			Vector2(rect.end.x - FOG_EXTENSION_SEAM_PX, rect.position.y),
			Vector2(FOG_EXTENSION_SEAM_PX, rect.size.y)), seam_color)
	ground_art.draw_rect(Rect2(
			Vector2(rect.position.x, rect.end.y - FOG_EXTENSION_SEAM_PX),
			Vector2(rect.size.x, FOG_EXTENSION_SEAM_PX)), seam_color)


func _chamfered_rect_points(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		rect.position + Vector2(0.0, cut),
	])


func _ground_palette_index(cell: Vector2i) -> int:
	var ground_terrain: int = _ground_terrain_at(cell)
	if ground_terrain == QingfengLayout.GroundTerrain.DIRT:
		return GROUND_DIRT_INDEX
	if ground_terrain == QingfengLayout.GroundTerrain.RICE:
		return GROUND_RICE_INDEX
	return _grass_palette_index_from_field(_ground_region_field_value(Vector2(cell) + Vector2.ONE * 0.5))


## Each authored variant only replaces cells of the same terrain semantic:
## dark grass never becomes the foundation under rice or dirt. The Qingfeng
## teleport replaces only the southern start cell.
func _ground_texture_for(cell: Vector2i) -> Texture2D:
	if visual_ground == null or visual_ground.tile_set == null:
		return null
	var source_id: int = visual_ground.get_cell_source_id(cell)
	if source_id < 0:
		return null
	var source := visual_ground.tile_set.get_source(source_id) as TileSetAtlasSource
	return source.texture if source != null else null


func _ground_asset_id_at(cell: Vector2i) -> String:
	if visual_ground == null:
		return ""
	var tile_data := visual_ground.get_cell_tile_data(cell)
	return String(tile_data.get_custom_data("asset_id")) if tile_data != null else ""


func _ground_terrain_at(cell: Vector2i) -> int:
	if visual_ground != null:
		var tile_data := visual_ground.get_cell_tile_data(cell)
		if tile_data != null:
			return int(tile_data.get_custom_data("ground_type"))
	return QingfengLayout.ground_terrain_at(cell)


func _uses_grass_variant(cell: Vector2i) -> bool:
	if _ground_terrain_at(cell) != QingfengLayout.GroundTerrain.GRASS:
		return false
	return _ground_region_field_value(Vector2(cell) + Vector2.ONE * 0.5) < -0.42


func _uses_dirt_variant(cell: Vector2i) -> bool:
	if _ground_terrain_at(cell) != QingfengLayout.GroundTerrain.DIRT:
		return false
	# Stable sparse replacement along the authored road network; never depends
	# on run seed, so terrain does not visually reshuffle between expeditions.
	return posmod(cell.x * 5 + cell.y * 3 + cell.x * cell.y, 7) < 2


func _ground_source_rect_for(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	return Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))


func _ground_fill_color_for(cell: Vector2i) -> Color:
	match _ground_palette_index(cell):
		GROUND_GRASS_DARK_INDEX:
			return GROUND_FILL_GRASS_DARK
		GROUND_DIRT_INDEX:
			return GROUND_FILL_DIRT
		GROUND_RICE_INDEX:
			return GROUND_FILL_RICE
		_:
			return GROUND_FILL_GRASS_LIGHT


## The approved source tiles already contain transparent corner padding. Crop
## only that empty outer ring so the Ref39-style gap stays narrow at runtime,
## while the authored staircase corner silhouette remains intact.
func _ground_modulate_for(cell: Vector2i) -> Color:
	return Color.WHITE


func _layout_is_wall(cell: Vector2i) -> bool:
	return QingfengLayout.TERRAIN_ROWS[cell.y][cell.x] == "#"


func _ground_region_field_value(cell_position: Vector2) -> float:
	return (
			sin((cell_position.x + 1.5) * 0.43)
			+ cos((cell_position.y - 1.0) * 0.49)
			+ sin((cell_position.x + cell_position.y) * 0.23) * 0.55)


func _grass_palette_index_from_field(field: float) -> int:
	if field >= 0.15:
		return GROUND_GRASS_LIGHT_INDEX
	return GROUND_GRASS_DARK_INDEX


## Kept as an empty compatibility layer so established draw order and fog
## composition remain stable. Wheat motion now replaces the rice tile itself
## in GroundArtLayer; it no longer draws extra rectangular strips above it.
func _draw_rice_foliage() -> void:
	pass


func _build_wheat_wave_runtime_frames() -> void:
	_wheat_wave_runtime_frames.clear()
	var source: Image = GOLDEN_WAVE_GROUND_TEXTURE.get_image()
	if source == null or source.get_size() != Vector2i(60, 60):
		return
	source.convert(Image.FORMAT_RGBA8)
	for raw_pattern: Array in WHEAT_WAVE_SHIFT_PATTERNS:
		var frame: Image = source.duplicate()
		for y: int in range(4, 56):
			var band: int = mini(7, int((y - 4) / 7.0))
			var shift: int = int(raw_pattern[band]) * WHEAT_WAVE_SOURCE_PIXEL_STEP
			for x: int in range(4, 56):
				var sample_x: int = clampi(x - shift, 4, 55)
				frame.set_pixel(x, y, source.get_pixel(sample_x, y))
		_wheat_wave_runtime_frames.append(ImageTexture.create_from_image(frame))


func _wheat_wave_texture_for(cell: Vector2i, fallback: Texture2D) -> Texture2D:
	if _ground_terrain_at(cell) != QingfengLayout.GroundTerrain.RICE \
			or _wheat_wave_runtime_frames.is_empty():
		return fallback
	var pulse: Dictionary = _active_wheat_wave_pulse_for_cell(cell)
	if pulse.is_empty():
		return fallback
	var age: float = _anim_time - float(pulse["start_time"])
	var progress: float = clampf(age / WHEAT_WAVE_DURATION, 0.0, 0.999)
	var frame_index: int = clampi(
			int(floor(progress * _wheat_wave_runtime_frames.size())),
			0, _wheat_wave_runtime_frames.size() - 1)
	return _wheat_wave_runtime_frames[frame_index]


func _active_wheat_wave_pulse_for_cell(cell: Vector2i) -> Dictionary:
	for pulse: Dictionary in _wheat_wave_pulses:
		if Vector2i(pulse["cell"]) != cell:
			continue
		var age: float = _anim_time - float(pulse["start_time"])
		if age >= 0.0 and age <= WHEAT_WAVE_DURATION:
			return pulse
	return {}


func _wheat_wave_cells_from(origin: Vector2i) -> Array:
	if _ground_terrain_at(origin) != QingfengLayout.GroundTerrain.RICE:
		return []
	var result: Array = []
	var distance_by_cell: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		var distance: int = int(distance_by_cell[cell])
		result.append({"cell": cell, "distance": distance})
		if distance >= WHEAT_WAVE_RADIUS:
			continue
		for neighbor: Vector2i in [cell + Vector2i.UP, cell + Vector2i.RIGHT,
				cell + Vector2i.DOWN, cell + Vector2i.LEFT]:
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= MapState.WIDTH or neighbor.y >= MapState.HEIGHT:
				continue
			if distance_by_cell.has(neighbor):
				continue
			if _ground_terrain_at(neighbor) != QingfengLayout.GroundTerrain.RICE:
				continue
			distance_by_cell[neighbor] = distance + 1
			frontier.append(neighbor)
	return result


func _trigger_wheat_wave(_from_cell: Vector2i, to_cell: Vector2i, move_dir: Vector2i) -> void:
	var wave_cells: Array = _wheat_wave_cells_from(to_cell)
	if wave_cells.is_empty():
		return
	var replaced_cells: Dictionary = {}
	for entry: Dictionary in wave_cells:
		replaced_cells[Vector2i(entry["cell"])] = true
	var retained: Array[Dictionary] = []
	for pulse: Dictionary in _wheat_wave_pulses:
		if not replaced_cells.has(Vector2i(pulse["cell"])):
			retained.append(pulse)
	_wheat_wave_pulses = retained
	for entry: Dictionary in wave_cells:
		_wheat_wave_pulses.append({
			"cell": Vector2i(entry["cell"]),
			"distance": int(entry["distance"]),
			"direction": move_dir,
			"start_time": _anim_time + int(entry["distance"]) * WHEAT_WAVE_RING_DELAY,
		})


func _prune_wheat_wave_pulses() -> void:
	var max_age: float = WHEAT_WAVE_DURATION
	_wheat_wave_pulses = _wheat_wave_pulses.filter(func(pulse: Dictionary) -> bool:
		return _anim_time - float(pulse["start_time"]) <= max_age)


func _terrain_object_texture_for(cell: Vector2i) -> Texture2D:
	return null


func _draw_object_art() -> void:
	pass


func _object_texture_for(gameplay_tile: int) -> Texture2D:
	return null


func _draw_marker_art() -> void:
	pass


## 单层椭圆脚影；跳步抬起时只收窄、变淡，不改变基础轮廓类型。
func _draw_player_backdrop() -> void:
	var lift: float = _player_shadow_lift()
	var width: float = _player_shadow_width_at_lift(lift)
	var height: float = round(lerpf(12.0, 8.0, lift))
	var opacity: float = lerpf(1.0, 0.52, lift)
	var center := TOKEN_CELL_FOOT_POINT + Vector2(
			_token_step_direction.x * round(lift * 2.0), 2.0)
	player_backdrop.draw_set_transform(center, 0.0, Vector2(width / height, 1.0))
	player_backdrop.draw_circle(Vector2.ZERO, height * 0.5,
			Color(PLAYER_SHADOW_MAIN_COLOR, PLAYER_SHADOW_MAIN_COLOR.a * opacity),
			true, -1.0, false)
	player_backdrop.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _player_shadow_lift() -> float:
	if not _token_step_active:
		return 0.0
	return sin(_token_step_progress_at(_camera_visual_token_origin) * PI)


func _player_shadow_width_at_lift(lift: float) -> float:
	var width: float = lerpf(PLAYER_SHADOW_BASE_WIDTH, PLAYER_SHADOW_MIN_WIDTH,
			clampf(lift, 0.0, 1.0))
	return round(width * 0.5) * 2.0


## 世界画布绘制（地表/迷雾=TerrainLayer shader；本层只画地图图签与落脚反馈）。
func _draw_canvas() -> void:
	pass


func _tile_uses_contact_shadow(tile: int) -> bool:
	return tile in [
		MapState.Tile.START,
		MapState.Tile.EVENT,
		MapState.Tile.EXT1,
		MapState.Tile.EXT2,
		MapState.Tile.EXT3,
	]


## 仅为仍使用小图签的入口/事件保留接触影；人物和正方形搜索资产不使用。
func _draw_map_icon_contact_shadow(rect: Rect2) -> void:
	var main_size := Vector2(rect.size.x * 0.56, 11.0)
	var upper_size := Vector2(rect.size.x * 0.38, 4.0)
	var shadow_y: float = rect.position.y + rect.size.y - 35.0
	canvas.draw_rect(
			Rect2(Vector2(rect.position.x + (rect.size.x - main_size.x) * 0.5, shadow_y), main_size),
			Color(0.035, 0.020, 0.010, 0.72))
	canvas.draw_rect(
			Rect2(Vector2(rect.position.x + (rect.size.x - upper_size.x) * 0.5, shadow_y - 4.0), upper_size),
			Color(0.035, 0.020, 0.010, 0.46))


## 背包画布固定在屏幕空间，地图相机移动不会带动背包格或手持物品。
func _draw_backpack_canvas() -> void:
	if map == null or not bp_overlay.visible:
		return
	_draw_backpack_layer(FontManager.f16)


## 背包浮层绘制（放置块/手上幽灵）。
## 空格底=bp_cells 节点（PvP 道具格同源 shader）；放置块内缩 3px 避开格底圆角。
func _draw_backpack_layer(f16: Font) -> void:
	for p: Dictionary in bp.placements:
		var it: Dictionary = p["item"]
		var col: Color = _cat_color(String(it["cat"]))
		for off: Vector2i in p["shape"]:
			var c: Vector2i = Vector2i(p["anchor"]) + off
			var cell_rect := Rect2(BP_ORIGIN + Vector2(c.x * BP_CELL + 3, c.y * BP_CELL + 3), Vector2(BP_CELL - 9, BP_CELL - 9))
			bp_canvas.draw_rect(cell_rect, col.darkened(0.35))
			bp_canvas.draw_rect(cell_rect, col, false, 1.0)
		var a: Vector2i = p["anchor"]
		bp_canvas.draw_texture_rect(_item_texture(it), Rect2(BP_ORIGIN + Vector2(a.x * BP_CELL + 4, a.y * BP_CELL + 4), Vector2(BP_CELL - 11, BP_CELL - 11)), false)
	if not held.is_empty():
		var cell: Vector2i = _bp_cell_at(mouse_pos)
		var shape: Array = held["shape"]
		if cell.x >= 0:
			var ok: bool = bp.can_place(shape, cell)
			for off: Vector2i in shape:
				var c: Vector2i = cell + off
				bp_canvas.draw_rect(Rect2(BP_ORIGIN + Vector2(c.x * BP_CELL, c.y * BP_CELL), Vector2(BP_CELL - 3, BP_CELL - 3)), COL_OK if ok else COL_BAD)
		else:
			for off: Vector2i in shape:
				bp_canvas.draw_rect(Rect2(mouse_pos + Vector2(off.x, off.y) * BP_CELL * 0.6, Vector2(BP_CELL, BP_CELL) * 0.55), Color(_cat_color(String(held["item"]["cat"])), 0.7))
			bp_canvas.draw_texture_rect(_item_texture(held["item"]), Rect2(mouse_pos + Vector2(2, 2), Vector2(BP_CELL, BP_CELL) * 0.5), false)
		bp_canvas.draw_string(f16, mouse_pos + Vector2(20, -12), String(held["item"]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_TEXT)


## 物品图标：战斗道具优先用真 PvP 图标（ItemCatalog·60 张现役素材），缺图/其余回退像素图签。
func _item_texture(it: Dictionary) -> Texture2D:
	if String(it.get("combat_id", "")) != "":
		var t: Texture2D = ItemCatalog.load_icon(String(it["combat_id"]))
		if t != null:
			return t
	return PixelArt.get_texture(String(it.get("icon", "sword")), _cat_color(String(it.get("cat", ""))))


func _cat_color(cat: String) -> Color:
	match cat:
		"gold": return COL_GOLD_ITEM
		"combat": return COL_COMBAT_ITEM
		"consumable": return COL_CONSUM_ITEM
		"rare": return COL_RARE_ITEM
	return COL_FLOOR


# ============================================================
# 输入
# ============================================================

func _bp_cell_at(pos: Vector2) -> Vector2i:
	var local: Vector2 = pos - BP_ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var c := Vector2i(int(local.x / BP_CELL), int(local.y / BP_CELL))
	if c.x >= bp.cols or c.y >= bp.rows:
		return Vector2i(-1, -1)
	return c


## 背包浮层开关。关闭时手上物品自动放回拾取区（不许"隔屏拿东西"）。
func _toggle_backpack(show_it: bool) -> void:
	if show_it == bp_overlay.visible:
		return
	if show_it:
		_cancel_click_route()
	if not show_it and not held.is_empty():
		pending.append(held["item"])
		held = {}
	bp_overlay.visible = show_it
	_set_player_visual_visible(not show_it and map != null)   # 浮层期间藏角色视觉（否则浮在暗幕上）
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not bp_overlay.visible or map == null:
		return
	if event is InputEventMouseMotion:
		mouse_pos = (event as InputEventMouseMotion).position
		if not held.is_empty():
			bp_canvas.queue_redraw()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		mouse_pos = mb.position
		if mb.button_index == MOUSE_BUTTON_RIGHT and not held.is_empty():
			pending.append(held["item"])
			held = {}
			_refresh()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell: Vector2i = _bp_cell_at(mb.position)
		if cell.x < 0:
			return
		if held.is_empty():
			var p: Dictionary = bp.remove_at(cell)
			if not p.is_empty():
				held = {"item": p["item"], "shape": (p["shape"] as Array).duplicate()}
				_refresh()
		else:
			if bp.place(held["item"], held["shape"], cell):
				held = {}
				_refresh()


func _on_map_view_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if map == null or map.over or select_overlay.visible or bp_overlay.visible or dialog.visible:
		return
	var destination_cell: Vector2i = _cell_from_map_view_position(mouse_button.position)
	if request_move_to_cell(destination_cell):
		map_view.accept_event()


func request_move_to_cell(destination_cell: Vector2i) -> bool:
	if map == null or map.over or select_overlay.visible or bp_overlay.visible or dialog.visible:
		return false
	if not _is_walkable_map_cell(destination_cell):
		return false
	_movement_generation += 1
	_follow_click_route(destination_cell, _movement_generation)
	return true


func _follow_click_route(destination_cell: Vector2i, generation: int) -> void:
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(MapState.WIDTH, MapState.HEIGHT))
	var path: Array[Vector2i] = GridPathfinderScript.find_path(
			map.player, destination_cell, bounds, _is_walkable_map_cell)
	if destination_cell != map.player and path.is_empty():
		movement_finished.emit(map.player, false)
		return
	_click_route_active = true
	for next_cell: Vector2i in path:
		while _camera_is_moving():
			await get_tree().process_frame
			if not is_instance_valid(self) or generation != _movement_generation:
				return
		if generation != _movement_generation or map == null or map.over \
				or select_overlay.visible or bp_overlay.visible or dialog.visible:
			_click_route_active = false
			movement_finished.emit(map.player if map != null else Vector2i(-1, -1), false)
			return
		var direction: Vector2i = next_cell - map.player
		var result_kind: String = _move_one_step(direction)
		if result_kind != "move":
			break
	while _camera_is_moving():
		await get_tree().process_frame
		if not is_instance_valid(self) or generation != _movement_generation:
			return
	_click_route_active = false
	var completed: bool = map != null and map.player == destination_cell
	movement_finished.emit(map.player if map != null else Vector2i(-1, -1), completed)


func _cancel_click_route() -> void:
	_movement_generation += 1
	_click_route_active = false


func _is_walkable_map_cell(cell: Vector2i) -> bool:
	return map != null and cell.x >= 0 and cell.y >= 0 \
			and cell.x < MapState.WIDTH and cell.y < MapState.HEIGHT \
			and map.grid[cell.y][cell.x] != MapState.Tile.WALL


func _cell_from_map_view_position(view_position: Vector2) -> Vector2i:
	if map_world == null:
		return Vector2i(-1, -1)
	var world_position: Vector2 = (view_position - map_world.position) / MAP_RENDER_SCALE
	var cell := Vector2i(floori(world_position.x / MAP_CELL), floori(world_position.y / MAP_CELL))
	return cell if _is_walkable_map_cell(cell) else Vector2i(-1, -1)


func _map_view_position_for_cell(cell: Vector2i) -> Vector2:
	return map_world.position + (Vector2(cell) + Vector2.ONE * 0.5) \
			* float(MAP_CELL) * MAP_RENDER_SCALE


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key: int = (event as InputEventKey).keycode
	if select_overlay.visible:
		if key == KEY_ESCAPE:
			TransitionManager.transition_to(MENU_SCENE)   # 选人阶段 ESC=回主菜单
		return
	if dialog.visible or map == null:
		return
	if key == KEY_B:
		_toggle_backpack(not bp_overlay.visible)
		return
	if key == KEY_ESCAPE:
		if bp_overlay.visible:
			_toggle_backpack(false)
		else:
			_prompt_leave()
		return
	if bp_overlay.visible:
		if key == KEY_R and not held.is_empty():
			held["shape"] = Loot.rotate_shape(held["shape"])
			bp_canvas.queue_redraw()
		elif key == KEY_X and not held.is_empty():
			_log("丢弃了 %s。" % String(held["item"]["name"]))
			held = {}
			_refresh()
		elif key == KEY_U and not held.is_empty():
			_use_held()
		return   # 浮层开着不移动
	if map.over:
		return
	if key == KEY_E or key == KEY_F:
		_cancel_click_route()
		_try_interact_current_cell()
		return
	var dir := Vector2i.ZERO
	match key:
		KEY_W, KEY_UP: dir = Vector2i.UP
		KEY_S, KEY_DOWN: dir = Vector2i.DOWN
		KEY_A, KEY_LEFT: dir = Vector2i.LEFT
		KEY_D, KEY_RIGHT: dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO:
		return
	_cancel_click_route()
	_move_one_step(dir)


func _move_one_step(dir: Vector2i) -> String:
	if map == null or map.over or absi(dir.x) + absi(dir.y) != 1:
		return "blocked"
	var prev: Vector2i = map.player
	var res: Dictionary = map.try_move(dir)
	if bool(res.get("moved", false)):
		_queued_move_direction = dir
		_trigger_wheat_wave(prev, map.player, dir)
	if bool(res.get("moved", false)) and search_state != null:
		search_state.close_container("moved")
		open_container_cell = Vector2i(-1, -1)
	for m: String in res.get("msgs", []):
		_log(m)
	match String(res["kind"]):
		"monster":
			pending_flee_from = prev
			_flash_cell(map.player, COL_MONSTER)
			_token_bump()
			_enter_real_battle(map.player)
		"event":
			_float_text(map.player, "可互动", COL_EVENT)
		"chest":
			_float_text(map.player, "可搜索", COL_CHEST)
		"ext":
			_float_text(map.player, "发现撤离点", COL_EXT_OPEN)
	_refresh()
	return String(res["kind"])


## 当前格统一主动交互入口。容器采用逐件、可中断续搜的回合制搜索；
## 正式容器 UI 接入前，已揭示物品通过现有拾取区进入背包整理流程。
func _try_interact_current_cell() -> void:
	if map == null or map.over:
		return
	var tile: int = map.grid[map.player.y][map.player.x]
	match tile:
		MapState.Tile.CHEST:
			_interact_search_container(map.player)
		MapState.Tile.EVENT:
			_run_event(map.player)
		MapState.Tile.EXT1, MapState.Tile.EXT2, MapState.Tile.EXT3:
			_prompt_extract(tile)
		_:
			return
	_refresh()


func _interact_search_container(cell: Vector2i) -> void:
	if search_state == null:
		search_state = SearchState.new()
	var container_id: String = _container_id_for_cell(cell)
	if not search_state.has_container(container_id):
		var fixed_contents: Array = map.prepare_chest_contents(cell)
		if fixed_contents.is_empty():
			_log("容器里没有可搜索的物品。")
			return
		search_state.register_container(container_id, fixed_contents)
	if open_container_cell != cell:
		search_state.open_container(container_id)
		open_container_cell = cell

	# 一件物品揭示后先停下：下一次交互把它转入拾取区，再允许搜索下一件。
	var snapshot: Dictionary = search_state.open_snapshot()
	var visible_items: Array = snapshot.get("visible_items", [])
	if not visible_items.is_empty():
		var entry_id: String = String((visible_items[0] as Dictionary)["entry_id"])
		var take_result: Dictionary = search_state.take_revealed(entry_id)
		if bool(take_result.get("ok", false)):
			pending.append((take_result["item"] as Dictionary).duplicate(true))
			_advance_container_action("pickup")
			_log("已取出 %s → 拾取区。" % String(take_result["item"]["name"]))
			_float_text(cell, "已取出", COL_CHEST)
			_finish_container_if_empty(cell)
		return

	var step_result: Dictionary = search_state.advance_turn()
	if not bool(step_result.get("ok", false)):
		var start_result: Dictionary = search_state.start_next_item()
		if not bool(start_result.get("ok", false)):
			_finish_container_if_empty(cell)
			return
		step_result = search_state.advance_turn()
	if not bool(step_result.get("ok", false)):
		return
	_advance_container_action("search")
	if bool(step_result.get("completed", false)):
		var item: Dictionary = step_result["revealed_item"]
		_log("搜索发现：%s。再次互动可取入拾取区。" % String(item["name"]))
		_float_text(cell, "发现 %s" % String(item["name"]), COL_CHEST)
	else:
		var remaining: int = int(step_result.get("remaining_turns", 0))
		_log("搜索中：还需 %d 回合；移动可中断且保留进度。" % remaining)
		_float_text(cell, "搜索 %d/%d" % [
				int(step_result.get("progress_turns", 0)),
				int(step_result.get("required_turns", 0))], COL_CHEST)


func _container_id_for_cell(cell: Vector2i) -> String:
	return "qingfeng:%d,%d" % [cell.x, cell.y]


func _finish_container_if_empty(cell: Vector2i) -> void:
	var snapshot: Dictionary = search_state.open_snapshot()
	if snapshot.is_empty():
		return
	if int(snapshot.get("hidden_count", 0)) > 0:
		return
	if not (snapshot.get("visible_items", []) as Array).is_empty():
		return
	map.deplete_chest(cell)
	search_state.close_container("depleted")
	open_container_cell = Vector2i(-1, -1)
	_log("容器已经搜空。")


func _advance_container_action(action: String) -> void:
	var result: Dictionary = map.advance_world_action(action)
	for msg: String in result.get("msgs", []):
		_log(msg)


func _use_held() -> void:
	var it: Dictionary = held["item"]
	if String(it["cat"]) != "consumable":
		_log("%s 不是消耗品。" % String(it["name"]))
		return
	match String(it["id"]):
		"potion":
			map.heal_front(1.0)
			_log("药瓶：前排 +1 HP。")
			_float_text(map.player, "+1.0 HP", COL_CONSUM_ITEM)
		"soup":
			map.heal_all(0.5)
			_log("大补汤：全队 +0.5 HP。")
			_float_text(map.player, "全队 +0.5 HP", COL_CONSUM_ITEM)
	held = {}
	_refresh()


# ============================================================
# 拾取区 / 装备 / 保险槽
# ============================================================

func _pick_from_pending(idx: int) -> void:
	if not held.is_empty() or idx >= pending.size():
		return
	var it: Dictionary = pending[idx]
	pending.remove_at(idx)
	held = {"item": it, "shape": (it["shape"] as Array).duplicate()}
	_refresh()


func _on_equip_clicked() -> void:
	if held.is_empty():
		_log("手上没东西——先拾起一件战斗道具。")
		return
	if bp.equip(held["item"]):
		_log("装上 %s。" % String(held["item"]["name"]))
		held = {}
	else:
		_log("只有战斗道具能装备。")
	_refresh()


func _unequip(idx: int) -> void:
	if not held.is_empty() or idx >= bp.equipment.size():
		return
	var it: Dictionary = bp.equipment[idx]
	bp.equipment.remove_at(idx)
	held = {"item": it, "shape": (it["shape"] as Array).duplicate()}
	_refresh()


func _on_insure_clicked() -> void:
	if held.is_empty():
		if not bp.insurance.is_empty():
			var it: Dictionary = bp.pop_insurance()
			held = {"item": it, "shape": (it["shape"] as Array).duplicate()}
	else:
		if bp.can_insure(held["item"]):
			bp.insure(held["item"])
			held = {}
			_log("放进保险槽（死亡也保住）。")
		else:
			_log("保险槽只收 ≤2×2 单件（已有物品或过大）。")
	_refresh()


## 从背包/拾取区找出最便宜的金币类物品并移除（行商/赌局用）。无则 {}。
func _take_cheapest_gold() -> Dictionary:
	var best_p: Dictionary = {}
	for p: Dictionary in bp.placements:
		if String(p["item"]["cat"]) == "gold":
			if best_p.is_empty() or int(p["item"]["gold"]) < int(best_p["item"]["gold"]):
				best_p = p
	var best_pend: int = -1
	for i: int in pending.size():
		var it: Dictionary = pending[i]
		if String(it["cat"]) == "gold":
			if best_pend < 0 or int(it["gold"]) < int(pending[best_pend]["gold"]):
				best_pend = i
	if best_pend >= 0 and (best_p.is_empty() or int(pending[best_pend]["gold"]) <= int(best_p["item"]["gold"])):
		var it2: Dictionary = pending[best_pend]
		pending.remove_at(best_pend)
		return it2
	if not best_p.is_empty():
		bp.placements.erase(best_p)
		return best_p["item"]
	return {}


# ============================================================
# 战斗 / 事件 / 结算
# ============================================================

## 通用敌人格直接进入当前战斗系统。正常晴风暂不生成敌人；正式敌人层通过
## MapState.inject_encounter() 注入带 hero_id 的 opponents 后即可复用本入口。
func _enter_real_battle(c: Vector2i) -> void:
	var encounter: Dictionary = map.resolve_encounter(c)
	if encounter.is_empty():
		_log("遭遇数据缺失，本次战斗已取消。")
		return
	var player_session: Dictionary = _battle_session_for_entries(map.team, true)
	var opponents_value: Variant = encounter.get("opponents", [])
	var opponent_entries: Array = opponents_value as Array if opponents_value is Array else []
	# 已倒下的敌人不重新进入下一场战斗；结果仍按“进战前存活顺序”回写原遭遇。
	var opponent_session: Dictionary = _battle_session_for_entries(opponent_entries, true)
	if player_session.is_empty() or opponent_session.is_empty():
		_log("战斗阵容缺少有效 hero_id，本次战斗已取消。")
		return
	if not held.is_empty():
		pending.append(held["item"])   # 手上物品放回拾取区（不跨场景带手）
		held = {}
	if search_state != null:
		search_state.interrupt("battle_contact")
	var battle_seed: int = seed_value + map.steps * 1009 + c.x * 31 + c.y
	if not BattleSetup.configure_pve(
			player_session["heroes"],
			opponent_session["heroes"],
			player_session["hp"],
			opponent_session["hp"],
			battle_seed):
		_log("战斗会话建立失败，本次战斗已取消。")
		return
	BattleSetup.expedition_state = {"map": map, "bp": bp, "search_state": search_state,
		"open_container_cell": open_container_cell, "pending": pending, "log": log_lines,
		"seed": seed_value, "tile": c, "flee_from": pending_flee_from,
		"hero_portrait": hero_portrait_path, "hero_idle_frames": hero_idle_frames_path}
	TransitionManager.transition_to("res://src/ui/battle_screen1.tscn")


func _battle_session_for_entries(entries: Array, living_only: bool) -> Dictionary:
	var heroes: Array[HeroData] = []
	var hp: Array[int] = []
	for value: Variant in entries:
		if not value is Dictionary:
			return {}
		var entry: Dictionary = value as Dictionary
		if living_only and float(entry.get("hp", 0.0)) <= 0.0:
			continue
		var hero_id: String = String(entry.get("hero_id", "")).strip_edges()
		var hero_path := "res://assets/data/heroes/%s.tres" % hero_id
		if hero_id.is_empty() or not ResourceLoader.exists(hero_path):
			return {}
		var source: Resource = load(hero_path)
		if not source is HeroData:
			return {}
		var hero: HeroData = (source as HeroData).duplicate(true) as HeroData
		heroes.append(hero)
		var hp_half: int = int(round(float(entry.get("hp", hero.max_hp)) * 2.0))
		hp.append(clampi(hp_half, 0, hero.max_hp * 2))
	if heroes.is_empty():
		return {}
	return {"heroes": heroes, "hp": hp}


func _roll_recruit_entry() -> Dictionary:
	if map.team.size() >= 3:
		return {}
	var owned: Dictionary = {}
	for member: Dictionary in map.team:
		owned[String(member.get("hero_id", ""))] = true
	var candidates: Array[HeroData] = []
	for hero: HeroData in HeroDataScript.create_launch_pool():
		if not owned.has(hero.hero_id):
			candidates.append(hero)
	if candidates.is_empty():
		return {}
	var recruit: HeroData = candidates[map.rng.randi_range(0, candidates.size() - 1)]
	return {
		"hero_id": recruit.hero_id,
		"name": recruit.hero_name,
		"hp": float(recruit.max_hp),
		"hp_max": float(recruit.max_hp),
	}


func _loot_text(loot: Array) -> String:
	var names: Array = []
	for it: Dictionary in loot:
		names.append(String(it["name"]))
	return "、".join(names) if not names.is_empty() else "无"


func _run_event(c: Vector2i) -> void:
	var ev: String = String(map.events.get(c, ""))
	var consume := func() -> void:
		map.events.erase(c)
		map.grid[c.y][c.x] = MapState.Tile.FLOOR
	match ev:
		"篝火":
			var hero_name: String = map.recruit(_roll_recruit_entry())
			if hero_name != "":
				_log("篝火·招募：%s 加入！" % hero_name)
				_float_text(map.player, "伙伴 +1", COL_PLAYER)
			else:
				map.heal_all(0.5)
				_log("篝火·休整：队伍已满，全队 +0.5 HP。")
				_float_text(map.player, "全队 +0.5 HP", COL_CONSUM_ITEM)
			consume.call()
		"清泉":
			_show_choice("清泉：选一种饮法", ["单英雄 +1 HP（前排）", "全队 +0.5 HP"], func(idx: int) -> void:
				if idx == 0:
					map.heal_front(1.0)
				else:
					map.heal_all(0.5)
				_log("清泉：恢复完成。")
				_float_text(map.player, "+1.0 HP" if idx == 0 else "全队 +0.5 HP", COL_CONSUM_ITEM)
				consume.call()
				_refresh())
		"陷阱":
			map.damage_front(1.0, "重伤于陷阱")
			_log("陷阱：前排 -1 HP。")
			_float_text(map.player, "前排 -1 HP", Color("ff6a5c"))
			consume.call()
			if map.over:
				_show_settlement()
		"神龛":
			var it: Dictionary = Loot.make_combat(map.rng, 1)
			pending.append(it)
			_log("神龛：%s → 拾取区。" % String(it["name"]))
			consume.call()
		"藏宝图":
			var found: Vector2i = map.reveal_random_chest()
			_log("藏宝图：%s。" % ("探明宝箱 (%d,%d)" % [found.x, found.y] if found.x >= 0 else "已无未知宝箱"))
			consume.call()
		"岔路赌局":
			_show_choice("岔路赌局：押你最便宜的金币物件，50/50 翻倍或没收", ["赌！", "不赌"], func(idx: int) -> void:
				if idx == 0:
					var stake: Dictionary = _take_cheapest_gold()
					if stake.is_empty():
						_log("赌局：身上没有金币物件，庄家挥手让你走了。")
					elif map.rng.randf() < 0.5:
						pending.append(stake)
						pending.append(stake.duplicate(true))
						_log("赌局：赢！%s ×2 → 拾取区。" % String(stake["name"]))
						_float_text(map.player, "赢！×2", COL_CHEST)
					else:
						_log("赌局：输了，%s 被没收。" % String(stake["name"]))
						_float_text(map.player, "被没收…", Color("ff6a5c"))
				consume.call()
				_refresh())
		"行商":
			_show_choice("行商（可回访·以物易物占位）", ["用最便宜的金币物件换 药瓶×2", "换 大补汤×1", "离开"], func(idx: int) -> void:
				if idx <= 1:
					var pay: Dictionary = _take_cheapest_gold()
					if pay.is_empty():
						_log("行商：你没有金币物件可换。")
					else:
						if idx == 0:
							var potion: Dictionary = {"id": "potion", "name": "药瓶", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "单英雄 +1 HP", "icon": "potion"}
							pending.append(potion)
							pending.append(potion.duplicate(true))
							_log("行商：%s 换了药瓶×2 → 拾取区。" % String(pay["name"]))
						else:
							pending.append({"id": "soup", "name": "大补汤", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_2X1, "gold": 0, "note": "全队 +0.5 HP", "icon": "soup"})
							_log("行商：%s 换了大补汤 → 拾取区。" % String(pay["name"]))
				_refresh())
		"修补匠":
			_show_choice("修补匠：背包扩容", ["+1 行", "+1 列"], func(idx: int) -> void:
				var ok: bool = bp.expand_row() if idx == 0 else bp.expand_col()
				if not ok:
					var potion: Dictionary = {"id": "potion", "name": "药瓶", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "单英雄 +1 HP", "icon": "potion"}
					pending.append(potion)
					pending.append(potion.duplicate(true))
					_log("修补匠：已到 6×6 上限，改给药瓶×2 → 拾取区。")
				else:
					_log("修补匠：背包扩容！")
				consume.call()
				_refresh())
		"兽踪":
			var egg_at: Vector2i = map.mark_egg_chest()
			_log("兽踪：%s" % ("最远的宝箱里似乎有蛋（已标记）。" if egg_at.x >= 0 else "线索断了。"))
			consume.call()
		_:
			consume.call()


func _prompt_extract(tile: int) -> void:
	if not map.ext_open(tile):
		_log("这里不是本局可用的撤离点。")
		return
	var left_behind: int = pending.size() + (0 if held.is_empty() else 1)
	var warn: String = "\n⚠ 拾取区还有 %d 件没拼进背包——撤离即放弃！" % left_behind if left_behind > 0 else ""
	_show_choice("发现撤离点。现在撤离？%s" % warn, ["撤离结算", "再逛逛"], func(idx: int) -> void:
		if idx == 0:
			map.extract()
			_show_settlement()
		_refresh())


func _show_settlement() -> void:
	var r: Dictionary = map.result
	var text: String
	if String(r.get("outcome", "")) == "extract":
		var s: Dictionary = bp.settle_extract()
		var names: Array = []
		for it: Dictionary in s["goods"]:
			names.append(String(it["name"]))
		text = "【撤离成功】\n金币入钱包 %d\n带出：%s\n装备栏 %d 件为本局租用·未带出\n地图行动 %d 次·战斗 %d 胜" % [
			int(s["gold"]), "、".join(names) if not names.is_empty() else "无",
			int(s["equipment_lost"]), int(r["steps"]),
			int(r["battles"])]
	else:
		var s2: Dictionary = bp.settle_death()
		var kept: Array = []
		for it: Dictionary in s2["kept"]:
			kept.append(String(it["name"]))
		text = "【全灭】%s\n本局金币：全部丢失\n保险槽保住：%s\n其余 %d 件消失\n地图行动 %d 次·战斗 %d 胜" % [
			String(r.get("cause", "")),
			"、".join(kept) if not kept.is_empty() else "（保险槽是空的）",
			int(s2["lost_count"]) + pending.size(), int(r["steps"]), int(r["battles"])]
	_show_choice(text, ["再来一局", "返回主菜单"], func(idx: int) -> void:
		if idx == 0:
			seed_value = randi() % 1000000
			_toggle_backpack(false)
			_set_player_visual_visible(false)
			_set_atmosphere_active(false)
			select_overlay.visible = true   # 再来一局=重选初始英雄
		else:
			TransitionManager.transition_to(MENU_SCENE))


func _prompt_leave() -> void:
	if map.over:
		TransitionManager.transition_to(MENU_SCENE)
		return
	_show_choice("返回主菜单？（本局作废·不结算）", ["继续探索", "返回主菜单"], func(idx: int) -> void:
		if idx == 1:
			TransitionManager.transition_to(MENU_SCENE))


func _show_choice(text: String, options: Array, cb: Callable) -> void:
	# ⚠ 必须立刻 remove_child：queue_free 到帧尾才移除，连环弹窗（遭遇→死亡结算）会把
	# 旧按钮留在新弹窗里——点到旧"进战"= 对已消失的怪开战 = 脚本错卡死（Eddy 实测踩中）。
	for child: Node in dialog_box.get_children():
		dialog_box.remove_child(child)
		child.queue_free()
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate = COL_TEXT
	FontManager.apply(lbl, 16)
	dialog_box.add_child(lbl)
	for i: int in options.size():
		var btn := Button.new()
		btn.text = String(options[i])
		btn.custom_minimum_size = Vector2(560, 44)
		FontManager.apply_btn(btn, 16)
		_jelly_button(btn, COL_EXT_OPEN.darkened(0.15) if i == 0 else Color("6b5c43"))   # 首选=确认绿·其余暖中性
		var idx: int = i
		btn.pressed.connect(func() -> void:
			dialog.hide()
			cb.call(idx))
		dialog_box.add_child(btn)
	# ⚠ 必须延迟弹出：连环弹窗（遭遇→死亡结算）时 hide() 在按钮信号返回后才真生效，
	# 会把同帧的 popup_centered() 盖掉 → 结算弹窗永不出现 = 卡死（Eddy 实测第二病根）。
	call_deferred("_popup_and_focus")


func _popup_and_focus() -> void:
	dialog.reset_size()   # 先按新内容重算尺寸再居中（否则沿用旧尺寸·位置偏上）
	dialog.popup_centered()
	if dialog_box.get_child_count() > 1:
		(dialog_box.get_child(1) as Button).grab_focus()
