---
artifact: REVIEW
feature: 04-towers-projectiles
role: Reviewer
status: accepted
updated: 2026-07-05
inputs: [project-context.md, PLAN.md, CHANGES.md, 实际代码(git 工作区全部新增/修改文件), 复跑 headless 全量测试(Godot 4.7 全路径)]
next: Producer
---

# REVIEW — 04-towers-projectiles

## 1. Verdict

**APPROVE**(复审,2026-07-05;首轮 REQUEST CHANGES 的 2 条 must-fix 均已核实真实解决)

复审核实过程(不轻信 `[x]` 标记):
- **must-fix ①**:读 [tower_def.gd:11-15](scripts/defs/tower_def.gd:11) 实际代码 + `git diff`——`attack_range` 注明「格(tile)+ 换算发生点(塔根 `_apply_def` × `Balance.grid.tile_size`)+ 与 EnemyDef.speed(px/s)/02 AoE 半径(px)双轨并存、统一复核挂 06」,`projectile_speed` 注明「格/秒,换算规则同上」;diff 仅 3 行注释,零逻辑改动。Reviewer 自跑 4.7 全路径 `--check-only` 退出码 0。
- **must-fix ②**:CHANGES §3 计数已更正为 94 并注明误记缘由,§4 补申报了首轮遗漏项,§7 完整记录返工。Reviewer 复跑 headless 全量测试:**20 用例 94 方法 0 失败**,退出码 0,0 SCRIPT ERROR(仅 test_instant_effects / test_wave_spawner 两条既有预期 push_warning)——与 CHANGES 数字一致。
- **返工引入新问题扫描**:返工改动面 = tower_def.gd 注释 + CHANGES.md 文档,无代码逻辑变化,全量测试无回归;无新问题。

首轮 Should-fix(projectile.gd 零向量回退、build_grid.gd 缺兜底警告)与 Nits 均为非阻塞,维持原记录不阻塞本 verdict,留给 05/06/07 顺路处理。

代码本体质量很高:D5/D6/D7 三个关键决策落地准确,02/03 契约(`take_damage` / `apply_element` / `ENEMY_GROUP` / `progress` 鸭子读取)逐一比对签名无一错接,测试期望值全部经计算推导不硬编码。

---

以下为首轮审查记录(2026-07-05,verdict 当时为 REQUEST CHANGES),must-fix 已全部 `[x]`:

## 2. Must-fix(blocking)

- [x] `scripts/defs/tower_def.gd:11-12` — **PLAN 04-D2 明文要求「tower_def.gd 注释必须同步改写标明单位」,未执行**(该文件不在本次改动集,`attack_range` / `projectile_speed` 无任何单位标注),且 CHANGES §4 偏差清单未申报此遗漏。为什么阻塞:「距离标尺双轨并存」是 PLAN §5 第一条风险 flag——03 的 `EnemyDef.speed` 与 02 的 AoE 半径是 px,04 塔数值是 tile;TowerDef 是 07 数值校准(CSV ↔ .tres 同步)直接编辑的表面,`attack_range = 2.5` 不标单位极易被当 px 改错,这正是 D2 把注释列为「必须」的原因。修复方向:给两字段加注释标明 tile 单位(格、格/秒,运行时 × `Balance.grid.tile_size` 换算 px),建议顺带提示与 EnemyDef.speed(px)双轨并存、统一复核挂 06;改后 `--check-only` 过一遍。
- [x] `harness/features/04-towers-projectiles/CHANGES.md:63`(§3)— 「20 用例 **84** 方法 0 失败」计数有误:Reviewer 以 4.7 全路径复跑实测为 **20 用例 94 方法 0 失败**(既有 72 + 本功能新增 22 = 94)。CHANGES 是审计线索,数字须更正;同时在 §4 补申报上一条 tower_def.gd 注释项的遗漏与补做。

## 3. Should-fix(non-blocking)

- `scenes/towers/projectile.gd:60` — `remaining == 0`(弹丸恰与目标重合)时 `to_target.normalized()` 得零向量,`hit_direction` 以 `Vector2.ZERO` 传入契约②。当前无实害(03 击退按路径进度回退、忽略 direction),但契约语义上 hit_direction 应为归一化方向;后续任何真消费方向的效果(如带方向的击飞特效)会拿到零向量。可在零向量时回退用弹丸出生方向或 `Vector2.RIGHT`。
- `scripts/systems/build_grid.gd:24-29` — `world_to_cell` / `cell_center` 在 `cfg` 未注入且 Balance autoload 缺失时裸空引用崩溃(`_ready` 自接线静默失败后无任何提示)。可在 `_ready` 兜底失败时 `push_warning`(与 Weapon 缺兄弟节点的处理风格一致)。非阻塞:当前唯一运行时调用方 dev_playground 必有 Balance,headless 测试显式注入。

## 4. Nits

