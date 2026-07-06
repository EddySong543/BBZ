## 远征地图探索原型 UI（F6 运行 MapProto.tscn）
## 占位美术：纯色格+字符图例。操作：WASD/方向键移动·干粮/药瓶按钮·N 新种子·R 重开本种子。
extends Control

const MapState := preload("res://prototypes/expedition/map_proto/map_state.gd")

const CELL: int = 56
const GRID_ORIGIN := Vector2(80, 120)
const COL_FLOOR := Color("2a2a33")
const COL_WALL := Color("14141a")
const COL_FOG := Color("07070a")
const COL_GRID_LINE := Color("3a3a46")
const COL_PLAYER := Color("e8c15a")
const COL_MONSTER := Color("c04848")
const COL_EVENT := Color("8a6fc0")
const COL_CHEST := Color("c08a3a")
const COL_EXT := Color("4a9a6a")
const COL_EXT_CLOSED := Color("555560")
const COL_WANDER := Color("e04040")

var state: MapState
var seed_value: int = 20260706
var font: Font
var log_lines: Array = []
var hud: Label
var log_label: Label
var dialog: PopupPanel
var dialog_box: VBoxContainer
var pending_flee_from: Vector2i   # 逃跑退回格

func _ready() -> void:
	font = load("res://assets/font/ark-pixel-16px-proportional-zh_cn.ttf")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 16
	theme = th
	_build_ui()
	_new_run(seed_value)

func _build_ui() -> void:
	hud = Label.new()
	hud.position = Vector2(GRID_ORIGIN.x + MapState.SIZE * CELL + 60, GRID_ORIGIN.y)
	hud.size = Vector2(520, 640)
	add_child(hud)
	log_label = Label.new()
	log_label.position = Vector2(GRID_ORIGIN.x + MapState.SIZE * CELL + 60, GRID_ORIGIN.y + 520)
	log_label.size = Vector2(900, 420)
	log_label.modulate = Color(0.8, 0.82, 0.78)
	add_child(log_label)
	var title := Label.new()
	title.text = "远征模式 · 地图探索原型（占位美术）    移动=WASD/方向键   N=新种子   R=重开   干粮=1键   药瓶=2键"
	title.position = Vector2(GRID_ORIGIN.x, 60)
	add_child(title)
	dialog = PopupPanel.new()
	dialog_box = VBoxContainer.new()
	dialog_box.custom_minimum_size = Vector2(560, 0)
	dialog.add_child(dialog_box)
	add_child(dialog)

func _new_run(p_seed: int) -> void:
	seed_value = p_seed
	state = MapState.new()
	state.setup(p_seed)
	log_lines = []
	_log("新的一局：种子 %d。找到战利品并活着撤离。" % p_seed)
	_refresh()

func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 14:
		log_lines.pop_front()

func _refresh() -> void:
	var s: String = ""
	s += "补给：%d%s\n" % [state.supplies, "（饥饿行军中！）" if state.supplies <= 0 else ""]
	s += "刻：%.1f（步 %d + 战斗拍×0.5）\n" % [state.ticks(), state.steps]
	s += "危险度 D：%d / %d%s\n" % [state.danger(), MapState.D_CAP, "（游荡怪出没！）" if state.wanderer != Vector2i(-1, -1) else ""]
	s += "\n撤离点：\n"
	s += "  撤1（近）：%s\n" % _ext_text(MapState.Tile.EXT1)
	s += "  撤2（中）：%s\n" % _ext_text(MapState.Tile.EXT2)
	s += "  撤3（深）：永不关闭\n"
	s += "\n队伍：\n"
	for h: Dictionary in state.team:
		var hp: float = float(h["hp"])
		s += "  %s  HP %.1f/%.1f%s\n" % [String(h["name"]), maxf(0.0, hp), float(h["hp_max"]), "（倒下）" if hp <= 0.0 else ""]
	s += "\n背囊（占位计数·拼图见背包原型）：\n"
	s += "  金币 %d   干粮 %d   药瓶 %d   战斗道具 %d\n" % [state.gold, state.rations, state.potions, state.combat_items]
	if not state.rare_names.is_empty():
		s += "  稀有：%s\n" % "、".join(state.rare_names)
	hud.text = s
	log_label.text = "\n".join(log_lines)
	queue_redraw()

