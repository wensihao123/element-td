# BACKLOG

updated: 2026-07-05

## v1 范围线
一句话:**MVP 可玩原型** — 4 基础塔(无分支)+ 6 反应 + Gauge 制、1 张交叉口地图 10 波(含 1 种自带火附着怪)、金币单货币、状态可视化(图标 + gauge 环 + 反应飘字);验证"触发反应爽不爽、看不看得懂"。目标 2–3 周。

## Now(已承诺,按序执行)
1. `06-map-waves-economy` — 交叉口地图(**网格制**:TileMap/格子搭建,路格美术占格、Path2D 沿格心画、建造格标记,消费 04 的网格摆塔契约)、10 波配置、金币经济、胜负判定
   - 01/04 遗留(距离标尺双轨):04 新数值已 tile 制(TowerDef.attack_range/projectile_speed,经 `Balance.grid.tile_size` 换算),但 03 EnemyDef.speed 与 02 反应 AoE 半径仍 px——统一复核归 06,复核前不得顺手改旧数值(04 PLAN §5)。
   - 02 遗留:ICD 期间异元素「不反应、不附着、不动 gauge」的手感待整局试玩复核(PLAN 02-D8)。
   - 03 遗留:① `wave_spawner.gd` `start_wave` 对首条目 null 的手写坏数据会空引用崩溃,手写 10 波 `.tres` 时留意或顺手一行修复(03 REVIEW should-fix);② 清波判定归 06——`wave_spawn_finished` = 生成完毕非清波,若需 spawner 托管波内状态先过 /state-machine-master(03-D8);③ innate 一次性附着、耗尽变白板的教学持续性——05 已落地可视化并 gate 记录手感观察,处置(是否加持续提示/重附着)归 06 整局试玩复核(03-D5 / 05 承接)。
   - 04 遗留:① `dev_playground.gd` 的 dev 网格叠加层绘制是临时物(注释已标 dev-only),06 做正式建造/地图 UI 时删除——05 未碰建造交互,现单归 06(04 REVIEW nit / 05 裁定收窄);② `build_grid.gd` `_ready` 自接线失败无警告,接真实地图时顺路补 `push_warning`(04 REVIEW should-fix);③ `buildable.has()` O(n) 线性扫,真实地图格子多了可换 Dictionary 集合(04 REVIEW nit);④ 经济接线:cost_gold 已填占位但 04 不消费,扣费归 06;BuildGrid 无 release(无售塔),做售塔时几行扩展(04 PLAN §5);⑤ 弹丸不换目标(04-D7)的空弹浪费属可接受占位,整局试玩观感明显糟再记 flag(04 PLAN §5)。
   - 05 遗留(REVIEW should-fix):反应飘字上浮改 local `position.y`、扩散环锚 `global_position`,依赖「`ReactionVfxLayer` 保持默认变换(原点/无缩放)」隐式契约——06 正式地图接线时把该约束**显式写进 INTEGRATION-STEPS**(挂载时校验层 transform,或把上浮也改为不吃父变换),别让它只活在 05 CHANGES §5(05 REVIEW)。

## Next(排队,按优先序)
1. `07-balance-sim` — headless 平衡仿真 + CSV 报表 + `.tres`↔CSV 同步脚本
   - 03 遗留:敌人量表 hp/speed/armor/gold 与 dev_wave 节奏全占位待校准;毒腐蚀 -2 在 armor 0 怪 = 同额伤害每跳 +2,e2e 已固化数据点,校准归 07/num-smith。
   - 04 遗留:① 4 塔占位数值(damage 5 / 0.8s / 2.5 格 / 6 格/s / 100 金)全待校准,headless 数据点:runner 4 发点杀、lava_hound 需 20 发单座火塔射程内打不死必漏——管线正常,数值归 07(04 CHANGES §6);② Weapon 冷却按物理帧量化,60fps 下每发最多慢一帧,实际射速略低于 1/fire_interval,校准时知悉即可不必改(04 REVIEW nit)。

