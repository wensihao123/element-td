---
artifact: REVIEW
feature: 03-enemies-waves
role: Reviewer
status: accepted
updated: 2026-07-05
inputs: [PLAN.md, CHANGES.md(含 §7 返工记录), harness/project-context.md, 工作区真实 diff(git diff + 全部新增文件), 亲跑标准三连(首审 + 复审各一轮)]
next: Producer
---

# REVIEW — 03-enemies-waves(复审,首轮 REQUEST CHANGES → 本轮收口)

## 1. Verdict

**APPROVE WITH NITS**

复审通过。首轮 2 条 must-fix 逐条验实(不信记号,读真实代码 + 亲跑测试):终态互斥 guard 与回归测试真实落地,簿记三件全部对齐。返工零副作用——改动面恰好是声称的两处代码 + 三处文档,标准三连亲跑全绿(14 用例 **72** 方法 0 失败,逐案数了方法数)。遗留的 1 条 should-fix 与 3 条 nits 均非阻塞,已转入 HANDOFF flags 携带给后续 feature。03 满足功能完成判据。

## 2. Must-fix(blocking)——全部确认解决

- [x] **簿记与提交面对齐(must-fix ①)**——复审确认三件齐:① CHANGES §5「全局清单」已如实记 autoload `_mcp_game_helper` + `[editor_plugins]` 启用 godot_ai(均标注 dev 工具、非游戏系统,游戏代码不得依赖);② project-context §6 已补约束条(干净 checkout 插件缺失 ERROR 属预期、§5 全绿标准豁免该条,与 project.godot:21/:27-29 现状一致);③ `godot-ai-LICENSE.txt` 裁定随仓库提交(MIT 文本在位,.gitignore 未忽略它、仍忽略 `addons/`,与人裁定一致;commit 动作归人,已在 CHANGES §7 写明)。
- [x] **终点/死亡双终态信号不互斥(must-fix ②)**——复审确认:`enemy.gd:62-64` `take_damage` 首行 `is_queued_for_deletion()` guard 落地(采纳推荐方案,与 `tick` 的 `enemy.gd:81` 既有 guard 对称,注释写明契约意图);回归测试 `test_enemy.gd:205-219` `test_exit_then_lethal_damage_emits_exit_only` 断言到位(到终点后 999 致死伤 → hp 不动、`enemy_died` 0 次、`enemy_reached_exit` 恰 1 次),亲跑 PASSED;CHANGES §5 契约已注明「两终态信号互斥,每敌恰发其一,06 无需去重」。**双向都封死**:先终点后补刀由新 guard 拦,先死亡后 tick 由 `tick` 既有 guard 拦——每敌恰发其一成立。

## 3. Should-fix(non-blocking,遗留携带)

- `scripts/systems/wave_spawner.gd:43` — `start_wave` 对「首条目为 null」的手写坏数据会空引用崩溃,与 `tick` 的 null 条目防御(:55-58)深度不一致。本轮未修(scope 限 must-fix,开工前已向人确认),**转 HANDOFF flag 携带给 06**:手写 10 波 `.tres` 时留意,或届时顺手一行修复(`var first: SpawnEntry = wave.entries[0]` 后判 null 取 0.0)。

## 4. Nits(optional,原样遗留)

- `.gitignore:5` — 文件末尾缺换行符;人 commit 03 变更集时顺手补即可。
- `scenes/enemies/enemy.gd:38` — innate 前置检查含 `status.cfg != null`:Balance 缺失且未注入 cfg 时熔岩犬静默变白板(`apply_innate` 自带 warning 被外层短路)。silent-soft 不好排查,05/06 若踩到再修。
- `harness/archive/02-reaction-core/HANDOFF.md:59-60` — 两条销案注记日期 2026-07-04 与实际完成日 2026-07-05 微不一致(不影响追溯)。

## 5. What I checked but found fine

**复审轮(本轮新验)**
- **返工改动面与声称一致**:代码只动 `enemy.gd`(+guard 3 行 + 契约注释)与 `test_enemy.gd`(+1 回归方法,10→11);文档动 CHANGES §5/§7、project-context §6、HANDOFF。未发现计划外改动混入。
- **guard 无副作用**:`take_damage` 终态拒收语义与 HealthComponent 既有「死后免疫」guard(health_component.gd:19)叠加不冲突——根层拦终态、组件层拦已死,职责清晰;既有 10 个 enemy 测试全数保持绿,e2e 精确数值断言未受扰动。
- **回归测试质量**:用既有 `_spawn`/`_cleanup` 模式与 RecordingBus 注入,前置断言(已排队删除、exit 恰 1 次)+ 三重后置断言(hp 不动、died 0、exit 仍 1),测的正是首轮指出的双记账路径。
- **亲跑三连(不信 CHANGES 口头)**:`--import` exit 0、0 条 ERROR(本机装有插件,豁免条未触发);`enemy.gd`/`test_enemy.gd` `--check-only` 各 exit 0;`run_tests.gd` exit 0,14 用例 72 方法 0 失败(逐案方法数 4+7+3+3+11+3+6+5+4+7+6+1+5+7=72,与 CHANGES §7 声称一致)。
- **HANDOFF/CHANGES 账面**:返工记录 §7 如实(含「未动 should-fix/nits、开工前已向人确认」的 scope 声明);HANDOFF 两条返工 flag 的删除线销案注记与事实相符。

**首审轮(维持有效,详见下)**
- **正确性/契约消费(逐行读了全部新增代码)**:护甲公式与 D3 完全一致(减法 → maxf 0 → damage_taken 后乘,armor 经 resolve 允许负甲);`died` 恰一次 + 死后免疫 + 组件不自 free;击退 = progress 回退 clamp 0、忽略 direction(D2);眩晕查 `resolve(&"stunned", 0.0) > 0.0`、速度经 `resolve(&"speed", def.speed)`;死亡/终点一律 `queue_free`,全代码无同步 `free()`(02 REVIEW 铁律)。
- **innate(D5)**:`apply_innate` 只设 element/gauge + 发 `status_started`,不挂 base_status,`apply_element` 主路径零改动;测试断言「tick 1s 无灼烧伤」。
- **WaveSpawner(D6/D7/D8)**:线性游标 + 累计式计时保证大步长 tick 确定性补吐;`wave_started`/`wave_spawn_finished` 各恰一次;信号名、参数与 D8 完全一致,EventBus 与 RecordingBus 信号面同步。
- **测试真实性**:e2e 断言穿透护甲的精确数值(armor 0/2 两档、毒负甲 +2、冰减速 ×0.7),期望值动态取自 `.tres`,无硬编码;dev 演武场 headless 冒烟 exit 0、五信号日志齐全。
- **PLAN 对账**:§3 全部步骤 `[x]` 与 diff 一一对应,无 `[~]` 搁浅;三个 Phase gate 全过(Phase 3 人工 gate 已由人 2026-07-05 F6 目检确认);§4 偏差三条如实申报且合理;收官回填齐(project-context §2/§3/§6,02 HANDOFF 三条 flag 规范销案)。
- **硬 NO 与约定**:游戏数值全住 `.tres`;跨系统全走 EventBus;无计划外重构;全静态类型、signal 过去式、snake_case;手写 `.tscn` 结构正确(`node_paths` 标记在位)。
- **安全轴**:无用户输入、无秘密、无注入面(资源路径全为常量),不适用项如实记录。
- **过度设计轴**:无——spawner 无 FSM(D7 裁定)、HealthComponent 无多余抽象、`SpawnEntry`/`WaveDef` 字段恰好够用。
