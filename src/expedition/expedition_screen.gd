## 远征模式主界面 —— 全屏大地图探索（2026-07-07 Eddy 定形态重构）。
##
## 流程：进入 → 选初始英雄（浮层）→ 进图（选地图步骤=待世界观拍板后加）。
## 形态：全屏=地图本身（⛔背景/衬底），HUD=两侧竖带信息条（不遮地图），
## 背包=按 B 唤出的整理浮层（背包格+拾取区+装备栏+保险槽同屏整理），
## 玩家=所选英雄的像素头像 token 在图上探索（移动左右摇摆·卡通感）。
## 设计规范：design/ui-design-system.md（全暖色系·暖骨框·Ark Pixel·⛔夜色衬底）。
## 规则源：design/expedition-map.md / expedition-backpack.md。逻辑层 = expedition_map_state / expedition_backpack_state。
##
## 操作：WASD/方向键移动 ｜ B 背包浮层 ｜ 浮层内：左键拾/放·R 旋转·右键放回·U 用消耗品·X 丢弃 ｜ ESC 关浮层/返回。
extends Control

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")
const PixelArt := preload("res://src/expedition/expedition_pixel_art.gd")
const ItemCatalog := preload("res://src/battle/item_catalog.gd")
const HeroDataScript := preload("res://src/battle/hero_data.gd")   # class_name 在 headless 可能未注册→走 preload
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const TERRAIN_SHADER := preload("res://assets/shaders/canvas_ui_expedition_terrain.gdshader")

const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 布局（1920×1080·地图居中全高·HUD 走两侧竖带·背包/选英雄=居中浮层）──
const MAP_CELL: int = 88
const MAP_ORIGIN := Vector2(432, 12)            # (1920 - 12*88)/2 = 432
const HUD_PANEL := Rect2(16, 16, 400, 330)      # 左上：行军
const LOG_PANEL := Rect2(16, 780, 400, 284)     # 左下：手记流水
const TEAM_PANEL := Rect2(1504, 16, 400, 220)   # 右上：队伍
const INFO_PANEL := Rect2(1504, 252, 400, 460)  # 右中：行囊状态 + 操作提示
# 背包浮层（居中·B 唤出）
const OV_PANEL := Rect2(340, 110, 1240, 860)
const BP_ORIGIN := Vector2(400, 240)
const BP_CELL: int = 52
# 选英雄浮层
const SEL_PANEL := Rect2(440, 140, 1040, 800)

# ── 色板（§2 令牌：暖骨框 / 暖米白字 / 语义色·全暖色系=Eddy 定·⛔夜色衬底）──
const COL_BG := Color("17110a")            # 全屏底（地图外两侧竖带）
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

const EQUIP_EFF_BONUS: float = 0.05        # 占位：每件装备 +0.05 拆解效率

var map: MapState
var bp: Backpack
var pending: Array = []            # 拾取区（待拼放·撤离不计入）
var held: Dictionary = {}          # {item, shape} 手上物品
var log_lines: Array = []
var seed_value: int = 0
var mouse_pos: Vector2
var pending_flee_from: Vector2i
var hero_portrait_path: String = ""   # 初始英雄头像（token 用·跨战斗寄存恢复）

var hud_label: Label
var team_label: Label
var log_label: Label
var info_label: Label
var pend_box: VBoxContainer
var equip_box: VBoxContainer
var insure_btn: Button
var dialog: PopupPanel
var dialog_box: VBoxContainer
var bp_overlay: Control            # 背包整理浮层（B 唤出）
var select_overlay: Control        # 选初始英雄浮层（进图前）
var player_token: TextureRect      # 英雄头像 token（摇摆动画在 _process）
var canvas: Control                # 顶层绘制画布（地图图签/背包格·必须压在面板填充之上）

# ── 地形层（数据纹理驱动·地表/迷雾/揭示全在 shader）──
var terrain_mat: ShaderMaterial
var _terrain_img: Image            # 12×12 RGBAF（R=地形类 G=已探明 B=探明时刻·预分配复用）
var _terrain_tex: ImageTexture
var _reveal_time: Dictionary = {}  # Vector2i -> float 探明时刻（负值=开局已探明不放动画）
var _anim_time: float = 0.0        # shader/token 统一时钟
var _token_tween: Tween            # token 移动补间（活跃时摇摆加大）


