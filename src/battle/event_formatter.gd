class_name EventFormatter
extends Object

## 把 BattleCore 产生的结构化事件 Dictionary 翻译成中文显示文本。
##
## 设计意图：BattleCore 的 events 只携带 {id, 参数...}，不含任何文案。
## i18n 时整体替换本文件即可，BattleCore / 测试 / UI 无需改动。
##
## 事件 schema 约定：
##   - 必填字段：id (String)
##   - 通用字段：player (int, 0/1) — 用于显示 "P1"/"P2"
##   - 其他字段按事件特定 — 见下方 match 各分支


static func format(e: Dictionary) -> String:
	var id: String = e.get("id", "")
	var p_label: String = "P%d" % (int(e.get("player", -1)) + 1)
	match id:
		"charge_gain":
			return "%s 攒 +%d能量" % [p_label, e.amount]
		"caijin_buff_set":
			return "%s [财源广进] 下次攒能量翻倍" % p_label
		"caijin_triggered":
			return "%s [财源广进] 攒能量翻倍！" % p_label
		"sheshen_used":
			return "%s [舍身] -2HP +3能量" % p_label
		"yuzhe_random":
			return "%s [不可知之权柄] → %s" % [p_label, action_name(e.action_id)]
		"baishou_spent":
			return "%s 百兽消耗 %d 能量" % [p_label, e.amount]
		"baishou_destroy_clones":
			return "%s 百兽摧毁 %d 个分身！" % [p_label, e.count]
		"baishou_blocked":
			return "%s 百兽被大防格挡" % p_label
		"baishou_hits":
			return "%s 百兽造成 %d 次1点伤害" % [p_label, e.count]
		"fange_reflect":
			return "%s [反戈] 无视防御，反弹%d伤害" % [p_label, e.amount]
		"fange_immune":
			return "%s [反戈] 被无敌免疫！" % p_label
		"shield_absorb":
			return "%s 护盾吸收%d伤害" % [p_label, e.amount]
		"jiaotu_immune":
			return "%s [狡兔] 免疫了 %d 伤害" % [p_label, e.amount]
		"damage_taken":
			return "%s 受到 %d 伤害" % [p_label, e.amount]
		"haizhu_energy_gain":
			return "%s [亥猪] 纳福 +%d能量" % [p_label, e.amount]
		"shetui_revive":
			return "%s [蛇蜕] 复活！1HP，波/防永久升级" % p_label
		"draw":
			return "双方全灭 — 平局！"
		"victory":
			var winner: int = e.winner
			var loser: int = 3 - winner
			return "P%d 全灭，P%d 获胜！" % [loser, winner]
		"jiaotu_free_switch":
			return "%s [狡兔三窟] 下回合免费切换" % p_label
		"shenwai_create":
			return "%s [身外化身] 创建1个分身！(共%d个)" % [p_label, e.total]
		"clone_destroyed":
			return "%s [分身] 假身被%s摧毁！" % [p_label, _source_label(e.source)]
		"big_defend_block":
			return "%s 被大防格挡" % p_label
		"defend_block":
			return "%s 被防格挡" % p_label
		"attack_hit":
			return "%s 命中，%d 伤害" % [p_label, e.amount]
		"force_switch_prompt":
			return "%s 英雄阵亡，请选择替补英雄" % p_label
		"no_switch_available":
			return "%s 无存活英雄可切换" % p_label
	push_warning("EventFormatter: unknown event id %s" % id)
	return "[未知事件: %s]" % id


static func _source_label(source_id: String) -> String:
	match source_id:
		"attack": return "攻击"
		"baishou": return "百兽"
		"test": return "测试"
	return source_id


## P1-NEW1: 把 action id (来自 BattleCore.get_action_id) 翻译为中文显示文本。
## i18n 时整体替换本 match 即可。
static func action_name(action_id: String) -> String:
	match action_id:
		"charge": return "攒"
		"attack": return "波"
		"defend": return "防"
		"big_attack": return "大波"
		"big_defend": return "大防"
		"switch": return "切换"
		"fange": return "反戈"
		"baishou": return "百兽"
		"jiaotu": return "狡兔三窟"
		"shetui": return "蛇蜕"
		"sheshen": return "舍身"
		"shenwai": return "身外化身"
		"caijin": return "财源广进"
		"yuzhe": return "不可知之权柄"
	push_warning("EventFormatter: unknown action_id %s" % action_id)
	return "[未知动作: %s]" % action_id
