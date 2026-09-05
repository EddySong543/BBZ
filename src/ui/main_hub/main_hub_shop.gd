class_name MainHubShopStage
extends BattleStage

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProfileStore := preload("res://src/core/player_profile.gd")
const FALLBACK_HERO_PATH := "res://assets/data/heroes/h01.tres"
const H01_WALK_FRAMES_PATH := "res://assets/sprites/heroes/h01/h01_walk.tres"

@export var district_id: StringName = &"shop"

@onready var player_character: MainHubCharacter = $ActorLayer/PlayerCharacter


func _ready() -> void:
	super()
	_load_profile_character()


func get_layer_contract() -> Dictionary[String, float]:
	var contract: Dictionary[String, float] = {}
	for child: Node in get_children():
		if child is CanvasItem and child.has_meta("parallax_factor"):
			contract[child.name] = float(child.get_meta("parallax_factor"))
	return contract


func _load_profile_character() -> void:
	var selected_hero_id: String = ProfileStore.get_avatar_hero()
	var selected_hero: HeroData = null
	for candidate: HeroData in HeroDataScript.create_launch_pool():
		if candidate.hero_id == selected_hero_id:
			selected_hero = candidate
			break
	if selected_hero == null:
		selected_hero = load(FALLBACK_HERO_PATH) as HeroData
	if selected_hero == null or not ResourceLoader.exists(selected_hero.sprite_frames_path):
		return
	var walk_path := H01_WALK_FRAMES_PATH if selected_hero.hero_id == "h01" else ""
	player_character.configure_animation_resources(
			selected_hero.sprite_frames_path, walk_path)
