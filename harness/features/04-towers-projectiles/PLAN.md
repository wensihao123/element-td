---
artifact: PLAN
feature: 04-towers-projectiles
role: Planner
status: draft
updated: 2026-07-05
inputs: [project-context.md, BACKLOG.md(04 条目含开工必读①–④), 元素反应塔防-项目说明.md(§3.1/§4.3/§5), archive/02+03 的 PLAN/REVIEW/HANDOFF, 现有代码实测(enemy.gd / status_component.gd / health_component.gd / reaction_effect.gd / wave_spawner.gd / balance.gd / tower_def.gd / dev_playground)]
next: Implementer
---

# PLAN — 04-towers-projectiles(塔场景组合 + 弹丸命中管线 + 网格摆塔)

## 1. Goal

交付可开火的数据驱动塔(Targeting/Weapon/ProjectileSpawner 三组件)+ 弹丸命中管线(投伤 + 元素附着,接通 02/03 全部既有契约)+ 网格摆塔底座(tile 常量、吸附格心、一格一塔),在 dev 演武场可人工摆塔看反应。

## 2. Approach & key decisions

总思路:塔侧完全复刻 03 敌人的成功模式——通用单场景 + Def 注入 + 具名子组件 + headless 先行;网格只做「几何换算 + 占用簿记」的最小底座,真实地图数据源留给 06 注入。

- **04-D1|tile 尺寸 = 64px,住 `data/balance/grid_config.tres`(新 `GridConfig` Resource),Balance autoload 增加 `grid` 字段。**
  Why:BACKLOG 契约④要求 tile 常量住 `res://data/` 且由本 PLAN 定夺,64px 与现演武场分辨率(1152×648 视野 = 18×10 格)匹配;暴露方式沿 `Balance.config` 既有先例,一处权威。
  备选:塞进 GaugeConfig——拒,gauge 是元素数值、grid 是空间标尺,职责不同混住会让 07 的 CSV 同步脏。
- **04-D2|TowerDef 的 `attack_range` / `projectile_speed` 语义定为 tile 单位(格、格/秒),运行时 × `tile_size` 换算 px。**
  Why:BACKLOG 契约④「距离数值一律以 tile 为标尺」;字段现无任何 `.tres` 使用者,现在定语义零返工。tower_def.gd 注释必须同步改写标明单位。
  备选:沿用 px——拒,违契约④,且 06 换地图尺寸时全部数值重调。
  (注:03 的 `EnemyDef.speed` 与 02 反应效果的 AoE 半径仍是 px,双轨并存;统一复核已挂 06,见 §5。)
- **04-D3|BuildGrid = 非 autoload 场景节点(沿 WaveSpawner 先例),只管「几何 + 簿记」不管实例化:`world_to_cell` / `cell_center` / `can_build` / `claim`;buildable 格集合注入式。**
  Why:实例化塔归调用方(dev 输入工具、未来 06 的建造流程),BuildGrid 无需依赖塔场景即可 headless 全测;06 把 TileMap 建造格标记转成注入集合,零改 BuildGrid。一格一塔 = `Dictionary[Vector2i, Node]` 占用表,`can_build` = 在 buildable 集合内且未被占用。
  备选:BuildGrid.place() 全托管实例化——拒,把场景依赖搅进纯逻辑,Phase 1 没法独立交付。
  (无售塔故不做 release,06 若做售塔补几行,见 §5。)
- **04-D4|通用 `tower.tscn` 数据驱动(沿 03-D9 敌人先例):根脚本 `scenes/towers/tower.gd`(`class_name Tower`),三具名直接子节点 `Targeting` / `Weapon` / `ProjectileSpawner`(项目说明 §4.3 明定组合 + 02-D7 具名发现约定),组件脚本住 `scripts/components/`;`setup(def: TowerDef)` 注入,`_ready` 空字段自接线 Balance(02-D1 模式),占位视觉 = Polygon2D 按 `def.element.color` 染色。**
  Why:换元素只是换 Def(项目说明原话),加塔 = 加 `.tres` 零场景复制;测试先显式注入再入树,与 01–03 全部先例一致。
  备选:每元素一个场景——拒,4 份场景漂移维护。
