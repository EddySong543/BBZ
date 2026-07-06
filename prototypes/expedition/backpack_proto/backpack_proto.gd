## 远征背包拼图原型 UI（F6 运行 BackpackProto.tscn）
## 交互：点掉落区拾起 → 鼠标带着走 → R 旋转 → 点背包格放下；右键放回掉落区；X 丢弃。
## 点背包内物品=拾回手上；保险槽/装备栏按钮=放入或取回。
extends Control

const BackpackState := preload("res://prototypes/expedition/backpack_proto/backpack_state.gd")
const LootGen := preload("res://prototypes/expedition/loot_gen.gd")

const CELL: int = 72
const GRID_ORIGIN := Vector2(720, 220)
const COL_EMPTY := Color("2a2a33")
const COL_LINE := Color("3a3a46")
const COL_GOLD := Color("b08a3a")
const COL_COMBAT := Color("5a7ab0")
const COL_CONSUM := Color("5a9a6a")
const COL_RARE := Color("9a5ab0")
const COL_OK := Color(0.4, 0.9, 0.5, 0.55)
const COL_BAD := Color(0.95, 0.35, 0.3, 0.55)

var state: BackpackState
var rng := RandomNumberGenerator.new()
var offers: Array = []          # 掉落区物品
var held: Dictionary = {}       # {item, shape} 空 = 没拿东西
var offer_box: VBoxContainer
var equip_box: VBoxContainer
var insure_btn: Button
var stats: Label
var result_label: Label
var mouse_pos: Vector2

func _ready() -> void:
	var th := Theme.new()
	th.default_font = load("res://assets/font/ark-pixel-16px-proportional-zh_cn.ttf")
	th.default_font_size = 16
	theme = th
	rng.seed = 20260706
	state = BackpackState.new()
	_build_ui()
	_sim_kill("t1")
	_refresh()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "远征模式 · 背包拼图原型    拾起=左键点物品   放下=点背包格   R=旋转   右键=放回   X=丢弃"
	title.position = Vector2(60, 40)
	add_child(title)
	# 左：掉落区 + 模拟按钮
	var sim_row := HBoxContainer.new()
	sim_row.position = Vector2(60, 90)
	add_child(sim_row)
	for cfg: Array in [["模拟击杀 T1", "t1"], ["击杀 T2", "t2"], ["击杀 T3(Boss)", "t3"], ["开宝箱", "chest"]]:
		var b := Button.new()
		b.text = String(cfg[0])
		var kind: String = String(cfg[1])
		b.pressed.connect(func() -> void:
			_sim_kill(kind)
			_refresh())
		sim_row.add_child(b)
	var offer_title := Label.new()
	offer_title.text = "―― 掉落区（点击拾起）――"
	offer_title.position = Vector2(60, 140)
	add_child(offer_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 175)
	scroll.size = Vector2(420, 620)
	add_child(scroll)
	offer_box = VBoxContainer.new()
	offer_box.custom_minimum_size = Vector2(400, 0)
	scroll.add_child(offer_box)
	# 右：保险槽 / 装备栏 / 扩容 / 结算 / 状态
	var rx: float = GRID_ORIGIN.x + 6 * CELL + 60
	insure_btn = Button.new()
	insure_btn.position = Vector2(rx, GRID_ORIGIN.y)
	insure_btn.size = Vector2(360, 64)
	insure_btn.pressed.connect(_on_insure_clicked)
	add_child(insure_btn)
	var equip_title := Label.new()
	equip_title.text = "装备栏（PvE 局内·上限解开·撤离不带出）"
	equip_title.position = Vector2(rx, GRID_ORIGIN.y + 84)
	add_child(equip_title)
	var equip_btn := Button.new()
	equip_btn.text = "把手上的战斗道具装上"
	equip_btn.position = Vector2(rx, GRID_ORIGIN.y + 116)
	equip_btn.size = Vector2(360, 40)
	equip_btn.pressed.connect(_on_equip_clicked)
	add_child(equip_btn)
	equip_box = VBoxContainer.new()
	equip_box.position = Vector2(rx, GRID_ORIGIN.y + 166)
	equip_box.custom_minimum_size = Vector2(360, 0)
	add_child(equip_box)
	var grow_row := HBoxContainer.new()
	grow_row.position = Vector2(GRID_ORIGIN.x, GRID_ORIGIN.y - 50)
	add_child(grow_row)
	for cfg: Array in [["修补匠：+1 行", true], ["修补匠：+1 列", false]]:
		var b := Button.new()
		b.text = String(cfg[0])
		var is_row: bool = bool(cfg[1])
		b.pressed.connect(func() -> void:
			var ok: bool = state.expand_row() if is_row else state.expand_col()
			result_label.text = "" if ok else "已到 6×6 上限（改给干粮×2——见子文档 C 边界）"
			_refresh())
		grow_row.add_child(b)
	var settle_row := HBoxContainer.new()
	settle_row.position = Vector2(rx, GRID_ORIGIN.y + 420)
	add_child(settle_row)
	var b_ext := Button.new()
	b_ext.text = "撤离结算"
	b_ext.pressed.connect(func() -> void: _settle(true))
	settle_row.add_child(b_ext)
	var b_die := Button.new()
	b_die.text = "死亡结算"
	b_die.pressed.connect(func() -> void: _settle(false))
	settle_row.add_child(b_die)
	stats = Label.new()
	stats.position = Vector2(rx, GRID_ORIGIN.y + 480)
	stats.size = Vector2(500, 200)
	add_child(stats)
	result_label = Label.new()
	result_label.position = Vector2(60, 830)
	result_label.size = Vector2(1800, 220)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.modulate = Color(0.9, 0.85, 0.6)
	add_child(result_label)