func _ready() -> void:
	seed_value = randi() % 1000000
	_build_ui()
	if not BattleSetup.expedition_state.is_empty():
		_resume_from_battle()   # 真战斗打完回图（任务 D）
	else:
		select_overlay.visible = true   # 正常入口：先选初始英雄


## 真战斗回图（任务 D·2026-07-06）：恢复跨场景寄存的跑动状态 + 消费战斗结果回写地图。
func _resume_from_battle() -> void:
	var st: Dictionary = BattleSetup.expedition_state
	BattleSetup.expedition_state = {}
	map = st["map"]
	bp = st["bp"]
	pending = st["pending"]
	log_lines = st["log"]
	seed_value = int(st["seed"])
	hero_portrait_path = String(st.get("hero_portrait", ""))
	held = {}
	_reveal_time.clear()   # 战斗回图：已探明格全盖负值 = 不重播翻显动画
	for c: Vector2i in map.revealed:
		_reveal_time[c] = -10.0
	terrain_mat.set_shader_parameter("seed_f", float(seed_value % 977))
	_apply_token_portrait()
	player_token.visible = true
	var r: Dictionary = BattleSetup.pve_result
	BattleSetup.pve_result = {}
	if r.is_empty():
		_log("战斗结果缺失——本次遭遇作废（防御兜底）。")
		_refresh()
		return
	var res: Dictionary = map.apply_battle_result(Vector2i(st["tile"]), bool(st["wanderer"]),
		String(r["outcome"]), int(r["beats"]), r["team_hp"], int(r["monster_hp"]), Vector2i(st["flee_from"]))
	match String(r["outcome"]):
		"win":
			pending.append_array(res["loot"])
			_log("战斗胜利（%d 拍·+%.1f 刻）！掉落 → 拾取区：%s" % [int(r["beats"]), float(int(r["beats"])) * 0.5, _loot_text(res["loot"])])
		"flee":
			_log("脱离战斗（挨了一拍），怪物驻留原格（血量保留）。")
		"lose":
			_log("队伍在战斗中全灭……")
	if map.over:
		_show_settlement()
	_refresh()


# ============================================================
# UI 构建（全屏地图 + 两侧 HUD 竖带 + 背包/选英雄浮层）
# ============================================================

func _build_ui() -> void:
	_make_terrain_layer()
	for r: Rect2 in [HUD_PANEL, LOG_PANEL, TEAM_PANEL, INFO_PANEL]:
		_make_panel(r, self)
	_label(HUD_PANEL.position + Vector2(20, 14), 16, "―― 行军 ――", self).modulate = COL_BONE
	hud_label = _label(HUD_PANEL.position + Vector2(20, 44), 16, "", self)
	hud_label.size = Vector2(HUD_PANEL.size.x - 40, HUD_PANEL.size.y - 60)
	_label(TEAM_PANEL.position + Vector2(20, 14), 16, "―― 队伍 ――", self).modulate = COL_BONE
	team_label = _label(TEAM_PANEL.position + Vector2(20, 44), 16, "", self)
	team_label.size = Vector2(TEAM_PANEL.size.x - 40, TEAM_PANEL.size.y - 60)
	_label(INFO_PANEL.position + Vector2(20, 14), 16, "―― 行囊手记 ――", self).modulate = COL_BONE
	info_label = _label(INFO_PANEL.position + Vector2(20, 44), 16, "", self)
	info_label.size = Vector2(INFO_PANEL.size.x - 40, INFO_PANEL.size.y - 60)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label = _label(LOG_PANEL.position + Vector2(20, 14), 16, "", self)
	log_label.size = LOG_PANEL.size - Vector2(40, 28)
	log_label.modulate = COL_TEXT_DIM
	_build_backpack_overlay()
	# 绘制画布压在面板/浮层之上（IGNORE 不吞点击·根 _gui_input 收背包点击）
	canvas = Control.new()
	canvas.name = "DrawCanvas"
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_canvas)
	add_child(canvas)
	# 英雄头像 token（摇摆动画）：pivot 设脚底中心 = 不倒翁式左右摇。
	# 必须压在 canvas 图签之上（否则起点帐篷等同格图签会盖住头像）；浮层/选人期间隐藏。
	player_token = TextureRect.new()
	player_token.name = "PlayerToken"
	player_token.size = Vector2(64, 64)
	player_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_token.stretch_mode = TextureRect.STRETCH_SCALE
	player_token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素头像放大保硬边
	player_token.pivot_offset = Vector2(32, 64)
	player_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_token.visible = false   # 进图（_new_run）才现身
	add_child(player_token)
	_build_select_overlay()   # 选英雄浮层压最上（含按钮·必须在 canvas 之上可点）
	dialog = PopupPanel.new()
	dialog.exclusive = true   # 点外部不可关——防"死亡结算被点掉→movement 封锁看似卡死"
	dialog_box = VBoxContainer.new()
	dialog_box.custom_minimum_size = Vector2(560, 0)
	dialog.add_child(dialog_box)
	add_child(dialog)


