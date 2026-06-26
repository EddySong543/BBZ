class_name ItemCatalog
extends RefCounted

## 道具目录（ADR-003 D1）。集中数据源：id → 元数据 + 一句话描述 + 效果参数 + 逻辑脚本。
## 逻辑在 src/battle/items/<id>.gd（继承 ItemEffect）。make(id) 构造一件 ItemData（含独立 effect 实例）。
##
## 当前已实装 = 首发 61 件（T1 20 / T2 24 / T3 17·含中立 / 趣味）= design/items-firstrelease.md（真相源）。
## 全集 112 件（design/items-list.md）中未入选的 51 件为延后释放池，按版本逐批上线。
##
## 道具均为字符串 id（tier 前缀拼音），无数字编号。⚠ id 拼音为历史化石、≠ 当前显示名
## （如 t1_xiangjiaopi=「臭鸡蛋」、t1_lingdang=「STEAL技能卡」）——id 是内部稳定主键、永不展示给玩家，
## 故不随显示名改名。显示名 item_name 已与 design/items-list.md 对齐。
## 美术：图标按约定路径 ICON_DIR/<id>.png 加载（见底部 icon_path / load_icon）；缺图时 UI 回退占位文字。

const _S_PRE := ItemData.Seq.PRE
const _S_ANY := ItemData.Seq.ANY
const _T_ENEMY := ItemData.Target.ENEMY
const _T_SELF := ItemData.Target.SELF

