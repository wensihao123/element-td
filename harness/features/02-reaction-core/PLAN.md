---
artifact: PLAN
feature: 02-reaction-core
role: Planner
status: accepted
updated: 2026-07-04
inputs: [harness/project-context.md, harness/BACKLOG.md, 元素反应塔防-项目说明.md §2/§4, harness/archive/01-data-layer/HANDOFF.md, harness/archive/01-data-layer/CHANGES.md, harness/archive/01-data-layer/REVIEW.md, 现有全量代码(scripts/ test/ data/)]
next: Implementer
---

# PLAN — 02-reaction-core

## 1. Goal

落地反应核心运行时:EventBus + ReactionSystem + StatusComponent(以及承载运行时状态的 ModifierStack / ActiveEffects 两个组件)与 6 个效果积木的 apply() 逻辑,headless 测试先行,覆盖 gauge 规则、反应表、ICD、补偿效果执行,全程不依赖画面。

## 2. Approach & key decisions

> 01 归档的 4 条遗留 flags 全部织入本计划:② 断言计数防线、③ autoload 探针 → Phase 1;
> ① 效果无状态 → D3;④ base_status 持续型语义 → D3/D5(只动类接口,不动数据布局)。

- **D1:系统脚本可注入,autoload 仅作游戏态接线**
  - 决定:`event_bus.gd` / `reaction_system.gd` 均 `extends Node` **不带 class_name**(避免与 autoload 名冲突,沿 balance.gd 先例),注册为 autoload `EventBus` / `ReactionSystem`;但 ReactionSystem 的依赖(GaugeConfig、反应表、bus)全部经 `setup()` 注入,StatusComponent 的 `reaction_system` / `cfg` 也是注入字段。headless 测试显式 `load().new()` 构造整套对象,不依赖 autoload 是否在 `-s` 模式加载。
  - 为什么:沿 01-D2 精神(零单例耦合、可测);flag ③ 未验证前,任何测试都不许赌 autoload 行为。
  - 弃选:测试直接引用 autoload 单例——`-s` 行为未证,且把系统焊死在全局状态上。
  - 附带说明:StatusComponent 直接调 `ReactionSystem.try_react()` 是《项目说明》§4.3 明定的管线,不违反「跨系统走 EventBus」铁律——该铁律针对订阅型跨系统(UI/结算/成就),本计划不改。

- **D2:反应表运行时从目录扫描构建**
  - 决定:autoload 态 `_ready()` 用 DirAccess 扫 `res://data/reactions/*.tres` 建表;表 key = 两元素 id 排序后 `"a+b"` 拼接(与 test_data_integrity 同式)。测试态经 `setup()` 注入显式 `Array[ReactionDef]`。
  - 为什么:加反应 = 加 `.tres`,零代码改动(硬 NO:新反应禁止改核心代码)。
  - 弃选:硬编码 preload 列表——每加反应都要动 ReactionSystem。

- **D3:效果运行时 = 享元模式,一切可变状态住 ActiveEffects 组件**
  - 决定:效果 Resource 只当「参数 + 逻辑」(共享实例,flag ①,自身零字段写入)。新增组件 `ActiveEffects`(`scripts/components/active_effects.gd`):`register(fx: ReactionEffect, ctx: Dictionary, duration: float) -> int`(句柄)/ `cancel(id)`(幂等)/ `tick(delta)`;每条目持有 `{fx, state: Dictionary, remaining}`,到期回调 `fx.on_end()` 后移除;`duration = -1.0` 永续直至 cancel。ReactionEffect 基类新增默认空实现 `on_start(target, ctx) -> Dictionary`(返回该次施加的私有 state)/ `on_tick(target, state, delta)` / `on_end(target, state)`;`apply(target, ctx)` 仍是唯一分发入口——瞬发效果在 apply() 内执行完毕,持续型效果在 apply() 内把自己注册进目标的 ActiveEffects。`@export` 数据布局零改动(flag ④ 授权范围内)。
  - 为什么:同一个 fire.tres 的 DotEffect 同时挂 10 个敌人,状态必须逐宿主隔离;state 字典归 ActiveEffects 所有,效果类天然无状态。
  - 弃选:效果 `duplicate()` 后自持状态——与「运行时不改 .tres」同源风险、内存翻倍、且 duplicate 对共享 SubResource 的深浅拷贝语义易踩坑。

