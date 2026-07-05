---
artifact: CHANGES
feature: 04-towers-projectiles
role: Implementer
status: draft
updated: 2026-07-05
inputs: [project-context.md, PLAN.md]
next: Reviewer
---

# CHANGES — 04-towers-projectiles

Auto 模式一次跑完 PLAN 四个 Phase(13 步全 `[x]`);Phase 3/4 的 F6 人工 gate 待人执行(见 §3 限制)。

## 1. What changed

**新增(游戏代码)**
- `scripts/defs/grid_config.gd` — `GridConfig` Resource(`tile_size`,类默认 64 为代码快照,权威在 .tres)。
- `data/balance/grid_config.tres` — tile_size = 64.0(04-D1)。
- `scripts/systems/build_grid.gd` — `BuildGrid`:`world_to_cell` / `cell_center` / `can_build` / `claim`,cfg 与 buildable 注入式,占用表 `Dictionary[Vector2i, Node]`(04-D3)。
- `scripts/components/targeting.gd` — `Targeting.acquire`:enemies 组扫描 + 距离过滤 + progress 最大(04-D5);跳过已排队删除的敌人。
- `scripts/components/weapon.gd` — `Weapon`:纯冷却计时(初始 0 即首发)、目标持有直到失效/出射程、经兄弟节点索敌/开火(04-D5)。
- `scripts/components/projectile_spawner.gd` — `ProjectileSpawner.spawn`:实例化 + setup + 挂自身子节点(04-D9)。
- `scenes/towers/tower.gd` + `tower.tscn` — `Tower` 根:三具名子组件 + Visual 占位;`setup(def)` 注入,tile→px 换算分发(04-D2/D4);tscn 内联 projectile.tscn 到 spawner。
- `scenes/towers/projectile.gd` + `projectile.tscn` — `Projectile`:追踪、位移≥剩余距离判中、先附着后投伤、死目标整弹丢弃、目标失效自毁(04-D6/D7)。
- `data/towers/fire_basic.tres` / `ice_basic.tres` / `lightning_basic.tres` / `poison_basic.tres` — 4 塔占位数值统一(04-D8)。

**修改(游戏代码)**
- `scripts/systems/balance.gd` — 增加 `grid: GridConfig` preload(04-D1)。
- `scenes/maps/dev_playground.gd` — 订阅 `reaction_triggered` 打日志(补 03 缺口);预置塔 def 注入;dev 摆塔输入(数字键 1–4 选塔 + 左键放置,04-D10,全部标注 dev-only);dev 网格叠加层 `_draw`(可建格淡绿填充 + 网格线,gate 反馈补全,见 §4)。
- `scenes/maps/dev_playground.tscn` — 预置火塔 `PresetFireTower`(格 (1,1) 心 (96,96))+ `BuildGrid` 节点。

**新增(测试)**
- `test/cases/test_build_grid.gd`(4 方法)、`test_targeting.gd`(4)、`test_weapon.gd`(5)、`test_tower.gd`(1)、`test_projectile.gd`(4)、`test_tower_e2e.gd`(2)。
- `test/support/stub_spawner.gd`、`stub_projectile.gd` — Weapon/Spawner 测试替身。

**修改(测试)**
- `test/cases/test_data_integrity.gd` — 增 `test_grid_config_matches_mvp_baseline` + `test_tower_defs_integrity`。

## 2. Why(映射 PLAN 步骤)

| PLAN 步骤 | 落点 |
|---|---|
| P1-1 GridConfig + Balance.grid | grid_config.gd / grid_config.tres / balance.gd |
| P1-2 BuildGrid | build_grid.gd + test_build_grid.gd |
| P2-1 Targeting | targeting.gd + test_targeting.gd |
| P2-2 Weapon | weapon.gd + stub_spawner.gd + test_weapon.gd(前 4 方法) |
| P2-3 ProjectileSpawner | projectile_spawner.gd + stub_projectile.gd + test_weapon 第 5 方法 |
| P2-4 塔根 | tower.gd / tower.tscn + test_tower.gd |
| P2-5 4 塔 .tres | data/towers/×4 + test_data_integrity 扩展 |
| P3-1 弹丸 | projectile.gd / projectile.tscn |
| P3-2 弹丸测试 | test_projectile.gd(4 断言组齐) |
| P3-3 塔↔敌 e2e | test_tower_e2e.gd + tower.tscn 内联弹丸场景 |
| P3-4 演武场预置塔 | dev_playground 两文件 + reaction_triggered 日志 |
| P4-1 dev 摆塔输入 | dev_playground 两文件(BuildGrid 挂载 + 输入) |
| P4-2 收尾三连 | 见 §3 |

