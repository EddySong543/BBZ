extends Node

## 远征 PvE 驱动器（2026-07-17 battle_screen 拆分批②·任务 D 2026-07-06 的 PvE 段原文迁入·
## 零行为变化）。职责=PvE 模式的全部寄生逻辑：白板队/怪物构建·怪物驾驶员（ExpeditionPolicy）
## 定招与明牌面板·脱离按钮·回程结算（BattleSetup.pve_result → 远征地图）。
## 宿主=battle_screen（setup 注入·仅 PvE 局创建）：授权本组件读写宿主状态机
## （state/GAME_OVER 收口）与战斗只读面（battle）——UI 只读铁律不变（写 battle 仅经引擎入口 strike）。
## 🎨 美术挂点（怪物立绘 art 字段）说明随 monster_frames 迁入·消费契约不变（零改码换图）。

const ExpeditionPolicy := preload("res://src/expedition/expedition_monster_policy.gd")
const ExpeditionPixelArt := preload("res://src/expedition/expedition_pixel_art.gd")
const PVE_JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
# 远征怪物系列色（图签占位染色·monsters.json series 字段）：博弈=金 / 考官=蓝（memory expedition）
const PVE_SERIES_COLORS: Dictionary = {"gamble": Color("e0b54a"), "exam": Color("3f6fb0")}

var _h: Control = null                 # 宿主 battle_screen
var _policy: ExpeditionPolicy          # 怪物驾驶员（五策略·可支付归一化）
var choice: Dictionary = {}            # 本拍怪物已定招（回合开始抽样·明牌显示分布·确认时提交·宿主读）
var _odds_label: Label                 # 明牌概率表（博弈系）/ 循环提示（考官系）
var _flee_btn: Button                  # 脱离按钮（挨一拍·退回地图）
var _ending := false                   # 防重复回程结算


func setup(host: Control) -> void:
	_h = host


## 进入 PvE 局（宿主 _ready 的 pve 分支调）：建驾驶员 + PvE 专属 UI + 怪物立绘喂显示。
func activate(monster_def: Dictionary) -> void:
	_policy = ExpeditionPolicy.new(monster_def, randi())
	_build_ui()
	_h.p2_char_display.sprite_frames = monster_frames(monster_def)   # 任务 I：白板→像素图签占位/MJ art 字段


## 远征队伍 → 3 槽白板 HeroData（存活者在前·不足补 0 血板凳·同加时赛零特判）。
func build_team(team: Array) -> Array:
	var out: Array = []
	for m in team:
		out.append(_vanilla(String(m["name"]), maxi(1, int(m["hp_max"]) / 2)))
	while out.size() < 3:
		out.append(_vanilla("——", 1))
	return out


func build_monster(def: Dictionary, hp_half: int) -> Array:
	var out: Array = [_vanilla(String(def.get("name", "怪物")), maxi(1, (hp_half + 1) / 2))]
	while out.size() < 3:
		out.append(_vanilla("——", 1))
	return out


func _vanilla(display_name: String, hp_points: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = ""      # 空 id = 白板（无技能组件·与校准 sim 同法）
	h.hero_name = display_name
	h.max_hp = hp_points
	return h


## PvE 怪物立绘（任务 I·白板→程序化像素图签占位）。
## 🎨 美术挂点：素材到位后在 monsters.json 该怪条目加可选字段 "art": "res://...（SpriteFrames .tres 或单图）"
## 即自动替换·零改码（字段缺省=程序占位·见 design/expedition-monsters.md + design/expedition-art-spec.md P1）。
func monster_frames(def: Dictionary) -> SpriteFrames:
	var art_path: String = String(def.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		var res: Resource = load(art_path)
		if res is SpriteFrames:
			return res
		if res is Texture2D:
			var sf_art := SpriteFrames.new()
			sf_art.add_animation("idle")
			sf_art.add_frame("idle", res)
			return sf_art
	var tier: int = int(def.get("tier", 1))
	var icon: String = "paw" if tier == 1 else ("fang" if tier == 2 else "horns")
	var col: Color = PVE_SERIES_COLORS.get(String(def.get("series", "")), Color("b3a386"))
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.add_frame("idle", ExpeditionPixelArt.get_texture(icon, col, 256))
	return sf


## PvE 专属 UI：明牌概率表（敌方区下缘·暖底芯片）+ 脱离按钮（左下·jelly 节奏橙）。运行时代码建·不动 PvP .tscn。
func _build_ui() -> void:
	_odds_label = Label.new()
	_odds_label.position = Vector2(660, 168)
	_odds_label.size = Vector2(600, 36)
	_odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_odds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_odds_label.modulate = Color(0.95, 0.91, 0.80)
	_odds_label.pivot_offset = Vector2(300, 18)   # 中心轴=明牌亮出 pop 用
	var chip := StyleBoxFlat.new()   # 暖色深底芯片（J 任务·对齐远征弹窗语言）
	chip.bg_color = Color(0.14, 0.11, 0.07, 0.85)
	chip.border_color = Color("b3a386")
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(6)
	chip.set_content_margin_all(6)
	_odds_label.add_theme_stylebox_override("normal", chip)
	FontManager.apply(_odds_label, 16)
	add_child(_odds_label)
	_flee_btn = Button.new()
	_flee_btn.text = tr("脱离战斗（挨一拍·退回）")
	_flee_btn.position = Vector2(56, 700)
	_flee_btn.size = Vector2(250, 44)
	FontManager.apply_btn(_flee_btn, 16)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		_flee_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_flee_btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_flee_btn.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	_flee_btn.add_theme_constant_override("outline_size", 4)
	var jelly := ColorRect.new()   # 果冻底（节奏橙=撤退语义·show_behind_parent 垫在文字下）
	jelly.color = Color.WHITE
	jelly.set_anchors_preset(Control.PRESET_FULL_RECT)
	jelly.show_behind_parent = true
	jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = PVE_JELLY_SHADER
	var base := Color("c47f33")
	m.set_shader_parameter("fill_top", base.lightened(0.12))
	m.set_shader_parameter("fill_bottom", base.darkened(0.32))
	m.set_shader_parameter("edge_inner", base.lightened(0.38))
	m.set_shader_parameter("edge_outer", Color(0.05, 0.045, 0.04))
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 44.0)
	m.set_shader_parameter("corner", 0.16)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 250.0 / 44.0)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("wear", 0.18)
	jelly.material = m
	_flee_btn.add_child(jelly)
	_flee_btn.pressed.connect(_on_flee)
	add_child(_flee_btn)