- **D4:持续型数值效果一律走 ModifierStack;眩晕 = 保留键 `&"stunned"` 计数**
  - 决定:新增组件 `ModifierStack`(`scripts/components/modifier_stack.gd`):`add(stat: StringName, flat: float, pct: float) -> int` / `remove(handle)` / `resolve(stat: StringName, base: float) -> float = (base + Σflat) * (1 + Σpct)`;不管时限(计时统一归 ActiveEffects,单一计时权威)。StunEffect = 在 `&"stunned"` 上 `add(+1 flat)`,`resolve(&"stunned", 0.0) > 0.0` 即眩晕——重叠眩晕天然计数正确(冻结 1.5s + 电解 1s 互不误清)。已占用 stat 键:`speed` / `armor` / `damage_taken` / `stunned`。
  - 为什么:slow/armor/damage_taken/stunned 全走一套挂载-回滚机制;硬 NO「运行时增益走 ModifierStack」。`+1` 是布尔计数编码,不是平衡数值,不违反数值入 `.tres` 铁律。
  - 弃选:每种控制各开布尔字段——重叠即错乱,正是散 bool 反模式。

- **D5:base_status 生命周期由 StatusComponent 驱动(flag ④ 语义落点)**
  - 决定:获得状态时(无状态 → 附着)对 `element.base_status` 逐个 `fx.apply(owner, ctx)`,ctx 带 `handle_sink: Array[int]` 收集 ActiveEffects 句柄(base_status 的 DotEffect / StatModifierEffect duration 均为 -1.0 = 随状态存续);gauge 归零过期时逐句柄 `cancel()` 回滚,发 `status_expired`。反应消耗后只要 gauge > 0,base status 原封不动(反协同铁律:反应不吃减速)。
  - 为什么:「gauge > 0 期间持续生效 + 归零回滚」正是 flag ④ 要确认的语义;句柄收集让回滚不依赖效果自省。
  - 弃选:base_status 施加/回滚推给 03 的敌人场景——flag ④ 属 02 责任,且 gauge 测试没有它就测不到「状态过期 → 减速复原」。

- **D6:空间查询 = SceneTree 组 `&"enemies"` 扫描 + 距离过滤**
  - 决定:AoE / 传播的「半径内敌人」= `get_nodes_in_group(&"enemies")` 过滤 `global_position` 距离;组名为代码常量(标识符,非数值)。
  - 为什么:headless 可测(Node2D 位置无需物理世界)、无碰撞体依赖(那是 03/04 的资产);MVP 数十敌规模线性扫描无虞。
  - 弃选:Area2D / 物理空间查询——要物理体与碰撞形状,02 没有,headless 测试也重。

- **D7:组件发现约定 = 实体根节点的具名直接子节点**
  - 决定:约定敌人实体根(Node2D)下挂具名子节点 `StatusComponent` / `ModifierStack` / `ActiveEffects`;ReactionEffect 基类提供受保护 helper(`_stack(target)` / `_active(target)` 之类)按名查找,查无返回 null 并 push_warning(fail-soft)。03 的敌人场景遵此约定。
  - 为什么:传播效果要在**邻居**身上解析组件,ctx 传引用无从覆盖邻居;具名子节点最简单、场景与测试同构。
  - 弃选:`@export` 接线(传播场景仍需查找)/ ctx 传引用(只覆盖主目标)。