## Later / v2(明确延后,已留架构缝)
- 塔 3 级二选一分支(附着型/触发型)(注:Weapon 现为纯冷却计时无 FSM,分支若引入蓄力/多段/模式切换,先过 /state-machine-master,04 PLAN §5)
- **弹丸 `hit_direction` 零向量(技术债,低危)**:弹丸与目标重合时方向为零向量;现无消费方(03-D2 击退走路径进度回退、忽略 direction),真消费方向的效果(v2 新反应)出现时需在 `projectile.gd:60` 补零向量回退(04 REVIEW should-fix 留档)
- 中立塔:棱镜塔、回响塔
- 反应结晶货币 + 科技树
- gauge 衰减、差异化附着量/消耗量(override 机制已预留)
- **导出闸门(技术债,首次导出 PCK 前必修)**:两账同筐,均只在导出时触雷、v1 不导出不触雷——① `reaction_system.gd` 的 DirAccess 扫描在导出包内落空(`.tres` 变 `.tres.remap`)→ 导出版反应表静默为空,修法 = 剥 `.remap` 后缀或改显式清单(02 REVIEW should-fix);② 反应飘字中文字形靠系统字体回退,导出 PCK 后可能豆腐块,需内嵌中文字体或改英文/图标(05 PLAN §5)。
- **godot-ai MCP 游戏侧 helper 握手失败(dev 工具债,低危)**:`project_run` 的游戏侧 `_mcp_game_helper` 握手恒失败(helper_live 一直 false),运行时截图自查降级为 headless 探针 + 人工 F6(05 CHANGES §6)。不阻塞任何交付(纯 dev 工具、游戏代码禁依赖),有空排查 addons 游戏侧组件即可。
- 复合敌人:元素免疫/吸收、净化者、元素护盾 Boss
- 战役 15 关结构、解题式关卡、无尽模式
- 美术风格基线与正式资产(MVP 用占位)

## Shipped
- `01-data-layer` — 项目骨架 + defs/effects 资源类 + 11 个数据 .tres + headless 测试跑道(commit 1c7ca73,已归档 `harness/archive/01-data-layer/`)
- `02-reaction-core` — EventBus/ReactionSystem autoload + Status/Modifier/ActiveEffects 组件 + 7 类效果运行时 + 33 个 headless 测试(commit 5b24051,已归档 `harness/archive/02-reaction-core/`)
- `03-enemies-waves` — 通用敌人实体(路径移动/护甲/innate 附着)+ HealthComponent + WaveDef/SpawnEntry/WaveSpawner + dev 演武场,复审 APPROVE WITH NITS + 人工 playtest gate 通过(commit e240391,已归档 `harness/archive/03-enemies-waves/`)
- `04-towers-projectiles` — 网格摆塔(GridConfig/BuildGrid,tile=64px)+ 通用塔实体(Targeting/Weapon/ProjectileSpawner)+ 追踪弹丸命中管线(先附着后投伤)+ 4 基础塔 .tres,复审 APPROVE(2 must-fix 返工核实)+ 双 playtest gate 通过,4.7 headless 20 用例 94 方法全绿(commit 12b9f50,已归档 `harness/archive/04-towers-projectiles/`)
- `05-status-ui` — 状态可视化:头顶图标(首字占位/贴图零码升级)+ gauge 环(draw_arc 自绘)+ 反应飘字/扩散环占位;两条互不依赖路线(实体自身视图轮询 / 地图级层订阅 EventBus),逻辑代码零改动(D7 铁则),复审 APPROVE WITH NITS + 双 playtest gate F6 目验 PASS,4.7 headless 22 用例 0 失败(已归档 `harness/archive/05-status-ui/`,commit 待记)

---
*以下为 ledger,按需查阅*

## Cut
(暂无)

