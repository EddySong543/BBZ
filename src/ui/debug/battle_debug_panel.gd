extends VBoxContainer

## 战斗调试面板（DEBUG 专用·左侧竖排测试按钮）：数值、换英雄、Buff 与加时巡检。
## ⚠ 全项目【唯一】直接改写 BattleCore 状态的 UI —— 有意隔离于此，让 battle_screen 保持「只读引擎状态」。
## ⚠ 不走正常结算管线：debug 致死不触发强制换人浮窗（要测死亡流程请打真实战斗）。
## 表现回接 battle_screen 走信号（面板不碰 juice / 刷新，保持职责单一）：
##   state_changed → 请 battle_screen _update_all 刷新；hit_fx → 请 battle_screen 播打击 juice。

signal state_changed                        # 改了 battle 状态 → 请 battle_screen 刷新
signal hit_fx(player: int, dmg_half: int)   # 造伤按钮 → 请 battle_screen 播打击表现（飘字/斩击/震屏）
signal overtime_requested                   # 一键进加时赛 → 请 battle_screen 组白板 1v1 并重载场景
signal enemy_switch_requested(target_slot: int) # 敌方正式选择切换，用于巡检切换触发技能与演出

const PLAYER := 0
const AI := 1

var _battle: BattleCore
var _art_pool: Array[HeroData] = []   # 美术巡检池：全英雄池中有 idle 资产的（首次点击构建）
var _buff_picker: VBoxContainer
var _buff_target := AI
var _buff_target_button: Button

const DEBUG_BUFFS: Array[Dictionary] = [
	{"id": &"poison", "name": "毒素"},
	{"id": &"vulnerable", "name": "脆弱"},
	{"id": &"sword_qi", "name": "剑气"},
	{"id": &"h02_wave_upgrade", "name": "玄金不动相"},
	{"id": &"h08_retained_big_defend", "name": "不坠神言"},
]


## 由 battle_screen 在创建后调用：注入 battle 引用 + 建按钮。
func setup(battle_ref: BattleCore) -> void:
	_battle = battle_ref
	position = Vector2(12.0, 300.0)
	add_theme_constant_override("separation", 6)
	var defs: Array = [
		["满能量", _dbg_full_energy],
		["满血", _dbg_full_hp],
		["敌 -10", _dbg_damage_enemy],
		["我 -10", _dbg_damage_self],
		["敌 +盾2", _dbg_shield_enemy],
		["我 下个英雄", _dbg_next_hero_self],
		["敌 下个英雄", _dbg_next_hero_enemy],
		["敌方切换", _dbg_enemy_switch_next],
		["进加时赛", _dbg_enter_overtime],
	]
	for d in defs:
		var b := _make_debug_button(d[0] as String)
		b.pressed.connect(d[1] as Callable)
		add_child(b)
	var add_buff_button := _make_debug_button("添加 Buff", Vector2(132.0, 40.0), 17)
	add_buff_button.name = "AddBuffButton"
	add_buff_button.modulate = Color(1.0, 0.92, 0.68, 0.94)
	add_buff_button.pressed.connect(_toggle_buff_picker)
	add_child(add_buff_button)
	_build_buff_picker()


func _make_debug_button(text: String, minimum_size := Vector2(92.0, 30.0),
		font_size := 14) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = Color(1.0, 1.0, 1.0, 0.82)
	FontManager.apply_btn(button, font_size)
	return button


func _build_buff_picker() -> void:
	_buff_picker = VBoxContainer.new()
	_buff_picker.name = "BuffPicker"
	_buff_picker.visible = false
	_buff_picker.add_theme_constant_override("separation", 3)
	add_child(_buff_picker)
	for definition: Dictionary in DEBUG_BUFFS:
		var button := _make_debug_button(String(definition.name), Vector2(132.0, 28.0), 13)
		button.name = "Buff_%s" % String(definition.id)
		button.pressed.connect(_dbg_add_buff.bind(StringName(definition.id)))
		_buff_picker.add_child(button)
	_buff_target_button = _make_debug_button("添加至我方", Vector2(132.0, 32.0), 14)
	_buff_target_button.name = "BuffTargetToggle"
	_buff_target_button.modulate = Color(0.76, 0.88, 1.0, 0.94)
	_buff_target_button.pressed.connect(_toggle_buff_target)
	_buff_picker.add_child(_buff_target_button)


func _toggle_buff_picker() -> void:
	_buff_picker.visible = not _buff_picker.visible
	if _buff_picker.visible:
		_buff_target = AI
		_refresh_buff_target_button()


func _toggle_buff_target() -> void:
	_buff_target = PLAYER if _buff_target == AI else AI
	_refresh_buff_target_button()


func _refresh_buff_target_button() -> void:
	# 文案表示下一次点击会切换到的目标；首次打开默认敌方，因此底部显示“添加至我方”。
	_buff_target_button.text = "添加至我方" if _buff_target == AI else "添加至敌方"


func _dbg_add_buff(effect_id: StringName) -> void:
	if _battle == null:
		return
	var player := _buff_target
	var slot: int = _battle.active_index[player]
	match effect_id:
		&"poison":
			_battle.set_status(player, slot, "poison",
					int(_battle.get_status(player, slot, "poison", 0)) + 1)
		&"vulnerable":
			_battle.set_status(player, slot, "vuln",
					int(_battle.get_status(player, slot, "vuln", 0)) + 1)
		&"sword_qi":
			_battle.set_team_status(player, "jianqi", mini(
					int(_battle.get_team_status(player, "jianqi", 0)) + 1, 4))
		&"h02_wave_upgrade":
			_battle.upgrade_next_wave[player] = true
		&"h08_retained_big_defend":
			_battle.retained_big_defend[player] = true
			_battle.retained_big_defend_until_turn[player] = _battle.turn_number + 1
		_:
			push_warning("debug: 未知 Buff %s" % effect_id)
			return
	state_changed.emit()


