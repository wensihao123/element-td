---
artifact: CHANGES
feature: 02-reaction-core
role: Implementer
status: draft
updated: 2026-07-04
inputs: [harness/project-context.md, harness/features/02-reaction-core/PLAN.md]
next: Reviewer
---

# CHANGES — 02-reaction-core

## 1. What changed

新增(运行时):
- `scripts/components/modifier_stack.gd` — 运行时属性修饰栈:add/remove/resolve,`(base+Σflat)*(1+Σpct)`,句柄自增,未知 stat 返 base。
- `scripts/components/active_effects.gd` — 持续型效果载体:register/cancel(幂等)/tick,`duration -1` 永续,到期回调 on_end;唯一计时权威。
- `scripts/components/status_component.gd` — gauge 簿记 + base status 生命周期:apply_element(附着/叠层/异元素转发)、consume(归零过期回滚)、tick(ICD 递减 + 衰减)、status_started/status_expired 信号。
- `scripts/systems/event_bus.gd` — autoload「EventBus」,本 feature 仅声明 `reaction_triggered`。
- `scripts/systems/reaction_system.gd` — autoload「ReactionSystem」:setup 注入建表(id 排序拼 key)、try_react(D8/D9 定序)、_ready 游戏态自接线(Balance.config + DirAccess 扫描 + get_node_or_null 取 EventBus)。

修改(运行时):
- `scripts/effects/reaction_effect.gd` — 基类扩展:on_start/on_tick/on_end 默认实现、ctx 契约注释、`ENEMY_GROUP` 常量、helpers `_stack/_active/_component`(D7 具名子节点发现)、`_enemies_in_radius`(D6 组扫描)、`_deal_damage`(D10 鸭子投递)、`_collect_handle`(handle_sink)。
- `scripts/effects/dot_effect.gd` — apply 注册进 ActiveEffects;累加器住 state,每满 tick_interval 投 `take_damage(dps*tick_interval, source)`,首跳在满一个间隔后。
- `scripts/effects/stat_modifier_effect.gd` — on_start 挂 ModifierStack 存句柄入 state,on_end 摘除。
- `scripts/effects/stun_effect.gd` — `&"stunned"` flat +1 计数(布尔编码),重叠控制互不误清。
- `scripts/effects/aoe_damage_effect.gd` — 半径内组员**含主目标**逐个投伤。
- `scripts/effects/knockback_effect.gd` — 鸭子投递 `apply_knockback(distance, ctx.hit_direction)`。
- `scripts/effects/propagate_effect.gd` — 半径内组员**剔除主目标**,逐邻居浅拷贝 ctx 并覆写 hit_direction 为「主目标→邻居」,inner.apply。
- `project.godot` — 注册 autoload `EventBus`、`ReactionSystem`(列表次序 = 初始化次序,排 Balance 之后)。

新增/修改(测试):
- `test/test_case.gd` — 断言计数防线:`assert_count` 每 assert_* +1。
- `test/run_tests.gd` — 零断言用例记 FAILED(疑似方法内运行时崩溃);测试体从 `_initialize` 挪到首个 process 帧执行(见 §4 偏差)。
- `test/probe_autoload.gd` — autoload 探针(保留,引擎升级复测)。
- `test/support/stub_enemy.gd` — 最小敌人实体:入 `&"enemies"` 组、三具名子组件、记录 take_damage/apply_knockback。
- `test/support/recording_bus.gd` — 与 EventBus 同签名的记录型总线(见 §4 偏差)。
- `test/cases/test_modifier_stack.gd`、`test_active_effects.gd`、`test_durational_effects.gd`、`test_instant_effects.gd`、`test_status_component.gd`、`test_reaction_system.gd`、`test_reactions_e2e.gd` — 共 33 个新测试方法。

回填(文档):
- `harness/project-context.md` — §3 补录组件具名子节点/enemies 组/享元/鸭子键位契约;§6 回填 autoload 已加载结论(flag ③ 完成)+ `_initialize` root 未入树新坑。

## 2. Why(对应 PLAN 步骤)