- `scripts/components/weapon.gd:34` — 冷却按物理帧量化:`_cooldown` 减到 0 后剩余量丢弃,60fps 下实际射速略低于 1/fire_interval(每发最多慢一帧)。TD 常规实现,07 校准数值时知道这点即可,不必改。
- `scripts/systems/build_grid.gd:33` — `buildable.has()` 是 O(n) 线性扫;dev 场 153 格无感,06 接真实地图格子多了可换 Dictionary 集合。
- CHANGES §1 说 dev 网格叠加层是「gate 反馈补全」并标注 dev-only,[dev_playground.gd:67-83](scenes/maps/dev_playground.gd:67) 注释确实写清了归属(正式建造 UI 归 05/06)——处理得当,仅提醒 05 做正式 UI 时记得删这段 dev 绘制。

## 5. What I checked but found fine

- **D6 命中结算顺序**(先附着后投伤、死目标整弹丢弃):[projectile.gd:58-66](scenes/towers/projectile.gd:58) 实现正确,`tick` 与 `_hit` 双重 `is_queued_for_deletion` guard;test_projectile 断言组①(反应伤与直伤同帧、gauge 先被消耗)、②(queued 目标 gauge/hp/反应三不动)、④(大步长恰中一次)+ e2e ②(击杀弹反应链路、AoE 波及邻怪、反应归属 = 塔)覆盖到位。
- **D7 弹丸行为**:纯几何判中(位移 ≥ 剩余距离)无 magic 半径;目标 free/queued → 自毁不追尸;自毁后再 tick 不重复命中(tick 首行 guard)。
- **D5 索敌**:[targeting.gd](scripts/components/targeting.gd) 组扫描 + 距离过滤(≤ 含边界)+ progress 最大,跳过 queued 敌人;Weapon 持有目标直到失效/出射程才重索(test_weapon 专门断言「b 的 progress 已更大仍不跳变」)。
- **D2 换算一致性**:tile→px 仅在塔根 `_apply_def` 一处发生(2.5 格 × 64 = 160px),test_tower 断言经 `def × tile_size` 计算而非硬编码;Weapon/Projectile 全程 px,无二次换算。
- **D1/D3 网格底座**:GridConfig 权威在 .tres(类默认 64 注释标明是代码快照,沿 01 先例);Balance.grid 一处权威;BuildGrid 注入式、负坐标 floor 正确(测试覆盖负格往返);claim 只簿记不实例化,与 06 的注入缝一致。
- **D8 数据**:4 塔 .tres 数值全同仅 element 互异,element 引用指向既有 4 元素;test_data_integrity 新增两方法(grid 基准 + 塔完整性含 id/element 唯一性)。
- **D9**:全库 grep 无新增 EventBus 信号;命中链路信号均为 02/03 既有。
- **D10**:dev 摆塔输入、buildable 格生成、网格叠加层全部注释标明 dev-only;预置塔也 claim 占格(一格一塔不变量对 dev 生效)。
- **契约签名比对**:`take_damage(amount, source)`([enemy.gd:62](scenes/enemies/enemy.gd:62))、`apply_element(incoming, amount, source, hit_direction)`([status_component.gd:30](scripts/components/status_component.gd:30))、`ENEMY_GROUP`([reaction_effect.gd:18](scripts/effects/reaction_effect.gd:18))——弹丸/索敌侧调用完全吻合;无同步 `free()` 敌人(铁律)。
- **硬 NO 逐条**:游戏代码无数值字面量(组件字段默认 0 属注入占位;dev 工具数据按 D10 豁免且已注释);无运行时改 .tres;无 match 分支;无计划外重构(03 px 数值一行未动);无 MVP 外系统实现。
- **安全轴**:无外部输入面(dev 按键仅演武场)、无网络/秘密/注入风险;`payload` 字典键位生产/消费两侧一致。
- **过度设计轴**:无多余抽象——BuildGrid 刻意最小(无 release,已挂 06)、Weapon 无状态机(FSM 需求挂 /state-machine-master)、ProjectileSpawner 三行职责,合格。
- **约定轴**:全程静态类型标注;文件 snake_case、类 PascalCase;组件具名直接子节点(02-D7);Resource 均 `class_name`。
- **PLAN 标记对账**:13 步全 `[x]` 与 diff 一一对应(含 CHANGES §4 申报的 4 处合理偏差:test_tower.gd 载体、stub_projectile、tscn 内联时序、e2e 期望值修正);无 `[~]` 搁浅。Phase 1/2 gate = headless 绿(复跑证实);Phase 3/4 人工 F6 gate 已由人执行确认(HANDOFF 2026-07-05 记录,含 dev 网格叠加层补全后复验),无遗留未验项。
- **复跑验证**(非轻信 CHANGES):`Godot_v4.7-stable_win64` 全路径,headless 全量 **20 用例 94 方法 0 失败**,退出码 0,0 SCRIPT ERROR(仅两条既有测试的预期 push_warning)。