func _ext_text(tile: int) -> String:
	var t: float = state.ticks()
	match tile:
		MapState.Tile.EXT1:
			return "开放（%.0f 刻后关闭）" % (MapState.EXT1_CLOSE - t) if t < MapState.EXT1_CLOSE else "已关闭"
		MapState.Tile.EXT2:
			if t < MapState.EXT2_OPEN:
				return "未开（%.0f 刻后开放）" % (MapState.EXT2_OPEN - t)
			return "开放（%.0f 刻后关闭）" % (MapState.EXT2_CLOSE - t) if t < MapState.EXT2_CLOSE else "已关闭"
	return ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16161c"))
	if state == null:
		return
	for y: int in MapState.SIZE:
		for x: int in MapState.SIZE:
			var c := Vector2i(x, y)
			var rect := Rect2(GRID_ORIGIN + Vector2(x * CELL, y * CELL), Vector2(CELL - 2, CELL - 2))
			if not state.revealed.has(c):
				draw_rect(rect, COL_FOG)
				continue
			var tile: int = state.grid[y][x]
			var col := COL_FLOOR
			var glyph: String = ""
			var gcol := Color.WHITE
			match tile:
				MapState.Tile.WALL:
					col = COL_WALL
				MapState.Tile.START:
					glyph = "起"
					gcol = Color(0.7, 0.7, 0.75)
				MapState.Tile.MONSTER:
					var m: Dictionary = state.monsters.get(c, {})
					glyph = "怪%d" % int(m.get("tier", 0))
					if bool(m.get("resolved", false)):
						glyph += "†"  # 打过一半驻留
					gcol = COL_MONSTER
				MapState.Tile.EVENT:
					glyph = "？"
					gcol = COL_EVENT
				MapState.Tile.CHEST:
					glyph = "宝"
					if bool(state.chests.get(c, {}).get("egg", false)):
						glyph = "蛋"
					gcol = COL_CHEST
				MapState.Tile.EXT1, MapState.Tile.EXT2, MapState.Tile.EXT3:
					var open: bool = state.ext_open(tile)
					glyph = "撤%d" % (tile - MapState.Tile.EXT1 + 1)
					gcol = COL_EXT if open else COL_EXT_CLOSED
			draw_rect(rect, col)
			if glyph != "":
				draw_string(font, rect.position + Vector2(8, 34), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gcol)
	# 游荡怪
	if state.wanderer != Vector2i(-1, -1) and state.revealed.has(state.wanderer):
		var wr := Rect2(GRID_ORIGIN + Vector2(state.wanderer.x * CELL, state.wanderer.y * CELL), Vector2(CELL - 2, CELL - 2))
		draw_string(font, wr.position + Vector2(8, 34), "游", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_WANDER)
	# 玩家
	var pr := Rect2(GRID_ORIGIN + Vector2(state.player.x * CELL, state.player.y * CELL), Vector2(CELL - 2, CELL - 2))
	draw_rect(pr, COL_PLAYER, false, 3.0)
	draw_string(font, pr.position + Vector2(18, 34), "队", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_PLAYER)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if dialog.visible:
		return
	var key: int = event.keycode
	if key == KEY_N:
		_new_run(randi() % 1000000)
		return
	if key == KEY_R:
		_new_run(seed_value)
		return
	if state.over:
		return
	if key == KEY_1:
		if state.use_ration():
			_log("吃掉干粮：补给 +10。")
		_refresh()
		return
	if key == KEY_2:
		if state.use_potion():
			_log("使用药瓶：前排 +1 HP。")
		_refresh()
		return
	var dir := Vector2i.ZERO
	match key:
		KEY_W, KEY_UP: dir = Vector2i.UP
		KEY_S, KEY_DOWN: dir = Vector2i.DOWN
		KEY_A, KEY_LEFT: dir = Vector2i.LEFT
		KEY_D, KEY_RIGHT: dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO:
		return
	var prev: Vector2i = state.player
	var res: Dictionary = state.try_move(dir)
	for m: String in res.get("msgs", []):
		_log(m)
	match String(res["kind"]):
		"death":
			_show_settlement()
		"monster":
			pending_flee_from = prev
			_prompt_monster(state.player)
		"wanderer":
			var report: Dictionary = state.fight_wanderer()
			_log_battle(report)
			if bool(report.get("death", false)):
				_show_settlement()
		"event":
			_run_event(state.player)
		"chest":
			var loot: Array = state.open_chest(state.player)
			_log("开箱：%s。" % _loot_text(loot))
		"ext":
			_prompt_extract(state.grid[state.player.y][state.player.x])
	_refresh()

