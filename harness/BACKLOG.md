# BACKLOG

updated: 2026-07-04

## v1 范围线
一句话:**MVP 可玩原型** — 4 基础塔(无分支)+ 6 反应 + Gauge 制、1 张交叉口地图 10 波(含 1 种自带火附着怪)、金币单货币、状态可视化(图标 + gauge 环 + 反应飘字);验证"触发反应爽不爽、看不看得懂"。目标 2–3 周。

## Now(已承诺,按序执行)
1. `01-data-layer` — Godot 项目初始化 + `defs/` 全部 Resource 类 + global_config + 4 元素 + 6 反应 `.tres`
2. `02-reaction-core` — EventBus + ReactionSystem + StatusComponent,headless 测试先行(gauge 规则、反应表、ICD、补偿)

## Next(排队,按优先序)
1. `03-enemies-waves` — 敌人(Path2D 寻路 + Health/StatusComponent)+ 波次生成器(含自带火附着怪)
2. `04-towers-projectiles` — 塔场景组合(Targeting/Weapon/ProjectileSpawner)+ 弹丸命中管线
3. `05-status-ui` — 头顶状态图标 + gauge 环形进度条 + 反应飘字/特效占位(支柱 3 的落点)
4. `06-map-waves-economy` — 交叉口地图、10 波配置、金币经济、胜负判定
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
(暂无)

---
*以下为 ledger,按需查阅*

## Cut
(暂无)

## Decision log
- 2026-07-04 — harness 初始化 — Verdict: 以《元素反应塔防-项目说明.md》为设计与架构基准,MVP 第 5 节直接定为 v1 范围线;实现顺序采用项目说明第 5 节建议顺序切成 7 个 feature。
  Why: 项目说明已完成 Game Designer 层面的工作,无需重复设计;按依赖序(数据层 → 核心逻辑 → 实体 → 表现 → 关卡 → 工具)排队,每个 feature 可独立验收。
- 2026-07-04 — 是否先跑 /arch-guard 建 ARCHITECTURE.md — Verdict: 暂缓(Later 未列,属流程决定)。
  Why: 项目说明第 4 节本身就是架构基准且足够详尽;等实际代码出现结构分歧再引入 arch-guard,避免开局文档过载。
