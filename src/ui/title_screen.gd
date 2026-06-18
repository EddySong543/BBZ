extends Control

## 标题屏（P1-4e: 从 start_screen 拆出）— 点 StartButton 切到 BP 屏。

@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var start_button: Button = $StartButton


func _ready() -> void:
	title_label.text = "波波攒"
	FontManager.apply(title_label, 48)
	title_label.add_theme_color_override("font_color", Color("#f5c518"))

	subtitle_label.text = "1v1 同时回合制英雄对战"
	FontManager.apply(subtitle_label, 24)
	subtitle_label.add_theme_color_override("font_color", Color("#888899"))

	start_button.text = "开始匹配"
	FontManager.apply_btn(start_button, 32)
	start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/bp_screen.tscn")
