class_name ItemCatalog
extends RefCounted

## 道具目录（ADR-003 D1）。集中数据源：id → 元数据 + 一句话描述 + 效果参数 + 逻辑脚本。
## 逻辑在 src/battle/items/<id>.gd（继承 ItemEffect）。make(id) 构造一件 ItemData（含独立 effect 实例）。
##
## 当前 = Tier-1 全部【非趣味】框架件（design/items.md §1 · 26 件·铜镜+毒刺已删）。
## T1 趣味点缀（倒数沙漏/命运转盘…）待 Eddy 定稿后另加；T2/T3 后续。

const _S_PRE := ItemData.Seq.PRE
const _S_ANY := ItemData.Seq.ANY
const _T_ENEMY := ItemData.Target.ENEMY
const _T_SELF := ItemData.Target.SELF

## id → {name, dim, role, seq, target, desc(一句话), params, script}
const _DEF := {
	# --- 1A 进攻 ---
	"t1_feibiao": {
		name = "生锈的飞镖", dim = "进攻", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "对敌方出战造成 0.5 伤。", params = {dmg = 1},
		script = preload("res://src/battle/items/t1_feibiao.gd")},
	"t1_xianshou": {
		name = "先手", dim = "进攻", role = "填隙", seq = _S_PRE, target = _T_SELF,
		desc = "你这次攻击 +0.5 伤。", params = {bonus = 1},
		script = preload("res://src/battle/items/t1_xianshou.gd")},
	"t1_dutu_yingbi": {
		name = "赌徒的硬币", dim = "进攻", role = "随机", seq = _S_PRE, target = _T_SELF,
		desc = "抛币：正面这次攻击 +1.0 伤，反面落空。", params = {win = 2},
		script = preload("res://src/battle/items/t1_dutu_yingbi.gd")},
	"t1_podun_zhou": {
		name = "银质穿甲箭", dim = "进攻", role = "破防", seq = _S_PRE, target = _T_SELF,
		desc = "若对手本回合用「防」，你这次攻击穿防。", params = {},
		script = preload("res://src/battle/items/t1_podun_zhou.gd")},
	# --- 1B 防御 ---
	"t1_jiudun": {
		name = "破旧的护盾", dim = "防御", role = "填隙", seq = _S_ANY, target = _T_SELF,
		desc = "己方出战 +0.5 甲（额外血量层）。", params = {armor = 1},
		script = preload("res://src/battle/items/t1_jiudun.gd")},
	"t1_houshou": {
		name = "后手", dim = "防御", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "若对手本回合攻击，你 +1.0 甲；否则无效。", params = {armor = 2},
		script = preload("res://src/battle/items/t1_houshou.gd")},
	"t1_lzhi_shengming": {
		name = "劣质生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "己方出战回 0.5 HP。", params = {heal = 1},
		script = preload("res://src/battle/items/t1_lzhi_shengming.gd")},
	"t1_qipao": {
		name = "残缺的佛像", dim = "防御", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "若对手「大波」，你这次「防」可挡下大波一次。", params = {},
		script = preload("res://src/battle/items/t1_qipao.gd")},
	"t1_tongqian": {
		name = "算命先生的铜钱", dim = "防御", role = "对冲", seq = _S_ANY, target = _T_SELF,
		desc = "若对手攻击则 +0.5 甲，否则 +0.5 能。", params = {armor = 1, energy = 1},
		script = preload("res://src/battle/items/t1_tongqian.gd")},
	# --- 1C 能量 ---
	"t1_lzhi_fali": {
		name = "劣质法力药水", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合若你「攒」，额外 +0.5 能。", params = {energy = 1},
		script = preload("res://src/battle/items/t1_lzhi_fali.gd")},
	"t1_moli_shuijing": {
		name = "下金蛋的鹅", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合你不攻击，则 +0.5 能。", params = {energy = 1},
		script = preload("res://src/battle/items/t1_moli_shuijing.gd")},
	"t1_shengli_zhou": {
		name = "四两", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合你用大波 / 大防，省 0.5 能。", params = {save = 1},
		script = preload("res://src/battle/items/t1_shengli_zhou.gd")},
	# --- 1D 状态 ---
	"t1_yaohuo": {
		name = "妖火", dim = "状态", role = "", seq = _S_ANY, target = _T_ENEMY,
		desc = "敌方出战灼烧，下回合 −0.5 HP 且该回合无法回血。", params = {dot = 1},
		script = preload("res://src/battle/items/t1_yaohuo.gd")},
	# --- 1E 干扰 ---
	"t1_xiangjiaopi": {
		name = "臭鸡蛋", dim = "干扰", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "对手本回合攻击 −0.5 伤。", params = {penalty = 1},
		script = preload("res://src/battle/items/t1_xiangjiaopi.gd")},
	"t1_lingdang": {
		name = "STEAL技能卡", dim = "干扰", role = "", seq = _S_ANY, target = _T_ENEMY,
		desc = "对手本回合若「攒」，少回 0.5 能。", params = {penalty = 1},
		script = preload("res://src/battle/items/t1_lingdang.gd")},
	"t1_huanying": {
		name = "伪造的宝石", dim = "干扰", role = "诈唬", seq = _S_ANY, target = _T_SELF,
		desc = "你的道具栏对对手多显示 1 个假道具，直到你下次用道具。", params = {},
		script = preload("res://src/battle/items/t1_huanying.gd")},
	"t1_miwu": {
		name = "一片树叶", dim = "干扰", role = "信息", seq = _S_ANY, target = _T_SELF,
		desc = "你的 1 个道具对对手隐藏，直到你下次用道具。", params = {},
		script = preload("res://src/battle/items/t1_miwu.gd")},
	# --- 1F 导出 ---
	"t1_xixie_yaya": {
		name = "血魔的獠牙", dim = "导出", role = "进攻→防御", seq = _S_PRE, target = _T_SELF,
		desc = "你这次攻击命中时回 0.5 HP。", params = {heal = 1},
		script = preload("res://src/battle/items/t1_xixie_yaya.gd")},
	"t1_moli_yuanquan": {
		name = "盗版太极图", dim = "导出", role = "防御→能量", seq = _S_ANY, target = _T_SELF,
		desc = "本回合你防御成功时 +0.5 能。", params = {energy = 1},
		script = preload("res://src/battle/items/t1_moli_yuanquan.gd")},
	# --- 1G 扩展（含变体 / 净化 / 节奏 / 随机）---
	# 注：「毒刺」（命中下毒）已删 —— 与巳蛇 h06 淬毒功能完全相同，禁撞英雄（Eddy 2026-06-18）。
	"t1_siyecao": {
		name = "最后一箭", dim = "进攻", role = "随机变体", seq = _S_PRE, target = _T_ENEMY,
		desc = "造成 0.5 伤；若你 HP 比对手低，改为 1.0 伤。", params = {dmg = 1, boon = 2},
		script = preload("res://src/battle/items/t1_siyecao.gd")},
	"t1_shandian": {
		name = "暗箭", dim = "进攻", role = "破防", seq = _S_ANY, target = _T_ENEMY,
		desc = "对敌方出战 0.5 伤，无视「防」。", params = {dmg = 1},
		script = preload("res://src/battle/items/t1_shandian.gd")},
	"t1_jiedu_yaoshui": {
		name = "解毒药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "回 0.5 HP，并解除自身全部毒 / 灼。", params = {heal = 1},
		script = preload("res://src/battle/items/t1_jiedu_yaoshui.gd")},
	"t1_hushenfu": {
		name = "圣贤书", dim = "防御", role = "净化", seq = _S_ANY, target = _T_SELF,
		desc = "本回合免疫对手对你的一次干扰 / debuff。", params = {immune = 1},
		script = preload("res://src/battle/items/t1_hushenfu.gd")},
	"t1_fengzhixue": {
		name = "回马枪", dim = "节奏", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "本回合若你「切换」，下回合你的攻击 +0.5 伤。", params = {bonus = 1},
		script = preload("res://src/battle/items/t1_fengzhixue.gd")},
	"t1_jinnang": {
		name = "不太鼓的锦囊", dim = "随机", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "随机获得 +0.5 伤 / +0.5 甲 / +0.5 能 之一。", params = {},
		script = preload("res://src/battle/items/t1_jinnang.gd")},
}


## 构造一件道具（带独立 effect 实例 + 独立 params 副本）。未知 id 返回 null。
static func make(id: String) -> ItemData:
	if not _DEF.has(id):
		push_error("ItemCatalog: 未知道具 id %s" % id)
		return null
	var d: Dictionary = _DEF[id]
	var item := ItemData.new()
	item.item_id = id
	item.item_name = d["name"]
	item.tier = 1
	item.dimension = d["dim"]
	item.role = d.get("role", "")
	item.sequence_tag = d["seq"]
	item.target_mode = d["target"]
	item.description = d["desc"]
	item.ev_half = 1
	item.params = (d["params"] as Dictionary).duplicate(true)
	item.effect = d["script"].new()
	return item


## 全部 Tier-1 非趣味件（id 字典序）。
static func all_tier1() -> Array[ItemData]:
	var out: Array[ItemData] = []
	var keys: Array = _DEF.keys()
	keys.sort()
	for id in keys:
		out.append(make(id))
	return out


static func ids() -> Array:
	return _DEF.keys()
