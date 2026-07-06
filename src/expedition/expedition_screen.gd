## 远征模式主界面（先行版）——地图探索 + 形状背包一体屏。
##
## 设计规范：design/ui-design-system.md（暖色深底 + 暖骨像素框 + Ark Pixel + 暖米白字·⛔夜色衬底已去=Eddy 2026-07-06 定）。
## 规则源：design/expedition-map.md / expedition-backpack.md。逻辑层 = expedition_map_state / expedition_backpack_state。
## ⚠ 战斗 = 占位自动结算（先知效率带·装备每件 +0.05 效率占位钩子）——真战斗接入 = 后续任务。
##
## 操作：WASD/方向键移动 ｜ 左键拾/放 ｜ R 旋转 ｜ 右键放回拾取区 ｜ U 用手上消耗品 ｜ X 丢弃 ｜ ESC 返回。
extends Control

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")

const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 布局（1920×1080）──
const MAP_PANEL := Rect2(64, 110, 700, 700)
const MAP_ORIGIN := Vector2(78, 124)
const MAP_CELL: int = 56
const LOG_PANEL := Rect2(64, 830, 700, 210)
const HUD_PANEL := Rect2(796, 110, 350, 400)
const BP_PANEL := Rect2(796, 530, 350, 510)
const BP_ORIGIN := Vector2(824, 596)
const BP_CELL: int = 44
const PEND_PANEL := Rect2(1166, 110, 350, 560)
const EQUIP_PANEL := Rect2(1166, 690, 350, 350)
const INFO_PANEL := Rect2(1536, 110, 320, 930)

# ── 色板（§2 令牌：暖骨框 / 暖米白字 / 语义色·全暖色系=Eddy 定·⛔不用夜色衬底）──
const COL_BG := Color("17110a")            # 暖色深底衬底（比面板更沉一档）
const COL_PANEL := Color("241c12")         # 暖色深底面板
const COL_TEXT := Color(0.95, 0.91, 0.80)  # 暖米白（禁纯白）
const COL_TEXT_DIM := Color(0.72, 0.68, 0.58)
const COL_FLOOR := Color("2e2417")
const COL_WALL := Color("15100a")
const COL_FOG := Color("0d0a06")           # 迷雾=近黑暖调（随全暖色系·⛔冷靛已去）
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

var hud_label: Label
var log_label: Label
var info_label: Label
var pend_box: VBoxContainer
var equip_box: VBoxContainer
var insure_btn: Button
var dialog: PopupPanel
var dialog_box: VBoxContainer
var canvas: Control   # 顶层绘制画布（地图/背包格·必须压在面板填充之上）


func _ready() -> void:
	seed_value = randi() % 1000000
	_build_ui()
	_new_run(seed_value)


# ============================================================
# UI 构建（暖骨框面板 + Ark Pixel）
# ============================================================

