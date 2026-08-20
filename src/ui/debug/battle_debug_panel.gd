extends VBoxContainer

## 战斗调试面板（DEBUG 专用·左侧竖排测试按钮）：满能量 / 满血 / 敌我造伤 / 加盾 / 换英雄。
## ⚠ 全项目【唯一】直接改写 BattleCore 状态的 UI —— 有意隔离于此，让 battle_screen 保持「只读引擎状态」
##   （联机防作弊边界·可 grep 断言 battle_screen 不写 hp/energy/shield）。
## ⚠ 不走正常结算管线：debug 致死不触发强制换人浮窗（要测死亡流程请打真实战斗）。
## 表现回接 battle_screen 走信号（面板不碰 juice / 刷新，保持职责单一）：
##   state_changed → 请 battle_screen _update_all 刷新；hit_fx → 请 battle_screen 播打击 juice。

signal state_changed                        # 改了 battle 状态 → 请 battle_screen 刷新
signal hit_fx(player: int, dmg_half: int)   # 造伤按钮 → 请 battle_screen 播打击表现（飘字/斩击/震屏）
signal overtime_requested                   # 一键进加时赛 → 请 battle_screen 组白板 1v1 并重载场景

const PLAYER := 0
const AI := 1

var _battle: BattleCore
var _art_pool: Array[HeroData] = []   # 美术巡检池：全英雄池中有 idle 资产的（首次点击构建）


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
		["进加时赛", _dbg_enter_overtime],
	]
	for d in defs:
		var b := Button.new()
		b.text = d[0] as String
		b.custom_minimum_size = Vector2(92.0, 30.0)
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.82)
		FontManager.apply_btn(b, 14)
		b.pressed.connect(d[1] as Callable)
		add_child(b)


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