- **D8:ICD 期间异元素命中 = 不反应、不附着、不动 gauge**
  - 决定:冷却中第二元素命中只造成武器本体伤害,元素量丢弃;原状态原量保留。
  - 为什么:《项目说明》只说「冷却期内不触发反应」,未定附着归属;此裁定最简且严守「每敌最多 1 种元素」。已记 flag 待 05/06 手感复核;改动面隔离在 StatusComponent 单分支。
  - 弃选:ICD 期间覆盖/替换附着——引入第二套状态切换规则,MVP 无证据需要。

- **D9:try_react 流程定序**
  - 决定:`try_react(status, incoming, source, hit_direction := Vector2.ZERO) -> bool`:ICD 拦截 → 查表(4 元素 6 对全存在,查无即返 false)→ 设 ICD → `status.consume(get_cost(cfg))`(可能触发归零过期回滚)→ 逐个 `fx.apply(target, ctx)` → `bus.reaction_triggered.emit(def, target, source)`(bus 空安全)→ 返 true。incoming 元素被反应消耗,**不附着**。
  - 为什么:效果执行时 gauge 已是终值、信号发出时一切定格,下游订阅者(05 飘字)看到一致状态。
  - 弃选:先效果后扣量——效果执行期观察到旧 gauge,状态不一致。

- **D10:伤害/击退投递 = 鸭子契约,HealthComponent 归 03**
  - 决定:效果通过 `target.take_damage(amount: float, source: Node)` / `target.apply_knockback(distance: float, direction: Vector2)` 鸭子方法投递(`has_method` 检查,查无 push_warning 不崩);02 测试用 `StubEnemy`(`test/support/stub_enemy.gd`,Node2D + 具名子组件 + 调用记录)。反应伤害的 source 一路透传 = 触发方塔(归属铁律)。
  - 为什么:HealthComponent / 护甲公式 / 击杀金币是 03 的授权范围,02 不越界;契约点名记入 CHANGES Wiring Contract 防漂移。
  - 弃选:02 顺手实现 HealthComponent——侵占 03 范围,护甲量表未定。

- **ctx 标准键(契约,随 D3 一并写进基类注释)**:`source: Node`(归属塔)、`reaction: ReactionDef` 或 `element: ElementDef`(base status 路径)、`hit_direction: Vector2`(默认 ZERO;PropagateEffect 对每个邻居浅拷贝 ctx 并把方向覆写为「主目标 → 邻居」)、`handle_sink: Array[int]`(可选,仅 base status 路径)。
- **测试数值约定**:期望值一律从资源推导(`cfg.default_attach`、`def.get_cost(cfg)`、效果字段),不在测试里再抄一份字面量;需要非零衰减等特殊值时测试内构造合成 GaugeConfig(测试脚手架,不算游戏数值,01 已有先例)。

## 3. Phased steps

### Phase 1: 测试跑道防线 + autoload 探针(清 flag ②③)

- [x] Step: 断言计数防线——`TestCase` 加 `assert_count: int`(两个 assert_* 各自 +1);`run_tests.gd` 对每个 `test_` 方法取调用前后计数差,差为 0 → 该用例记 FAILED(注明「零断言,疑似方法内运行时崩溃」)。
  - Files: `test/test_case.gd`、`test/run_tests.gd`
  - Verify: 现有 3 用例仍全绿(exit 0);临时插入一个零断言用例确认整体 exit 1 且指名该方法,确认后删除(过程记入 CHANGES §3)。
- [x] Step: autoload 探针 `test/probe_autoload.gd`(`extends SceneTree`,打印 `-s` 模式下 `root.get_node_or_null("Balance")` 是否非空,显式 quit(0));跑一次,把实测结论回填 `project-context.md` §6(替换「未验证」条目);探针保留供引擎升级复测。
  - Files: `test/probe_autoload.gd`、`harness/project-context.md`
  - Verify: 探针命令 exit 0、输出含明确「存在/不存在」;§6 不再含「未验证」字样。
- Playtest gate (Phase 1): 纯管道,无可玩点;确认项 = 上述两条 Verify 均过。