# ---------- 战斗 ----------

func _prompt_monster(c: Vector2i) -> void:
	var m: Dictionary = state.resolve_encounter(c)
	var head: String = "遭遇 %s（T%d·HP %.0f）— 明牌可读" % [String(m["name"]), int(m["tier"]), float(m["hp"])]
	_show_choice(head, [
		"进战（自动结算·先知效率占位）",
		"逃跑（挨一拍 %.1f HP·退回）" % (0.5 * float(m["tier"])),
	], func(idx: int) -> void:
		if idx == 0:
			var report: Dictionary = state.fight(c)
			_log_battle(report)
			if bool(report.get("death", false)):
				_show_settlement()
		else:
			var report: Dictionary = state.flee(c, pending_flee_from)
			_log("逃跑：挨 %s 一拍（-%.1f HP），怪驻留原格（血量保留）。" % [String(report["name"]), float(report["dmg"])])
			if bool(report.get("death", false)):
				_show_settlement()
		_refresh())

func _log_battle(report: Dictionary) -> void:
	_log("击败 %s：%d 拍（+%.1f 刻），受伤 %.1f HP。%s" % [
		String(report["name"]), int(report["beats"]), float(report["beats"]) * 0.5,
		float(report["dmg"]), "掉落：" + _loot_text(report["loot"]) if not (report["loot"] as Array).is_empty() else ""])

func _loot_text(loot: Array) -> String:
	var names: Array = []
	for it: Dictionary in loot:
		names.append(String(it["name"]))
	return "、".join(names) if not names.is_empty() else "无"

# ---------- 事件 ----------

func _run_event(c: Vector2i) -> void:
	var ev: String = String(state.events.get(c, ""))
	var consume := func() -> void:
		state.events.erase(c)
		state.grid[c.y][c.x] = MapState.Tile.FLOOR
	match ev:
		"篝火":
			var name: String = state.recruit()
			if name != "":
				_log("篝火·招募：%s 加入队伍！" % name)
			else:
				state.heal_all(0.5)
				_log("篝火·休整：队伍已满，全队 +0.5 HP。")
			consume.call()
		"清泉":
			_show_choice("清泉：选一种饮法", ["单英雄 +1 HP（前排）", "全队 +0.5 HP"], func(idx: int) -> void:
				if idx == 0:
					state.heal_front(1.0)
				else:
					state.heal_all(0.5)
				_log("清泉：恢复完成。")
				consume.call()
				_refresh())
		"陷阱":
			if state.rations > 0:
				_show_choice("陷阱！", ["用 1 干粮抵掉", "硬吃：补给 -5"], func(idx: int) -> void:
					if idx == 0:
						state.rations -= 1
						_log("陷阱：丢出干粮抵掉了。")
					else:
						state.supplies = maxi(0, state.supplies - 5)
						_log("陷阱：补给 -5。")
					consume.call()
					_refresh())
			else:
				state.supplies = maxi(0, state.supplies - 5)
				_log("陷阱：补给 -5（没有干粮可抵）。")
				consume.call()
		"神龛":
			state.combat_items += 1
			_log("神龛：获得 1 件随机 T1 战斗道具（占位计数）。")
			consume.call()
		"藏宝图":
			var found: Vector2i = state.reveal_random_chest()
			_log("藏宝图：探明宝箱 %s。" % ("于 (%d,%d)" % [found.x, found.y] if found.x >= 0 else "——地图上已无未知宝箱"))
			consume.call()
		"岔路赌局":
			if state.gold >= 20:
				_show_choice("岔路赌局：押 20 金，50/50 翻倍或没收", ["赌！", "不赌"], func(idx: int) -> void:
					if idx == 0:
						if state.rng.randf() < 0.5:
							state.gold += 20
							_log("赌局：赢了！金币 +20。")
						else:
							state.gold -= 20
							_log("赌局：输了。金币 -20。")
					else:
						_log("赌局：转身离开。")
					consume.call()
					_refresh())
			else:
				_log("岔路赌局：身上不足 20 金，庄家挥挥手让你走了。")
				consume.call()
		"行商":
			_show_choice("行商（可回访·媒介=金币占位）", ["买干粮 +10 补给（20 金）", "买药瓶（30 金）", "离开"], func(idx: int) -> void:
				if idx == 0 and state.gold >= 20:
					state.gold -= 20
					state.supplies += 10
					_log("行商：买了干粮，补给 +10。")
				elif idx == 1 and state.gold >= 30:
					state.gold -= 30
					state.potions += 1
					_log("行商：买了药瓶。")
				elif idx <= 1:
					_log("行商：金币不够。")
				_refresh())
			# 行商不消费格子（可回访）
		"巢穴":
			_show_choice("巢穴：连战 2 场（高危高掉落）", ["清巢！", "绕开"], func(idx: int) -> void:
				if idx == 0:
					for i: int in 2:
						if state.over:
							break
						var def_pos: Vector2i = c
						state.monsters[def_pos] = {"key": "nest", "name": "巢中怪", "tier": 2, "hp": 8.0, "hp_max": 8.0, "resolved": false}
						var report: Dictionary = state.fight(def_pos)
						_log_battle(report)
						if bool(report.get("death", false)):
							_show_settlement()
							return
					_log("巢穴清空！")
				consume.call()
				_refresh())
		"修补匠":
			state.rations += 2
			_log("修补匠：背包扩容在背包原型里演——这里折干粮×2。")
			consume.call()
		"兽踪":
			var egg_at: Vector2i = state.mark_egg_chest()
			_log("兽踪：%s" % ("追踪到线索，最远的宝箱里似乎有蛋（已标记）。" if egg_at.x >= 0 else "线索断了（无宝箱）。"))
			consume.call()
		_:
			consume.call()

