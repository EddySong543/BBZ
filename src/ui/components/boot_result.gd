class_name BootResult
extends RefCounted

## boot_screen 对波启动过场的结局——跨场景静态记忆（同一进程内）。
##
## boot 里两道波对撞，随机一方"盖过"另一方进入标题。胜方色（蓝 / 红）由此记下，
## 供 main_menu / bp_screen 的单色对波背景（wave_flow_bg.gd）继承：胜方的波
## 继续在菜单背景里朝它的方向缓缓横扫。
##
## 直接进菜单（未经过 boot，例如编辑器单独运行场景）时用默认值，不报错。

## 上一次 boot 对波的胜方是否为蓝侧（false = 红侧）。默认蓝。
static var last_blue_wins: bool = true

## 是否真的经历过一次 boot 对波（用于区分"默认值"与"真结局"，备用）。
static var has_result: bool = false


## boot_screen 在分出胜负时调用，记下胜方色。
static func set_winner(blue_wins: bool) -> void:
	last_blue_wins = blue_wins
	has_result = true


## boot→menu 衔接用的"胜方色幕"颜色。
## 取该色波场亮浪头档位的色相（蓝/红），让 boot 末尾决堤色幕、菜单进场色幕、
## 与波流背景三者同色相连贯——无白闪硬切。色值对应 canvas_env_wave_flow 的 ramp 高档。
static func dip_color() -> Color:
	return Color(0.36, 0.64, 1.0) if last_blue_wins else Color(0.96, 0.37, 0.25)