### Phase 2: 运行时状态载体 + 6 个效果 apply()(清 flag ①,铺垫 flag ④)

- [x] Step: `ModifierStack` 组件(D4):`add` / `remove` / `resolve`,句柄自增 int,未知 stat 返回 base。
  - Files: `scripts/components/modifier_stack.gd`、`test/cases/test_modifier_stack.gd`
  - Verify: 先 `--import` 再 check-only 通过;用例覆盖叠加算式、按句柄移除、未知 stat、`&"stunned"` 计数场景,全绿。
- [x] Step: `ActiveEffects` 组件 + ReactionEffect 基类接口扩展(D3/D6/D7):register/cancel/tick,`duration -1` 永续;基类加 on_start/on_tick/on_end 默认空实现与组件/组扫描 helper;`_physics_process` 调 `tick`(headless 测试手动 tick,确定性)。
  - Files: `scripts/components/active_effects.gd`、`scripts/effects/reaction_effect.gd`、`test/cases/test_active_effects.gd`
  - Verify: 定时到期触发 on_end 并移除;-1 永续直至 cancel;cancel 幂等;**同一 fx 资源注册到两个宿主,state 互不串(flag ① 回归测试)**。
- [x] Step: 三个持续型效果实装(全经 ActiveEffects 注册,自身零字段写入):`DotEffect`(state 存累加器,每满 tick_interval 调 `take_damage(dps * tick_interval, source)`,首跳在满一个间隔后)、`StatModifierEffect`(on_start 挂栈存句柄入 state,on_end 摘除)、`StunEffect`(`&"stunned"` +1 / 摘除)。
  - Files: `scripts/effects/dot_effect.gd`、`scripts/effects/stat_modifier_effect.gd`、`scripts/effects/stun_effect.gd`、`test/cases/test_durational_effects.gd`
  - Verify: dot 按 tick 精确出伤(期望从字段推导);modifier 到期回滚复原;双眩晕重叠期间 resolve > 0,先到期的不误清后者。
- [x] Step: `StubEnemy` 测试支撑类(`extends Node2D`,入 `&"enemies"` 组,具名子组件 ModifierStack/ActiveEffects,记录 take_damage/apply_knockback 调用)+ 三个瞬发效果实装:`AoeDamageEffect`(以 target.global_position 为圆心,半径内组员**含主目标**逐个投伤)、`KnockbackEffect`(鸭子 apply_knockback)、`PropagateEffect`(邻居 = 半径内组员**去除主目标**,per-邻居浅拷贝 ctx 覆写方向,`inner.apply(邻居, ctx)`)。
  - Files: `test/support/stub_enemy.gd`、`scripts/effects/aoe_damage_effect.gd`、`scripts/effects/knockback_effect.gd`、`scripts/effects/propagate_effect.gd`、`test/cases/test_instant_effects.gd`
  - Verify: 半径内/外命中判定;传播不含主目标;传播 inner 为持续型(StunEffect)时正确注册进**邻居**的 ActiveEffects。
- Playtest gate (Phase 2): 纯管道;确认 = headless 全部用例 0 失败。

### Phase 3: StatusComponent — gauge 规则 + base status 生命周期(flag ④ 落地)

- [x] Step: `StatusComponent`(D5/D8):字段 `element: ElementDef` / `gauge: float` / `icd_remaining: float`,注入 `cfg: GaugeConfig` 与 `reaction_system: Node`;`apply_element(incoming, amount, source, hit_direction := Vector2.ZERO)`——无状态 → 附着 clamp(0, max)、发 `status_started`、经 ActiveEffects 施加 base_status(handle_sink 收句柄);同元素 → `gauge = clamp(gauge + amount, 0, max)`;异元素 → 仅转发 `reaction_system.try_react(self, ...)`(ICD 拦截由 ReactionSystem 判,见 D9);`consume(amount)`——扣量,≤ 0 → 过期(cancel 全部句柄、element 置 null、发 `status_expired`);`tick(delta)`——icd_remaining 递减、`gauge -= cfg.decay_per_sec * delta` 与归零过期;`_physics_process` 调 tick。信号:`status_started(element)` / `status_expired(element)`。
  - Files: `scripts/components/status_component.gd`、`test/support/stub_enemy.gd`(挂上 StatusComponent)、`test/cases/test_status_component.gd`
  - Verify: 附着 clamp / 同元素叠层至 max / 合成 config(decay > 0)衰减至归零过期 / 过期回滚(冰减速 resolve 复原)/ 异元素只转发不自决(spy 假 reaction_system 收到一次调用,gauge 未动)。