## id → {name, dim, role, seq, target, desc(一句话), params, script}
const _DEF := {
	# --- 1A 进攻 ---
	"t1_feibiao": {
		name = "生锈的暗器", dim = "进攻", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "对敌方出战造成 0.5 伤。", params = {dmg = 1}, upgrade = "t2_feibiao",
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
		desc = "己方出战 +0.5 甲（额外血量层）。", params = {armor = 1}, upgrade = "t2_jiandun",
		script = preload("res://src/battle/items/t1_jiudun.gd")},
	"t1_houshou": {
		name = "后手", dim = "防御", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "若对手本回合攻击，你 +1.0 甲；否则无效。", params = {armor = 2},
		script = preload("res://src/battle/items/t1_houshou.gd")},
	"t1_lzhi_shengming": {
		name = "劣质生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "己方出战回 0.5 HP。", params = {heal = 1}, upgrade = "t2_shengming",
		script = preload("res://src/battle/items/t1_lzhi_shengming.gd")},
	"t1_qipao": {
		name = "残缺的佛像", dim = "防御", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "若对手「大波」，你这次「防」可挡下大波一次。", params = {},
		script = preload("res://src/battle/items/t1_qipao.gd")},
	"t1_tongqian": {
		name = "算命铜钱", dim = "博弈", role = "对冲", seq = _S_ANY, target = _T_SELF,
		desc = "若对手攻击则 +0.5 甲，否则 +0.5 能。", params = {armor = 1, energy = 1},
		script = preload("res://src/battle/items/t1_tongqian.gd")},
	# --- 1C 能量 ---
	"t1_lzhi_fali": {
		name = "劣质法力药水", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合若你「攒」，额外 +0.5 能。", params = {energy = 1}, upgrade = "t2_fali",
		script = preload("res://src/battle/items/t1_lzhi_fali.gd")},
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
	"t1_hushenfu": {
		name = "圣贤书", dim = "防御", role = "净化", seq = _S_ANY, target = _T_SELF,
		desc = "本回合免疫对手对你的一次干扰 / debuff。", params = {immune = 1},
		script = preload("res://src/battle/items/t1_hushenfu.gd")},
	"t1_fengzhixue": {
		name = "回马枪", dim = "节奏", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "本回合若你「切换」，下回合你的攻击 +0.5 伤。", params = {bonus = 1},
		script = preload("res://src/battle/items/t1_fengzhixue.gd")},

	# ========== Tier-2（连携件 ≈1.0·非中立/非趣味·Phase 1）==========
	# --- 2A 进攻 ---
	"t2_feibiao": {
		tier = 2, ev = 2, name = "锋利的飞镖", dim = "进攻", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "对敌方出战造成 1.0 伤。", params = {dmg = 2},
		script = preload("res://src/battle/items/t2_feibiao.gd")},
	"t2_shuangsheng": {
		tier = 2, ev = 2, name = "双生咒符", dim = "进攻", role = "泛连携", seq = _S_PRE, target = _T_SELF,
		desc = "你本回合攻击的命中次数 +1（多触发一次 on-hit，伤害不变）。", params = {hits = 1},
		script = preload("res://src/battle/items/t2_shuangsheng.gd")},
	"t2_shitiechong": {
		tier = 2, ev = 2, name = "噬铁虫", dim = "进攻", role = "破防", seq = _S_PRE, target = _T_ENEMY,
		desc = "降对手防御一级 1 回合（大防→防、防→无）。", params = {},
		script = preload("res://src/battle/items/t2_shitiechong.gd")},
	"t2_pomoshi": {
		tier = 2, ev = 2, name = "破魔矢", dim = "进攻", role = "穿透", seq = _S_PRE, target = _T_SELF,
		desc = "你这次「波」改为穿防。", params = {},
		script = preload("res://src/battle/items/t2_pomoshi.gd")},
	"t2_qiubite": {
		tier = 2, ev = 2, name = "心脏掌握魔法", dim = "进攻", role = "穿甲", seq = _S_PRE, target = _T_SELF,
		desc = "你这次攻击无视对手护甲层（穿甲）。", params = {},
		script = preload("res://src/battle/items/t2_qiubite.gd")},
	# --- 2B 防御 ---
	"t2_jiandun": {
		tier = 2, ev = 2, name = "坚固的护盾", dim = "防御", role = "填隙", seq = _S_ANY, target = _T_SELF,
		desc = "己方出战 +1.0 甲（额外血量层）。", params = {armor = 2},
		script = preload("res://src/battle/items/t2_jiandun.gd")},
	"t2_wudouwawa": {
		tier = 2, ev = 2, name = "巫毒娃娃", dim = "防御", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "放一个 HP1 替身，下次受伤由它吃下（溢出穿过、挨一下即碎）。", params = {hp = 2},
		script = preload("res://src/battle/items/t2_wudouwawa.gd")},
	"t2_huanhundan": {
		tier = 2, ev = 2, name = "还魂丹", dim = "防御", role = "救援", seq = _S_ANY, target = _T_SELF,
		desc = "本局一次，你出战将死时改为保留 0.5 HP。", params = {},
		script = preload("res://src/battle/items/t2_huanhundan.gd")},
	# --- 2C 治疗 ---
	"t2_shengming": {
		tier = 2, ev = 2, name = "普通生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "己方出战回 1.0 HP。", params = {heal = 2}, upgrade = "t3_shengming",
		script = preload("res://src/battle/items/t2_shengming.gd")},
	"t2_nuanyu": {
		tier = 2, ev = 2, name = "暖玉", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "你「防御」回合回 1.0 HP（反 stall）。", params = {heal = 2},
		script = preload("res://src/battle/items/t2_nuanyu.gd")},
	# --- 2D 能量 ---
	"t2_fali": {
		tier = 2, ev = 2, name = "普通法力药水", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合若你「攒」，额外 +1.0 能。", params = {energy = 2}, upgrade = "t3_fali",
		script = preload("res://src/battle/items/t2_fali.gd")},
	"t2_baolie": {
		tier = 2, ev = 2, name = "爆裂卷轴", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "你这次「大波」少耗 1 能。", params = {save = 2},
		script = preload("res://src/battle/items/t2_baolie.gd")},
	# --- 2E 节奏 ---
	# --- 2F 状态 ---
	"t2_duyao": {
		tier = 2, ev = 2, name = "毒药瓶", dim = "状态", role = "连携", seq = _S_ANY, target = _T_ENEMY,
		desc = "敌方出战 +2 层毒（任意攻击引爆）。", params = {poison = 2},
		script = preload("res://src/battle/items/t2_duyao.gd")},
	"t2_lieyin": {
		tier = 2, ev = 2, name = "猎物印记", dim = "状态", role = "易伤", seq = _S_ANY, target = _T_ENEMY,
		desc = "敌方出战本回合下次受击 +0.5。", params = {amount = 1},
		script = preload("res://src/battle/items/t2_lieyin.gd")},
	# --- 2G 干扰 ---
	"t2_daijia": {
		tier = 2, ev = 2, name = "力量的代价", dim = "干扰", role = "元件层", seq = _S_ANY, target = _T_ENEMY,
		desc = "对手本回合费能动作（大波/大防）多耗 1 能。", params = {tax = 2},
		script = preload("res://src/battle/items/t2_daijia.gd")},
	"t2_dingshen": {
		tier = 2, ev = 2, name = "定身符", dim = "干扰", role = "元件层", seq = _S_ANY, target = _T_ENEMY,
		desc = "对手本回合无法「切换」。", params = {},
		script = preload("res://src/battle/items/t2_dingshen.gd")},
	# --- 2H 导出 ---
	"t2_jike": {
		tier = 2, ev = 2, name = "扭曲的饥渴", dim = "导出", role = "攻→防", seq = _S_PRE, target = _T_SELF,
		desc = "你这次攻击命中回 1.0 HP。", params = {heal = 2},
		script = preload("res://src/battle/items/t2_jike.gd")},
	"t2_huoshou": {
		tier = 2, ev = 2, name = "秘银充能护手", dim = "导出", role = "攻→能", seq = _S_PRE, target = _T_SELF,
		desc = "你攻击命中时 +0.5 能。", params = {energy = 1},
		script = preload("res://src/battle/items/t2_huoshou.gd")},
	"t2_xiongyao": {
		tier = 2, ev = 2, name = "凶药", dim = "导出", role = "HP→攻", seq = _S_PRE, target = _T_SELF,
		desc = "弃 0.5 HP，你这次攻击 +1.0 伤。", params = {pay = 1, bonus = 2},
		script = preload("res://src/battle/items/t2_xiongyao.gd")},
	# --- 2I 博弈 ---
	"t2_shaizi": {
		tier = 2, ev = 2, name = "命运骰子", dim = "博弈", role = "博弈", seq = _S_ANY, target = _T_SELF,
		desc = "随机 +1.0 伤 / 甲 / 能 之一，可重抛一次（取对你更有利的一面）。", params = {amount = 2},
		script = preload("res://src/battle/items/t2_shaizi.gd")},

	# ========== Tier-3（超模 / build-around·非中立/非趣味·Phase 1 可实装子集）==========
	"t3_longxi": {
		tier = 3, ev = 4, name = "龙息", dim = "进攻", role = "自成核", seq = _S_PRE, target = _T_SELF,
		desc = "本回合「大波」翻倍（4.0 穿防）；被「大防」挡下 → 下回合力竭。", params = {},
		script = preload("res://src/battle/items/t3_longxi.gd")},
	"t3_yujin": {
		tier = 3, ev = 6, name = "不死鸟的羽毛", dim = "进攻", role = "自成核", seq = _S_PRE, target = _T_SELF,
		desc = "若你 HP ≤ 1.0，这次攻击 +3.0 伤穿大防。", params = {threshold = 2, bonus = 6},
		script = preload("res://src/battle/items/t3_yujin.gd")},
	"t3_jianyi": {
		tier = 3, ev = 4, name = "至臻剑意", dim = "进攻", role = "穿透", seq = _S_PRE, target = _T_SELF,
		desc = "你这次「大波」改为穿大防一次。", params = {},
		script = preload("res://src/battle/items/t3_jianyi.gd")},
	"t3_shengming": {
		tier = 3, ev = 4, name = "上等生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "己方出战回 2.0 HP。", params = {heal = 4},
		script = preload("res://src/battle/items/t3_shengming.gd")},
	"t3_fali": {
		tier = 3, ev = 4, name = "上等法力药水", dim = "能量", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "立即 +2.0 能。", params = {energy = 4},
		script = preload("res://src/battle/items/t3_fali.gd")},
	"t3_tinglong": {
		tier = 3, ev = 4, name = "停龙剑", dim = "能量", role = "能→攻", seq = _S_PRE, target = _T_ENEMY,
		desc = "弃光全部能量，每 1.0 能对敌造 0.5 伤穿大防。", params = {},
		script = preload("res://src/battle/items/t3_tinglong.gd")},

	# ========== Tier-3 遗物（持久·每回合 tick·Phase 2）==========
	"t3_judingsanhua": {
		tier = 3, ev = 6, name = "聚鼎三花", dim = "进攻", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "你每次攻击额外多 1 次命中（伤害不变），3 次后散。", params = {relic = true, hits = 1, charges = 3},
		script = preload("res://src/battle/items/t3_judingsanhua.gd")},
	"t3_shixinding": {
		tier = 3, ev = 6, name = "噬心钉", dim = "进攻", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "攻击 +1.0 伤，但你无法防御。", params = {relic = true, bonus = 2},
		script = preload("res://src/battle/items/t3_shixinding.gd")},
	"t3_budongmingwang": {
		tier = 3, ev = 6, name = "不动明王甲", dim = "防御", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "防御成功回 0.5 HP 且 +0.5 能，但攻击 −0.5。", params = {relic = true},
		script = preload("res://src/battle/items/t3_budongmingwang.gd")},
	"t3_xumingxiang": {
		tier = 3, ev = 6, name = "续命香", dim = "防御", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "持有期间每回合 +0.5 HP，持续 3 回合。", params = {relic = true, heal = 1, turns = 3},
		script = preload("res://src/battle/items/t3_xumingxiang.gd")},
	"t3_qingyuanbaolian": {
		tier = 3, ev = 6, name = "青元宝莲", dim = "能量", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "持有期间每回合自动 +0.5 能，3 回合后消失。", params = {relic = true, energy = 1, turns = 3},
		script = preload("res://src/battle/items/t3_qingyuanbaolian.gd")},

	# ========== Phase 3A 纯逻辑件（切换替身 / 强制切换 / 信息博弈）==========
	"t2_caoren": {
		tier = 2, ev = 2, name = "替身草人", dim = "节奏", role = "切换", seq = _S_ANY, target = _T_SELF,
		desc = "你「切换」时留个稻草替身，对手本回合对你的攻击落空。", params = {},
		script = preload("res://src/battle/items/t2_caoren.gd")},
	"t3_yiqi": {
		tier = 3, ev = 4, name = "气", dim = "博弈", role = "信息", seq = _S_ANY, target = _T_SELF,
		desc = "立 2 个纸扎替身，对手攻击 2/3 概率落空（信息博弈）。", params = {decoys = 2},
		script = preload("res://src/battle/items/t3_yiqi.gd")},

	# ========== 首发补全：节奏/状态/干扰 capstone + 中立/趣味/meta 留种（2026-06-24·items-firstrelease）==========
	"t1_weihouzhen": {
		name = "尾后针", dim = "中立", role = "结构", seq = _S_ANY, target = _T_SELF,
		desc = "你出战阵亡时，对敌方出战造成 0.5 真伤（临死反咬）。", params = {},
		script = preload("res://src/battle/items/t1_weihouzhen.gd")},
	"t1_guike": {
		name = "占卜龟壳", dim = "中立", role = "meta", seq = _S_ANY, target = _T_SELF,
		desc = "你下次 3 选 1 不满意，可整批重抽一次。", params = {},
		script = preload("res://src/battle/items/t1_guike.gd")},
	"t1_ronglu": {
		name = "随身熔炉", dim = "中立", role = "meta", seq = _S_ANY, target = _T_SELF,
		desc = "烧掉你一件未使用道具，立即 +0.5 能。", params = {energy = 1},
		script = preload("res://src/battle/items/t1_ronglu.gd")},
	"t2_fengyin": {
		tier = 2, ev = 2, name = "封印卷轴", dim = "干扰", role = "元件层", seq = _S_ANY, target = _T_ENEMY,
		desc = "封住对手 1 个道具槽本回合（下回合自解）。", params = {},
		script = preload("res://src/battle/items/t2_fengyin.gd")},
	"t2_mojing": {
		tier = 2, ev = 2, name = "闪亮的魔晶", dim = "中立", role = "结构", seq = _S_ANY, target = _T_SELF,
		desc = "本回合立即 +1 能，下回合 −1 能（借明天的钱）。", params = {energy = 2, penalty = 2},
		script = preload("res://src/battle/items/t2_mojing.gd")},
	"t2_dianjinshi": {
		tier = 2, ev = 2, name = "点金石", dim = "中立", role = "meta", seq = _S_ANY, target = _T_SELF,
		desc = "立即把你一件 T1 道具升为 T2（免部署锁 + 定向你选）。", params = {},
		script = preload("res://src/battle/items/t2_dianjinshi.gd")},
	"t3_yemingzhu": {
		tier = 3, ev = 4, name = "夜明珠", dim = "节奏", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "你切换登场的英雄，本回合攻击 +0.5 且登场冲撞 0.5。", params = {relic = true},
		script = preload("res://src/battle/items/t3_yemingzhu.gd")},
	"t3_hedinghong": {
		tier = 3, ev = 4, name = "鹤顶红", dim = "状态", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "你引爆毒时，伤害额外 +1.0（毒爆放大器）。", params = {relic = true},
		script = preload("res://src/battle/items/t3_hedinghong.gd")},
	"t3_tianluodiwang": {
		tier = 3, ev = 4, name = "天罗地网", dim = "干扰", role = "一次性", seq = _S_ANY, target = _T_ENEMY,
		desc = "本回合封住对手全部道具槽 + 禁止切换（下回合自解）。", params = {},
		script = preload("res://src/battle/items/t3_tianluodiwang.gd")},
	"t3_mengdie": {
		tier = 3, ev = 4, name = "梦蝶", dim = "趣味", role = "一次性", seq = _S_ANY, target = _T_SELF,
		desc = "本局一次：把你与对手当前的 HP / 能量 / 道具栏整体对调。", params = {},
		script = preload("res://src/battle/items/t3_mengdie.gd")},
	"t3_morihuozhong": {
		tier = 3, ev = 4, name = "末日火种", dim = "中立", role = "结构", seq = _S_ANY, target = _T_SELF,
		desc = "你仅剩 1 名英雄存活时，其攻击与防御各 +1.0。", params = {atk = 2, armor = 2},
		script = preload("res://src/battle/items/t3_morihuozhong.gd")},
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
	item.tier = int(d.get("tier", 1))
	item.dimension = d["dim"]
	item.role = d.get("role", "")
	item.sequence_tag = d["seq"]
	item.target_mode = d["target"]
	item.description = d["desc"]
	item.ev_half = int(d.get("ev", 1))
	item.upgrade_to = d.get("upgrade", "")
	item.params = (d["params"] as Dictionary).duplicate(true)
	item.effect = d["script"].new()
	return item


## 指定 tier 的全部件（id 字典序）。
static func all_for_tier(t: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	var keys: Array = _DEF.keys()
	keys.sort()
	for id in keys:
		if int((_DEF[id] as Dictionary).get("tier", 1)) == t:
			out.append(make(id))
	return out


static func all_tier1() -> Array[ItemData]:
	return all_for_tier(1)


static func all_tier2() -> Array[ItemData]:
	return all_for_tier(2)


static func all_tier3() -> Array[ItemData]:
	return all_for_tier(3)


## 全部已实装件（id 字典序）。
static func all() -> Array[ItemData]:
	var out: Array[ItemData] = []
	var keys: Array = _DEF.keys()
	keys.sort()
	for id in keys:
		out.append(make(id))
	return out


static func ids() -> Array:
	return _DEF.keys()


# ========== 美术图标约定（B·2026-06-20）==========
## 图标按约定路径加载、无需逐件配字段：res://assets/sprites/items/<id>.png。
## 暂存区 newAssets/ 由 tools/import_item_art.gd 按「中文名→id」分配进来；UI 缺图回退占位文字。
const ICON_DIR := "res://assets/sprites/items/"


## 某 id 的图标约定路径（文件不一定存在）。
static func icon_path(id: String) -> String:
	return ICON_DIR + id + ".png"


## 加载某 id 的图标；未导入 / 不存在则返回 null（调用方据此回退占位文字）。
static func load_icon(id: String) -> Texture2D:
	if id == "":
		return null
	var p := icon_path(id)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D


## 稀有度底色（按 tier·2026-06-26 Eddy：道具框背景改按稀有度而非维度划分）。
## 通用约定色：普通=暖灰 / 稀有=蓝 / 传说=金。图鉴卡 / 战斗道具栏芯片 / 抽卡卡 统一引用。
static func rarity_color(tier: int) -> Color:
	match tier:
		2: return Color("8a4fc4")   # 稀有 = 紫（避开蓝波背景撞色·高稀有度惯例色）
		3: return Color("dca12e")   # 传说 = 金
		_: return Color("8c887e")   # 普通 = 暖灰


## 显示名 → id 映射（从 _DEF 实时构建，永不过时）。重名会 push_error（当前全唯一）。
## 供 tools/import_item_art.gd 把「臭鸡蛋.png」分配为「t1_xiangjiaopi.png」。
static func name_to_id() -> Dictionary:
	var m := {}
	for id in _DEF:
		var nm: String = (_DEF[id] as Dictionary)["name"]
		if m.has(nm):
			push_error("ItemCatalog: 显示名重复『%s』(id %s / %s)，名→id 映射有歧义" % [nm, m[nm], id])
		m[nm] = id
	return m
