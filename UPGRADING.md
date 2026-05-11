# 升级 Claude Code Game Studios

本指南涵盖将你现有的游戏项目仓库从模板的一个版本升级到下一个版本。

**查找你的当前版本**，在 git log 中：
```bash
git log --oneline | grep -i "release\|setup"
```
或者查看 `README.md` 中的版本徽章。

---

## 目录

- [升级策略](#升级策略)
- [v0.2.0 → v0.3.0](#v020--v030)
- [v0.1.0 → v0.2.0](#v010--v020)

---

## 升级策略

有三种方式获取模板更新。根据你的仓库设置方式选择。

### 策略 A —— Git 远程合并（推荐）

适用场景：你克隆了模板并在其上添加了自己的提交。

```bash
# 将模板添加为远程仓库（一次性设置）
git remote add template https://github.com/Donchitos/Claude-Code-Game-Studios.git

# 获取新版本
git fetch template main

# 合并到你的分支
git merge template/main --allow-unrelated-histories
```

Git 只会在模板和你都修改过的文件中标记冲突。逐一解决——你的游戏内容保留，结构性改进也一并带入。然后提交合并。

**提示：** 最容易产生冲突的文件是 `CLAUDE.md` 和 `.claude/docs/technical-preferences.md`，因为你已经在其中填写了引擎和项目设置。保留你的内容，接受结构性变更。

---

### 策略 B —— 挑选特定提交

适用场景：你只需要某个特定功能（例如只想要新技能，不需要完整更新）。

```bash
git remote add template https://github.com/Donchitos/Claude-Code-Game-Studios.git
git fetch template main

# 挑选你需要的特定提交
git cherry-pick <commit-sha>
```

每个版本的提交 SHA 列在下方的版本章节中。

---

### 策略 C —— 手动复制文件

适用场景：你没有使用 git 来设置模板（只是下载了 zip 包）。

1. 在你的仓库旁边下载或克隆新版本。
2. 直接复制**"可安全覆盖"**下列出的文件。
3. 对于**"需要小心合并"**下的文件，并排打开两个版本，在保留你内容的同时手动合并结构性变更。

---

## v0.2.0 → v0.3.0

**发布日期：** 2026-03-09
**提交范围：** `e289ce9..HEAD`
**主要主题：** `/design-system` GDD 编写、`/map-systems` 重命名、自定义状态栏

### 破坏性变更

#### `/design-systems` 重命名为 `/map-systems`

`/design-systems` 技能被重命名为 `/map-systems`，因为分解 = *映射*，而不是 *设计*。

**需要执行：** 更新所有调用 `/design-systems` 的文档、笔记或脚本。新的调用方式为 `/map-systems`。

### 变更内容

| 类别 | 变更 |
|------|------|
| **新技能** | `/design-system`（引导式 GDD 编写，逐章节） |
| **重命名的技能** | `/design-systems` → `/map-systems`（破坏性重命名） |
| **新文件** | `.claude/statusline.sh`、`.claude/settings.json` 状态栏配置 |
| **技能更新** | `/gate-check` ——通过时写入 `production/stage.txt`，新的阶段定义 |
| **技能更新** | `brainstorm`、`start`、`design-review`、`project-stage-detect`、`setup-engine` ——交叉引用修复 |
| **Bug 修复** | `log-agent.sh`、`validate-commit.sh` ——钩子执行修复 |
| **文档** | 新增 `UPGRADING.md`、更新 `README.md`、更新 `WORKFLOW-GUIDE.md` |

---

### 文件：可安全覆盖

**需要添加的新文件：**
```
.claude/skills/design-system/SKILL.md
.claude/statusline.sh
```

**可以覆盖的已有文件（无用户内容）：**
```
.claude/skills/map-systems/SKILL.md      ← 原为 design-systems/SKILL.md
.claude/skills/gate-check/SKILL.md
.claude/skills/brainstorm/SKILL.md
.claude/skills/start/SKILL.md
.claude/skills/design-review/SKILL.md
.claude/skills/project-stage-detect/SKILL.md
.claude/skills/setup-engine/SKILL.md
.claude/hooks/log-agent.sh
.claude/hooks/validate-commit.sh
README.md
docs/WORKFLOW-GUIDE.md
UPGRADING.md
```

**需要删除（已被重命名替代）：**
```
.claude/skills/design-systems/   ← 整个目录；已被 map-systems/ 替代
```

---

### 文件：需要小心合并

#### `.claude/settings.json`

新版本添加了指向 `.claude/statusline.sh` 的 `statusLine` 配置块。如果你没有自定义过 `settings.json`，直接覆盖是安全的。否则，手动添加此配置块：

```json
"statusLine": {
  "script": ".claude/statusline.sh"
}
```

---

### 新功能

#### 自定义状态栏

`.claude/statusline.sh` 在终端状态栏中显示 7 阶段制作流水线面包屑：

```
ctx: 42% | claude-sonnet-4-6 | Systems Design
```

在制作/打磨/发布阶段，如果 `production/session-state/active.md` 中存在 `<!-- STATUS -->` 块，还会显示当前活动的 Epic/Feature/Task：

```
ctx: 42% | claude-sonnet-4-6 | Production | Combat System > Melee Combat > Hitboxes
```

当前阶段从项目产物中自动检测，也可以通过将阶段名称写入 `production/stage.txt` 来固定。

#### `/gate-check` 阶段推进

当关卡通过（PASS）结论确认后，`/gate-check` 现在会将新阶段名称写入 `production/stage.txt`。这会立即更新所有未来会话的状态栏，无需手动编辑文件。

---

### 升级后

1. **删除旧的技能目录：**
   ```bash
   rm -rf .claude/skills/design-systems/
   ```

2. **测试状态栏** ——启动 Claude Code 会话，你应该在终端底部看到阶段面包屑。

3. **验证钩子执行**是否仍然正常工作：
   ```bash
   bash .claude/hooks/log-agent.sh '{}' '{}'
   bash .claude/hooks/validate-commit.sh '{}' '{}'
   ```

---

## v0.1.0 → v0.2.0

**发布日期：** 2026-02-21
**提交范围：** `ad540fe..e289ce9`
**主要主题：** 上下文韧性、AskUserQuestion 集成、`/map-systems` 技能

### 变更内容

| 类别 | 变更 |
|------|------|
| **新技能** | `/start`（引导入门）、`/map-systems`（系统分解）、`/design-system`（引导式 GDD 编写） |
| **新钩子** | `session-start.sh`（恢复）、`detect-gaps.sh`（缺口检测） |
| **新模板** | `systems-index.md`、3 个协作协议模板 |
| **上下文管理** | 重大重写——添加了文件支持的状态策略 |
| **代理更新** | 14 个设计/创意代理——AskUserQuestion 集成 |
| **技能更新** | 全部 7 个 `team-*` 技能 + `brainstorm` ——在阶段转换时使用 AskUserQuestion |
| **CLAUDE.md** | 从约 159 行精简到约 60 行；5 个文档导入替代 10 个 |
| **钩子更新** | 全部 8 个钩子——Windows 兼容性修复、新功能 |
| **文档删除** | `docs/IMPROVEMENTS-PROPOSAL.md`、`docs/MULTI-STAGE-DOCUMENT-WORKFLOW.md` |

---

### 文件：可安全覆盖

这些是纯基础设施文件——你没有自定义过它们。直接复制新版本，对项目内容无风险。

**需要添加的新文件：**
```
.claude/skills/start/SKILL.md
.claude/skills/map-systems/SKILL.md
.claude/skills/design-system/SKILL.md
.claude/docs/templates/systems-index.md
.claude/docs/templates/collaborative-protocols/design-agent-protocol.md
.claude/docs/templates/collaborative-protocols/implementation-agent-protocol.md
.claude/docs/templates/collaborative-protocols/leadership-agent-protocol.md
.claude/hooks/detect-gaps.sh
.claude/hooks/session-start.sh
production/session-state/.gitkeep
docs/examples/README.md
.github/ISSUE_TEMPLATE/bug_report.md
.github/ISSUE_TEMPLATE/feature_request.md
.github/PULL_REQUEST_TEMPLATE.md
```

**可以覆盖的已有文件（无用户内容）：**
```
.claude/skills/brainstorm/SKILL.md
.claude/skills/design-review/SKILL.md
.claude/skills/gate-check/SKILL.md
.claude/skills/project-stage-detect/SKILL.md
.claude/skills/setup-engine/SKILL.md
.claude/skills/team-audio/SKILL.md
.claude/skills/team-combat/SKILL.md
.claude/skills/team-level/SKILL.md
.claude/skills/team-narrative/SKILL.md
.claude/skills/team-polish/SKILL.md
.claude/skills/team-release/SKILL.md
.claude/skills/team-ui/SKILL.md
.claude/hooks/log-agent.sh
.claude/hooks/pre-compact.sh
.claude/hooks/session-stop.sh
.claude/hooks/validate-assets.sh
.claude/hooks/validate-commit.sh
.claude/hooks/validate-push.sh
.claude/rules/design-docs.md
.claude/docs/hooks-reference.md
.claude/docs/skills-reference.md
.claude/docs/quick-start.md
.claude/docs/directory-structure.md
.claude/docs/context-management.md
docs/COLLABORATIVE-DESIGN-PRINCIPLE.md
docs/WORKFLOW-GUIDE.md
README.md
```

**可以覆盖的代理文件**（如果你没有在其中写入自定义提示词）：
```
.claude/agents/art-director.md
.claude/agents/audio-director.md
.claude/agents/creative-director.md
.claude/agents/economy-designer.md
.claude/agents/game-designer.md
.claude/agents/level-designer.md
.claude/agents/live-ops-designer.md
.claude/agents/narrative-director.md
.claude/agents/producer.md
.claude/agents/systems-designer.md
.claude/agents/technical-director.md
.claude/agents/ux-designer.md
.claude/agents/world-builder.md
.claude/agents/writer.md
```

如果你*确实*自定义了代理提示词，请参阅下方的"需要小心合并"。

---

### 文件：需要小心合并

这些文件同时包含模板结构和你的项目特定内容。**不要**覆盖它们——手动合并变更。

#### `CLAUDE.md`

模板版本从约 159 行精简到约 60 行。关键结构性变更：移除了 5 个文档导入，因为它们已被 Claude Code 自动加载（agent-roster、skills-reference、hooks-reference、rules-reference、review-workflow）。

**从你的版本中保留：**
- `## Technology Stack` 部分（你的引擎/语言选择）
- 你添加的任何项目特定内容

**从新版本中采纳：**
- 更精简的导入列表（如果存在 5 个冗余的 `@` 导入，请删除）
- 更新的协作协议措辞

#### `.claude/docs/technical-preferences.md`

如果你运行过 `/setup-engine`，此文件包含你的引擎配置、命名规范和性能预算。全部保留。模板版本只是空的占位符。

#### `.claude/docs/templates/game-concept.md`

轻微的结构更新——添加了指向 `/map-systems` 的 `## Next Steps` 部分。如果你想获得更新的引导，请将该部分添加到你的副本中，但这不是必需的。

#### `.claude/settings.json`

检查新版本是否添加了你想要的权限规则。变更很小（schema 更新）。如果你没有自定义过 `settings.json`，覆盖是安全的。

#### 自定义代理文件

如果你在任何代理 `.md` 文件中添加了项目特定知识或自定义行为，请做 diff 对比，手动添加新的 AskUserQuestion 集成部分，而不是覆盖。每个代理的变更是在系统提示词末尾添加的标准化协作协议块。

---

### 文件：需要删除

这些文件在 v0.2.0 中被移除。如果你的仓库中存在，可以安全删除——它们已被更好的组织方式替代。

```
docs/IMPROVEMENTS-PROPOSAL.md      → 被 WORKFLOW-GUIDE.md 替代
docs/MULTI-STAGE-DOCUMENT-WORKFLOW.md → 内容已合并到 context-management.md
```

---

### 升级后

1. **运行 `/project-stage-detect`** ——验证系统能够用新的检测逻辑正确读取你的项目。

2. **如果你还没用过 `/start`，运行一次** ——它现在能正确识别你的阶段并跳过你已完成的上手步骤。

3. **检查 `production/session-state/`** 是否存在并被 gitignore：
   ```bash
   ls production/session-state/
   cat .gitignore | grep session-state
   ```

4. **测试钩子执行** ——如果你在 Windows 上，验证新钩子在 Git Bash 中能无错误运行：
   ```bash
   bash .claude/hooks/detect-gaps.sh '{}' '{}'
   bash .claude/hooks/session-start.sh '{}' '{}'
   ```

---

*每个未来版本都会在本文件中有自己的章节。*