## 3. How I verified it

全程 Godot **4.7-stable** 全路径调用(本 session shell 持旧 PATH 指 4.6.3,已绕开;见 §6 flag)。
- `--import`:退出码 0,日志 0 条 ERROR(每次新增 .gd/.tres/.tscn 后均先跑)。
- `--check-only -s`:18 个新增/改动脚本逐个过,全部退出码 0。
- headless 全量测试:**20 用例 94 方法 0 失败,0 SCRIPT ERROR**(既有 72 方法 + 本功能新增 22 = 94,无回归;首版误记 84,经 Reviewer 复跑指正后更正)。
- headless 跑 dev_playground 场景(≈15s 墙钟):预置火塔自动开火,5 只 runner 全部 enemy_died,熔岩犬(同元素火弹)只充能不反应、带甲漏过——与 Phase 3 gate 预期一致;dev 可建格 153/180(路径带剔除生效);0 SCRIPT ERROR。
- **人工 F6 gate(Phase 3 + Phase 4)已执行通过**(2026-07-05,人目验):首轮反馈"无网格看不出可建格"→ 补 dev 网格叠加层(见 §4)后复验,确认没问题。

## 4. Deviations from the plan

- **新增 `test/cases/test_tower.gd`**:PLAN P2-4 的 Files 未列测试文件,但其 Verify 要求"headless 实例化 + setup 断言",需要载体;沿既有测试规范落一个用例文件。
- **新增 `test/support/stub_projectile.gd`**:P2-3 Verify 要求"替身 scene",支撑脚本是实现该替身的最小方式(沿 RecordingBus/StubEnemy 先例)。
- **tower.tscn 在 P3-3 步补内联 projectile.tscn**:P2-4 建 tscn 时弹丸场景尚不存在(PLAN 自身的时序),Phase 3 弹丸就位后回填——属计划内衔接,非改设计。
- **e2e 期望值修正一次**:AoE 40 对 runner(30 hp)是致死伤,hp 钳 0;首跑断言未钳制而失败,修正为"钳 0 + died 信号"双断言(修 1 次即绿,未触发 2 次上限)。
- **test_weapon._cleanup 修 2 次**:对已 free 实例的带类型循环变量赋值/`is` 判断都会报 SCRIPT ERROR,最终改为 `is_instance_valid` 先行(测试代码问题,非产品代码)。
- **遗漏(首轮未申报,REVIEW must-fix ① 返工补做)**:PLAN 04-D2 明文要求「tower_def.gd 注释必须同步改写标明单位」,首轮实现未执行也未在本节申报——`attack_range` / `projectile_speed` 当时无任何单位标注。返工已补:两字段注明 tile 单位(格、格/秒,运行时由塔根 `_apply_def` × `Balance.grid.tile_size` 换算 px),并提示与 EnemyDef.speed(px/s)、02 AoE 半径(px)双轨并存、统一复核挂 06。
- **gate 反馈补全:dev 网格叠加层**(PLAN 未列):人执行 Phase 4 gate 时反馈"场地没有网格,不知道可以放哪",gate 无法目验——在 dev_playground 加 `_draw` 画可建格淡绿填充 + 细网格线,标注 dev-only。属 D10 dev 工具可用性补全,不是 05/06 的正式建造 UI(射程预览/放置光标仍未做)。验证:check-only 0、headless 场景 0 SCRIPT ERROR、全量 20 用例 0 失败无回归。

## 5. Wiring Contract

