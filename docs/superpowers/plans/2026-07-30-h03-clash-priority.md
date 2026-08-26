# h03「白额雷音」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 h03 重做为 5 HP 的对攻先制英雄：双方均使用「波」或「大波」时，尾火的基础攻击优先结算；若该攻击实际击杀敌方攻击英雄，则取消敌方此次基础攻击。

**Architecture:** 在 `HeroSkill` 增加无状态的基础攻击对攻优先级 hook，h03 返回更高优先级；`BattleCore` 仅在双方原选招都是基础攻击且优先级不相等时重排双方基础动作 hit。斩杀判断锁定敌方出招槽位并检查其 HP 是否从存活变为死亡；只跳过敌方基础动作 hit，道具 hit、费用、动作历史及已消费的团队强化均保持原语义。

**Tech Stack:** Godot 4、GDScript、GUT、Resource `.tres`、CSV i18n。

## Global Constraints

- 技能名固定为 `白额雷音`，h03 最大生命固定为 `5`。
- 玩家可见说明固定为：`双方均使用「波」或「大波」时，尾火【虎】优先攻击；若击杀敌方出战英雄，取消其此次攻击。`
- 仅双方原选招均为 `ActionDef.ATTACK_ACTIONS` 时触发；攻击型主动技和道具攻击不触发。
- 非致死时保持双方基础攻击均结算；双 h03 同优先级时保持原同步独立结算，不产生 P0 座位优势。
- 护甲、替身、无敌、还魂、天狗护主使敌方攻击英雄未实际阵亡时，不取消其攻击。
- 被取消方的全部基础动作 hit 均跳过；其道具 hit、能量费用、疾风次数、山河借骨升级、焚天火兆等已发生的消费不返还。
- 不新增持久状态，不修改 clone/snapshot schema，不提升 `SNAPSHOT_VERSION`。
- 保留工作区内 h01、h02、Scene/UI 及其他任务改动；只做精确小块补丁。
- 未经用户明确要求，不 commit、不 push。

---

### Task 1: 先用失败测试锁定发布数据与结算边界

**Files:**
- Modify: `tests/unit/battle/v4/test_hero_team_role.gd`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/v4/test_heroes_dark_v4.gd`

**Interfaces:**
- Consumes: `BattleCore.setup()`、`select_action()`、`resolve()`、`HeroData` 资源。
- Produces: h03 发布数据、四种基础攻击组合、P0/P1 对称、致死/非致死、镜像、保命、道具 hit 与旧双命中退役的行为合同。

- [ ] **Step 1: 写发布数据失败测试**

```gdscript
func test_h03_published_data_matches_approved_redesign() -> void:
	var h := load("res://assets/data/heroes/h03.tres") as HeroData
	assert_not_null(h, "h03 数据资源必须可加载")
	assert_eq(h.max_hp, 5, "尾火生命应为 5")
	assert_eq(h.skill_description, "白额雷音", "尾火应使用已定稿技能名")
	assert_eq(h.skill_detail,
		"双方均使用「波」或「大波」时，尾火【虎】优先攻击；若击杀敌方出战英雄，取消其此次攻击。",
		"尾火描述应准确表达基础攻击对攻先制与致死断招")
```

- [ ] **Step 2: 用表驱动测试锁定四种波/大波组合**

```gdscript
func test_h03_nonlethal_base_attack_clash_keeps_both_attacks() -> void:
	for pair in [
		[ActionDef.Action.ATTACK, ActionDef.Action.ATTACK, 2, 2],
		[ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK, 4, 2],
		[ActionDef.Action.BIG_ATTACK, ActionDef.Action.ATTACK, 2, 4],
		[ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_ATTACK, 4, 4],
	]:
		var b := _battle("h03", 5, 20)
		var hp0: int = b.hp[0][0]
		var hp1: int = b.hp[1][0]
		_resolve(b, int(pair[0]), int(pair[1]))
		assert_eq(b.hp[0][0], hp0 - int(pair[2]), "非致死时敌方攻击照常结算")
		assert_eq(b.hp[1][0], hp1 - int(pair[3]), "尾火攻击照常结算")
