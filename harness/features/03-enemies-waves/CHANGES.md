---
artifact: CHANGES
feature: 03-enemies-waves
role: Implementer
status: draft
updated: 2026-07-05
inputs: [PLAN.md, harness/project-context.md, harness/archive/02-reaction-core/HANDOFF.md]
next: Reviewer
---

# CHANGES — 03-enemies-waves(敌人实体 + 波次生成器)

执行模式:Auto(人授权),全 PLAN 3 Phase 9 步一次跑完,PLAN.md 步骤全 `[x]`。

## 1. What changed

**游戏代码(新增)**
- `scripts/components/health_component.gd` — 血量 + 护甲结算组件(减法护甲、负甲增伤、脆化后乘、died 恰一次、死后免疫、无栈 fail-soft)。
- `scenes/enemies/enemy.gd` — 敌人实体根 `class_name Enemy`(setup 注入 def/path、鸭子方法转发、路径移动 tick、击退=进度回退、终点/死亡走 EventBus + queue_free、innate 附着、占位视觉染色)。
- `scenes/enemies/enemy.tscn` — 通用敌人场景(Node2D 根 + 四具名子组件 + Polygon2D 16px 占位)。
- `scripts/defs/spawn_entry.gd`、`scripts/defs/wave_def.gd` — 波次数据 Resource 类。
- `scripts/systems/wave_spawner.gd` — 单波生成器 `class_name WaveSpawner`(线性游标 + 倒计时,无 FSM)。
- `scenes/maps/dev_playground.gd`、`scenes/maps/dev_playground.tscn` — dev 演武场(S 形 Path2D + WaveSpawner + Camera2D,自动播 dev_wave,五信号 print)。
- `data/enemies/runner.tres`(hp 30/speed 60/armor 0/gold 5)、`data/enemies/lava_hound.tres`(hp 60/speed 45/armor 2/gold 10/innate=fire)、`data/waves/dev_wave.tres`(runner ×5 @1s;delay 3s 后 lava_hound ×2 @2s)——全占位量表。

**游戏代码(修改)**
- `scripts/effects/propagate_effect.gd` — 传播浅拷贝 ctx 后 `erase("handle_sink")`(02 flag ② 加固)。
- `scripts/components/status_component.gd` — 新增 `apply_innate(element, amount)`,apply_element 主路径零改动。
- `scripts/systems/event_bus.gd` — 新增 5 信号(enemy_spawned / enemy_died / enemy_reached_exit / wave_started / wave_spawn_finished)。

**测试**
- `test/cases/test_health_component.gd`(新,6 方法)、`test/cases/test_enemy.gd`(新,10 方法)、`test/cases/test_enemy_e2e.gd`(新,3 方法)、`test/cases/test_wave_spawner.gd`(新,7 方法)。
- `test/support/recording_bus.gd` — 信号面随 EventBus 同步扩充(+5 信号与记录数组)。
- `test/cases/test_instant_effects.gd`(+1 handle_sink 回归)、`test/cases/test_defs.gd`(+1 波次类默认值)、`test/cases/test_data_integrity.gd`(+3:敌人量表/lava_hound innate/dev_wave 完整性)。

**harness 簿记**
- `harness/archive/02-reaction-core/HANDOFF.md` — 销案 flag ②(handle_sink)、flag ③(伤害过护甲复核);flag ④ 注记转「待校准」。
- `harness/project-context.md` — §2 目录注记(scenes 实体脚本落位、data/waves/)、§3 新增 03 契约条、§6 新增两坑(node_paths、headless 模拟时长)。

## 2. Why(映射 PLAN 步骤)

| PLAN 步骤 | 落点 |
|---|---|
| P1S1 handle_sink 加固 | propagate_effect.gd + test_instant_effects 回归 + 02 销案 |
| P1S2 HealthComponent | health_component.gd + test_health_component |
| P1S3 敌人根 + 场景 + 信号 | enemy.gd/.tscn + status_component.apply_innate + event_bus + recording_bus + test_enemy(前 5 方法) |
| P1S4 路径移动 + 契约消费 + 终点 | enemy.gd 的 tick/_snap_to_path/apply_knockback + test_enemy(后 5 方法) |
| P1S5 端到端复核 | test_enemy_e2e + 02 flag ③ 销案 |
| P2S1 波次 Resource 类 | spawn_entry.gd / wave_def.gd + test_defs 扩展(+ EventBus 波次 2 信号,见 §4 偏差) |
| P2S2 数据 .tres | runner / lava_hound / dev_wave + test_data_integrity 扩展 |
| P2S3 WaveSpawner | wave_spawner.gd + test_wave_spawner |
| P3S1 dev 演武场 + 收官 | dev_playground.gd/.tscn + project-context 回填 + 本文件 + HANDOFF |

