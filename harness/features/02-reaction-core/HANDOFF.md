---
feature: 02-reaction-core
status: done
updated: 2026-07-04
---
# HANDOFF — 02-reaction-core(反应核心运行时)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。
>
> 读取顺序:**「管线状态」+「下一步」是必读状态**;「决策记录」「未决 flags」是参考/账本,
> 需要追溯才往下看。功能 `done` 后,整目录(含本文件)挪进 `harness/archive/`。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | [x] 不需要——由《元素反应塔防-项目说明.md》§2/§4 承担(BACKLOG 2026-07-04 决策,沿 01 先例) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | [x] 不需要——代码面仅 01 产物,Planner 制订计划时已全量通读(PLAN §4) |
| 计划 | Planner | PLAN.md | [x] |
| 实现 | Implementer | CHANGES.md | [x] |
| 审查 | Reviewer | REVIEW.md | [x] APPROVE WITH NITS(0 must-fix;3 should-fix + 3 nits 见 REVIEW.md;headless 全绿由 Reviewer 亲测复现) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | [x] 不需要——纯逻辑零资产,可视化归 05-status-ui(PLAN §4) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | [x] 不需要——autoload 注册即 project.godot 文本改动,headless 验证(PLAN §4) |

> 状态记号(与 PLAN 步骤、REVIEW must-fix 同一套,全 harness 一致):
> `[ ]` 未开始 · `[~]` 进行中(含产出 draft、含被打回返工中) · `[x]` 完成或确认不需要(此阶段已了结)。
> Implementer 跑分阶段 PLAN 时可在「实现」行后缀阶段进度,如 `[~] phase 2/4`
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
**功能完成 → Producer 归档 + 记 Shipped**:`/role-producer 02-reaction-core`。审查 verdict = APPROVE WITH NITS(2026-07-04),必需三阶段(计划/实现/审查)全 `[x]`,满足功能完成判据。Producer 归档时请处置:① REVIEW.md 3 条 should-fix(导出包 `.tres.remap` 地雷 / Propagate handle_sink 一行加固 / Wiring Contract 补 take_damage 禁同步 free)——转 BACKLOG 或排给后续 feature;② 人工确认项:编辑器开项目无报错 + autoload 面板见 Balance/EventBus/ReactionSystem 三条(headless 无法替代,10 秒即验)。

## 决策记录(账本·按需读)
- 2026-07-04 设计/勘探/美术/接线四个可选阶段裁定不走(来源:PLAN §4,Planner)。
- 2026-07-04 实现期实测(Implementer):`-s` 模式 autoload **已加载**(01 flag ③ 结论,探针保留);`_initialize` 阶段 root 未入树 → run_tests.gd 测试体改首帧执行(坑已回填 project-context §6)。
- 2026-07-04 关键技术决策 D1–D10 见 PLAN §2:系统可注入 autoload 仅接线(D1)、反应表目录扫描(D2)、效果享元 + ActiveEffects 承载运行时状态(D3)、持续数值/眩晕统一走 ModifierStack(D4)、base_status 生命周期归 StatusComponent(D5)、空间查询 = enemies 组扫描(D6)、组件具名子节点约定(D7)、ICD 期间异元素吞附着(D8)、try_react 定序(D9)、伤害/击退鸭子契约(D10)。

## 未决 flags
- (02 审查新增,REVIEW should-fix)`reaction_system.gd:24` DirAccess 扫描 `.tres` 在导出 PCK 后落空(文件名变 `*.tres.remap`)→ 导出版反应表**静默为空**;首次导出前必须修(剥 `.remap` 后缀或改显式清单)。
- (02 审查新增,REVIEW should-fix)Wiring Contract 需补:03 的 `take_damage` 禁止同步 `free()` 敌人(死亡走 `queue_free`)——AoE 组员遍历与 ActiveEffects.tick 都在迭代中投伤,同步释放 = use-after-free。
- ICD 期间异元素命中裁定为「不反应、不附着、不动 gauge」(PLAN D8,设计文档未明说)——已按此实现,待 05/06 手感复核。
- 三条契约须由 03/04 落地消费:`take_damage(amount, source)` / `apply_knockback(distance, direction)` / `resolve(&"stunned", 0.0) > 0.0`——已写进 CHANGES §5 Wiring Contract 与 project-context §3。
- 02 伤害断言未过护甲公式(HealthComponent 归 03);03 落地后补一条端到端复核。
- (02 新增)PropagateEffect 浅拷贝 ctx ⇒ handle_sink 被邻居共享;当前无实害(base_status 无传播)。REVIEW should-fix 给出一行拆雷方案(`neighbor_ctx.erase("handle_sink")`),落地后本 flag 可销案;否则未来给 base_status 配传播效果时句柄归属需重审(CHANGES §6)。
- (02 新增)Playtest 人工确认项:编辑器开项目无报错 + autoload 面板见 Balance/EventBus/ReactionSystem 三条(headless 已验 ProjectSettings 层)。
- (承 01)毒腐蚀 add_flat -2.0 待 03 敌人护甲量表复核;radius/distance/speed 等 px 数值待 06 地图 tile 尺度复核。
