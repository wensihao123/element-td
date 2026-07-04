---
artifact: PLAN
feature: 03-enemies-waves
role: Planner
status: draft
updated: 2026-07-04
inputs: [harness/project-context.md, harness/BACKLOG.md, 元素反应塔防-项目说明.md §3.2/§4/§5, harness/archive/02-reaction-core/HANDOFF.md, harness/archive/02-reaction-core/CHANGES.md §5 Wiring Contract]
next: Implementer
---

# PLAN — 03-enemies-waves(敌人实体 + 波次生成器)

## 1. Goal

落地敌人实体(Path2D 寻路 + HealthComponent + 消费 02 三条契约)与数据驱动的波次生成器(含 1 种自带火附着怪),全程 headless 可测,并销掉 02 归档遗留的 4 条开工必读 flags。

## 2. Approach & key decisions

架构总线:敌人 = 通用场景 `enemy.tscn`(数据由 `EnemyDef` 注入)+ 02 既定的三具名子组件 + 新增第四具名子组件 `HealthComponent`;波次生成器 = 非 autoload 场景节点,吃 `WaveDef` 资源按时间表吐怪;跨系统只经 EventBus 新信号。所有决策基于 02 落地代码实测接口(`StubEnemy` 是敌人节点约定样板,`CHANGES 02 §5` 是契约文本)。

- **D1 移动实现:敌人根自持 `Path2D` 引用 + `progress` 浮点,每帧 `curve.sample_baked()` 采样设位置。**
  Why:knockback 的「路径进度回退」语义直接落在 progress 上;headless 测试可构造 `Curve2D` + 手动 `tick(delta)` 确定性驱动;敌人根保持是 `&"enemies"` 组里的 `Node2D`(02-D6 空间查询依赖 `global_position`,采样后经 `path.to_global()` 换算)。
  Rejected:`PathFollow2D` 父子挂载(敌人必须成为 Path2D 子节点,场景组织被路径绑架;headless 测试要搭完整父子树;knockback 还是得操作 progress,没省任何事)。
- **D2 击退语义:`progress = maxf(progress - distance, 0.0)`,忽略 `direction` 参数。**
  Why:固定路径 TD 里横向位移会脱轨,「沿路退」是唯一自洽语义;`apply_knockback(distance, direction)` 签名保持 02 契约原样,direction 留给未来自由移动敌人。
  Rejected:按 direction 与路径切线点积决定退/进——过度设计,MVP 无任何效果需要「击进」。
- **D3 护甲公式:`final = maxf(amount - armor, 0.0) * stack.resolve(&"damage_taken", 1.0)`,其中 `armor = stack.resolve(&"armor", base_armor)`;允许负护甲增伤。**
  Why:减法公式零新增调参常量(0.0/1.0 是中性边界,01/02 先例允许);毒腐蚀 `armor -2.0` 天然落成增伤,正是毒的战术价值;脆化倍率乘在护甲减免之后,对高甲怪也有效(打 Boss 定位)。
  Rejected:`amount * (1 - armor/(armor+K))` 乘法公式——引入新调参常量 K,而 BALANCE.md 未建(Producer 已裁定数值框架缓到 07),不给 PLAN 里埋没人背书的数字。
- **D4 `HealthComponent` = 第四个具名直接子节点;鸭子方法 `take_damage`/`apply_knockback` 住敌人根脚本、转发组件;死亡 = `died` 信号恰一次 + `queue_free()`,死后再伤直接 return。**
  Why:02 的 `_deal_damage` 投递目标是**组里的敌人根**,方法必须在根上;组件化保持 02-D7 发现约定一致(effects/05 可按名寻址);「hp ≤ 0 后免疫」guard 防 AoE 同帧鞭尸重复计死;`queue_free` 是 02 REVIEW 明令(迭代中同步 `free()` = use-after-free)。
  Rejected:把 `take_damage` 直接放 HealthComponent 上、根不转发——鸭子调用打不到(02 投递只查根);根脚本直接管血不设组件——armor/damage_taken 结算逻辑失去独立可测性。
