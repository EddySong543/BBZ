extends Control

@export_range(0.5, 4.0, 0.1) var fade_duration: float = 1.8
@export_range(0.0, 1.0, 0.01) var minimum_alpha: float = 0.84

@onready var _label: Label = $Label

var _fade_tween: Tween


func _ready() -> void:
	FontManager.apply(_label, 24)
	_start_fade_loop()


func _start_fade_loop() -> void:
	modulate.a = minimum_alpha
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_loops()
	_fade_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		fade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(
		self,
		"modulate:a",
		minimum_alpha,
		fade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
