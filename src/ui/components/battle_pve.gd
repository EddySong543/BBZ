extends Node

## 远征 PvE 的窄适配层。
##
## 战斗规则、英雄技能、敌方决策和道具经济均由当前 BattleCore / BattleAI
## 提供。本组件只做三件事：复制完整 HeroData、应用跨战 HP、
## 将战斗结果封装后返回远征。它不构造白板角色，不决定出招，也不手算脱战伤害。

const PveBattleSession := preload("res://src/battle/pve_battle_session.gd")

var _host: Control = null
var _ending: bool = false


func setup(host: Control) -> void:
	_host = host


## 战斗会话使用独立 Resource 实例，但保留 hero_id 与全部当前字段。
## 空 hero_id 代表旧白板协议，在此直接拒绝。
func build_team(team: Array) -> Array[HeroData]:
	return PveBattleSession.copy_team(team)


## 跨战 HP 是进入战斗前的会话状态，不是另一套结算规则。
## 传入空数组时保持 BattleCore.setup() 设置的满血；超界值夹到本英雄上限。
func apply_initial_hp(player_hp: Array, opponent_hp: Array) -> void:
	if _host == null or _host.battle == null:
		push_error("BattlePve: setup(host) must be called before apply_initial_hp")
		return
	PveBattleSession.apply_initial_hp(_host.battle, player_hp, opponent_hp)


func capture_result(outcome: String) -> Dictionary:
	return PveBattleSession.capture_result(_host.battle if _host != null else null, outcome)


## 终局是 PvE 唯一的流程出口：保存远征状态并返回地图。
func finish(outcome: String) -> void:
	if _ending:
		return
	_ending = true
	_host.state = _host.State.GAME_OVER
	_host._set_buttons_active(false)
	BattleSetup.pve_result = capture_result(outcome)
	_host.status_label.text = tr("胜利！") if outcome == "win" else tr("失败")
	_host.status_label.add_theme_color_override(
		"font_color", Color("#5fd86b") if outcome == "win" else Color("#dddddd"))
	_host.status_label.visible = true
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or not is_instance_valid(_host):
		return
	TransitionManager.transition_to("res://src/expedition/expedition_screen.tscn")