## 回合开始：怪物定招（引擎从显示表直接采样=明牌诚实性结构保证）+ 更新明牌面板。
func pick_turn() -> void:
	choice = _policy.pick(_h.battle, _h.AI)
	var odds: Dictionary = choice.get("odds", {})
	if odds.is_empty():
		_odds_label.text = tr("明牌：无（此怪出招有循环·可观察学习）")
	else:
		var names := {"attack": tr("波"), "defend": tr("防"), "charge": tr("攒"), "bigAttack": tr("大波"), "bigDefend": tr("大防")}
		var parts: Array = []
		for k in odds:
			parts.append("%s %.0f%%" % [String(names.get(k, k)), float(odds[k])])
		_odds_label.text = tr("明牌 ｜ ") + "  ·  ".join(parts)
	# 明牌亮出 pop（J 任务·中心轴回弹·提示"新一拍的牌翻开了"）
	_odds_label.scale = Vector2(1.14, 1.14)
	var tw := create_tween()
	tw.tween_property(_odds_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 脱离战斗（子文档 B §5）：占当拍·敌方本拍动作免费命中一次（无防御结算）·退回进入前格子。
func _on_flee() -> void:
	if _h.state != _h.State.PLAYER_SELECT or _h.battle.game_over or _ending:
		return
	var act: int = int(choice.get("action", ActionDef.Action.CHARGE))
	var dmg: int = 0
	if act == ActionDef.Action.ATTACK:
		dmg = 2
	elif act == ActionDef.Action.BIG_ATTACK:
		dmg = 4
	if dmg > 0:
		_h.battle.strike(_h.PLAYER, dmg, _h.AI, ActionDef.Pen.NORMAL)   # 无防御动作在场=直落（护盾仍吸收）·引擎入口
	await finish("flee", 1)


## 回程结算：写 BattleSetup.pve_result → 波幕转场回远征地图（expedition_screen 消费并回写地图状态）。
func finish(outcome: String, extra_beats: int = 0) -> void:
	if _ending:
		return
	_ending = true
	_h.state = _h.State.GAME_OVER
	_h._set_buttons_active(false)
	var team_hp: Array = []
	for i in range(_h.battle.hp[_h.PLAYER].size()):
		team_hp.append(maxi(0, _h.battle.hp[_h.PLAYER][i]))
	BattleSetup.pve_result = {outcome = outcome, beats = _h.battle.turn_number + extra_beats,
		team_hp = team_hp, monster_hp = maxi(0, _h.battle.hp[_h.AI][0])}
	var texts := {"win": tr("怪物被击败！"), "lose": tr("全灭……"), "flee": tr("脱离战斗")}
	_h.status_label.text = String(texts[outcome])
	_h.status_label.add_theme_color_override("font_color", Color("#5fd86b") if outcome == "win" else Color("#dddddd"))
	_h.status_label.visible = true
	await get_tree().create_timer(1.0).timeout
	TransitionManager.transition_to("res://src/expedition/expedition_screen.tscn")
