# BACKLOG

updated: 2026-07-05

## v1 范围线
一句话:**MVP 可玩原型** — 4 基础塔(无分支)+ 6 反应 + Gauge 制、1 张交叉口地图 10 波(含 1 种自带火附着怪)、金币单货币、状态可视化(图标 + gauge 环 + 反应飘字);验证"触发反应爽不爽、看不看得懂"。目标 2–3 周。

## Now(已承诺,按序执行)
1. `04-towers-projectiles` — 塔场景组合(Targeting/Weapon/ProjectileSpawner)+ 弹丸命中管线
   - **开工必读**(既有契约的消费方,全文见 project-context §3):
     ① 命中投伤一律走 `take_damage(amount, source)`(source = 塔;反应伤害记给触发方塔),**禁止同步 `free()` 敌人**;
     ② 附着走 `StatusComponent.apply_element`(经具名子节点发现,02-D7);
     ③ 索敌 = `&"enemies"` 组扫描 + 距离过滤(02-D6),敌人已带 HealthComponent 护甲结算(03-D3/D4);
     ④ **网格摆塔契约(2026-07-05 人裁定,保卫萝卜式)**:地图为网格,塔只能建在空建造格——吸附格心、一格一塔、路格/障碍格不可建;tile 尺寸为全局常量住 `res://data/`(具体值 04 PLAN 定夺,建议 64px),索敌半径等距离数值一律以 tile 为标尺表达或换算;敌人路径保持 Path2D 固定路线(沿格心画),玩家不能堵路改道。

## Next(排队,按优先序)
1. `05-status-ui` — 头顶状态图标 + gauge 环形进度条 + 反应飘字/特效占位(支柱 3 的落点)(执行手段 2026-07-05:经 godot-ai MCP 直操编辑器搭 UI + `editor_screenshot` 自查可读性,人工 gate 只验最终手感;质量目标仍是"占位但可读",正式美术等 STYLE-BIBLE)(03 遗留:innate 一次性附着、耗尽变白板的教学持续性,可视化落地后与 06 共担手感复核,03-D5)
2. `06-map-waves-economy` — 交叉口地图(**网格制**:TileMap/格子搭建,路格美术占格、Path2D 沿格心画、建造格标记,消费 04 的网格摆塔契约)、10 波配置、金币经济、胜负判定(01 遗留:radius/distance/speed 等 px 数值以 tile 尺寸为标尺复核;02 遗留:ICD 期间异元素「不反应、不附着、不动 gauge」的手感待整局试玩复核,PLAN 02-D8;03 遗留:① `wave_spawner.gd` `start_wave` 对首条目 null 的手写坏数据会空引用崩溃,手写 10 波 `.tres` 时留意或顺手一行修复(03 REVIEW should-fix);② 清波判定归 06——`wave_spawn_finished` = 生成完毕非清波,若需 spawner 托管波内状态先过 /state-machine-master,03-D8)
3. `07-balance-sim` — headless 平衡仿真 + CSV 报表 + `.tres`↔CSV 同步脚本(03 遗留:敌人量表 hp/speed/armor/gold 与 dev_wave 节奏全占位待校准;毒腐蚀 -2 在 armor 0 怪 = 同额伤害每跳 +2,e2e 已固化数据点,校准归 07/num-smith)

## Later / v2(明确延后,已留架构缝)
- 塔 3 级二选一分支(附着型/触发型)
- 中立塔:棱镜塔、回响塔
- 反应结晶货币 + 科技树
- gauge 衰减、差异化附着量/消耗量(override 机制已预留)
- **导出闸门(技术债,首次导出 PCK 前必修)**:`reaction_system.gd` 的 DirAccess 扫描在导出包内落空(`.tres` 变 `.tres.remap`)→ 导出版反应表静默为空;修法 = 剥 `.remap` 后缀或改显式清单,几行改动(02 REVIEW should-fix)。v1 验证全程编辑器/本机跑,不导出不触雷。
- 复合敌人:元素免疫/吸收、净化者、元素护盾 Boss
- 战役 15 关结构、解题式关卡、无尽模式
- 美术风格基线与正式资产(MVP 用占位)

## Shipped
- `01-data-layer` — 项目骨架 + defs/effects 资源类 + 11 个数据 .tres + headless 测试跑道(commit 1c7ca73,已归档 `harness/archive/01-data-layer/`)
- `02-reaction-core` — EventBus/ReactionSystem autoload + Status/Modifier/ActiveEffects 组件 + 7 类效果运行时 + 33 个 headless 测试(commit 5b24051,已归档 `harness/archive/02-reaction-core/`)
- `03-enemies-waves` — 通用敌人实体(路径移动/护甲/innate 附着)+ HealthComponent + WaveDef/SpawnEntry/WaveSpawner + dev 演武场,复审 APPROVE WITH NITS + 人工 playtest gate 通过(commit e240391,已归档 `harness/archive/03-enemies-waves/`)

---
*以下为 ledger,按需查阅*

## Cut
(暂无)

## Decision log
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
- 2026-07-05 — 03-enemies-waves 归档;复审遗留 1 条 should-fix + 3 条 nits 分流 — Verdict: ① `wave_spawner.start_wave` 首条目 null 无防御 → 挂 06(手写 10 波 `.tres` 时留意或顺手修);② innate 教学持续性手感 → 挂 05/06 复核;③ 敌人量表与毒腐蚀数据点校准 → 挂 07;④ 3 条 nits(.gitignore 末行换行、innate cfg 缺失静默白板、02 归档日期微差)不单开工作项,随手可校。
  Why: 均不影响 headless 全绿与 03 验收面(playtest gate 已过);沿 02 归档先例按"就近落地"分流,04 为既有契约的纯消费方,无新增账。变更集 commit 经人授权由 Producer 代执行(feat e240391)。
