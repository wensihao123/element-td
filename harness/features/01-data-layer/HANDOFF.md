---
feature: 01-data-layer
status: done
updated: 2026-07-04
---
# HANDOFF — 01-data-layer(数据层骨架)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。
>
> 读取顺序:**「管线状态」+「下一步」是必读状态**;「决策记录」「未决 flags」是参考/账本,
> 需要追溯才往下看。功能 `done` 后,整目录(含本文件)挪进 `harness/archive/`。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | [x] 不需要——由《元素反应塔防-项目说明.md》承担(BACKLOG 2026-07-04 决策) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | [x] 不需要——全新空仓,无既有代码可勘探 |
| 计划 | Planner | PLAN.md | [x] |
| 实现 | Implementer | CHANGES.md | [x] |
| 审查 | Reviewer | REVIEW.md | [x] APPROVE WITH NITS(2026-07-04,无 must-fix) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | [x] 不需要——纯数据层,无资产需求 |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | [x] 不需要——.tres 全部手写文本 + headless 验证(PLAN D6) |

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
> 3. **接线 ↔ 人**:本 feature 不需要。

## 功能完成判据(写死)
> 所有**需要的**阶段都 `[x]`,且审查 verdict 非 REQUEST CHANGES。
> 本 feature 需要的阶段 = 计划、实现、审查(其余已裁定不需要)。
> 满足时:完成最后一个必需阶段的那个 role 把 frontmatter `status` 翻 `done`,
> 「下一步」写「功能完成 → Producer 归档 + 记 Shipped」。归档动作由 Producer 做。

## 下一步
功能完成 → Producer 归档 + 记 Shipped:`/role-producer 01-data-layer`(切换前先 /clear)。
(全部产物已随 commit 1c7ca73 入库,2026-07-04。)

## 决策记录(账本·按需读)
- 2026-07-04 设计/勘探/美术/接线四个可选阶段裁定不走(来源:PLAN.md §4,Planner)。
- 2026-07-04 effects/ 积木类(参数壳)纳入本 feature,apply() 逻辑归 02(PLAN D1)。
- 2026-07-04 defs 零 autoload 依赖,get_attach/get_cost 显式传 GaugeConfig(PLAN D2)。
- 2026-07-04 自研微型测试跑道(run_tests.gd + TestCase),不引 GUT(PLAN D3)。
- 2026-07-04 元素基础状态复用 ReactionEffect 积木,ElementDef 不开专属数值字段(PLAN D4)。
- 2026-07-04 项目说明未指定的效果数值由 PLAN D8 占位表裁定,07-balance-sim 前均为占位。

## 未决 flags
- base_status 复用 ReactionEffect 的持续型语义待 02-reaction-core 确认(只许调类接口,不动数据布局)。
- 毒腐蚀 add_flat -2.0 待 03 敌人护甲量表落地后复核。
- radius/distance/speed 等 px 数值待 06 地图 tile 尺度落地后复核。
- (可选)若要先建 BALANCE.md 数值框架,可在 02 之前跑 /num-smith;Planner 建议不阻塞。
- `-s` 模式下 autoload 是否实例化未验证(现有测试不依赖它);02 落地 ReactionSystem 时验证并回填 project-context §6(来源:CHANGES §6,Implementer)。
- 编辑器 Inspector 抽查(资源类型可见、steam_burst 数值正确)Auto 模式未做;Reviewer 已用 headless 载入 + 数值断言等价覆盖,人工抽查仍可选(来源:CHANGES §3 / REVIEW §5)。
- effect SubResource 经 load() 后为共享实例:02 实现 apply() 必须无状态,运行时状态住 StatusComponent/ModifierStack,不得写 effect 自身字段(来源:REVIEW Should-fix)。
- 测试跑道对"test_ 方法运行时崩溃且零断言"会误报 PASSED;02 写逻辑测试前建议加断言计数防线(来源:REVIEW Should-fix)。