- Phase 1 Step 1(防线)→ test_case.gd / run_tests.gd(清 01 flag ②)。
- Phase 1 Step 2(探针)→ probe_autoload.gd + project-context §6(清 01 flag ③,结论:`-s` 模式 autoload **已加载**)。
- Phase 2 Step 1(D4)→ modifier_stack.gd + test_modifier_stack.gd。
- Phase 2 Step 2(D3/D6/D7)→ active_effects.gd + reaction_effect.gd + test_active_effects.gd(flag ① 回归:同一 fx 两宿主 state 互不串 ✓)。
- Phase 2 Step 3 → dot/stat_modifier/stun_effect.gd + test_durational_effects.gd。
- Phase 2 Step 4 → stub_enemy.gd + aoe/knockback/propagate_effect.gd + test_instant_effects.gd。
- Phase 3 Step 1(D5/D8)→ status_component.gd + stub_enemy.gd(挂 StatusComponent)+ test_status_component.gd(flag ④ 语义落地:gauge > 0 持续生效、归零句柄回滚)。
- Phase 4 Step 1 → event_bus.gd + project.godot。
- Phase 4 Step 2(D2/D9)→ reaction_system.gd + project.godot。
- Phase 4 Step 3 → test_reaction_system.gd。
- Phase 4 Step 4 → test_reactions_e2e.gd。
- Phase 4 Step 5 → project-context.md 回填 + 本文件 + HANDOFF。

## 3. How I verified it

标准三连(project-context §5,每步后跑,最终收官全绿):
- `--import`:exit 0,日志 0 ERROR(每次新增 class_name 脚本后均先跑)。
- `--check-only -s <script>`:全部改动脚本逐个 exit 0(含 run_tests.gd)。
- `run_tests.gd`:**10 用例 40 方法,0 失败,exit 0**;e2e 日志六反应逐条 `PASSED e2e 反应 <id>`。

过程性验证:
- 防线自证:临时插入零断言用例 → 整体 exit 1 且指名 `test_zero_assert_should_be_flagged`;删除后回绿(Phase 1 Step 1 Verify 要求的过程,已执行)。
- 探针实测:`-s` 模式 `root.get_node_or_null("Balance")` 非空 → autoload 已加载。
- 树时机探针(临时,已删):`_initialize` 阶段 root.is_inside_tree() = false、组查询空;首帧后正常 → 支撑 §4 偏差 1。
- 测试日志中仅存的 WARNING 是 test_instant_effects 故意走 fail-soft 路径(缺 apply_knockback 方法)的预期输出。

Auto 模式 Playtest gate 记录:四个 gate 均为「纯管道 = headless 全绿」型,已全部自证。**遗留人工确认项(限制)**:编辑器打开项目无报错、项目设置 autoload 面板可见 Balance / EventBus / ReactionSystem 三条——headless 无法替代,建议 Reviewer/人工顺手一看。

## 4. Deviations from the plan

1. **run_tests.gd 测试体挪到首个 process 帧**(Phase 2 Step 4 文件清单未列 run_tests.gd)。原因:实测 `_initialize` 阶段 root 未入树,组查询/is_inside_tree 全部失效,组扫描类测试无法运行;属跑道必要适配,不改任何用例语义,已回填 project-context §6。
2. **新增 `test/support/recording_bus.gd`**(计划文件清单未列)。test_reaction_system 与 test_reactions_e2e 共用的记录型总线,避免两处重复内嵌类;纯测试支撑,不进运行时。
3. **ReactionEffect 基类落点略多于计划字面**:`_deal_damage` / `_collect_handle` / `_component` helpers 与 `ENEMY_GROUP` 常量——均为 D6/D7/D10 明确授权的机制,只是收拢在基类而非散在子类。

无其他偏差:效果零字段写入、数值零字面量(`+1.0` stunned 计数与测试脚手架合成值除外,均为计划明示)、无计划外功能。

## 5. Wiring Contract(03/04/05 与 Integrator 消费)