- **D5 自带元素附着(innate):`StatusComponent` 新增 `apply_innate(element, amount)` —— 只设 element/gauge 并发 `status_started`,**不挂 base_status**;敌人 `_ready` 时以 `cfg.default_attach` 调用。**
  Why:走现有 `apply_element` 路径,火的 base_status(灼烧 DoT)会让熔岩犬**出生即自燃**,且 MVP 衰减为 0 → 永续烧到死,设计上荒谬;innate 语义 = 「元素在身、可供反应」,异元素命中照常走 `try_react`(触发方塔归属不受影响),后续同元素命中走既有「仅充能」分支,语义自洽。专用方法 4 行,02 已测主路径零改动。
  Rejected:让它自烧(出生自杀,不可用);元素抗性/免疫系统(v1 明确不做,BACKLOG Later 已留位);给 `apply_element` 加 `with_base_status` 参数(污染 02 已测签名)。注意 edge case:innate 火耗尽后再被火塔附着会正常挂灼烧——接受,火打火本就是低效路线,flag 待手感复核(§5)。
- **D6 波次数据结构:新增 `SpawnEntry`(enemy: EnemyDef / count: int / spawn_interval: float / start_delay: float)与 `WaveDef`(entries: Array[SpawnEntry]),数据住新目录 `data/waves/`;spawner 只负责**播放单个 WaveDef**,10 波序列/波间经济归 06。**
  Why:波次内容是数值,铁律要求住 `.tres`;单波播放是 06 关卡流程的最小可组合单元。
  Rejected:波次表写在代码或场景里(违反硬 NO);03 直接做 10 波序列播放器(侵占 06 范围,且胜负/经济未到位无从验收)。
- **D7 `WaveSpawner` = 非 autoload 场景节点,顺序推进生成队列,不建状态机。**
  Why:MVP 语义只有「按时间表逐条目吐怪」,一个游标 + 计时器即可,手动 `tick(delta)` 可测;波进行中重复 `start_wave` 忽略并 push_warning。
  Rejected:autoload 化(spawner 属于地图局部,不是全局系统);为 idle/spawning/done 建 FSM——当前无任何跨状态交互,若 06 关卡流程需要暂停/加速/跳波,届时先过 /state-machine-master(§5 flag)。
- **D8 EventBus 新信号 5 条(过去式命名):`enemy_spawned(enemy)`、`enemy_died(enemy, def)`、`enemy_reached_exit(enemy, def)`、`wave_started(wave)`、`wave_spawn_finished(wave)`。**
  Why:06 经济订阅 `enemy_died`(读 `def.gold_reward`)、胜负订阅 `enemy_reached_exit`;`wave_spawn_finished` 明确语义 = **生成完毕**而非「波被消灭」——清波判定归 06(组计数),命名上防误读。
  Rejected:`wave_finished`(歧义);敌人死亡只发组件局部信号不上总线(06 就得直接引用敌人实例,违反 EventBus 铁律)。
- **D9 通用 `enemy.tscn` 单场景,`setup(def: EnemyDef, path: Path2D)` 注入数据;占位视觉 = 16px 单色多边形,innate 怪以 `innate_element.color` 染色。**
  Why:数据驱动(加敌人 = 加 .tres,零场景复制);占位染色让 Phase 3 人工 gate 一眼认出熔岩犬,用的是 ElementDef 已有 color 字段,零新增数值;正式可视化归 05。
  Rejected:每种敌人一个场景(内容膨胀路线,违背 01 以来的数据驱动基线)。
- **D10 脚本落位:`enemy.gd` 随场景放 `scenes/enemies/`(实体 = 场景 + 脚本一体);`wave_spawner.gd` 放 `scripts/systems/`(系统逻辑,非 autoload)。**
  Why:`scripts/` 四子目录是横切层(defs/effects/components/systems),实体根脚本不属于其中任何一类,Godot 惯例脚本贴场景;spawner 是可复用系统逻辑非实体。
  Rejected:新开 `scripts/entities/`(为一个文件开目录,等 04 塔实体落地若同样纠结再统一)。落地后回填 project-context §2 目录注记(收官步)。

注入约定(沿 02-D1 可测性模式):`enemy.gd` 的 `_ready` 仅在字段为空时自接线(`StatusComponent.cfg = Balance.config`、`reaction_system = ReactionSystem`,`get_node_or_null` 容错);headless 测试先显式注入再入树,不依赖单例。