## Decision log
- 2026-07-05 — 05-status-ui 归档;遗留 flags 分流 — Verdict: ① 06 升 Now、07 升 Next 第 1;② 06 挂账:innate 教学持续性处置(承 03/05,可视化已落地待整局手感裁定)、dev 网格叠加层删除**收窄为仅 06**(05 未碰建造交互)、05 REVIEW should-fix 飘字/环依赖「层默认变换」隐式契约 → 06 接线显式写进 INTEGRATION-STEPS;③ Later:中文字形豆腐块**并入既有导出闸门**(同为不导出不触雷)、godot-ai MCP 游戏侧 helper 握手失败新增为 dev 工具债;④ 05 两条 nit(隐藏态陈旧字段、`_process` 无条件轮询)复审判无害留档、不入 BACKLOG。变更集(05 游戏码 + 归档)commit 待人授权后由 Producer 代执行(沿 02/03/04 先例)。
  Why: 05 复审 APPROVE WITH NITS、must-fix 空、双 F6 gate 通过、22 用例全绿,纯增量表现层零逻辑改动,直接归档无争议;所有遗留均非阻塞,沿 02/03/04 归档先例按「就近落地」分流到自然消费方(06 为地图/建造/接线正主,故收纳表现契约与建造工具删除;中文字形与导出闸门同为导出期问题合并免筐外增项;MCP 握手属 dev 工具非游戏范围,单列低危债不污染游戏 backlog)。
- 2026-07-04 — harness 初始化 — Verdict: 以《元素反应塔防-项目说明.md》为设计与架构基准,MVP 第 5 节直接定为 v1 范围线;实现顺序采用项目说明第 5 节建议顺序切成 7 个 feature。
  Why: 项目说明已完成 Game Designer 层面的工作,无需重复设计;按依赖序(数据层 → 核心逻辑 → 实体 → 表现 → 关卡 → 工具)排队,每个 feature 可独立验收。
- 2026-07-04 — 是否先跑 /arch-guard 建 ARCHITECTURE.md — Verdict: 暂缓(Later 未列,属流程决定)。
  Why: 项目说明第 4 节本身就是架构基准且足够详尽;等实际代码出现结构分歧再引入 arch-guard,避免开局文档过载。
- 2026-07-04 — 是否在 02 之前跑 /num-smith 建 BALANCE.md(01 HANDOFF 可选 flag)— Verdict: 暂缓。
  Why: MVP 数值全是占位、全住 global_config,07-balance-sim 才是数值工作的正主;现在建框架属文档过载,与 arch-guard 同理。数值失衡或 07 开工时再引入。
- 2026-07-04 — 02-reaction-core 归档;REVIEW 3 条 should-fix 分流 — Verdict: ① `.tres.remap` 导出地雷 → Later/v2 导出闸门;② PropagateEffect handle_sink 一行加固 → 纳入 03 PLAN(已落地销案);③ take_damage 禁同步 free → 契约条款回填 project-context §3 并挂 03 开工必读(已消费)。
  Why: 三条均不影响当前 headless 全绿,不值得为技术债单开 feature;按"就近落地"分流——①只在导出时触雷而 v1 不导出,②方案现成且 03 本就要碰效果测试,③本质是 03 实现约束而非独立工作项。
- 2026-07-05 — 引擎升级 Godot 4.6.3→4.7 + godot-ai MCP 配置就位(人告知)— Verdict: ① 核实:编辑器 4.7-stable、MCP 连通、编辑器零报错、`project.godot` features 已被 4.7 自动升为 "4.7"(未提交);但 PATH 的 CLI 仍 4.6.3,全量测试(14 用例 0 失败)绿在 4.6.3 非 4.7。② 在 04 开工前挂**环境闸门**:人工统一 CLI 到 4.7 → 复跑全量 + probe_autoload(§6 复测挂账被此升级触发)→ 授权提交 features 升级。③ MCP 定位不变:dev 工具,各 role 可用,游戏代码禁依赖(沿 03 归档人裁定)。
  Why: 混引擎开发(编辑 4.7 / 验证 4.6.3)会让 04 的失败误归因,统一成本仅几分钟;probe 复测本就是 §6 写死的升级触发项;闸门是环境动作非功能,不单开 feature,挂在 04 条目下随其销案。
  (2026-07-05 闸门全销:①人工换 PATH;②4.7 复跑全绿——`--import` 零报错、14 用例 0 失败、probe 通过;③经人授权由 Producer 代执行提交。04 开工放行。)