**Autoload(project.godot 已注册,无需编辑器手工步骤)**
- `Balance` → `res://scripts/systems/balance.gd`(01 已有)
- `EventBus` → `res://scripts/systems/event_bus.gd`
- `ReactionSystem` → `res://scripts/systems/reaction_system.gd`
  - `_ready()` 自接线:读 `Balance.config`、DirAccess 扫 `res://data/reactions/*.tres` 建表、`get_node_or_null("/root/EventBus")`。**加新反应 = 加 .tres 文件,零代码改动。**
  - 测试/自定义装配:`setup(cfg: GaugeConfig, reactions: Array[ReactionDef], bus: Node)`。

**敌人实体节点约定(03 敌人场景必须遵守,StubEnemy 是样板)**
- 根节点 `Node2D`,入组 `&"enemies"`(常量 `ReactionEffect.ENEMY_GROUP`)。
- 具名**直接子节点**(缺失时效果 fail-soft 丢弃并 push_warning):
  - `StatusComponent`(`scripts/components/status_component.gd`)— 注入字段:`cfg: GaugeConfig`(游戏态给 `Balance.config`)、`reaction_system: Node`(游戏态给 autoload `ReactionSystem`)。
  - `ModifierStack`(`scripts/components/modifier_stack.gd`)— 无注入。
  - `ActiveEffects`(`scripts/components/active_effects.gd`)— 无注入。
- 三组件均 `_physics_process` 自 tick;headless 测试不入树手动 `tick(delta)`。

**调用方接口(04 弹丸命中管线)**
- 命中附着入口:`StatusComponent.apply_element(incoming: ElementDef, amount: float, source: Node, hit_direction := Vector2.ZERO)`;`amount` 由 `TowerDef.get_attach(cfg)` 解析(04 责任);`source` 传塔节点(归属铁律);`hit_direction` 传弹丸飞行方向(击退/传播用)。

**鸭子方法契约(03 必须落地,02 只投递调用)**
- `take_damage(amount: float, source: Node)` — HealthComponent;`amount` 未过护甲,护甲结算在 03 内做。
- `apply_knockback(distance: float, direction: Vector2)` — 路径进度回退语义归 03/04。

**ModifierStack 保留键(03 移动/攻击/结算必须消费)**
- `&"speed"`:敌人移速 = `stack.resolve(&"speed", base_speed)`。
- `&"armor"`:护甲 = `stack.resolve(&"armor", base_armor)`(毒腐蚀走这里)。
- `&"damage_taken"`:受伤倍率 = `stack.resolve(&"damage_taken", 1.0)`(脆化走这里)。
- `&"stunned"`:**移动与攻击逻辑每帧须查** `stack.resolve(&"stunned", 0.0) > 0.0` 即眩晕/冻结。

**信号(05 可视化订阅)**
- `EventBus.reaction_triggered(reaction: ReactionDef, target: Node2D, source_tower: Node)` — 飘字用 `reaction.display_name`;发出时 gauge/效果均已定格。
- `StatusComponent.status_started(element: ElementDef)` / `status_expired(element: ElementDef)` — 状态图标 + gauge 环的挂/摘时机。

**其他**:无 inspector `@export` 接线、无 input actions、无 collision layers 需求。

## 6. Flags / Open questions

- (承 PLAN D8)ICD 期间异元素命中「不反应、不附着、不动 gauge」已按裁定实现,待 05/06 手感复核;改动面隔离在 ReactionSystem.try_react 前段 + StatusComponent 转发。
- (承 PLAN)02 伤害断言在「调用面」(StubEnemy 记录),未过护甲;03 落地 HealthComponent 后应补一条真伤害端到端。
- (承 PLAN)断言计数防线只兜「断言前崩溃」;断言后崩溃仍可能假绿,02 实测未遇到。
- (新,实现注记)PropagateEffect 浅拷贝 ctx ⇒ `handle_sink` 数组被邻居共享:当前 base_status 无传播效果、反应路径不带 sink,无实害;**若未来给 base_status 配传播效果,句柄归属需重审**(邻居句柄会混进主目标的回滚列表)。
- (新)Playtest 人工确认项:编辑器开项目无报错 + autoload 面板三条(headless 已验 ProjectSettings 层,编辑器 UI 层未验)。
- (承 01,原样传递)毒 armor -2.0 待 03 护甲量表复核;radius/distance 等 px 数值待 06 地图尺度复核。