```

为 P1 h03 建立双边队伍 helper，再以敌方 1 半点 HP 重跑四种组合，断言 h03 不受敌方基础攻击伤害，并出现 `base_attack_cancelled` 事件。

- [ ] **Step 3: 锁定不触发与保命边界**

新增独立测试：

- h03 在替补席时不提供团队优先级。
- h03 对攻击型主动技时不触发断招。
- h03 镜像且双方均在致死线时仍同时结算。
- 敌方有护甲、还魂或天狗护主而攻击英雄存活时，其攻击继续结算。
- 敌方同拍道具伤害在基础攻击被取消后仍结算。
- 敌方 h16 双发基础攻击被断招时两条 action hit 都跳过。
- h03 单次命中只给 h10 一层剑气，旧 `hit_count=2` 完全退役。

- [ ] **Step 4: 修正 h13 无封顶测试的夹具，不再依赖旧 h03**

将 `["h03", "h13", "h10"]` 改为 `["h05", "h13", "h10"]`；预置毒与印记后，单次命中产生毒爆、印记消费、破甲附着、剑意四个 proc，继续断言无封顶行为。

- [ ] **Step 5: 运行完整 GUT，确认新测试在旧实现上失败**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240
```

Expected: h03 新发布数据、对攻先制、旧双命中退役相关测试失败；既有无关失败单独记录。

---

### Task 2: 实现无状态对攻优先级与精确断招

**Files:**
- Modify: `src/battle/hero_skill.gd`
- Move: `src/battle/skills/h03_lianpu.gd` → `src/battle/skills/h03_leiyin.gd`
- Move: `src/battle/skills/h03_lianpu.gd.uid` → `src/battle/skills/h03_leiyin.gd.uid`
- Modify: `src/battle/battle_core.gd`

**Interfaces:**
- Produces: `HeroSkill.base_attack_clash_priority() -> int`，默认 `0`；h03 返回 `1`。
- Consumes: hit 字典的 `action`、`active`、`src_slot` 字段及 `_apply_damage()` 的现有即时保命管线。

- [ ] **Step 1: 增加通用无状态 hook**

```gdscript
## 双方均使用基础攻击时的对攻优先级。仅唯一较高值先结算；同值保持同步独立结算。
func base_attack_clash_priority() -> int:
	return 0
```

同时删除 `HeroSkill.hit_count()` 注释中对“尾火连扑”的现行引用，保留通用多命中 hook。

- [ ] **Step 2: 退役旧双命中组件并保留 UID**

```gdscript
extends HeroSkill

## h03 尾火【白额雷音】被动 · 进攻 · HP5
## 双方均使用「波」或「大波」时，尾火的基础攻击优先结算；
## 若该攻击实际击杀敌方攻击英雄，敌方本次基础攻击取消。

func base_attack_clash_priority() -> int:
	return 1
```

将注册表 preload 更新为 `res://src/battle/skills/h03_leiyin.gd`。

- [ ] **Step 3: 抽取单条 hit 的既有施加逻辑**

把当前 `resolve()` 中 `_apply_damage()`、攻击型主动技回调封装成 `_apply_resolve_hit(attacker_player, hit, actions, events) -> int`，保持事件、`src_slot` 归因和主动技回调完全不变。

- [ ] **Step 4: 仅为基础攻击对攻构建特殊顺序**

当双方原选招均为基础攻击、双方 hitlist 都有基础 action hit，且唯一一方 hook 值更高时：

1. 施加双方动作前道具 hit。
2. 施加高优先级方的全部基础 action hit。
3. 以敌方 action hit 的 `src_slot` 为攻击英雄槽；若该槽在步骤 2 前 `hp > 0`、步骤 2 后 `hp <= 0`，追加 `{id = "base_attack_cancelled", player = enemy}` 并跳过敌方全部基础 action hit。
4. 若未死亡，施加敌方全部基础 action hit。
5. 施加双方动作后道具 hit。