- Playtest gate (Phase 3): 纯管道;确认 = 用例全绿。说明:实现行数会超《项目说明》「~20 行」指导值(多了 ICD/衰减/生命周期挂载),职责仍单一(gauge 簿记 + 状态生命周期),Reviewer 按此基准审。

### Phase 4: EventBus + ReactionSystem + 六反应端到端

- [x] Step: `EventBus`(`scripts/systems/event_bus.gd`,extends Node 无 class_name,本 feature 仅声明 `signal reaction_triggered(reaction: ReactionDef, target: Node2D, source_tower: Node)`)+ `project.godot` 注册 autoload `EventBus`(后续 feature 各自增补信号)。
  - Files: `scripts/systems/event_bus.gd`、`project.godot`
  - Verify: `--import` 0 ERROR;`ProjectSettings.has_setting("autoload/EventBus")` 断言并入 Phase 4 用例。
- [x] Step: `ReactionSystem`(`scripts/systems/reaction_system.gd`,extends Node 无 class_name):`setup(cfg: GaugeConfig, reactions: Array[ReactionDef], bus: Node)` 建 `_table`(排序拼接 key,D2);`try_react(...)` 按 D8/D9;`_ready()` 游戏态自接线(`Balance.config` + DirAccess 扫描 + `get_node_or_null` 取 EventBus,写法按 Phase 1 探针结论容错);`project.godot` 注册 autoload `ReactionSystem`。
  - Files: `scripts/systems/reaction_system.gd`、`project.godot`
  - Verify: check-only 通过;autoload 注册断言并入用例;逻辑由下两步覆盖。
- [x] Step: ReactionSystem 单测:载入真实 6 反应 `.tres` 经 setup 建表 → 12 个方向 key 全命中;ICD 拦截(冷却内第二次 try_react 返 false 且 gauge 不动)与 tick 后释放;扣量 = `get_cost(cfg)`;扣到 0 → `status_expired` 且 base 回滚;反应后 incoming 元素未附着;**gauge > 0 时 base status(冰减速)原封不动(反协同铁律断言)**;bus 为 null 时不崩。
  - Files: `test/cases/test_reaction_system.gd`
  - Verify: 用例全绿;期望值全部由 cfg / def 推导。
- [x] Step: 六反应端到端矩阵:对每个反应 `.tres`——新建 StubEnemy 主目标(附 element_a 默认附着量)+ 半径内邻居 + 半径外哨兵,element_b 命中 → 统一断言 EventBus 信号(def.id / target / source)与 gauge 余量;逐反应断言:steam_burst 主目标 + 圈内受伤、圈外无;overload 伤害 + 击退记录;combustion 主目标与邻居按 tick 出 dot 伤;superconduct 主目标 + 邻居 stunned > 0、时限后释放;brittle `damage_taken` 修饰在场、到期回滚;electrolysis stunned 恰一个 duration 后释放。
  - Files: `test/cases/test_reactions_e2e.gd`
  - Verify: headless 全绿,汇总 0 失败;e2e 用例逐反应打印 PASSED 行。