## 3. Phased steps

### Phase 1: 02 遗留加固 + 敌人实体

- [x] Step: PropagateEffect handle_sink 一行加固(02 flag ②)。
  - Files: `scripts/effects/propagate_effect.gd`(浅拷贝后 `neighbor_ctx.erase("handle_sink")`)、`test/cases/test_instant_effects.gd`(新增回归:主目标 ctx 带 handle_sink 时,传播给邻居后 sink 不混入邻居句柄)、`harness/archive/02-reaction-core/HANDOFF.md`(未决 flags 该条加删除线销案,注日期)。
  - Verify: 标准三连(project-context §5)全绿;新增回归方法 PASSED。
- [x] Step: HealthComponent——血量 + 护甲结算(D3/D4)。
  - Files: `scripts/components/health_component.gd`(新;字段 `max_hp`/`base_armor` 由外部注入,`hp` 运行时;`take_damage(amount, source)` 内经兄弟 `ModifierStack` resolve armor/damage_taken,`died` 信号;hp ≤ 0 后再伤直接 return;**本组件不调 free/queue_free**,自毁归根脚本)、`test/cases/test_health_component.gd`(新)。
  - Verify: 测试覆盖:①减法护甲(armor 2、amount 5 → 扣 3)②负护甲增伤(armor resolve 为 -2、amount 5 → 扣 7)③脆化倍率先减后乘(armor 2、amount 5、damage_taken 1.4 → 扣 4.2)④扣到 0 时 `died` 恰发一次 ⑤死后再 `take_damage` 血量不变、`died` 不重发 ⑥无 ModifierStack 兄弟时 fail-soft 用 base 值。三连全绿。
- [x] Step: 敌人根脚本 + 场景组装 + EventBus 信号扩充(D4/D5/D8/D9)。
  - Files: `scenes/enemies/enemy.gd`(新;入 `ReactionEffect.ENEMY_GROUP` 组;`setup(def, path)`;鸭子方法 `take_damage`/`apply_knockback` 转发组件;收 `HealthComponent.died` → `EventBus.enemy_died.emit(self, def)` → `queue_free()`;`_ready` 空字段自接线 + innate 非空时 `status.apply_innate(def.innate_element, cfg.default_attach)` + 占位视觉按 innate 染色)、`scenes/enemies/enemy.tscn`(新;根 Node2D + 四具名子组件 + Polygon2D 占位)、`scripts/components/status_component.gd`(新增 `apply_innate`,主路径零改动)、`scripts/systems/event_bus.gd`(新增 D8 五信号)、`test/cases/test_enemy.gd`(新)。
  - Verify: 测试覆盖:①实例化后四具名子组件在位、已入组 ②`take_damage` 走通护甲公式扣真血 ③致死伤害 → `enemy_died` 总线信号(注入 RecordingBus 断言)+ `is_queued_for_deletion()` 为真、**无同步 free**(调用返回后节点引用仍有效)④innate 怪 `_ready` 后 `status.element.id == &"fire"`、`gauge == cfg.default_attach`,且 ActiveEffects **无灼烧条目**(D5:不挂 base_status)⑤无 innate 的 def 不附着。三连全绿。
- [x] Step: 路径移动 + 契约消费 + 终点(D1/D2)。
  - Files: `scenes/enemies/enemy.gd`(`tick(delta)`:`stack.resolve(&"stunned", 0.0) > 0.0` 则停;否则 `progress += stack.resolve(&"speed", def.speed) * delta`,采样 curve 设 `global_position`;`apply_knockback` 落成 progress 回退 clamp 0;progress ≥ baked_length → `EventBus.enemy_reached_exit.emit(self, def)` + `queue_free()`;`_physics_process` 调 `tick`,headless 手动驱动)、`test/cases/test_enemy.gd`(扩)。
  - Verify: 测试覆盖:①直线 curve 上 tick 1s 前进 `def.speed` px ②挂 `&"speed"` pct -0.3 后前进量 ×0.7 ③挂 `&"stunned"` flat +1 后 tick 不动,摘除后恢复 ④`apply_knockback(50, any)` 后 progress 回退 50 且不破 0 ⑤走到终点发 `enemy_reached_exit` 且 `is_queued_for_deletion()`。三连全绿。