# ---------- 撤离 / 结算 ----------

func _prompt_extract(tile: int) -> void:
	var idx_num: int = tile - MapState.Tile.EXT1 + 1
	if not state.ext_open(tile):
		_log("撤离点 撤%d 已关闭/未开放。" % idx_num)
		return
	_show_choice("撤%d 开放中：现在撤离？" % idx_num, ["撤离结算", "再逛逛"], func(idx: int) -> void:
		if idx == 0:
			state.extract()
			_show_settlement()
		_refresh())

func _show_settlement() -> void:
	var r: Dictionary = state.result
	var text: String
	if String(r["outcome"]) == "extract":
		text = "【撤离成功】\n金币带出 %d\n战斗道具 %d 件\n%s刻 %.1f（目标带 60-100：%s）\n步数 %d · 战斗 %d 胜" % [
			int(r["gold_saved"]), int(r["combat_items"]),
			("稀有：" + "、".join(r["rares"]) + "\n") if not (r["rares"] as Array).is_empty() else "",
			float(r["ticks"]), "落带 ✓" if bool(r["in_band"]) else "出带 ✗",
			int(r["steps"]), int(r["battles"])]
	else:
		text = "【全灭】%s\n金币保底（30%%）：%d\n刻 %.1f · 步数 %d · 战斗 %d 胜\n（保险槽规则在背包原型里演）" % [
			String(r["cause"]), int(r["gold_saved"]), float(r["ticks"]), int(r["steps"]), int(r["battles"])]
	_show_choice(text, ["再来一局（新种子）", "重开本局（同种子）"], func(idx: int) -> void:
		if idx == 0:
			_new_run(randi() % 1000000)
		else:
			_new_run(seed_value))

# ---------- 通用选择弹窗 ----------

func _show_choice(text: String, options: Array, cb: Callable) -> void:
	for child: Node in dialog_box.get_children():
		child.queue_free()
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_box.add_child(lbl)
	for i: int in options.size():
		var btn := Button.new()
		btn.text = String(options[i])
		var idx: int = i
		btn.pressed.connect(func() -> void:
			dialog.hide()
			cb.call(idx))
		dialog_box.add_child(btn)
	dialog.popup_centered()
	if dialog_box.get_child_count() > 1:
		(dialog_box.get_child(1) as Button).grab_focus()