## 地形+迷雾程序母题层（数据纹理驱动·单节点渲染 12×12）：地板三味/墙斜面/迷雾缓流/揭示翻显。
## 图签仍走 canvas 顶层绘制（本层只管地表）。美术期换地形贴图 = 换本节点渲染方式，数据接口可续用。
func _make_terrain_layer() -> void:
	var t := ColorRect.new()
	t.name = "TerrainLayer"
	t.position = MAP_ORIGIN
	t.size = Vector2(MapState.SIZE * MAP_CELL, MapState.SIZE * MAP_CELL)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_img = Image.create(MapState.SIZE, MapState.SIZE, false, Image.FORMAT_RGBAF)
	_terrain_tex = ImageTexture.create_from_image(_terrain_img)
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	terrain_mat.set_shader_parameter("map_data", _terrain_tex)
	terrain_mat.set_shader_parameter("grid_n", float(MapState.SIZE))
	terrain_mat.set_shader_parameter("cell_px", float(MAP_CELL))
	t.material = terrain_mat
	add_child(t)


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
	insure_btn = _button(Vector2(BP_ORIGIN.x, 620), Vector2(320, 36), "", _on_insure_clicked, bp_overlay)
	var grow_row := HBoxContainer.new()
	grow_row.position = Vector2(BP_ORIGIN.x, 668)
	bp_overlay.add_child(grow_row)
	for cfg: Array in [["扩容+1行", true], ["扩容+1列", false]]:
		var b := Button.new()
		b.text = String(cfg[0])
		FontManager.apply_btn(b, 16)
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
	_button(Vector2(1200, OV_PANEL.position.y + 100), Vector2(350, 36), "把手上的战斗道具装上", _on_equip_clicked, bp_overlay)
	equip_box = VBoxContainer.new()
	equip_box.position = Vector2(1200, OV_PANEL.position.y + 148)
	equip_box.custom_minimum_size = Vector2(350, 0)
	bp_overlay.add_child(equip_box)


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


## 选定初始英雄 → 开局。头像成为地图 token；队首名字用真英雄名。
func _on_hero_selected(h: HeroData) -> void:
	hero_portrait_path = h.portrait_path
	select_overlay.visible = false
	_new_run(seed_value, h.hero_name)
	_apply_token_portrait()


func _apply_token_portrait() -> void:
	if hero_portrait_path != "" and ResourceLoader.exists(hero_portrait_path):
		player_token.texture = load(hero_portrait_path)
	else:
		player_token.texture = PixelArt.get_texture("flag", COL_PLAYER, 64)


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

func _new_run(p_seed: int, leader_name: String = "") -> void:
	seed_value = p_seed
	map = MapState.new()
	map.setup(p_seed)
	if leader_name != "":
		map.team[0]["name"] = leader_name   # 初始英雄=队首（HP 骨架不变·数值待 H 拍板）
	bp = Backpack.new()
	pending = []
	held = {}
	log_lines = []
	_reveal_time.clear()   # 开局已探明格在首次 _refresh 盖当前钟 → 起手播一段翻显（地图"浮现"）
	terrain_mat.set_shader_parameter("seed_f", float(p_seed % 977))
	player_token.visible = true
	_log("踏入迷雾（种子 %d）。补给 %d·撤1 已开。" % [p_seed, map.supplies])
	_refresh()


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 9:
		log_lines.pop_front()


func _eff_bonus() -> float:
	return EQUIP_EFF_BONUS * float(bp.equipment.size())