- [x] Step: 收尾回填与交接:`project-context.md` §3 补录新约定(组件具名子节点、`&"enemies"` 组、take_damage/apply_knockback/`&"stunned"` 契约)、§6 增删实测坑;更新本 feature `HANDOFF.md`(实现 `[x]`、下一步 Reviewer)并写 `CHANGES.md`(Wiring Contract 必须点名 03/04 要消费的全部契约)。
  - Files: `harness/project-context.md`、`harness/features/02-reaction-core/HANDOFF.md`、`harness/features/02-reaction-core/CHANGES.md`
  - Verify: §5 三连命令(--import / check-only / run_tests)全绿收官;文档与实际一致。
- Playtest gate (Phase 4): 纯管道——反应「爽不爽、看不看得懂」的体验验证明确延后到 05(飘字/特效)与 06(整局);本阶段替代确认 = e2e 日志六反应逐条 PASSED + 汇总 0 失败。可选人工:编辑器开项目无报错,项目设置 autoload 面板见 Balance / EventBus / ReactionSystem 三条。

## 4. Out of scope

本 feature 不做(对应 HANDOFF 中标 `[x]` 不需要的可选阶段):
- **勘探(Explorer)**:代码面仅 01 产物,本计划制订时已全量通读(defs / effects / test / 11 个 .tres)→ 不需要。
- **美术(Art Spec)**:纯逻辑,零资产需求;可视化整体归 05-status-ui → 不需要。
- **接线(Engine Integrator)**:autoload 注册即 project.godot 文本改动,headless 可验,无编辑器手工步骤 → 不需要。
- (设计阶段沿 01 先例由《元素反应塔防-项目说明.md》承担,BACKLOG 2026-07-04 决策。)

功能边界之外:
- HealthComponent / 护甲结算公式 / 击杀金币 → 03(02 只投递 take_damage 调用,数值不过护甲)。
- 击退在 Path 寻路上的真实语义(路径进度回退)→ 03/04(02 只记录鸭子调用)。
- 弹丸命中管线(谁调 apply_element、attach 量由 TowerDef.get_attach 解析)→ 04。
- 任何 UI / 特效 / 飘字 / 状态图标 → 05;EventBus 只留 reaction_triggered 一个信号,死亡/金币/波次信号归各自 feature。
- 补偿铁律的**平衡性**验证(收益 ≥ 消耗价值的数值论证)→ 07-balance-sim;02 只保证补偿效果确实执行。
- 不新增、不修改任何 `.tres`;不做 ModifierStack 之上的 buff 系统泛化(科技树等 v2)。

## 5. Risks & Flags / Open questions

- **ICD 期间异元素命中「不反应不附着」是本计划裁定**(D8,设计文档未明说)——待 05/06 手感复核;若要改为覆盖附着,改动面隔离在 StatusComponent 单分支。
- **三条鸭子/键位契约必须被 03/04 消费**:`take_damage(amount, source)`、`apply_knockback(distance, direction)`、`resolve(&"stunned", 0.0) > 0.0`(移动/攻击都要查)——Implementer 务必写进 CHANGES Wiring Contract,防止 03 规划时漂移。
- **02 的伤害断言在「调用面」**:未过护甲公式,e2e 断的是 StubEnemy 收到的调用参数,不是最终血量;03 落地后应有一条端到端复核。
- **组扫描为线性复杂度**:每次 AoE/传播 O(敌人数);MVP 数十敌无虞,过百敌 + 高频反应再优化(07 仿真可量化)。
- **断言计数防线只兜「断言前崩溃」**:断言后崩溃仍可能假绿(概率低);02 实测若出现,再升级为跑道子进程隔离,不在本计划。
- **StatusComponent 会超「~20 行」指导值**:多出 ICD / 衰减 / base status 生命周期;职责仍单一,已在 Phase 3 gate 声明,Reviewer 按此审。
- **autoload 探针结论未知**:存在与否两种结果都不阻塞(设计不依赖,D1);结论回填 §6 即完成 flag ③。
- (承 01,不新增)毒 armor -2.0 待 03 护甲量表复核;radius/distance 等 px 数值待 06 地图尺度复核。
