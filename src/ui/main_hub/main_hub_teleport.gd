class_name MainHubTeleportStage
extends BattleStage

signal exit_requested(direction: StringName, target_district: StringName)

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProfileStore := preload("res://src/core/player_profile.gd")
const FALLBACK_HERO_PATH := "res://assets/data/heroes/h01.tres"

@export var district_id: StringName = &"teleport"
@export var left_district_id: StringName = &"team_prep"
@export var right_district_id: StringName = &"shop"

@onready var player_character: CharacterDisplay = $CharacterLayer/PlayerCharacter
@onready var portal_rig: MainHubPortalRig = $PortalLayer/PortalRig


func _ready() -> void:
	super()
	_load_profile_character()


func get_layer_contract() -> Dictionary[String, float]:
	var contract: Dictionary[String, float] = {}
	for layer_name: String in [
		"Backdrop",
		"FarEnvironment",
		"MidEnvironment",
		"GroundEnvironment",
		"PortalLayer",
		"CharacterLayer",
		"ForegroundEnvironment",
	]:
		var layer := get_node(layer_name) as CanvasItem
		contract[layer_name] = float(layer.get_meta("parallax_factor"))
	return contract


func get_exit_contract() -> Dictionary[StringName, StringName]:
	return {
		&"left": left_district_id,
		&"right": right_district_id,
	}


func request_exit(direction: StringName) -> bool:
	var target_district: StringName
	match direction:
		&"left":
			target_district = left_district_id
		&"right":
			target_district = right_district_id
		_:
			return false
	if target_district.is_empty():
		return false
	exit_requested.emit(direction, target_district)
	return true


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
	player_character.sprite_frames_path = selected_hero.sprite_frames_path
