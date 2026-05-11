# 目录结构 (Directory Structure)

```text
/
├── CLAUDE.md                    # 主配置文件 (Master configuration)
├── .claude/                     # 代理定义、技能、钩子、规则、文档
├── src/                         # 游戏源代码（核心、玩法、AI、网络、UI、工具）
├── assets/                      # 游戏资产（美术、音频、特效、着色器、数据）
├── design/                      # 游戏设计文档（GDD、叙事、关卡、平衡性）
├── docs/                        # 技术文档（架构、API、复盘报告）
│   └── engine-reference/        # 精选的引擎 API 快照（版本锁定）
├── tests/                       # 测试套件（单元测试、集成测试、性能测试、试玩测试）
├── tools/                       # 构建与管线工具（CI、构建、资产管线）
├── prototypes/                  # 一次性原型（与 src/ 隔离）
└── production/                  # 生产管理（冲刺、里程碑、发布）
    ├── session-state/           # 临时会话状态（active.md — 已 gitignore）
    └── session-logs/            # 会话审计日志（已 gitignore）
```