func _build_ui() -> void:
	for r: Rect2 in [MAP_PANEL, LOG_PANEL, HUD_PANEL, BP_PANEL, PEND_PANEL, EQUIP_PANEL, INFO_PANEL]:
		_make_panel(r)
	var title := _label(Vector2(64, 40), 32, "远征 · 先行版")
	title.modulate = COL_PLAYER
	_label(Vector2(360, 52), 16, "搜打撤：找到战利品·拼进背包·活着撤离").modulate = COL_TEXT_DIM
	_label(HUD_PANEL.position + Vector2(20, 14), 16, "―― 行军 ――").modulate = COL_BONE
	hud_label = _label(HUD_PANEL.position + Vector2(20, 44), 16, "")
	hud_label.size = Vector2(HUD_PANEL.size.x - 40, HUD_PANEL.size.y - 60)
	_label(BP_PANEL.position + Vector2(20, 14), 16, "―― 背包（撤离只带走包里的）――").modulate = COL_BONE
	insure_btn = _button(BP_PANEL.position + Vector2(20, BP_PANEL.size.y - 130), Vector2(BP_PANEL.size.x - 40, 36), "", _on_insure_clicked)
	var grow_row := HBoxContainer.new()
	grow_row.position = BP_PANEL.position + Vector2(20, BP_PANEL.size.y - 84)
	add_child(grow_row)
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
	_label(PEND_PANEL.position + Vector2(20, 14), 16, "―― 拾取区（点击拾起·不拼进包=带不走）――").modulate = COL_BONE
	var scroll := ScrollContainer.new()
	scroll.position = PEND_PANEL.position + Vector2(16, 46)
	scroll.size = PEND_PANEL.size - Vector2(32, 62)
	add_child(scroll)
	pend_box = VBoxContainer.new()
	pend_box.custom_minimum_size = Vector2(PEND_PANEL.size.x - 56, 0)
	scroll.add_child(pend_box)
	_label(EQUIP_PANEL.position + Vector2(20, 14), 16, "―― 装备栏（战斗+效率·撤离不带出）――").modulate = COL_BONE
	_button(EQUIP_PANEL.position + Vector2(20, 44), Vector2(EQUIP_PANEL.size.x - 40, 36), "把手上的战斗道具装上", _on_equip_clicked)
	equip_box = VBoxContainer.new()
	equip_box.position = EQUIP_PANEL.position + Vector2(20, 92)
	equip_box.custom_minimum_size = Vector2(EQUIP_PANEL.size.x - 40, 0)
	add_child(equip_box)
	_label(INFO_PANEL.position + Vector2(20, 14), 16, "―― 行囊手记 ――").modulate = COL_BONE
	info_label = _label(INFO_PANEL.position + Vector2(20, 44), 16, "")
	info_label.size = Vector2(INFO_PANEL.size.x - 40, INFO_PANEL.size.y - 60)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label = _label(LOG_PANEL.position + Vector2(20, 14), 16, "")
	log_label.size = LOG_PANEL.size - Vector2(40, 28)
	log_label.modulate = COL_TEXT_DIM
	# 绘制画布最后加 = 压在所有面板填充之上（IGNORE 不吞点击·根 _gui_input 收背包点击）
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_canvas)
	add_child(canvas)
	dialog = PopupPanel.new()
	dialog.exclusive = true   # 点外部不可关——防"死亡结算被点掉→movement 封锁看似卡死"
	dialog_box = VBoxContainer.new()
	dialog_box.custom_minimum_size = Vector2(560, 0)
	dialog.add_child(dialog_box)
	add_child(dialog)


## 暖骨框面板 = 暖色深底填充 + 像素框（§2.1 配方·装饰节点必 IGNORE 防吞点击）。
func _make_panel(r: Rect2) -> void:
	var fill := ColorRect.new()
	fill.position = r.position
	fill.size = r.size
	fill.color = COL_PANEL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
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
	add_child(frame)


