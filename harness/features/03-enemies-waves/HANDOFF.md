---
feature: 03-enemies-waves
status: done
updated: 2026-07-05
---
# HANDOFF — 03-enemies-waves(敌人实体 + 波次生成器)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。
>
> 读取顺序:**「管线状态」+「下一步」是必读状态**;「决策记录」「未决 flags」是参考/账本,
> 需要追溯才往下看。功能 `done` 后,整目录(含本文件)挪进 `harness/archive/`。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | [x] 不需要——由《元素反应塔防-项目说明.md》§3.2/§5 承担(沿 01/02 先例,PLAN §4) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | [x] 不需要——Planner 制订计划时已全量通读 01/02 产物与实测接口(PLAN §2/§4) |
| 计划 | Planner | PLAN.md | [x] |
| 实现 | Implementer | CHANGES.md | [x] 返工完成(2026-07-05):REVIEW 2 条 must-fix 全 `[x]`——①簿记对齐三件(CHANGES §5 如实记 autoload/插件、project-context §6 补约束、LICENSE 定随仓库提交)②take_damage 终态 guard + 回归测试 + 契约注互斥;三连全绿 14 用例 72 方法 0 失败,详见 CHANGES §7 |
| 审查 | Reviewer | REVIEW.md | [x] 复审 **APPROVE WITH NITS**(2026-07-05):2 条 must-fix 逐条验实(guard+回归测试真实落地、簿记三件对齐),亲跑三连全绿 14 用例 72 方法 0 失败;1 条 should-fix + 3 条 nits 非阻塞遗留,转 flags 携带 |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | [x] 不需要——占位方块 + 既有 element color,零新资产;正式可视化归 05(PLAN §4) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | [x] 不需要——场景全部 .tscn 文本由 Implementer 直写,无编辑器手工步骤;Phase 3 人工 playtest gate 属验收非接线(PLAN §4) |

> 状态记号(与 PLAN 步骤、REVIEW must-fix 同一套,全 harness 一致):
> `[ ]` 未开始 · `[~]` 进行中(含产出 draft、含被打回返工中) · `[x]` 完成或确认不需要(此阶段已了结)。
> Implementer 跑分阶段 PLAN 时可在「实现」行后缀阶段进度,如 `[~] phase 2/3`
> (细到步骤看 PLAN.md 的 `[~]/[x]`)。
> 阻塞不是第四种状态:阶段留在 `[~]`,把阻塞项写进下面「未决 flags」。

## 验收回环(三处人机来回 · 写死,严格照走)
> 1. **实现 ↔ 审查**:Implementer 完工 → 实现 `[x]`、审查 `[ ]`、开 Reviewer。Reviewer 出 REVIEW.md:
>    APPROVE / APPROVE WITH NITS → 审查 `[x]`;REQUEST CHANGES → 审查 `[~]`、实现退回 `[~]`,
>    must-fix 每条带记号当返工单,Implementer **只针对 must-fix** 逐条改完 → 实现 `[x]`、回 Reviewer 复审。
> 2. **美术 ↔ 人**:本 feature 不需要。
> 3. **接线 ↔ 人**:本 feature 不需要(但 PLAN Phase 3 有一个**人工 playtest gate**:
>    编辑器 F6 跑 `dev_playground.tscn` 按 gate 清单目检——属实现阶段验收动作,由人执行后把结果告知 Implementer/Reviewer)。

## 功能完成判据(写死)
> 所有**需要的**阶段都 `[x]`,且审查 verdict 非 REQUEST CHANGES。
> 本 feature 需要的阶段 = 计划、实现、审查(其余已裁定不需要)。
> 满足时:完成最后一个必需阶段的那个 role 把 frontmatter `status` 翻 `done`,
> 「下一步」写「功能完成 → Producer 归档 + 记 Shipped」。归档动作由 Producer 做。

## 下一步
**功能完成 → Producer 归档 + 记 Shipped**:开 `/role-producer 03-enemies-waves`,把本目录挪进 `harness/archive/`、BACKLOG 记 Shipped、遗留 flags 按去向挂账(should-fix 挂 06)。另:03 变更集尚未 commit(含 `godot-ai-LICENSE.txt`,人裁定随仓库提交),commit 动作归人。

