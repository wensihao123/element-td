---
artifact: REVIEW
feature: 05-status-ui
role: Reviewer
status: accepted
updated: 2026-07-05
inputs: [project-context.md, PLAN.md, CHANGES.md, 真实代码 diff(status_display/floating_text/reaction_vfx_layer .gd+.tscn、enemy.tscn、dev_playground.tscn、6 反应 .tres、两个新测试), 依赖侧交叉核对(status_component/event_bus/reaction_def/element_def/recording_bus/stub_enemy)]
next: Producer
---

# REVIEW — 05-status-ui(状态可视化:头顶图标 + gauge 环 + 反应飘字/占位特效)

## 1. Verdict

**APPROVE WITH NITS**

纯增量表现层落地干净:头顶状态走"实体自身视图轮询"、反应飘字走"地图级层订阅 EventBus"两条互不依赖的路线,均忠实 PLAN。逻辑代码零改动经 diff 佐证(D7 铁则守住)。测试实跑复核 **22 用例 0 失败**、`--import` exit 0,CHANGES 的验证声明属实。两个 playtest gate 是**人工 F6 目验 PASS**(非 Auto 未验残留)。无 must-fix。

## 2. Must-fix(blocking)

无。

## 3. Should-fix(non-blocking)

- `scenes/ui/reaction_vfx_layer.gd:84` / `scenes/ui/floating_text.gd:32` — 飘字与扩散环的表现依赖「层保持默认变换(原点、无缩放)」这一隐式契约:`_spawn_burst` 用 `global_position = anchor` 锚定(对缩放/偏移健壮),但 `FloatingText.tick` 直接改 **local** `position.y` 上浮——若 06 正式地图把 `ReactionVfxLayer` 挂在带缩放/非原点的父节点下,上浮量会随父缩放走样、且飘字锚点会偏。CHANGES §5 wiring contract 已写「保持默认变换」,故本 feature 内无害;**建议 06 接线时把该约束显式带进 INTEGRATION-STEPS**,别让它只活在 05 的 CHANGES 里。方向:06 挂载时校验层 transform,或把上浮也改为不吃父变换的方式。

## 4. Nits(可选)

- `scenes/ui/status_display.gd:27-31` — 隐藏分支只清了 `ring_ratio` 与 `visible`,`ring_color` / `showing_icon` 保留上次值。因整节点隐藏、下次显示 `tick` 会重算,**功能无害**;若日后有人在隐藏态读这两个字段做断言/判定,会拿到陈旧值。留档即可,不必改。
- `scenes/ui/status_display.gd:20` 等 — `_process` 每帧无条件 `_find_status()` 轮询(即便敌人长期无状态)。PLAN §5 已把性能顾虑记档(MVP 敌人量无虞、07 headless 无渲染路径),这里只作覆盖记录,非改动要求。

## 5. What I checked but found fine(覆盖面)

- **正确性核对**:
  - `StatusDisplay.tick` 的显示/隐藏切换、`ring_ratio = clampf(gauge/max_gauge)`、`max_gauge <= 0` 的除零保护、`element.color` 取色、首字/贴图双分支切换 —— 均正确;`_find_status` 对 `get_parent()==null`(孤儿节点)有空守卫,测试 `test_hidden_without_status_sibling` 实证不崩。
  - `ReactionVfxLayer._on_reaction_triggered` 的 `reaction==null / target==null` 双守卫、**位置快照 `anchor = target.global_position`**(先取值再生成,不持 target 引用)—— 正是防「反应与击杀同帧、目标随即 `queue_free`」的关键设计;`test_target_freed_same_frame_does_not_crash` 实证 `target.free()` 后 tick 不崩、飘字仍锚定快照。
  - `setup(new_bus)` 换绑先 `is_connected` 判断再 `disconnect`/`connect`,无重复连接风险;`_ready` 仅在 `bus==null` 时自接 `/root/EventBus`,测试注入路径(setup 先于入树)不触发自接线分支 —— 与 02-D1 先例一致。
  - `FloatingText.tick` / `Burst.tick` 的 `lifetime<=0` 短路 + `age>=lifetime` 自毁边界正确;`_draw` 的 `progress` 同样有除零保护。
- **忠实度 / 计划漂移**:PLAN §3 全部步骤 `[x]`,与 diff 一一对应(CHANGES §2 映射表核对无误);三处偏差(头顶偏移用实例 `position` 存 enemy.tscn、Burst 内嵌类由层 `@export` 代持参数、测试复用 `RecordingBus` 不新增 support 文件)均记 CHANGES §4,符合 D5 精神且经 HANDOFF 决策记录人已认可 —— **无隐蔽扩项**。两个 phase 的 playtest gate 均人工 F6 目验 PASS(HANDOFF + CHANGES §3),非「Auto 需在编辑器确认」的未决项。
- **铁则 / 硬 NO**:
  - EventBus **未新增信号**(`event_bus.gd` 无 diff,D7 守住);`status_component.gd` / `reaction_system.gd` / `enemy.gd` / 各 effect **逻辑零改动**(diff 仅 `enemy.tscn` 加子场景实例、`dev_playground.tscn` 加层实例、6 反应 `.tres` 加 `color` 行)。
  - 反应色写进**既有** `ReactionDef.color` 字段(销 `reaction_def.gd:8` 注释「05-status-ui 再定」),未新造伪装成平衡数据的 `.tres`;6 个色值即 PLAN D6 建议表原值(`overload`/`steam_burst` diff 核对一致)。
  - 表现常量走场景 `@export`(D5,人已认可 05-D5),`.gd` 里的默认值均为**可被 .tscn 覆盖的表现默认**、非游戏/平衡数值 —— 不触硬 NO「数值字面量住 .tres」。
- **约定**:全静态类型标注(`: float` / `-> void`);三个场景根脚本 `class_name`(StatusDisplay / FloatingText / ReactionVfxLayer);`enemy.tscn` 加挂节点为子场景实例(未踩 Node 型 `@export` 的 `node_paths` 坑,因走 `get_node_or_null` 兄弟发现而非 NodePath 导出);跨系统通信只订阅 EventBus 信号,无系统间直接引用。
- **安全**:纯 UI 展示,无输入处理/鉴权/密钥/注入面 —— 不适用。
- **过度设计**:Burst 内嵌类精简、无冗余抽象/配置/依赖;`draw_arc` 自绘符合占位阶段"零资产"取向。
- **测试真实性**:亲自 `--import`(exit 0)+ 全量 `run_tests.gd`(exit 0,输出「22 个用例,0 失败」),新增 10 个测试方法全 PASSED;唯一 WARNING 来自 `test_wave_spawner` 既有的 `push_warning` 断言用例,非本 feature 引入、非失败。