> 04 全部场景由 `.tscn` 文本直写完成接线(HANDOFF 已裁定不走 Integrator);本节供 Reviewer 与后续 feature(05/06)消费。

- **`tower.tscn`(根脚本 `tower.gd`,Node2D)——已装配完毕,即取即用**
  - 生成方式:`instantiate()` → `setup(def: TowerDef)` → `add_child` → 置 `global_position`(建造流程另需 BuildGrid.claim)。
  - 依赖 autoload:`Balance`(取 `grid`/`config`;测试可注入 `grid_cfg`/`gauge_cfg` 字段绕开)。
  - 子节点 `ProjectileSpawner.projectile_scene: PackedScene` 已在 tscn 里指向 `projectile.tscn`,无需再赋值。
  - 无对外信号;反应/死亡信号由命中链路经 EventBus 发出(02/03 既有五信号,04 未新增)。
- **`projectile.tscn`(根脚本 `projectile.gd`,Node2D)**——只应由 `ProjectileSpawner.spawn` 生成;`setup(target, speed_px, damage, element, attach_amount, source)`,source 必须是塔根(反应归属 + 出生位置)。
- **`BuildGrid`(纯 Node,非 autoload)**——挂场景后注入 `buildable: Array[Vector2i]`(06:TileMap 建造格 → 集合);`cfg` 空则 `_ready` 自接 `Balance.grid`。`claim` 只记账不实例化;无 release(售塔时再扩展)。
- **组件脚本(`Targeting`/`Weapon`/`ProjectileSpawner`)**——须作为塔根**具名直接子节点**(名字 = 类名);Weapon 依赖兄弟节点按名发现,单独复用时需保持该结构。
- **敌人侧消费的既有契约**(未改动):`&"enemies"` 组、`take_damage(amount, source)`、`StatusComponent.apply_element(element, amount, source, hit_direction)`、`progress` 字段(鸭子读取)。
- **输入**:04 未新增 Input Map action(dev 摆塔用原始 keycode/鼠标事件,仅存在于 dev_playground)。

## 6. Flags / Open questions

- **shell PATH 仍指 4.6.3**(project-context §1 已知坑的本 session 实证):`where godot` → `G:\Godot\Godot_v4.6.3\`。本 session 全程用 4.7 全路径绕开;人重启终端前,任何直接敲 `godot` 的验证都会跑在 4.6.3 上,建议尽快清 PATH。
- 占位数值观感(headless 侧数据点,供 07):runner 被 4 发点杀(5-0 甲),lava_hound 需 20 发(5-2 甲)、火塔单塔射程内打不死会漏过——gate 只验管线,不算失败,如实记录。
- 弹丸不换目标(D7)的空弹浪费:headless e2e 未见异常;肉眼观感待 F6 gate,明显糟再记 flag 给 06/07。
- PLAN §5 既有 flags(距离标尺双轨、Weapon 无 FSM、cost_gold 不消费等)无新增变化,不复述。

## 7. Rework(首轮 REVIEW REQUEST CHANGES 返工,2026-07-05)

按 REVIEW.md must-fix 逐条处理,全部 `[x]`:

- **must-fix ①(tower_def.gd 单位注释)**:`scripts/defs/tower_def.gd` 为 `attack_range` / `projectile_speed` 补注释——标明 tile 单位(格、格/秒)、换算发生点(塔根 `_apply_def` × `Balance.grid.tile_size`,一处权威)、与 EnemyDef.speed(px/s)/02 AoE 半径(px)双轨并存提示及统一复核挂 06。纯注释改动,无逻辑变化。
  - 验证:4.7 全路径 `--check-only -s res://scripts/defs/tower_def.gd` 退出码 0。
- **must-fix ②(CHANGES 记录更正)**:§3 测试计数 84→94(既有 72 + 新增 22);§4 补申报首轮遗漏 tower_def.gd 注释项及其返工补做。
  - 验证:4.7 全路径复跑 headless 全量测试——**20 用例 94 方法 0 失败**,退出码 0,0 SCRIPT ERROR(仅 test_wave_spawner 既有预期 push_warning),与 Reviewer 复跑数字一致。
