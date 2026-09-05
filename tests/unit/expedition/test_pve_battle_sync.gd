extends GutTest

## PvE 只保留会话适配；英雄、AI、道具和结算继续使用当前本地战斗实现。

const BattlePve := preload("res://src/ui/components/battle_pve.gd")
const BATTLE_SCENE := preload("res://src/ui/battle_screen1.tscn")


class PveHostStub:
	extends Control
	var battle: BattleCore
	var state: int = 0
	var status_label := Label.new()

	func _ready() -> void:
		add_child(status_label)

	func _set_buttons_active(_active: bool, _dim_inactive: bool = true) -> void:
		pass


func after_each() -> void:
	BattleSetup.reset()
	BattleSetup.pve_result = {}


func _hero(hero_id: String) -> HeroData:
	return load("res://assets/data/heroes/%s.tres" % hero_id) as HeroData


func test_pve_setup_rejects_blank_hero_definitions() -> void:
	var blank := HeroData.new()
	blank.hero_name = "旧白板"
	blank.max_hp = 5

	assert_false(BattleSetup.configure_pve([blank], [_hero("h02")]))
	assert_false(BattleSetup.pve_mode)


func test_pve_adapter_copies_complete_real_hero_data() -> void:
	var source: HeroData = _hero("h05")
	var adapter := BattlePve.new()
	add_child_autofree(adapter)

	var team: Array = adapter.build_team([source])

	assert_eq(team.size(), 1)
	assert_true(team[0] is HeroData)
	assert_eq((team[0] as HeroData).hero_id, "h05")
	assert_eq((team[0] as HeroData).skill_description, source.skill_description)
	assert_eq((team[0] as HeroData).sprite_frames_path, source.sprite_frames_path)
	assert_ne(team[0], source, "战斗会话应复制只读英雄定义，不能把跨场景资源当白板改写")


func test_pve_battle_scene_uses_current_heroes_ai_and_item_economy() -> void:
	var player: HeroData = _hero("h05")
	var opponent: HeroData = _hero("h13")
	assert_true(BattleSetup.configure_pve(
		[player], [opponent], [7], [7], 2468))

	var screen := BATTLE_SCENE.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(screen._pve)
	assert_eq((screen.battle.heroes[0][0] as HeroData).hero_id, "h05")
	assert_eq((screen.battle.heroes[1][0] as HeroData).hero_id, "h13")
	assert_not_null(screen.battle.get_skill(0, 0), "PvE 必须保留当前英雄技能组件")
	assert_not_null(screen.battle.get_skill(1, 0), "PvE 对手同样走当前英雄/敌人定义")
	assert_eq(screen.battle.hp[0], [7])
	assert_eq(screen.battle.hp[1], [7])
	assert_eq(screen.battle.slots[0].size(), BattleCore.SLOT_COUNT)
	assert_eq(screen.battle.slots[1].size(), BattleCore.SLOT_COUNT)
	assert_false(screen.battle.pve_no_econ, "PvE 不再锁死旧装备槽，沿用当前道具经济")
	assert_eq(screen._pved.get_child_count(), 0,
		"PvE 适配层不再生成旧概率表或手算脱战按钮")
	var legal: Array = screen.battle.legal_actions(screen.AI)
	var choice: Dictionary = screen._ai.choose_action(screen.battle, screen.AI)
	assert_has(legal, choice, "PvE 对手必须从当前 BattleCore.legal_actions 中选择")
	assert_true(screen.battle.apply_choice(screen.AI, choice),
		"PvE 对手选择必须经过与玩家相同的 apply_choice 入口")


func test_pve_result_keeps_each_opponent_hp() -> void:
	var host := PveHostStub.new()
	add_child_autofree(host)
	host.battle = BattleCore.new()
	host.battle.setup([_hero("h01")], [_hero("h02"), _hero("h03")], 42)
	host.battle.hp[0][0] = 6
	host.battle.hp[1].assign([3, 8])

	var adapter := BattlePve.new()
	add_child_autofree(adapter)
	adapter.setup(host)
	var result: Dictionary = adapter.capture_result("win")

	assert_eq(result["team_hp"], [6])
	assert_eq(result["opponent_hp"], [3, 8])
	assert_false(result.has("monster_hp"), "结果协议不再保留旧单怪字段")