优先级相同、任一方动作 hit 落空或不满足基础攻击对攻时，走原同步独立结算循环。

- [ ] **Step 5: 运行完整 GUT，确认结算测试转绿**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240
```

Expected: h03 行为测试全部通过；普通攻击互换伤害、h02/h22/h16、clone/snapshot 既有测试无回归。

---

### Task 3: 同步资源、演出提示、i18n 与现行设计真相源

**Files:**
- Modify: `assets/data/heroes/h03.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `src/ui/battle_screen.gd`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/heroes-schools.md`
- Modify: `design/build-design-framework.md`
- Modify: `design/items.md`
- Modify: `design/items-list.md`
- Modify: `design/items-firstrelease.md`
- Modify comments only: `src/battle/skills/h10_taichuwanfa.gd`
- Modify comments only: `src/battle/skills/h13_shuchao.gd`
- Modify comments only: `src/battle/skills/h15_xueyong.gd`
- Modify comments only: `src/battle/skills/h16_baihong.gd`
- Modify comments only: `src/battle/skills/h20_duanzui.gd`
- Modify comments only: `src/battle/items/t2_duyao.gd`
- Modify: `src/battle/ai/README.md`

**Interfaces:**
- Consumes: `base_attack_cancelled` 事件的 `player` 字段。
- Produces: 发布数据、中文词条、战斗内“断招”提示及一致的设计文档。

- [ ] **Step 1: 更新 h03 资源**

```text
max_hp = 5
skill_description = "白额雷音"
skill_detail = "双方均使用「波」或「大波」时，尾火【虎】优先攻击；若击杀敌方出战英雄，取消其此次攻击。"
```

- [ ] **Step 2: 让取消事件驱动演出**

在 `_animate_resolution()` 从事件流构建 `cancelled_attacks: Array[bool]`；收到 `base_attack_cancelled` 时给该方添加“断招”标签，并只在 `_play_battle_anims()` 的动画动作参数中把该方动作置为 `-1`。头顶动作圆圈仍显示原盲选动作，费用与历史不变。

- [ ] **Step 3: 精确更新 i18n**

替换 h03 旧名称与旧描述条目，并加入战斗 UI 的 `断招` 翻译源；不重生成或覆盖工作区内其他翻译改动。

- [ ] **Step 4: 更新当前设计文档与联动注释**

将现行 h03 定义统一为：

- HP5、技能名“白额雷音”、进攻维。
- 双方基础攻击对攻时先结算；斩杀敌方攻击英雄则断招。
- 组合价值来自压低血线、攻击增伤/穿透授权、强制拉出软目标，再以对攻斩杀剥夺还手。
- 非致死不减伤，防/大防与道具规则不变，镜像同速。

旧“双段/连扑”只在明确标注的历史决策段落保留，并改成“旧版/当时”措辞；现行技能、道具和 AI 文档不得继续宣称 h03 提供双命中。

- [ ] **Step 5: 扫描旧现行引用**

Run:

```powershell
rg -n "银虎掠影|连扑|虎双段|尾火.*两段|h03.*hit_count|h03.*双命中" src tests design assets/data assets/i18n
```

Expected: 仅明确标注为历史废案的记录允许命中；发布数据、源码现行注释、测试与现行设计章节零旧语义。

---

### Task 4: 导入、完整验证与差异审计

**Files:**
- Verify only: all task files above

- [ ] **Step 1: 检查 GDScript 与资源导入**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180
```

Expected: exit code 0；重命名脚本 UID 正常导入；无 parse/resource error。

- [ ] **Step 2: 运行完整 GUT**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

Expected: h03、普通同步攻击、道具、h13、h15/h16、clone/snapshot 测试全部通过；若工作区既有 Scene3 视觉测试仍失败，记录精确名称且确认与本任务差异无关。

- [ ] **Step 3: 自查本任务差异**

Run:

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo diff --check
git -c safe.directory=$Repo -C $Repo status --short
```

逐文件确认没有覆盖 h01/h02/Scene/UI 既有改动，不提交、不推送。