- **04-D5|索敌策略 = 射程内 `progress` 最大者(「首怪」),Weapon 持有目标直到失效/出射程才重索。**
  Why:首怪优先是 TD 惯例,且附着顺序可预测——玩家能推理「冰塔先命中队首」从而摆位设计反应时机(支柱 2);`progress` 字段 03 已带,组扫描(复用 `ReactionEffect.ENEMY_GROUP`)+ 距离过滤 + 取 max,零新基建。
  备选:最近距离优先——拒,目标随走位高频跳变,附着落点不可预测,反应时机变随机噪音。
- **04-D6|命中结算顺序 = 先 `StatusComponent.apply_element`(可能触发反应)后 `take_damage`;目标已 `is_queued_for_deletion()` 则整个命中丢弃。**
  Why:先附着保证「击杀弹也能触发反应」——清杂反应(蒸汽爆破)最爽的时刻恰是补刀瞬间(支柱 1);若反应伤害先杀死目标,随后的直伤被 03 的终态 guard 自然吸收,不双记账。命中丢弃 guard 防止对已死目标结算(02 REVIEW use-after-free 铁律的弹丸侧延伸)。
  备选:先投伤后附着——拒,击杀弹永不触发反应,玩家学到「补刀前别指望反应」是反支柱 1 的教学。
- **04-D7|弹丸 = 追踪目标节点;目标失效(死亡/被释放)→ 弹丸 `queue_free`,不追尸不换目标;命中判定 = 本帧位移 ≥ 到目标剩余距离(无 magic 命中半径)。**
  Why:判定纯几何、确定性,headless 手动 tick 可精确断言;不换目标是最简占位行为,高射速下的空弹浪费留 07 观察(§5)。
  备选:落点结算(非追踪)——拒,快弹慢怪下弹道预判是额外系统,MVP 不值。
- **04-D8|4 塔占位数值统一(仅 `element` 与 id/名字不同),全住 `data/towers/*.tres`:damage 5 / fire_interval 0.8s / attack_range 2.5 格 / projectile_speed 6 格/s / cost_gold 100 / attach_override -1(用全局 2U)。**
  Why:MVP 验证的是反应管线不是数值手感,统一数值让反应对比干净;数字只出现在 `.tres`(硬 NO 红线),校准归 07。`cost_gold` 填占位但 04 不消费——经济归 06。
- **04-D9|04 不新增 EventBus 信号;弹丸实例挂 ProjectileSpawner 子节点。**
  Why:命中链路所需信号(`reaction_triggered` / `enemy_died` 等)02/03 已齐;`tower_placed` 之类等 06 经济真实需要再议,不投机泛化(hard NO)。弹丸挂 spawner 沿 WaveSpawner 吐怪挂自身先例。
- **04-D10|dev 摆塔输入(数字键 1–4 选塔 + 左键放置)是演武场 dev 工具,写在 dev_playground 侧;正式建造交互归 05/06。**
  Why:04 的验收面是「摆塔 → 开火 → 反应」全链路可人工目验,不是建造 UI;dev 侧的 buildable 格集合与按键映射属 dev 工具数据(沿 dev_playground 既有 DEV_WAVE_PATH 先例),不受数值进 `.tres` 红线约束,但须注释标明 dev-only。

**既有契约消费对照**(BACKLOG 开工必读,Implementer 照此接线,不再自行设计):
① 弹丸直伤走敌人根 `take_damage(amount, source)`(source = 塔根节点),禁同步 free——03 的 enemy.gd 已带终态 guard;
② 附着走敌人根具名子节点 `StatusComponent.apply_element(element, amount, source, hit_direction)`,`hit_direction` 传弹丸飞行方向归一化(过载击退用);附着量 = `def.get_attach(cfg)`,cfg 取自 Balance(注入优先);
③ 索敌 = `ReactionEffect.ENEMY_GROUP` 组扫描 + 距离过滤(02-D6);
④ 网格摆塔 = 本 PLAN D1–D3 落地。