## 决策记录(账本·按需读)
- 2026-07-04 设计/勘探/美术/接线四个可选阶段裁定不走(来源:PLAN §4,Planner)。
- 2026-07-04 关键技术决策 03-D1~D10 见 PLAN §2:自持 path+progress 移动(D1)、击退=progress 回退(D2)、减法护甲公式+负甲增伤(D3)、HealthComponent 第四具名子节点+根转发鸭子方法(D4)、innate 附着不挂 base_status(D5)、WaveDef/SpawnEntry+data/waves/(D6)、spawner 非 autoload 无 FSM(D7)、EventBus 五新信号+wave_spawn_finished 语义(D8)、通用 enemy.tscn 数据驱动+占位染色(D9)、脚本落位 scenes/enemies/ 与 scripts/systems/(D10)。
- 2026-07-04 设计空白裁定(Planner,较重要):自带火怪若走既有 apply_element 会被自身灼烧 DoT 永续烧死(衰减为 0),故 innate 语义定为「元素在身可反应、不吃自身基础状态」;元素免疫系统明确留给 v2(PLAN D5 + §5 flag)。
- 2026-07-05 人裁定(审查回合,REVIEW must-fix ①):godot-ai 插件走「配置入库、代码不入库」——project.godot 两段插件配置(`_mcp_game_helper` autoload + editor_plugins)随仓库提交,`addons/` 保持 .gitignore 忽略(人手动所加、有意);无插件的干净 checkout 首启有一条已知插件加载报错,属预期,文档化归 must-fix ① 返工。

## 未决 flags
- ~~(03 审查新增,REVIEW must-fix ①)**godot-ai 插件配置与簿记不一致**~~ 已返工并经复审终销(2026-07-05):CHANGES §5 如实记 autoload/editor_plugins、project-context §6 补「干净 checkout 插件报错属预期」约束、LICENSE 裁定随仓库提交(CHANGES §7;Reviewer 复审验实,REVIEW §2)。
- ~~(03 审查新增,REVIEW must-fix ②)**enemy 终点/死亡双终态信号不互斥**~~ 已返工并经复审终销(2026-07-05):`take_damage` 首行 `is_queued_for_deletion()` guard + 回归测试 `test_exit_then_lethal_damage_emits_exit_only` + CHANGES §5 契约注明「互斥,每敌恰发其一」(CHANGES §7;Reviewer 复审验实含双向互斥,REVIEW §2)。
- (03 复审遗留,REVIEW §3 should-fix,非阻塞)`wave_spawner.gd:43` `start_wave` 对「首条目 null」的手写坏数据会空引用崩溃(tick 侧有防御、start_wave 侧没有)——**06 手写 10 波 `.tres` 时留意**,或届时顺手一行修复;3 条 nits(.gitignore 末行换行、innate cfg 缺失静默白板、02 归档日期微差)见 REVIEW §4,随手可校不阻塞。
- ~~(03 实现新增)**Phase 3 人工 playtest gate 待跑**(Auto 模式限制)——headless 能验的(信号时序/出生点/走完全程)已全绿,gate 过 = 03 验收面完成。~~ 已销案:2026-07-05 人工 F6 目检通过——整波生成、白色 runner 与橙色熔岩犬肉眼可辨、沿路径走到终点消失、控制台日志对应齐全。**03 验收面完成。**
- ~~(承 02 flag ②,PLAN Phase 1 Step 1 消化)PropagateEffect handle_sink 加固——落地后销 archive/02 HANDOFF 对应条。~~ 已落地销案(2026-07-05,含回归测试)。
- ~~(承 02 flag ③,PLAN Phase 1 Step 5 消化)真敌人过护甲公式的端到端伤害复核——落地后销 archive/02 HANDOFF 对应条。~~ 已落地销案(2026-07-05,test_enemy_e2e 固化 armor 0/2 两档精确数值)。
- (承 01/02 flag ④,已固化数据点转「待校准」)毒腐蚀 -2 在 armor 0 怪上 = 同额伤害 +2/次(DoT 每 0.5s 跳即每跳 +2,e2e 已断言)——校准归 07/num-smith。
- (03 新增,PLAN D5)innate 一次性附着、耗尽变白板:教学持续性待 05/06 手感复核;innate 耗尽后再被火塔附着会正常挂灼烧(后天附着语义),接受并观察。
- (03 新增,PLAN D8)`wave_spawn_finished` = 生成完毕非清波;清波判定归 06,若需 spawner 托管波内状态,先过 /state-machine-master。
- (03 新增,PLAN §5)敌人量表(hp/speed/armor/gold)与 dev_wave 节奏全占位,07 校准;px 尺度待 06 地图复核(承 01)。
