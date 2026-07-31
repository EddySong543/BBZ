extends Node

const OUT_DIR := "D:/Game/BoBoZan/_probe_output/scene1_no_ui_parallax_frames"
const FRAME_COUNT := 60
const FRAME_STEP_SECONDS := 1.0 / 12.0
const KEEP_ROOTS := {
	"StageSlot": true,
	"FinisherGrab": true,
	"FinisherVeil": true,
	"WorldGroup": true,
	"ForeDust": true,
	"LowerDust": true,
	"WorldGrab": true,
	"PostFX": true,
}

var _battle: Node
var _frame := 0
var _elapsed := 0.0
var _started := false


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_clear_old_frames()
	_battle = (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(_battle)
	await get_tree().create_timer(2.2).timeout
	_hide_battle_ui(_battle)
	_started = true


func _process(delta: float) -> void:
	if not _started:
		return
	_elapsed += delta
	if _elapsed < FRAME_STEP_SECONDS:
		return
	_elapsed -= FRAME_STEP_SECONDS
	if _frame >= FRAME_COUNT:
		get_tree().quit()
		return
	await _capture_frame()


func _capture_frame() -> void:
	var t := float(_frame) / float(FRAME_COUNT - 1)
	var wave := 0.5 - 0.5 * cos(t * TAU)
	Input.warp_mouse(Vector2(220.0 + wave * 1480.0, 540.0))
	await RenderingServer.frame_post_draw
	var path := "%s/frame_%03d.png" % [OUT_DIR, _frame]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
	_frame += 1


func _hide_battle_ui(root: Node) -> void:
	for child in root.get_children():
		if KEEP_ROOTS.has(child.name):
			continue
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _clear_old_frames() -> void:
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("frame_") and file_name.ends_with(".png"):
			dir.remove(file_name)