## 3. Phased steps

### Phase 1: 网格底座(GridConfig + BuildGrid)
- [x] Step: 新建 `GridConfig` Resource 类(`@export var tile_size: float = 64.0`,类默认值 = 项目说明式代码快照,权威在 `.tres`)+ `data/balance/grid_config.tres`;`balance.gd` 增加 `var grid: GridConfig = preload(...)`。
  - Files: `scripts/defs/grid_config.gd`(新)、`data/balance/grid_config.tres`(新)、`scripts/systems/balance.gd`
  - Verify: §5 第 0 步 `--import` 零报错(豁免条款照旧);`--check-only -s` 过 grid_config.gd
- [x] Step: 新建 `BuildGrid` 节点:`world_to_cell(pos) -> Vector2i`、`cell_center(cell) -> Vector2`、`can_build(cell) -> bool`(buildable 集合内且未占用)、`claim(cell, tower) -> void`;`cfg: GridConfig` 与 buildable 集合(`Array[Vector2i]` 或等价)均注入式,空 cfg 时 `_ready` 自接线 `Balance.grid`(02-D1 模式)。
  - Files: `scripts/systems/build_grid.gd`(新)、`test/cases/test_build_grid.gd`(新)
  - Verify: headless 测试绿——格心换算往返一致(含负坐标格)、非 buildable 格拒绝、已占用格拒绝、claim 后 can_build 翻 false
- Playtest gate (Phase 1): 纯管线,无可玩验证——headless 全量绿(既有 14 用例 + 新增 0 失败)即过。

### Phase 2: 塔实体(三组件 + 4 塔 .tres)
- [x] Step: `Targeting` 组件:`acquire(origin: Node2D, range_px: float) -> Node2D`——`ENEMY_GROUP` 组扫描 + 距离过滤 + `progress` 最大者(经 `node.get("progress")` 鸭子读取,缺省 0);无候选返回 null。
  - Files: `scripts/components/targeting.gd`(新)、`test/cases/test_targeting.gd`(新)
  - Verify: headless 绿——射程外不选、多怪选 progress 最大、空场返回 null
- [x] Step: `Weapon` 组件:持有 def 派生参数(由塔根 setup 时注入,含换算好的 range_px/speed_px)、冷却计时(初始 0,有目标即首发,之后每 `fire_interval` 一发)、目标失效/出射程时经兄弟节点 `Targeting` 重索、开火时调兄弟 `ProjectileSpawner.spawn(target, payload)`;`_physics_process` 委托 `tick(delta)`(03 手动驱动先例)。
  - Files: `scripts/components/weapon.gd`(新)、`test/cases/test_weapon.gd`(新)
  - Verify: headless 绿——stub spawner 记录:有目标立即首发、发射间隔 = fire_interval、目标离场后停火并重索
- [x] Step: `ProjectileSpawner` 组件:`@export var projectile_scene: PackedScene`,`spawn(target, payload)` 实例化弹丸、`setup` 注入、`add_child`(弹丸挂自身,D9);Phase 2 先以最小桩交付(弹丸场景 Phase 3 才有,本步测试用替身场景)。
  - Files: `scripts/components/projectile_spawner.gd`(新)
  - Verify: `--check-only` 过;test_weapon 中以替身 scene 验证 spawn 被调用且子节点入树
- [x] Step: 塔根 `tower.gd`(`class_name Tower`)+ `tower.tscn`:根 Node2D + `Visual`(Polygon2D 占位,按 `def.element.color` 染色)+ 三具名子节点;`setup(def)` 注入并向 Weapon 分发换算参数(× `Balance.grid.tile_size`,cfg 注入优先);`.tscn` 手写注意 `node_paths` 坑(project-context §6)。
  - Files: `scenes/towers/tower.gd`(新)、`scenes/towers/tower.tscn`(新)
  - Verify: `--import` 后 headless 实例化 + setup 断言:子组件发现齐全、range 换算 = 2.5 × 64 = 160px(数值从 .tres 读,断言经计算不硬编码期望语义)