func _sim_kill(kind: String) -> void:
	var drop: Array = LootGen.roll_drop(rng, kind)
	offers.append_array(drop)

func _refresh() -> void:
	for child: Node in offer_box.get_children():
		child.queue_free()
	for i: int in offers.size():
		var it: Dictionary = offers[i]
		var b := Button.new()
		var size: Vector2i = LootGen.shape_size(it["shape"])
		var density: String = ""
		if String(it["cat"]) == "gold":
			density = "·%d金/格" % int(round(float(it["gold"]) / float((it["shape"] as Array).size())))
		b.text = "%s  [%d×%d]%s  %s" % [String(it["name"]), size.x, size.y, density, String(it.get("note", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx: int = i
		b.pressed.connect(func() -> void: _pick_from_offers(idx))
		offer_box.add_child(b)
	for child: Node in equip_box.get_children():
		child.queue_free()
	for i: int in state.equipment.size():
		var it: Dictionary = state.equipment[i]
		var b := Button.new()
		b.text = "⚔ %s（点击卸下到手上）" % String(it["name"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx: int = i
		b.pressed.connect(func() -> void: _unequip(idx))
		equip_box.add_child(b)
	insure_btn.text = "保险槽（≤2×2·死亡保留）：%s" % (String(state.insurance["name"]) if not state.insurance.is_empty() else "空")
	var used: int = 0
	for p: Dictionary in state.placements:
		used += (p["shape"] as Array).size()
	stats.text = "背包 %d×%d：占用 %d/%d 格\n包内金币价值：%d\n装备中：%d 件（撤离不带出）\n手上：%s" % [
		state.cols, state.rows, used, state.rows * state.cols, state.gold_total(),
		state.equipment.size(), String(held["item"]["name"]) if not held.is_empty() else "空"]
	queue_redraw()

# ---------- 拾放 ----------

func _pick_from_offers(idx: int) -> void:
	if not held.is_empty() or idx >= offers.size():
		return
	var it: Dictionary = offers[idx]
	offers.remove_at(idx)
	held = {"item": it, "shape": (it["shape"] as Array).duplicate()}
	_refresh()

func _on_equip_clicked() -> void:
	if held.is_empty():
		result_label.text = "手上没东西——先从掉落区或背包里拾起一件战斗道具。"
		return
	if state.equip(held["item"]):
		held = {}
		result_label.text = ""
	else:
		result_label.text = "只有战斗道具能装备。"
	_refresh()

func _unequip(idx: int) -> void:
	if not held.is_empty() or idx >= state.equipment.size():
		return
	var it: Dictionary = state.equipment[idx]
	state.equipment.remove_at(idx)
	held = {"item": it, "shape": (it["shape"] as Array).duplicate()}
	_refresh()

func _on_insure_clicked() -> void:
	if held.is_empty():
		if not state.insurance.is_empty():
			var it: Dictionary = state.pop_insurance()
			held = {"item": it, "shape": (it["shape"] as Array).duplicate()}
	else:
		if state.can_insure(held["item"]):
			var it2: Dictionary = held["item"]
			state.insure(it2)
			held = {}
			result_label.text = ""
		else:
			result_label.text = "保险槽只收 ≤2×2 的单件（当前已有物品或过大）。"
	_refresh()

func _grid_cell_at(pos: Vector2) -> Vector2i:
	var local: Vector2 = pos - GRID_ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var c := Vector2i(int(local.x / CELL), int(local.y / CELL))
	if c.x >= state.cols or c.y >= state.rows:
		return Vector2i(-1, -1)
	return c

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_pos = (event as InputEventMouseMotion).position
		if not held.is_empty():
			queue_redraw()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		mouse_pos = mb.position
		if mb.button_index == MOUSE_BUTTON_RIGHT and not held.is_empty():
			offers.append(held["item"])
			held = {}
			_refresh()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell: Vector2i = _grid_cell_at(mb.position)
		if cell.x < 0:
			return
		if held.is_empty():
			var p: Dictionary = state.remove_at(cell)
			if not p.is_empty():
				held = {"item": p["item"], "shape": (p["shape"] as Array).duplicate()}
				_refresh()
		else:
			if state.place(held["item"], held["shape"], cell):
				held = {}
				result_label.text = ""
				_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_R and not held.is_empty():
		held["shape"] = LootGen.rotate_shape(held["shape"])
		queue_redraw()
	elif key == KEY_X and not held.is_empty():
		result_label.text = "丢弃了 %s（正式版丢弃物留在原地可回捡）。" % String(held["item"]["name"])
		held = {}
		_refresh()

# ---------- 结算 ----------

func _settle(is_extract: bool) -> void:
	if is_extract:
		var r: Dictionary = state.settle_extract()
		var names: Array = []
		for it: Dictionary in r["goods"]:
			names.append(String(it["name"]))
		result_label.text = "【撤离结算】金币入钱包 %d ｜ 带出物品：%s ｜ 装备栏 %d 件是本局租用·没带走（想带走就得卸进背包占格）｜ T3 入收藏不进 PvP 格1候选" % [
			int(r["gold"]), "、".join(names) if not names.is_empty() else "无", int(r["equipment_lost"])]
	else:
		var r: Dictionary = state.settle_death()
		var kept_names: Array = []
		for it: Dictionary in r["kept"]:
			kept_names.append(String(it["name"]))
		result_label.text = "【死亡结算】金币保底（30%%）：%d ｜ 保险槽保住：%s ｜ 其余 %d 件全部消失" % [
			int(r["gold"]), "、".join(kept_names) if not kept_names.is_empty() else "（保险槽是空的）", int(r["lost_count"])]

# ---------- 绘制 ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16161c"))
	if state == null:
		return
	var font: Font = get_theme_default_font()
	# 背包格
	var occ: Dictionary = state.occupied_cells()
	for y: int in state.rows:
		for x: int in state.cols:
			var rect := Rect2(GRID_ORIGIN + Vector2(x * CELL, y * CELL), Vector2(CELL - 3, CELL - 3))
			draw_rect(rect, COL_EMPTY)
			draw_rect(rect, COL_LINE, false, 1.0)
	# 已放置物品（同件同色块+首格名字）
	var drawn: Dictionary = {}
	for p: Dictionary in state.placements:
		var it: Dictionary = p["item"]
		var col: Color = _cat_color(String(it["cat"]))
		for off: Vector2i in p["shape"]:
			var c: Vector2i = Vector2i(p["anchor"]) + off
			var rect := Rect2(GRID_ORIGIN + Vector2(c.x * CELL, c.y * CELL), Vector2(CELL - 3, CELL - 3))
			draw_rect(rect, col)
		if not drawn.has(p):
			var a: Vector2i = p["anchor"]
			draw_string(font, GRID_ORIGIN + Vector2(a.x * CELL + 4, a.y * CELL + 24), String(it["name"]).left(4), HORIZONTAL_ALIGNMENT_LEFT, CELL * 2, 16, Color.WHITE)
			drawn[p] = true
	# 手上物品：跟随鼠标·落格吸附并示可放性
	if not held.is_empty():
		var cell: Vector2i = _grid_cell_at(mouse_pos)
		var shape: Array = held["shape"]
		if cell.x >= 0:
			var ok: bool = state.can_place(shape, cell)
			for off: Vector2i in shape:
				var c: Vector2i = cell + off
				var rect := Rect2(GRID_ORIGIN + Vector2(c.x * CELL, c.y * CELL), Vector2(CELL - 3, CELL - 3))
				draw_rect(rect, COL_OK if ok else COL_BAD)
		else:
			for off: Vector2i in shape:
				var rect := Rect2(mouse_pos + Vector2(off.x * CELL, off.y * CELL) * 0.6, Vector2(CELL, CELL) * 0.55)
				draw_rect(rect, Color(_cat_color(String(held["item"]["cat"])), 0.7))
		draw_string(font, mouse_pos + Vector2(20, -14), "%s（R 旋转）" % String(held["item"]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _cat_color(cat: String) -> Color:
	match cat:
		"gold": return COL_GOLD
		"combat": return COL_COMBAT
		"consumable": return COL_CONSUM
		"rare": return COL_RARE
	return COL_EMPTY