func _refresh() -> void:
	if map == null:
		return
	var s: String = "补给 %d%s\n" % [map.supplies, "（饥饿！）" if map.supplies <= 0 else ""]
	s += "刻 %.1f    危险度 D%d/%d%s\n" % [map.ticks(), map.danger(), MapState.D_CAP, "·游荡怪！" if map.wanderer != Vector2i(-1, -1) else ""]
	s += "\n撤1（近）%s\n撤2（中）%s\n撤3（深）永不关闭" % [_ext_text(MapState.Tile.EXT1), _ext_text(MapState.Tile.EXT2)]
	hud_label.text = s
	var ts: String = ""
	for h: Dictionary in map.team:
		var hp: float = float(h["hp"])
		ts += "%s\nHP %.1f/%.1f%s\n" % [String(h["name"]), maxf(0.0, hp), float(h["hp_max"]), "（倒下）" if hp <= 0.0 else ""]
	team_label.text = ts
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
	var used: int = 0
	for p: Dictionary in bp.placements:
		used += (p["shape"] as Array).size()
	info_label.text = "手上：%s\n拾取区待整理 %d 件\n\n背包 %d×%d·占用 %d/%d\n包内金币 %d\n装备 %d 件（效率 +%.2f）\n战斗 %d 胜·步数 %d\n\n移动 WASD/方向键\n背包 B（拾/放·旋转·装备）\n返回 ESC\n\n⚠ 拾取区的东西\n不拼进背包=带不走" % [
		String(held["item"]["name"]) if not held.is_empty() else "空", pending.size(),
		bp.cols, bp.rows, used, bp.rows * bp.cols, bp.gold_total(),
		bp.equipment.size(), _eff_bonus(), map.battles_won, map.steps]
	log_label.text = "\n".join(log_lines)
	_update_terrain_data()
	_update_token_position()
	canvas.queue_redraw()


## 把地图状态写进数据纹理（R=地形类 0地板/1墙 · G=已探明 · B=探明时刻）——shader 据此渲染。
## 新探明格在此处盖时间戳（与 _anim_time 同钟）→ shader 播逐块翻显。
func _update_terrain_data() -> void:
	if map == null or _terrain_img == null:
		return
	for y: int in MapState.SIZE:
		for x: int in MapState.SIZE:
			var c := Vector2i(x, y)
			var rev: bool = map.revealed.has(c)
			if rev and not _reveal_time.has(c):
				_reveal_time[c] = _anim_time
			var tile_v: float = 1.0 if map.grid[y][x] == MapState.Tile.WALL else 0.0
			_terrain_img.set_pixel(x, y, Color(tile_v, 1.0 if rev else 0.0, float(_reveal_time.get(c, 0.0)), 1.0))
	_terrain_tex.update(_terrain_img)


## token 跟随玩家格（补间移动·摇摆在 _process）。
func _update_token_position() -> void:
	if map == null:
		return
	var target: Vector2 = MAP_ORIGIN + Vector2(map.player.x * MAP_CELL, map.player.y * MAP_CELL) + Vector2(11.0, 8.0)
	if player_token.position == target:
		return
	if _token_tween != null and _token_tween.is_valid():
		_token_tween.kill()
	_token_tween = create_tween()
	_token_tween.tween_property(player_token, "position", target, 0.14).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_anim_time += delta
	if terrain_mat != null:
		terrain_mat.set_shader_parameter("anim_time", _anim_time)
	if player_token != null and player_token.texture != null:
		# 卡通摇摆：移动中大摆（前进的左右晃）·驻足小摆（idle 呼吸）
		var moving: bool = _token_tween != null and _token_tween.is_valid() and _token_tween.is_running()
		var amp: float = 0.16 if moving else 0.05
		var freq: float = 10.0 if moving else 2.2
		player_token.rotation = sin(_anim_time * freq) * amp


func _ext_text(tile: int) -> String:
	var t: float = map.ticks()
	match tile:
		MapState.Tile.EXT1:
			return "开放·%.0f 刻后关" % (MapState.EXT1_CLOSE - t) if t < MapState.EXT1_CLOSE else "已关闭"
		MapState.Tile.EXT2:
			if t < MapState.EXT2_OPEN:
				return "%.0f 刻后开" % (MapState.EXT2_OPEN - t)
			return "开放·%.0f 刻后关" % (MapState.EXT2_CLOSE - t) if t < MapState.EXT2_CLOSE else "已关闭"
	return ""


# ============================================================
# 绘制（地图图签 + 背包浮层格子 + 手上幽灵）
# ============================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)