## 3. How I verified it

- 标准三连(project-context §5)逐步执行,最终态:`--import` exit 0 无 ERROR;`--check-only -s` 全部改动脚本 exit 0;`run_tests.gd` exit 0,**14 用例 71 方法 0 失败**(02 基线 10 用例全数保持绿)。
- e2e 固化的精确数值:蒸汽爆破 AoE 40 → armor 0 剩 60.0 / armor 2 剩 62.0;毒附着(腐蚀 -2)armor 0 怪同额 10 伤扣 12 vs 对照 10(负甲增伤 +2 数据点);冰附着 tick 1s 前进 7.0(-30%)。
- dev 演武场 headless 冒烟(PLAN 指定命令,`--quit-after 2000`):exit 0、无 ERROR,日志含 wave_started、7 条 enemy_spawned(熔岩犬带 innate 火 gauge 2.0)、wave_spawn_finished。
- 追加诊断(`--quit-after 6000`,约 30+ 秒模拟):5 runner + 2 lava_hound 全部 `enemy_reached_exit`,完整移动管线在真实场景走通。
- **Phase 3 人工 playtest gate:已通过**(2026-07-05 人工 F6 目检)——整波生成,白色 runner 与橙色熔岩犬肉眼可辨,沿路径走到尽头消失,控制台日志对应齐全。(Auto 模式下 headless 先验了信号时序、出生点、走完全程,人工目检补上观感确认。)

## 4. Deviations from the plan

- **D8 五信号分两批落地**:`wave_started` / `wave_spawn_finished` 参数类型为 `WaveDef`,该类 P2S1 才存在,提前声明会编译失败;敌人 3 条随 P1S3、波次 2 条随 P2S1。最终信号面与 D8 完全一致。
- **spawner 测试的 tick 分割值取二进制精确数**(0.25/0.5/0.75/1.5):首版用 1.9+0.1 因浮点残差(2.0-1.9-0.1 ≈ 9e-17 > 0)差一帧,属测试构造问题非生成器逻辑错;生成器代码未为此加 epsilon。
- **dev_playground.tscn 手写踩坑修复**:WaveSpawner 节点头补 `node_paths=PackedStringArray("path")`,否则 Node 类型 export 静默 null(已回填 project-context §6)。

## 5. Wiring Contract

本 feature 场景全部 `.tscn` 文本直写,**无需编辑器手工接线**;以下为 04/05/06 消费与复用契约。

- **`scenes/enemies/enemy.gd`(`class_name Enemy`)→ 已附于 `enemy.tscn` 根(Node2D)**
  - 不手工摆放:由 `WaveSpawner` 实例化;若脚本化生成,须在 `add_child` **前**调 `setup(def: EnemyDef, path: Path2D)`。
  - 无 `@export`;运行时字段:`def`(数据)、`path`(寻路)、`bus`(总线,空则 `_ready` 自接 `/root/EventBus`)。
  - 需要 autoload:`Balance`(取 GaugeConfig)、`ReactionSystem`、`EventBus`——均空字段自接线,测试可注入替身。
  - 入组 `&"enemies"`(`ReactionEffect.ENEMY_GROUP`,_init 时);02 空间查询/伤害投递按组扫描,**无碰撞体、无 collision layer**。
  - 鸭子契约(02-D10 消费方):`take_damage(amount, source)` 经 HealthComponent 结算真血;`apply_knockback(distance, direction)` = 路径进度回退 clamp 0(忽略 direction)。
  - 经 EventBus 发:`enemy_died(enemy, def)`(死亡,gold_reward 由 06 从 def 读)、`enemy_reached_exit(enemy, def)`(漏怪,基地扣血归 06);两者均 `queue_free` 自毁,订阅方**不得缓存 enemy 引用跨帧使用**。**两终态信号互斥,每敌恰发其一**:`take_damage` 首行 `is_queued_for_deletion()` guard 拒收终态后伤害,同帧 AoE/DoT 补刀不会 exit + died 双发,06 无需去重(REVIEW must-fix ② 落地,回归测试 `test_exit_then_lethal_damage_emits_exit_only` 固化)。
  - 四具名直接子组件:`StatusComponent` / `ModifierStack` / `ActiveEffects` / `HealthComponent`(02-D7 约定,effects/05 按名寻址)。