- 2026-07-05 — 地图改网格系统(保卫萝卜式,人提议)— Verdict: 采纳为**固定路径 + 网格摆塔**,不新开 feature——网格摆放契约挂 04 开工必读④,地图网格化归 06;明确排除**挖坑挡路型**(塔占格改道 + 寻路)。
  Why: 固定路径与 03 已交付的 Path2D progress 移动完全兼容(路径沿格心画即可),03 零返工;网格摆塔恰是 04 尚未动工的部分,现在定免返工;tile 尺寸落地顺带解决 01 遗留的 px 数值标尺问题。挖坑挡路型需寻路 + 03 移动重写,冲击 2–3 周 v1 周期,且堵路策略与支柱 2(深度来自反应摆位组合)不同路,若未来想要走 v2 再议。
- 2026-07-05 — godot-ai MCP 接入后是否提升界面制作质量(人提问)— Verdict: 提升**制作与验证效率**(直操编辑器搭场景/UI + `editor_screenshot` 自查),挂 05 条目为执行手段;**不抬美术规格**——可读性质量本属 v1 验证目标,正式美术观感仍卡风格基线未定,归 Art Spec/STYLE-BIBLE,v1 维持"占位但可读"。
  Why: 工具变强 ≠ 范围变大;05 是支柱 3 落点、MCP 工具面(theme/animation/particle/ui)全覆盖的最大受益方,04/06 场景搭建顺带受益;把效率红利花在正式美术上 = 范围蠕变吃 v1 周期。
- 2026-07-05 — 04-towers-projectiles 归档;遗留 flags 分流 — Verdict: ① 05 升 Now(dev 网格叠加层删除提醒挂 05);② 06 挂 4 条:build_grid 自接线警告、buildable O(n)、cost_gold 扣费与售塔 release、弹丸不换目标观感,并把距离标尺双轨复核(01 遗留)更新为 04 tile 制 vs 03/02 px 的具体对账;③ 07 挂 2 条:4 塔占位数值 + headless 数据点(runner 4 发 / lava_hound 20 发)、Weapon 冷却帧量化知悉;④ hit_direction 零向量无 v1 消费方 → Later 技术债留档;Weapon 无 FSM 的触发条件挂 Later 塔分支条目。变更集 commit 12b9f50 经人授权由 Producer 代执行(沿 02/03 先例)。
  Why: 全部遗留均非阻塞(复审 APPROVE、双 gate 已过、4.7 全绿),按"就近落地"分流到各自然消费方;零向量债现无实害且消费方在 v2,升 Later 而非挂 06 免噪音。另:本 session shell 实证重启前进程仍持 4.6.3 PATH,操作提醒挂 05 条目。
- 2026-07-05 — 03-enemies-waves 归档;复审遗留 1 条 should-fix + 3 条 nits 分流 — Verdict: ① `wave_spawner.start_wave` 首条目 null 无防御 → 挂 06(手写 10 波 `.tres` 时留意或顺手修);② innate 教学持续性手感 → 挂 05/06 复核;③ 敌人量表与毒腐蚀数据点校准 → 挂 07;④ 3 条 nits(.gitignore 末行换行、innate cfg 缺失静默白板、02 归档日期微差)不单开工作项,随手可校。
  Why: 均不影响 headless 全绿与 03 验收面(playtest gate 已过);沿 02 归档先例按"就近落地"分流,04 为既有契约的纯消费方,无新增账。变更集 commit 经人授权由 Producer 代执行(feat e240391)。