## 顶层画布绘制（canvas.draw 信号）：地图图签 + 浮层背包格 + 手上幽灵（地表/迷雾=TerrainLayer shader）。
func _draw_canvas() -> void:
	if map == null:
		return
	var f16: Font = FontManager.f16
	var f12: Font = FontManager.f12
	var icon_sz := Vector2(64, 64)
	if bp_overlay.visible:
		_draw_backpack_layer(f16)   # 浮层开着只画背包（地图图签停画·防穿透浮层面板）
		return
	for y: int in MapState.SIZE:
		for x: int in MapState.SIZE:
			var c := Vector2i(x, y)
			if not map.revealed.has(c):
				continue
			var tile: int = map.grid[y][x]
			if tile == MapState.Tile.WALL:
				continue
			var rect := Rect2(MAP_ORIGIN + Vector2(x * MAP_CELL, y * MAP_CELL), Vector2(MAP_CELL - 2, MAP_CELL - 2))
			var icon_rect := Rect2(rect.position + Vector2(11, 11), icon_sz)
			match tile:
				MapState.Tile.START:
					PixelArt.draw_icon(canvas, "tent", icon_rect, COL_BONE)
				MapState.Tile.MONSTER:
					var m: Dictionary = map.monsters.get(c, {})
					var tier: int = int(m.get("tier", 1))
					var micon: String = "paw" if tier == 1 else ("fang" if tier == 2 else "horns")
					PixelArt.draw_icon(canvas, micon, icon_rect, COL_MONSTER)
					if bool(m.get("resolved", false)):
						canvas.draw_string(f12, rect.position + Vector2(rect.size.x - 18, 20), "†", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT)
				MapState.Tile.EVENT:
					canvas.draw_string(f16, rect.position + Vector2(rect.size.x * 0.5 - 16, rect.size.y * 0.5 + 12), "？", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, COL_EVENT)
				MapState.Tile.CHEST:
					if bool(map.chests.get(c, {}).get("egg", false)):
						PixelArt.draw_icon(canvas, "egg", icon_rect, COL_PLAYER)
					else:
						PixelArt.draw_icon(canvas, "chest", icon_rect, COL_CHEST)
				MapState.Tile.EXT1, MapState.Tile.EXT2, MapState.Tile.EXT3:
					var ecol: Color = COL_EXT_OPEN if map.ext_open(tile) else COL_EXT_CLOSED
					PixelArt.draw_icon(canvas, "arch", icon_rect, ecol)
					canvas.draw_string(f12, rect.position + Vector2(rect.size.x - 18, rect.size.y - 8), str(tile - MapState.Tile.EXT1 + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ecol)
	if map.wanderer != Vector2i(-1, -1) and map.revealed.has(map.wanderer):
		var wr := MAP_ORIGIN + Vector2(map.wanderer.x * MAP_CELL, map.wanderer.y * MAP_CELL)
		PixelArt.draw_icon(canvas, "eye", Rect2(wr + Vector2(11, 11), icon_sz), Color("ff6a5c"))
	# 当前格亮金描边（token 之下的落脚提示）
	var pr := Rect2(MAP_ORIGIN + Vector2(map.player.x * MAP_CELL, map.player.y * MAP_CELL), Vector2(MAP_CELL - 2, MAP_CELL - 2))
	canvas.draw_rect(pr, COL_PLAYER, false, 3.0)


## 背包浮层绘制（格子/放置/手上幽灵）——仅浮层可见时由 _draw_canvas 调用。
func _draw_backpack_layer(f16: Font) -> void:
	for y: int in bp.rows:
		for x: int in bp.cols:
			var rect := Rect2(BP_ORIGIN + Vector2(x * BP_CELL, y * BP_CELL), Vector2(BP_CELL - 3, BP_CELL - 3))
			canvas.draw_rect(rect, Color("1a1409"))
			canvas.draw_rect(rect, Color("3a3226"), false, 1.0)
	for p: Dictionary in bp.placements:
		var it: Dictionary = p["item"]
		var col: Color = _cat_color(String(it["cat"]))
		for off: Vector2i in p["shape"]:
			var c: Vector2i = Vector2i(p["anchor"]) + off
			var cell_rect := Rect2(BP_ORIGIN + Vector2(c.x * BP_CELL, c.y * BP_CELL), Vector2(BP_CELL - 3, BP_CELL - 3))
			canvas.draw_rect(cell_rect, col.darkened(0.35))
			canvas.draw_rect(cell_rect, col, false, 1.0)
		var a: Vector2i = p["anchor"]
		canvas.draw_texture_rect(_item_texture(it), Rect2(BP_ORIGIN + Vector2(a.x * BP_CELL + 4, a.y * BP_CELL + 4), Vector2(BP_CELL - 11, BP_CELL - 11)), false)
	if not held.is_empty():
		var cell: Vector2i = _bp_cell_at(mouse_pos)
		var shape: Array = held["shape"]
		if cell.x >= 0:
			var ok: bool = bp.can_place(shape, cell)
			for off: Vector2i in shape:
				var c: Vector2i = cell + off
				canvas.draw_rect(Rect2(BP_ORIGIN + Vector2(c.x * BP_CELL, c.y * BP_CELL), Vector2(BP_CELL - 3, BP_CELL - 3)), COL_OK if ok else COL_BAD)
		else:
			for off: Vector2i in shape:
				canvas.draw_rect(Rect2(mouse_pos + Vector2(off.x, off.y) * BP_CELL * 0.6, Vector2(BP_CELL, BP_CELL) * 0.55), Color(_cat_color(String(held["item"]["cat"])), 0.7))
			canvas.draw_texture_rect(_item_texture(held["item"]), Rect2(mouse_pos + Vector2(2, 2), Vector2(BP_CELL, BP_CELL) * 0.5), false)
		canvas.draw_string(f16, mouse_pos + Vector2(20, -12), String(held["item"]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_TEXT)


## 物品图标：战斗道具优先用真 PvP 图标（ItemCatalog·61 张现役素材），缺图/其余回退像素图签。
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
	if not show_it and not held.is_empty():
		pending.append(held["item"])
		held = {}
	bp_overlay.visible = show_it
	player_token.visible = not show_it and map != null   # 浮层期间藏 token（否则浮在暗幕上）
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not bp_overlay.visible or map == null:
		return
	if event is InputEventMouseMotion:
		mouse_pos = (event as InputEventMouseMotion).position
		if not held.is_empty():
			canvas.queue_redraw()
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
			canvas.queue_redraw()
		elif key == KEY_X and not held.is_empty():
			_log("丢弃了 %s。" % String(held["item"]["name"]))
			held = {}
			_refresh()
		elif key == KEY_U and not held.is_empty():
			_use_held()
		return   # 浮层开着不移动
	if map.over:
		return
	var dir := Vector2i.ZERO
	match key:
		KEY_W, KEY_UP: dir = Vector2i.UP
		KEY_S, KEY_DOWN: dir = Vector2i.DOWN
		KEY_A, KEY_LEFT: dir = Vector2i.LEFT
		KEY_D, KEY_RIGHT: dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO:
		return
	var prev: Vector2i = map.player
	var res: Dictionary = map.try_move(dir)
	for m: String in res.get("msgs", []):
		_log(m)
	match String(res["kind"]):
		"death":
			_show_settlement()
		"monster":
			pending_flee_from = prev
			_prompt_monster(map.player)
		"wanderer":
			pending_flee_from = prev
			_enter_real_battle(Vector2i(-1, -1), true)   # 游荡怪强制遭遇=真战斗（可战中脱离）
		"event":
			_run_event(map.player)
		"chest":
			var loot: Array = map.open_chest(map.player)
			pending.append_array(loot)
			_log("开箱：%s → 拾取区。" % _loot_text(loot))
		"ext":
			_prompt_extract(map.grid[map.player.y][map.player.x])
	_refresh()


func _use_held() -> void:
	var it: Dictionary = held["item"]
	if String(it["cat"]) != "consumable":
		_log("%s 不是消耗品。" % String(it["name"]))
		return
	match String(it["id"]):
		"ration":
			map.add_supplies(10)
			_log("吃掉干粮：补给 +10。")
		"potion":
			map.heal_front(1.0)
			_log("药瓶：前排 +1 HP。")
		"soup":
			map.heal_all(0.5)
			_log("大补汤：全队 +0.5 HP。")
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
		_log("装上 %s（效率 +%.2f）。" % [String(held["item"]["name"]), EQUIP_EFF_BONUS])
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


## 从背包/拾取区消耗一件指定 id 的消耗品（陷阱干粮抵）。成功 true。
func _consume_item(id: String) -> bool:
	for i: int in pending.size():
		if String(pending[i]["id"]) == id:
			pending.remove_at(i)
			return true
	for p: Dictionary in bp.placements:
		if String(p["item"]["id"]) == id:
			bp.placements.erase(p)
			return true
	return false


# ============================================================
# 战斗 / 事件 / 结算
# ============================================================

func _prompt_monster(c: Vector2i) -> void:
	var m: Dictionary = map.resolve_encounter(c)
	_show_choice("遭遇 %s（T%d·HP %.0f）— 明牌可读" % [String(m["name"]), int(m["tier"]), float(m["hp"])], [
		"进战（真实战斗）",
		"避战（挨一拍 %.1f HP·退回）" % (0.5 * float(m["tier"])),
	], func(idx: int) -> void:
		if idx == 0:
			_enter_real_battle(c, false)
		else:
			var report: Dictionary = map.flee(c, pending_flee_from)
			_log("避战：挨 %s 一拍（-%.1f HP），怪驻留原格。" % [String(report["name"]), float(report["dmg"])])
			if bool(report.get("death", false)):
				_show_settlement()
		_refresh())


## 进真战斗（任务 D）：跑动状态寄存 BattleSetup → 波幕转场 battle_screen（怪物驾驶员对手·明牌）。
## 无完整策略定义的占位实体（巢穴怪）回退占位自动结算。
func _enter_real_battle(c: Vector2i, is_wanderer: bool) -> void:
	var m: Dictionary = map.wanderer_encounter() if is_wanderer else map.resolve_encounter(c)
	if (m.get("def", {}) as Dictionary).is_empty():
		_after_battle(map.fight(c, _eff_bonus()))
		_refresh()
		return
	if not held.is_empty():
		pending.append(held["item"])   # 手上物品放回拾取区（不跨场景带手）
		held = {}
	BattleSetup.pve_mode = true
	BattleSetup.pve_monster = m["def"]
	BattleSetup.pve_monster_hp = int(round(float(m["hp"]) * 2.0))
	var team_snapshot: Array = []
	for h: Dictionary in map.team:
		if float(h["hp"]) > 0.0:
			team_snapshot.append({"name": String(h["name"]), "hp": int(round(float(h["hp"]) * 2.0)), "hp_max": int(round(float(h["hp_max"]) * 2.0))})
	BattleSetup.pve_team = team_snapshot
	var eq: Array = []
	for it: Dictionary in bp.equipment:
		if String(it.get("combat_id", "")) != "":
			eq.append(String(it["combat_id"]))
	BattleSetup.pve_equipment = eq
	BattleSetup.expedition_state = {"map": map, "bp": bp, "pending": pending, "log": log_lines,
		"seed": seed_value, "tile": c, "wanderer": is_wanderer, "flee_from": pending_flee_from,
		"hero_portrait": hero_portrait_path}
	TransitionManager.transition_to("res://src/ui/battle_screen.tscn")


func _after_battle(report: Dictionary) -> void:
	if bool(report.get("death", false)):
		_log("倒在 %s 面前……" % String(report["name"]))
		_show_settlement()
		return
	pending.append_array(report["loot"])
	_log("击败 %s：%d 拍·受伤 %.1f。掉落 → 拾取区：%s" % [String(report["name"]), int(report["beats"]), float(report["dmg"]), _loot_text(report["loot"])])


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
			var hero_name: String = map.recruit()
			if hero_name != "":
				_log("篝火·招募：%s 加入！" % hero_name)
			else:
				map.heal_all(0.5)
				_log("篝火·休整：队伍已满，全队 +0.5 HP。")
			consume.call()
		"清泉":
			_show_choice("清泉：选一种饮法", ["单英雄 +1 HP（前排）", "全队 +0.5 HP"], func(idx: int) -> void:
				if idx == 0:
					map.heal_front(1.0)
				else:
					map.heal_all(0.5)
				_log("清泉：恢复完成。")
				consume.call()
				_refresh())
		"陷阱":
			if _has_item("ration"):
				_show_choice("陷阱！", ["用 1 干粮抵掉", "硬吃：补给 -5"], func(idx: int) -> void:
					if idx == 0:
						_consume_item("ration")
						_log("陷阱：丢干粮抵掉。")
					else:
						map.supplies = maxi(0, map.supplies - 5)
						_log("陷阱：补给 -5。")
					consume.call()
					_refresh())
			else:
				map.supplies = maxi(0, map.supplies - 5)
				_log("陷阱：补给 -5（无干粮可抵）。")
				consume.call()
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
					else:
						_log("赌局：输了，%s 被没收。" % String(stake["name"]))
				consume.call()
				_refresh())
		"行商":
			_show_choice("行商（可回访·以物易物占位）", ["用最便宜的金币物件换 干粮×2", "换 药瓶×1", "离开"], func(idx: int) -> void:
				if idx <= 1:
					var pay: Dictionary = _take_cheapest_gold()
					if pay.is_empty():
						_log("行商：你没有金币物件可换。")
					else:
						if idx == 0:
							var r1: Dictionary = {"id": "ration", "name": "干粮", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "+10 补给", "icon": "ration"}
							pending.append(r1)
							pending.append(r1.duplicate(true))
							_log("行商：%s 换了干粮×2 → 拾取区。" % String(pay["name"]))
						else:
							pending.append({"id": "potion", "name": "药瓶", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "单英雄 +1 HP", "icon": "potion"})
							_log("行商：%s 换了药瓶 → 拾取区。" % String(pay["name"]))
				_refresh())
		"巢穴":
			_show_choice("巢穴：连战 2 场（高危高掉落）", ["清巢！", "绕开"], func(idx: int) -> void:
				if idx == 0:
					for i: int in 2:
						if map.over:
							break
						map.monsters[c] = {"key": "nest", "name": "巢中怪", "tier": 2, "hp": 8.0, "hp_max": 8.0, "resolved": false}
						map.grid[c.y][c.x] = MapState.Tile.MONSTER
						_after_battle(map.fight(c, _eff_bonus()))
						if map.over:
							return
					_log("巢穴清空！")
				consume.call()
				_refresh())
		"修补匠":
			_show_choice("修补匠：背包扩容", ["+1 行", "+1 列"], func(idx: int) -> void:
				var ok: bool = bp.expand_row() if idx == 0 else bp.expand_col()
				if not ok:
					pending.append({"id": "ration", "name": "干粮", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "+10 补给", "icon": "ration"})
					pending.append({"id": "ration", "name": "干粮", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "+10 补给", "icon": "ration"})
					_log("修补匠：已到 6×6 上限，改给干粮×2 → 拾取区。")
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


func _has_item(id: String) -> bool:
	for it: Dictionary in pending:
		if String(it["id"]) == id:
			return true
	for p: Dictionary in bp.placements:
		if String(p["item"]["id"]) == id:
			return true
	return false


func _prompt_extract(tile: int) -> void:
	var idx_num: int = tile - MapState.Tile.EXT1 + 1
	if not map.ext_open(tile):
		_log("撤%d 已关闭/未开放。" % idx_num)
		return
	var left_behind: int = pending.size() + (0 if held.is_empty() else 1)
	var warn: String = "\n⚠ 拾取区还有 %d 件没拼进背包——撤离即放弃！" % left_behind if left_behind > 0 else ""
	_show_choice("撤%d 开放中：现在撤离？%s" % [idx_num, warn], ["撤离结算", "再逛逛"], func(idx: int) -> void:
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
		text = "【撤离成功】\n金币入钱包 %d\n带出：%s\n装备栏 %d 件为本局租用·未带出\n刻 %.1f（目标带 60-100：%s）·战斗 %d 胜" % [
			int(s["gold"]), "、".join(names) if not names.is_empty() else "无",
			int(s["equipment_lost"]), float(r["ticks"]), "落带" if bool(r.get("in_band", false)) else "出带",
			int(r["battles"])]
	else:
		var s2: Dictionary = bp.settle_death()
		var kept: Array = []
		for it: Dictionary in s2["kept"]:
			kept.append(String(it["name"]))
		text = "【全灭】%s\n金币保底（30%%）：%d\n保险槽保住：%s\n其余 %d 件消失\n刻 %.1f·战斗 %d 胜" % [
			String(r.get("cause", "")), int(s2["gold"]),
			"、".join(kept) if not kept.is_empty() else "（保险槽是空的）",
			int(s2["lost_count"]) + pending.size(), float(r["ticks"]), int(r["battles"])]
	_show_choice(text, ["再来一局", "返回主菜单"], func(idx: int) -> void:
		if idx == 0:
			seed_value = randi() % 1000000
			_toggle_backpack(false)
			player_token.visible = false
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
		FontManager.apply_btn(btn, 16)
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