- [x] Step: 4 塔 `.tres`:`data/towers/fire_basic.tres` / `ice_basic.tres` / `lightning_basic.tres` / `poison_basic.tres`,按 D8 占位数值,element 指向既有 4 元素 `.tres`。
  - Files: `data/towers/*.tres`(新 ×4)
  - Verify: `--import` 零报错;headless 加载断言 4 份 def 字段齐全、element 引用非空且互异
- Playtest gate (Phase 2): 仍是管线——塔没有弹丸不会造成任何可观察效果,headless 全量绿即过(如实声明,无演武验证)。

### Phase 3: 弹丸 + 命中管线 + 演武场预置塔
- [x] Step: 弹丸 `projectile.gd`(`class_name Projectile`)+ `projectile.tscn`(scenes/towers/,实体根随场景放,03-D10 先例):`setup(target, speed_px, damage, element, attach_amount, source)`;`tick`:目标失效 → `queue_free`;本帧位移 ≥ 剩余距离 → 命中(D7),否则朝目标推进;命中执行 D6 顺序——目标 `is_queued_for_deletion()` 则丢弃,否则先 `StatusComponent.apply_element(element, attach_amount, source, 飞行方向归一化)` 再 `take_damage(damage, source)`,然后 `queue_free`;占位视觉小色点按元素染色。
  - Files: `scenes/towers/projectile.gd`(新)、`scenes/towers/projectile.tscn`(新)
  - Verify: `--import` + `--check-only` 过
- [x] Step: 弹丸 headless 测试:①命中后目标 gauge 与 hp 同帧变化且顺序为先附着后投伤(用真 enemy:断言反应在直伤前结算——lava_hound 满血受冰弹,steam_burst AoE 伤害与直伤都入账);②目标已 queued → gauge/hp 双双不动、弹丸自毁;③飞行中目标被 free → 弹丸自毁不崩;④大步长 tick 一帧跨过目标 → 恰好命中一次。
  - Files: `test/cases/test_projectile.gd`(新)
  - Verify: headless 绿,含上述 4 断言组
- [x] Step: 塔↔敌 e2e 测试:路径上放 runner + 火塔 → 连发直至 `enemy_died`(RecordingBus 断言恰一次);lava_hound(innate 火)+ 冰塔 → 首发即 `reaction_triggered`(steam_burst)且邻近 runner 吃到 AoE 伤害;全程手动 tick 确定性。
  - Files: `test/cases/test_tower_e2e.gd`(新)
  - Verify: headless 全量绿(既有 + 新增 0 失败)
- [x] Step: dev_playground 预置 1 座火塔(`.tscn` 手写,置于路径旁格心坐标)+ 订阅 `reaction_triggered` 打印日志行(补 03 缺的这条)。
  - Files: `scenes/maps/dev_playground.tscn`、`scenes/maps/dev_playground.gd`
  - Verify: headless 跑演武场脚本不报错;人工 gate 见下
- Playtest gate (Phase 3): 编辑器 F6 演武场——预置火塔对路过敌人自动开火:弹丸飞行肉眼可见、白色 runner 被打死(控制台 `enemy_died`)、熔岩犬被火弹命中只充能不反应(无 reaction 日志);控制台无报错。看点:塔的开火节奏与弹丸速度直觉上像不像 TD。

### Phase 4: 网格摆塔 dev 输入 + 全链路验收
- [x] Step: dev_playground 挂 `BuildGrid` 节点并注入 dev buildable 格集合(路径带以外的一片格子,dev 工具数据、注释标明 dev-only);数字键 1–4 选 4 塔 def,左键 → `world_to_cell` → `can_build` → 通过则实例化塔、`setup`、置于 `cell_center`、`claim`;拒绝时 print 原因(路格/已占用)。
  - Files: `scenes/maps/dev_playground.gd`、`scenes/maps/dev_playground.tscn`
  - Verify: `--check-only` 过;人工 gate 见下
