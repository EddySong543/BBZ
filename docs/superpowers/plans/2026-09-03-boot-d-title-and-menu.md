# Boot D 版标题与单机入口实施计划

## 目标

- 保留现有 Boot 背景、角色、标题入场与退出转场。
- 将五字标题落实为 D「右轴副题」：`波波攒`为主行，`传说`在下方右对齐。
- 用可聚焦按钮替换“点击任意位置进入”：四个主按钮与五个小按钮。

## 文件与契约

- `src/ui/boot_screen.tscn`：只调整`传/说`位置，添加可编辑的 BootMenu 节点。
- `src/ui/components/boot_menu_controller.gd`：统一按钮样式、焦点、入场显隐和占位链接。
- `src/ui/boot_screen.gd`：开始游戏、设置、退出等顶层行为。
- `src/ui/components/boot_intro_controller.gd`：沿用原 prompt 时间曲线驱动新菜单，不改变主动画参数。
- `tests/unit/ui/test_boot_intro.gd`、`test_boot_pressure_backdrop.gd`：锁定新交互、D 版几何与旧动画契约。

## 行为

- 开始游戏：沿用现有 Boot 退出能量与转场，进入 Main Menu。
- 读取存档：当前无完整进度存档接口，按钮保留并显示待接入提示。
- 加入愿望单、Steam、Discord、QQ、问题反馈：使用空 URL 占位；配置前显示“链接待配置”，配置后调用系统浏览器。
- 设置：复用`SettingsPanel`。
- 退出游戏：调用 Godot 退出。
- Intro 完成前按钮不可操作；完成后默认聚焦“开始游戏”。

## 验证

- Godot Import / GUT 定向测试无解析错误。
- 几何断言确认标题右对齐、菜单在 1920x1080 安全区且不重叠。
- 输入断言确认背景点击不再开始游戏、按钮焦点与占位反馈有效。
