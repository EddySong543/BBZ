# 远征模式原型（prototypes 隔离区·可丢弃代码）

> 设计真相源：`design/gdd/expedition-mode.md` + 子文档 A `design/expedition-monsters.md`。
> 本目录代码**不进 src/**，验证通过后按项目标准重写正式实装。

## 文件

| 文件 | 作用 |
|------|------|
| `expedition_monsters.json` | 首发 10 只怪定义（数据驱动·schema 见下） |
| `monster_policy.gd` | 怪物驾驶员：odds/cycle/turtleRule/multiTable/phased 五种策略·含可支付归一化（§5.1） |
| `run_expedition_sim.gd` | headless 校准：明牌真实性 ≤2pp / 遭遇拍数带 / 玩家胜率 / fallback 计数 |
| `out_calibration.md` | 校准报告（跑一次刷新一次） |
| `loot_gen.gd` | 共享掉落生成器（形状库+掉落表·子文档 C §7 草稿） |
| `map_proto/` | **任务 A：地图探索原型**（12×12 搜打撤·F6 `MapProto.tscn`·详见其 README） |
| `backpack_proto/` | **任务 B：背包拼图原型**（形状拼放+双结算·F6 `BackpackProto.tscn`·详见其 README） |
| `proto_shot.gd` | 原型截图跑器（带窗口·可选 walk 自动走动） |

## 跑校准

```bash
godot --headless --path <项目根> --script res://prototypes/expedition/run_expedition_sim.gd
```

## JSON schema（camelCase）

- 公共：`name`（中文名·占位可换）`series`（gamble/exam）`tier`（1/2/3）`hp`（点数）`kind`
- `kind: "odds"`：`tables[]` = `{id, trigger:{type: base|energyGe|hpLe, value}, odds:{attack|defend|charge|bigAttack|bigDefend: 权重}}`——触发器从上到下首命中生效，base 放末位
- `kind: "cycle"`：`cycle[]` = 动作名固定循环；付不起 → 改攒并计 fallback
- `kind: "turtleRule"`：能量 ≥2 能必大防、否则防（铁壳龟专用）
- `kind: "multiTable"`：`tables[]`/`enragedTables[]`（无 trigger）+ `enrageHpLe`——每拍明牌抽 1 张
- `kind: "phased"`：`phases[]` = 各带可选 `hpLe` 的子定义（取最后一个满足项·首项默认）
- `deferred`：该怪暂不完整实现的说明（如 k5 被动需引擎 hook）

## 已知边界（本轮校准的口径）

- 双档玩家：**先知**（读循环/读明牌分布做规则式回应+编织节奏）=会解题玩家的上界；**搜索 AI**（BattleAI v1·不读牌）=下界；真人居中
- 玩家 = 白板 HP5 单英雄，**无道具无技能**——玩家最弱态。**T1 胜率必须 >50%（教学关卡）；T2/T3 胜率仅参考**：正式口径要"多英雄+道具"的中后期玩家模型，本原型不建模
- k5 缠杀藤只跑本体（被动"同目标连击 +1 伤"需引擎 hook + 多英雄队伍，标 deferred）
- 怪物走与玩家完全相同的动作合法性（can_afford）与能量经济（GDD §3.1 规则层锁死）

## 研究发现（原型假设验证·随校准更新）

- ✅ **最终判定（v6·2026-07-05）：10/10 全过**——拍数带全落、T1 先知胜率全 >50%、明牌管线冒烟过。校准值已回写 `design/expedition-monsters.md` §4。
- ✅ **可支付归一化成立**：引擎从显示表直接采样=诚实性是结构保证；大样本偏差 0.2-1.5pp（500-1000 拍采样方差本身 ~2pp·设计验收口径已改 ≥2000 拍）
- ✅ **循环/规则/多表/分阶段五种策略引擎全部工作**，fallback 0（循环从未付不起）
- 🔑 **校准必须用"会读牌的玩家"**：搜索 AI 是猜拳 AI（蓄力雕先知 100% vs 搜索 1%）——读懂=碾压、读不懂=被碾压，正是 PvE"解题"设计成立性的直接证据，技能表达空间巨大
- 🔑 **动作层无防御回血**（治疗只在道具层·核查 battle_core）：对纯攻怪的人类赢法=防-防-大波经济循环（防挡白攒被动能→大波兑现）；先知的竞速判定必须"严格更快才对拼"（平手对拼=同拍双死=平）
- 🔑 **会解题玩家的拆解效率 ≈0.7-0.9 伤/拍**（远高于草稿估算 0.4-0.6）→ 怪物 HP 全线上调：K1/K2 3→5、B3 6→10、K4 6→8、K5 6→8、B4 10→18、K6 12→20
- ⚠ T2/T3 先知胜率=参考口径（玩家=单白板 HP5 最弱态；正式胜率校准需多英雄+道具模型——留给地图原型阶段）