## 一键进加时赛（测加时规则+日食演出用）：跳过平局判定与选人浮窗，
## 场景重载等跨界操作归 battle_screen（面板只发信号·保持职责单一）。
func _dbg_enter_overtime() -> void:
	overtime_requested.emit()


func _dbg_full_energy() -> void:
	_battle.energy[PLAYER] = _battle.energy_max[PLAYER]
	_battle.energy[AI] = _battle.energy_max[AI]
	state_changed.emit()


func _dbg_full_hp() -> void:
	for p in [0, 1]:
		for s in range(_battle.hp[p].size()):
			_battle.hp[p][s] = _battle.max_hp[p][s]
			_battle.shield[p][s] = 0
	state_changed.emit()


func _dbg_damage_enemy() -> void:
	_dbg_damage_active(AI, 10)


func _dbg_damage_self() -> void:
	_dbg_damage_active(PLAYER, 10)


## 给 player 出战英雄扣 amount HP（debug·不走结算/不触发死亡换人）。
## 改状态后 state_changed（刷新含心条 flinch）+ hit_fx（飘字/斩击/白闪/震屏·方便 F6 测质感）。
func _dbg_damage_active(player: int, amount: int) -> void:
	var s: int = _battle.active_index[player]
	_battle.hp[player][s] = maxi(_battle.hp[player][s] - amount * BattleCore.HP_UNIT, 0)
	state_changed.emit()
	hit_fx.emit(player, amount * BattleCore.HP_UNIT)


func _dbg_shield_enemy() -> void:
	var s: int = _battle.active_index[AI]
	_battle.shield[AI][s] += 2 * BattleCore.HP_UNIT
	state_changed.emit()


## 请求敌方按槽位顺序切到下一名存活替补。面板本身不改 active_index，必须由
## battle_screen 从正式选招/resolve 入口提交，才能覆盖 h11 等离场钩子与公共换人演出。
func _dbg_enemy_switch_next() -> void:
	if _battle == null or not _battle.can_switch(AI):
		return
	var active: int = _battle.active_index[AI]
	var team_size: int = _battle.heroes[AI].size()
	for offset: int in range(1, team_size):
		var candidate: int = (active + offset) % team_size
		if _battle.is_living_reserve(AI, candidate):
			enemy_switch_requested.emit(candidate)
			return


func _dbg_next_hero_self() -> void:
	_dbg_next_hero(PLAYER)


func _dbg_next_hero_enemy() -> void:
	_dbg_next_hero(AI)


## 把 player 出战英雄换成英雄池里下一个（h01→h02→…→h12→h01·跳过无美术的）。
## 完整替换该槽位的 HeroData + HeroSkill，并清掉旧英雄的槽位运行时状态。
## 仍是 DEBUG 巡检入口：不重建整局，但当前出战位会执行离场/初始化/登场 hook。
func _dbg_next_hero(player: int) -> void:
	if _art_pool.is_empty():
		for h in HeroData.create_pool_heroes():
			var has_art: bool = h.sprite_frames_path != "" and ResourceLoader.exists(h.sprite_frames_path)
			if not has_art:
				has_art = h.spritesheet_path != "" and ResourceLoader.exists(h.spritesheet_path)
			if has_art:
				_art_pool.append(h)
		if _art_pool.is_empty():
			push_warning("debug: 英雄池中没有任何带美术资产的英雄")
			return

	var slot: int = _battle.active_index[player]
	var cur_id: String = _battle.heroes[player][slot].hero_id
	var idx: int = -1
	for i in range(_art_pool.size()):
		if _art_pool[i].hero_id == cur_id:
			idx = i
			break
	var next_hero := _art_pool[(idx + 1) % _art_pool.size()].duplicate(true) as HeroData
	var old_skill: HeroSkill = _battle.get_skill(player, slot)
	if slot == _battle.active_index[player] and old_skill != null:
		old_skill.on_switch_out(_battle, player, slot)
	var next_max_hp := int(next_hero.max_hp) * BattleCore.HP_UNIT
	_battle._apply_hero_runtime_snapshot(player, slot, {
		hero = next_hero,
		hp = next_max_hp,
		max_hp = next_max_hp,
		shield = 0,
		pending_damage = 0,
		statuses = {},
		death_processed = false,
		killer = -1,
	})
	_battle.selected_action[player] = -1
	_battle._switch_to[player] = -1
	_battle._active_target[player] = -1
	_battle._attack_target[player] = -1
	_battle._second_action[player] = -1
	_battle._second_attack_target[player] = -1
	_battle._empowered_wave[player] = false
	_battle._split_big_wave[player] = false
	_battle._blood_payment[player] = false
	_battle._blood_payment_source[player] = -1
	_battle._energy_cap_discount[player] = false
	var next_skill: HeroSkill = _battle.get_skill(player, slot)
	if next_skill != null:
		next_skill.on_setup(_battle, player, slot)
		if slot == _battle.active_index[player]:
			next_skill.on_switch_in(_battle, player, slot)

	state_changed.emit()
	print("debug: P%d 出战英雄 → %s (%s)" % [player + 1, next_hero.hero_id, next_hero.hero_name])