- [x] Step: 收尾三连:`--import` 零报错(豁免条款照旧)→ 改动脚本逐个 `--check-only` → headless 全量 0 失败;更新 CHANGES.md 与 HANDOFF。
  - Files: (验证步,无新文件)
  - Verify: project-context §5 全绿标准
- Playtest gate (Phase 4): F6 演武场,按序目验:①点路径格 / 已占格 → 控制台拒绝原因、不出塔;②空建造格放冰塔 → 塔吸附格心、颜色对应元素;③冰塔命中熔岩犬 → `reaction_triggered steam_burst` 日志 + 邻近敌人同帧掉血;④对同一 runner 先火塔后电塔连击 → 过载反应、敌人沿路径肉眼可见倒退。核心看点(v1 验证目标预演):反应触发的瞬间,只看控制台 + 敌人行为能不能立刻明白发生了什么。

## 4. Out of scope

- **本功能裁定跳过的管线阶段**(HANDOFF 同步标 `[x]` 不需要):设计(《项目说明》§3.1/§4.3/§5 承担,沿 01–03 先例)、勘探(本 PLAN 已全量通读既有代码与实测契约)、美术(占位多边形 + 既有 element color,零新资产,正式可视化归 05)、接线(场景全 `.tscn` 文本直写,Phase 3/4 人工 gate 属验收非接线)。
- 金币扣费 / `cost_gold` 消费、放塔经济校验 —— 06(字段已填占位值挂账)。
- 真实地图网格:TileMap、路格/障碍格数据源、建造格标记 —— 06(BuildGrid 的 buildable 注入口已留)。
- 正式建造 UI(选塔面板、射程预览、放置光标)—— 05/06;04 只有 dev 按键输入。
- 状态可视化(图标/gauge 环/飘字)—— 05。
- 售塔、塔升级、3 级分支、中立塔 —— v2(架构缝:BuildGrid 占用表可逆、TowerDef 可扩 @export)。
- 数值校准与手感 —— 07(4 塔占位数值统一)。
- 新 EventBus 信号 —— 明确不加(D9)。

## 5. Risks & Flags / Open questions

- **距离标尺双轨并存**:04 新数值 tile 制(D2),但 03 `EnemyDef.speed`、02 反应 AoE 半径、演武场路径坐标仍 px——BACKLOG 已把统一复核挂 06,Implementer 期间**不要**顺手改旧数值(hard NO:计划外重构)。
- **占位数值手感未知**:damage 5 / 0.8s 打 hp 未知量表的怪,可能秒杀或挠痒;Phase 3/4 gate 只验管线与可读性,数值难看不算 gate 失败,记录观感留 07。
- **弹丸不换目标(D7)**:高射速 + 目标提前死亡时存在空弹浪费,属可接受占位行为;若 gate 观感明显糟(大量弹丸飞向空气),记 flag 给 07/06,不在 04 内改。
- **Weapon 是纯冷却计时,无状态机**:蓄力、多段、攻击模式切换等一旦要做,先过 /state-machine-master——本 PLAN 明确 Weapon 不引入 ad-hoc 状态旗标。
- **dev 输入 headless 不可测**:按键/点击链路只靠 Phase 4 人工 gate 覆盖,headless 覆盖到 `can_build`/`claim` 逻辑层为止。
- **BuildGrid 无 release**:无售塔故无解占用;06 若做售塔属几行扩展,占用表结构已支持。
- Open question(不阻塞,gate 时人工留意):首发即射(冷却初始 0)在放塔瞬间敌群已在射程内时是否观感突兀;若突兀,07 调 `fire_interval` 或 06 加放置延迟,04 不处理。
