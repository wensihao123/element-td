# BACKLOG

updated: 2026-07-04

## v1 范围线
一句话:**MVP 可玩原型** — 4 基础塔(无分支)+ 6 反应 + Gauge 制、1 张交叉口地图 10 波(含 1 种自带火附着怪)、金币单货币、状态可视化(图标 + gauge 环 + 反应飘字);验证"触发反应爽不爽、看不看得懂"。目标 2–3 周。

## Now(已承诺,按序执行)
1. `03-enemies-waves` — 敌人(Path2D 寻路 + Health/StatusComponent)+ 波次生成器(含自带火附着怪)
   - **02 归档遗留,开工必读**(全文见 `harness/archive/02-reaction-core/HANDOFF.md` 未决 flags):
     ① 必须消费三条契约(project-context §3):`take_damage(amount, source)`、`apply_knockback(distance, direction)`、移动/攻击逻辑查 `resolve(&"stunned", 0.0) > 0.0`;且 `take_damage` **禁止同步 `free()` 敌人**,死亡一律 `queue_free`(AoE 组遍历与 ActiveEffects.tick 都在迭代中投伤,同步释放 = use-after-free;02 REVIEW should-fix);
     ② 纳入 03 PLAN 一步:PropagateEffect handle_sink 一行加固 `neighbor_ctx.erase("handle_sink")`(02 REVIEW should-fix,方案现成,落地后销 archive/02 CHANGES §6 flag);
     ③ HealthComponent 落地后补端到端复核:02 伤害断言未过护甲公式;
     ④ 毒腐蚀 add_flat -2.0 待敌人护甲量表落地后复核(01 遗留)。

## Next(排队,按优先序)
1. `04-towers-projectiles` — 塔场景组合(Targeting/Weapon/ProjectileSpawner)+ 弹丸命中管线
2. `05-status-ui` — 头顶状态图标 + gauge 环形进度条 + 反应飘字/特效占位(支柱 3 的落点)
3. `06-map-waves-economy` — 交叉口地图、10 波配置、金币经济、胜负判定(01 遗留:radius/distance/speed 等 px 数值待地图 tile 尺度落地后复核;02 遗留:ICD 期间异元素「不反应、不附着、不动 gauge」的手感待整局试玩复核,PLAN 02-D8)
4. `07-balance-sim` — headless 平衡仿真 + CSV 报表 + `.tres`↔CSV 同步脚本

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
- 2026-07-04 — 02-reaction-core 归档;REVIEW 3 条 should-fix 分流 — Verdict: ① `.tres.remap` 导出地雷 → Later/v2 导出闸门;② PropagateEffect handle_sink 一行加固 → 纳入 03 PLAN;③ take_damage 禁同步 free → 契约条款回填 project-context §3 并挂 03 开工必读。
  Why: 三条均不影响当前 headless 全绿,不值得为技术债单开 feature;按"就近落地"分流——①只在导出时触雷而 v1 不导出,②方案现成且 03 本就要碰效果测试,③本质是 03 实现约束而非独立工作项。