- [x] Step: 端到端复核——真敌人过真反应(02 flag ③,flag ④ 数据点)。
  - Files: `test/cases/test_enemy_e2e.gd`(新;真 `enemy.tscn` + 真 `data/elements/*.tres` + 真 `ReactionSystem.setup` 装配,沿 02 e2e 入树模式)、`harness/archive/02-reaction-core/HANDOFF.md`(「02 伤害断言未过护甲」条销案)。
  - Verify: ①火+冰蒸汽爆破:AoE 伤害经护甲公式后的**精确数值**断言(armor 0 与 armor 2 两档注入对照)②毒附着(base_status 腐蚀 -2)后同额伤害在 armor 0 敌人上多扣 2(负护甲增伤数据点,记入 §5 flag 供 07 复核)③冰附着后敌人 tick 实际减速 30%。三连全绿。
- Playtest gate (Phase 1): 纯管道阶段,无可玩场景——headless 全绿即过(标准三连 + 本阶段全部新测试 0 失败);in-engine 观感统一归 Phase 3 gate。

### Phase 2: 波次数据 + 生成器

- [x] Step: 波次 Resource 类(D6)。
  - Files: `scripts/defs/spawn_entry.gd`、`scripts/defs/wave_def.gd`(均新,class_name + 全静态类型)、`test/cases/test_defs.gd`(扩:默认值与字段类型)。
  - Verify: 新 class_name 后先 `--import`(§5 第 0 步);`--check-only` 逐脚本 exit 0;test_defs 扩展方法 PASSED。
- [x] Step: 敌人与波次数据 `.tres`(占位量表,住数据不进代码)。
  - Files: `data/enemies/runner.tres`(建议占位:hp 30 / speed 60 / armor 0 / gold 5)、`data/enemies/lava_hound.tres`(hp 60 / speed 45 / armor 2 / gold 10 / innate_element = fire.tres)、`data/waves/dev_wave.tres`(两条目:runner ×5 间隔 1s;delay 3s 后 lava_hound ×2 间隔 2s)、`test/cases/test_data_integrity.gd`(扩)。
  - Verify: 完整性测试:`data/enemies/` 逐个加载 → id 非空、hp/speed > 0、gold > 0;`lava_hound.innate_element.id == &"fire"`;`dev_wave` entries 非空且 enemy 引用全非 null。三连全绿。
- [x] Step: WaveSpawner(D7/D8)。
  - Files: `scripts/systems/wave_spawner.gd`(新;`@export enemy_scene: PackedScene`、`@export path: Path2D`;`start_wave(wave: WaveDef)`,进行中重复调用忽略 + push_warning;`tick(delta)` 推进游标:entry 的 start_delay → 逐 interval 实例化 → `setup(def, path)` → add_child → `EventBus.enemy_spawned`;首只前发 `wave_started`,最后一只吐出后发 `wave_spawn_finished` 恰一次;`_physics_process` 调 `tick`)、`test/cases/test_wave_spawner.gd`(新,注入 RecordingBus + 手动 tick)。
  - Verify: 测试覆盖:①start_delay 内 0 只 ②interval 边界逐只吐、count 总数正确 ③两 entry 顺序衔接 ④`wave_started`/`wave_spawn_finished` 各恰一次、时序正确 ⑤吐出的实例已 setup(def 匹配、位于路径起点)⑥innate 怪出生即带火(gauge == default_attach)⑦进行中重复 start_wave 被忽略。三连全绿。
- Playtest gate (Phase 2): 纯管道阶段,headless 全绿即过;吐怪节奏观感归 Phase 3。

### Phase 3: dev 演武场 + 人工验证