func _label(pos: Vector2, px: int, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.modulate = COL_TEXT
	FontManager.apply(l, px)
	add_child(l)
	return l


func _button(pos: Vector2, sz: Vector2, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	FontManager.apply_btn(b, 16)
	b.pressed.connect(cb)
	add_child(b)
	return b


# ============================================================
# 一局流程
# ============================================================

func _new_run(p_seed: int) -> void:
	seed_value = p_seed
	map = MapState.new()
	map.setup(p_seed)
	bp = Backpack.new()
	pending = []
	held = {}
	log_lines = []
	_log("踏入迷雾（种子 %d）。补给 %d·撤1 已开。" % [p_seed, map.supplies])
	_refresh()


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 9:
		log_lines.pop_front()


func _eff_bonus() -> float:
	return EQUIP_EFF_BONUS * float(bp.equipment.size())


func _refresh() -> void:
	var s: String = "补给 %d%s\n" % [map.supplies, "（饥饿！）" if map.supplies <= 0 else ""]
	s += "刻 %.1f    危险度 D%d/%d%s\n" % [map.ticks(), map.danger(), MapState.D_CAP, "·游荡怪！" if map.wanderer != Vector2i(-1, -1) else ""]
	s += "\n撤1（近）%s\n撤2（中）%s\n撤3（深）永不关闭\n\n" % [_ext_text(MapState.Tile.EXT1), _ext_text(MapState.Tile.EXT2)]
	for h: Dictionary in map.team:
		var hp: float = float(h["hp"])
		s += "%s  HP %.1f/%.1f%s\n" % [String(h["name"]), maxf(0.0, hp), float(h["hp_max"]), "（倒下）" if hp <= 0.0 else ""]
	hud_label.text = s
	for child: Node in pend_box.get_children():
		child.queue_free()
	for i: int in pending.size():
		var it: Dictionary = pending[i]
		var b := Button.new()
		var sz: Vector2i = Loot.shape_size(it["shape"])
		b.text = "%s [%d×%d] %s" % [String(it["name"]), sz.x, sz.y, String(it.get("note", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		FontManager.apply_btn(b, 16)
		var idx: int = i
		b.pressed.connect(func() -> void: _pick_from_pending(idx))
		pend_box.add_child(b)
	for child: Node in equip_box.get_children():
		child.queue_free()
	for i: int in bp.equipment.size():
		var it: Dictionary = bp.equipment[i]
		var b := Button.new()
		b.text = "⚔ %s（点击卸下）" % String(it["name"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		FontManager.apply_btn(b, 16)
		var idx: int = i
		b.pressed.connect(func() -> void: _unequip(idx))
		equip_box.add_child(b)
	insure_btn.text = "保险槽（≤2×2·死亡保留）：%s" % (String(bp.insurance["name"]) if not bp.insurance.is_empty() else "空")
	var used: int = 0
	for p: Dictionary in bp.placements:
		used += (p["shape"] as Array).size()
	info_label.text = "手上：%s\n\n背包 %d×%d·占用 %d/%d\n包内金币 %d\n装备 %d 件（效率 +%.2f）\n战斗 %d 胜·步数 %d\n\n移动 WASD/方向键\n拾起/放下 左键\n旋转 R·放回 右键\n用消耗品 U·丢弃 X\n返回 ESC\n\n⚠ 拾取区的东西\n不拼进背包=带不走" % [
		String(held["item"]["name"]) if not held.is_empty() else "空",
		bp.cols, bp.rows, used, bp.rows * bp.cols, bp.gold_total(),
		bp.equipment.size(), _eff_bonus(), map.battles_won, map.steps]
	log_label.text = "\n".join(log_lines)
	canvas.queue_redraw()


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
# 绘制（地图 + 背包 + 手上幽灵）
# ============================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)


## 顶层画布绘制（canvas.draw 信号）：地图 + 背包 + 手上幽灵。
func _draw_canvas() -> void:
	if map == null:
		return
	var f16: Font = FontManager.f16
	var f12: Font = FontManager.f12
	# —— 地图 ——
	for y: int in MapState.SIZE:
		for x: int in MapState.SIZE:
			var c := Vector2i(x, y)
			var rect := Rect2(MAP_ORIGIN + Vector2(x * MAP_CELL, y * MAP_CELL), Vector2(MAP_CELL - 2, MAP_CELL - 2))
			if not map.revealed.has(c):
				canvas.draw_rect(rect, COL_FOG)
				continue
			var tile: int = map.grid[y][x]
			var col := COL_FLOOR
			var glyph: String = ""
			var gcol := COL_TEXT
			match tile:
				MapState.Tile.WALL:
					col = COL_WALL
				MapState.Tile.START:
					glyph = "起"
					gcol = COL_BONE
				MapState.Tile.MONSTER:
					var m: Dictionary = map.monsters.get(c, {})
					glyph = "怪%d" % int(m.get("tier", 0))
					if bool(m.get("resolved", false)):
						glyph += "†"
					gcol = COL_MONSTER
				MapState.Tile.EVENT:
					glyph = "？"
					gcol = COL_EVENT
				MapState.Tile.CHEST:
					glyph = "蛋" if bool(map.chests.get(c, {}).get("egg", false)) else "宝"
					gcol = COL_CHEST
				MapState.Tile.EXT1, MapState.Tile.EXT2, MapState.Tile.EXT3:
					glyph = "撤%d" % (tile - MapState.Tile.EXT1 + 1)
					gcol = COL_EXT_OPEN if map.ext_open(tile) else COL_EXT_CLOSED
			canvas.draw_rect(rect, col)
			if glyph != "":
				canvas.draw_string(f12, rect.position + Vector2(6, 36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, gcol)
	if map.wanderer != Vector2i(-1, -1) and map.revealed.has(map.wanderer):
		var wr := MAP_ORIGIN + Vector2(map.wanderer.x * MAP_CELL, map.wanderer.y * MAP_CELL)
		canvas.draw_string(f12, wr + Vector2(6, 36), "游", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff6a5c"))
	var pr := Rect2(MAP_ORIGIN + Vector2(map.player.x * MAP_CELL, map.player.y * MAP_CELL), Vector2(MAP_CELL - 2, MAP_CELL - 2))
	canvas.draw_rect(pr, COL_PLAYER, false, 3.0)
	canvas.draw_string(f12, pr.position + Vector2(16, 36), "队", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_PLAYER)
	# —— 背包 ——
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
			canvas.draw_rect(Rect2(BP_ORIGIN + Vector2(c.x * BP_CELL, c.y * BP_CELL), Vector2(BP_CELL - 3, BP_CELL - 3)), col)
		var a: Vector2i = p["anchor"]
		canvas.draw_string(f16, BP_ORIGIN + Vector2(a.x * BP_CELL + 3, a.y * BP_CELL + 20), String(it["name"]).left(3), HORIZONTAL_ALIGNMENT_LEFT, BP_CELL * 2, 16, COL_TEXT)
	# —— 手上幽灵 ——
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
		canvas.draw_string(f16, mouse_pos + Vector2(20, -12), String(held["item"]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_TEXT)


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


func _gui_input(event: InputEvent) -> void:
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
	if dialog.visible:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		_prompt_leave()
		return
	if key == KEY_R and not held.is_empty():
		held["shape"] = Loot.rotate_shape(held["shape"])
		canvas.queue_redraw()
		return
	if key == KEY_X and not held.is_empty():
		_log("丢弃了 %s。" % String(held["item"]["name"]))
		held = {}
		_refresh()
		return
	if key == KEY_U and not held.is_empty():
		_use_held()
		return
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
			_after_battle(map.fight_wanderer(_eff_bonus()))
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
		"进战（自动结算·占位）",
		"逃跑（挨一拍 %.1f HP·退回）" % (0.5 * float(m["tier"])),
	], func(idx: int) -> void:
		if idx == 0:
			_after_battle(map.fight(c, _eff_bonus()))
		else:
			var report: Dictionary = map.flee(c, pending_flee_from)
			_log("逃跑：挨 %s 一拍（-%.1f HP），怪驻留原格。" % [String(report["name"]), float(report["dmg"])])
			if bool(report.get("death", false)):
				_show_settlement()
		_refresh())


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
							var r1: Dictionary = {"id": "ration", "name": "干粮", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "+10 补给"}
							pending.append(r1)
							pending.append(r1.duplicate(true))
							_log("行商：%s 换了干粮×2 → 拾取区。" % String(pay["name"]))
						else:
							pending.append({"id": "potion", "name": "药瓶", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "单英雄 +1 HP"})
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
					pending.append({"id": "ration", "name": "干粮", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "+10 补给"})
					pending.append({"id": "ration", "name": "干粮", "cat": "consumable", "tier": 0, "shape": Loot.SHAPE_1X1, "gold": 0, "note": "+10 补给"})
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
			_new_run(randi() % 1000000)
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