- **`scripts/systems/wave_spawner.gd`(`class_name WaveSpawner`)→ 附于普通 Node,非 autoload**
  - `@export var enemy_scene: PackedScene` ← 赋 `res://scenes/enemies/enemy.tscn`。
  - `@export var path: Path2D` ← 赋场景中的 Path2D;**手写 .tscn 必须在节点头加 `node_paths=PackedStringArray("path")`**。
  - `bus` 空字段自接 `/root/EventBus`(测试注入 RecordingBus)。
  - API:`start_wave(wave: WaveDef)`(06 关卡流程调用;进行中重复调用忽略 + warning;吐完可复用播下一波);`_physics_process` 自驱,headless 可手动 `tick(delta)`。
  - 经 EventBus 发:`wave_started(wave)`(首只前)、`enemy_spawned(enemy)`(逐只)、`wave_spawn_finished(wave)`(**生成完毕≠清波**,清波判定归 06 组计数)。
  - 生成的敌人挂在 spawner 节点下。
- **`scenes/maps/dev_playground.tscn`** — F6 即跑,零接线;仅开发验证,正式地图归 06。
- **全局清单**:新 autoload `_mcp_game_helper`(`res://addons/godot_ai/runtime/game_helper.gd`,godot-ai 本机 dev 工具,**非游戏系统**,游戏代码不得依赖);`[editor_plugins]` 启用 `godot_ai`(同为 dev 工具;`addons/` 不入库,人裁定 2026-07-05,详见 REVIEW must-fix ① 与 project-context §6)。游戏系统层面:无新 autoload、无新 input action、无新 collision layer;新目录 `data/waves/`;新组无(沿用 `&"enemies"`)。

## 6. Flags / Open questions

- ~~**Phase 3 人工 gate 待跑**(Auto 限制)~~ 已通过(2026-07-05 人工目检,详见 §3)——**03 验收面完成**。
- **负甲增伤数据点已固化**(承 01/02 flag ④,转「待校准」):armor 0 怪吃毒后同额伤害 +2;对 DoT 每 0.5s 一跳即每跳 +2,数值观感归 07/num-smith 统一校准。
- **敌人量表与 dev_wave 节奏全占位**(hp/speed/armor/gold、S 形曲线 px 尺度),07 校准、06 地图尺度复核(承 PLAN §5)。
- **innate 一次性附着**:耗尽(约 2 次反应)变白板、再被火塔附着会正常挂灼烧——PLAN D5 已裁定接受,05/06 手感复核(原样传递)。
- headless 场景验证注意:`--quit-after 2000` ≈ 10 秒出头模拟时长,长流程验证需加大迭代(已回填 project-context §6)。

---

## 7. 返工记录(2026-07-05,REVIEW 首轮 REQUEST CHANGES)

只针对 REVIEW §2 两条 must-fix,未动 should-fix/nits(非阻塞,scope 外;开工前已向人确认)。

### Must-fix ①:提交面簿记对齐(纯文档,方向由人裁定)
- 本文件 §5「全局清单」改为如实记:新 autoload `_mcp_game_helper` + `[editor_plugins]` 启用 `godot_ai`(均为 dev 工具,非游戏系统)。
- `harness/project-context.md` §6 新增一条:godot-ai 为本机 dev 工具、`addons/` 有意不入库;**无插件的干净 checkout 首启/`--import` 报一条插件脚本缺失 ERROR 属预期**,§5 全绿标准豁免该条;游戏代码禁止依赖 `_mcp_game_helper`。
- `godot-ai-LICENSE.txt` 处置:**随仓库提交留档**(采纳 Reviewer 建议,与插件配置入库配套;不加 .gitignore)。文件随 03 变更集一并 commit——commit 动作归人(本 session 未授权提交)。

### Must-fix ②:终点/死亡双终态信号互斥
- `scenes/enemies/enemy.gd` — `take_damage` 首行加 `if is_queued_for_deletion(): return`(Reviewer 推荐方案,与 `tick` 既有 guard 对称):终态(到达终点或已死亡)后整体拒收伤害,died 无从触发。
- `test/cases/test_enemy.gd` — 新增回归 `test_exit_then_lethal_damage_emits_exit_only`(10→11 方法):到终点后同帧吃 999 致死伤,断言 hp 不动、`enemy_died` 0 次、`enemy_reached_exit` 保持恰 1 次。
- 本文件 §5 契约同步注明:**两终态信号互斥,每敌恰发其一**,06 无需去重。

### 返工验证(标准三连,全绿)
- `--import` exit 0,日志 0 条 ERROR(本机装有插件,无豁免条触发)。
- `--check-only -s`:`enemy.gd`、`test_enemy.gd` 均 exit 0。
- `run_tests.gd` exit 0:**14 用例 72 方法 0 失败**(首轮 71 + 新回归 1;02/03 既有用例全数保持绿)。
