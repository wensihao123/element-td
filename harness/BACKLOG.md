# BACKLOG

updated: 2026-07-04

## v1 范围线
一句话:**MVP 可玩原型** — 4 基础塔(无分支)+ 6 反应 + Gauge 制、1 张交叉口地图 10 波(含 1 种自带火附着怪)、金币单货币、状态可视化(图标 + gauge 环 + 反应飘字);验证"触发反应爽不爽、看不看得懂"。目标 2–3 周。

## Now(已承诺,按序执行)
1. `02-reaction-core` — EventBus + ReactionSystem + StatusComponent,headless 测试先行(gauge 规则、反应表、ICD、补偿)
   - **01 归档遗留,开工必读**(全文见 `harness/archive/01-data-layer/HANDOFF.md` 未决 flags):
     ① effect SubResource 经 load() 后为共享实例,apply() 必须无状态,运行时状态住 StatusComponent/ModifierStack;
     ② 测试跑道对"test_ 方法崩溃且零断言"会误报 PASSED,写逻辑测试前先加断言计数防线;
     ③ `-s` 模式下 autoload 是否实例化未验证,落地 ReactionSystem 时验证并回填 project-context §6;
     ④ base_status 复用 ReactionEffect 的持续型语义待确认(只许调类接口,不动数据布局)。

## Next(排队,按优先序)
1. `03-enemies-waves` — 敌人(Path2D 寻路 + Health/StatusComponent)+ 波次生成器(含自带火附着怪)(01 遗留:毒腐蚀 add_flat -2.0 待敌人护甲量表落地后复核)
2. `04-towers-projectiles` — 塔场景组合(Targeting/Weapon/ProjectileSpawner)+ 弹丸命中管线
3. `05-status-ui` — 头顶状态图标 + gauge 环形进度条 + 反应飘字/特效占位(支柱 3 的落点)
4. `06-map-waves-economy` — 交叉口地图、10 波配置、金币经济、胜负判定(01 遗留:radius/distance/speed 等 px 数值待地图 tile 尺度落地后复核)
5. `07-balance-sim` — headless 平衡仿真 + CSV 报表 + `.tres`↔CSV 同步脚本

## Later / v2(明确延后,已留架构缝)
- 塔 3 级二选一分支(附着型/触发型)
- 中立塔:棱镜塔、回响塔
- 反应结晶货币 + 科技树
- gauge 衰减、差异化附着量/消耗量(override 机制已预留)
- 复合敌人:元素免疫/吸收、净化者、元素护盾 Boss
- 战役 15 关结构、解题式关卡、无尽模式
- 美术风格基线与正式资产(MVP 用占位)

## Shipped
- `01-data-layer` — 项目骨架 + defs/effects 资源类 + 11 个数据 .tres + headless 测试跑道(commit 1c7ca73,已归档 `harness/archive/01-data-layer/`)

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