- [x] Step: dev 演武场场景(仅开发验证用,非正式地图——正式交叉口地图归 06)。
  - Files: `scenes/maps/dev_playground.tscn`(新;Path2D 一条 S 形曲线 + WaveSpawner 就位接线 + Camera2D)、`scenes/maps/dev_playground.gd`(新;`_ready` 自动 `start_wave(dev_wave)`,订阅 EventBus 五信号逐条 print——dev 工具允许 print)。
  - Verify: headless 冒烟:`timeout 120 godot --headless --display-driver headless --audio-driver Dummy --quit-after 2000 --path . res://scenes/maps/dev_playground.tscn > /tmp/godot_dev.log 2>&1` → exit 0 且日志无 ERROR、可见 `wave_started` 与至少一条 `enemy_spawned` 输出;标准三连仍全绿。
- Playtest gate (Phase 3): **人工**——编辑器打开项目,F6 运行 `dev_playground.tscn`,应看到并确认:①方块敌人按 1s 节奏从路径起点出生 ②沿 S 形路径平滑移动、无抖动脱轨 ③熔岩犬方块为火色(与 runner 肉眼可辨)且控制台有其 `enemy_spawned`/火附着日志 ④敌人抵达终点消失,控制台有 `enemy_reached_exit` ⑤全部吐完控制台有 `wave_spawn_finished`。此 gate 过 = 03 验收面完成。

收官(并入 Phase 3 最后一步执行):回填 `harness/project-context.md` §2(scenes/enemies/ 实体脚本落位、data/waves/ 新目录)与 §3(若有新契约);更新本 PLAN 勾选状态、CHANGES.md、HANDOFF.md。

## 4. Out of scope

- 塔、弹丸、命中管线、碰撞体/collision layer(04;03 空间语义全走组扫描,零碰撞需求)。
- 状态图标、gauge 环、反应飘字、血条 UI(05;`hp_changed` 之类展示信号也留给 05 按需加)。
- 正式地图、10 波内容配置、金币结算、基地扣血与胜负判定、波次序列播放/波间流程(06;03 spawner 只播单波)。
- 复合敌人(元素免疫/吸收、净化者、护盾 Boss)、gauge 衰减(v2,BACKLOG Later 已列)。
- 寻路导航/避障(固定路径 TD 无此需求)。
- **可选管线阶段裁定(HANDOFF 同步标 `[x]` 不需要)**:设计(《项目说明》§3.2/§5 承担,沿 01/02 先例)、勘探(本 PLAN §2 已全量通读 01/02 产物与实测接口)、美术(占位方块 + 既有 element color,无新资产)、接线(场景全部 `.tscn` 文本由 Implementer 直写,无编辑器手工步骤;Phase 3 人工 gate 属验收非接线)。

## 5. Risks & Flags / Open questions

- **护甲公式为 03 裁定,无 BALANCE.md 背书**(D3):减法 + 负护甲增伤 + 脆化后乘。毒腐蚀 -2 在 armor 0 怪上 = 每跳 +2(对 DoT 每 0.5s 一跳相当凶),Phase 1 e2e 会固化数据点;数值观感待 07-balance-sim(或届时 /num-smith 建 BALANCE.md)统一校准。承 01/02 flag ④,03 落地后该 flag 从「待落地」转「待校准」。
- **敌人量表全占位**(runner/lava_hound 的 hp/speed/armor/gold),住 `.tres`,07 校准;speed/半径类 px 数值待 06 地图 tile 尺度复核(承 01,原样传递)。
- **innate 一次性附着 + 不挂 base_status**(D5):熔岩犬 gauge 耗尽(约 2 次反应)后变白板,教学持续性待 05/06 手感复核;若需周期回火,涉及新数值(间隔/量),届时经 07/num-smith,不在 03 私加。edge case:innate 耗尽后再被火塔附着会正常挂灼烧(后天附着语义),接受并观察。
- **`wave_spawn_finished` = 生成完毕,非清波**(D8):清波判定归 06 组计数;若 06 发现需要 spawner 托管「波内存活」状态,升级前先过 /state-machine-master。
- **WaveSpawner 无状态机**(D7):线性游标够 MVP;06 关卡流程若要暂停/加速/跳波,同上先过 /state-machine-master。
- **ICD 期间异元素吞附着的手感**(02-D8 裁定)不由 03 复核,原样传递 05/06(BACKLOG 已挂 06)。
- 目录扩展两处(scenes/enemies/ 实体脚本、data/waves/)需回填 project-context §2——已写进 Phase 3 收官步,Implementer 勿漏。
