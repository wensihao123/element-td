---
feature: 04-towers-projectiles
status: done
updated: 2026-07-05
---
# HANDOFF — 04-towers-projectiles(塔 + 弹丸命中管线 + 网格摆塔)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。
>
> 读取顺序:**「管线状态」+「下一步」是必读状态**;「决策记录」「未决 flags」是参考/账本,
> 需要追溯才往下看。功能 `done` 后,整目录(含本文件)挪进 `harness/archive/`。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | [x] 不需要——由《元素反应塔防-项目说明.md》§3.1/§4.3/§5 承担(沿 01–03 先例,PLAN §4) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | [x] 不需要——Planner 制订计划时已全量通读 02/03 产物与现有代码实测接口(PLAN §2/§4) |
| 计划 | Planner | PLAN.md | [x] |
| 实现 | Implementer | CHANGES.md | [x] |
| 审查 | Reviewer | REVIEW.md | [x] 复审 APPROVE(2026-07-05):2 条 must-fix 逐条核实真实解决(读实际代码 + git diff + 复跑 20 用例 94 方法 0 失败),返工无新问题;首轮 Should-fix/Nits 非阻塞留档给 05/06/07 |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | [x] 不需要——占位多边形 + 既有 element color,零新资产;正式可视化归 05(PLAN §4) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | [x] 不需要——场景全部 `.tscn` 文本由 Implementer 直写;Phase 3/4 人工 playtest gate 属验收非接线(PLAN §4) |

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
> 3. **接线 ↔ 人**:本 feature 不需要(但 PLAN Phase 3 与 Phase 4 各有一个**人工 playtest gate**:
>    编辑器 F6 跑 `dev_playground.tscn` 按 gate 清单目检——属实现阶段验收动作,由人执行后把结果告知 Implementer/Reviewer)。

## 功能完成判据(写死)
> 所有**需要的**阶段都 `[x]`,且审查 verdict 非 REQUEST CHANGES。
> 本 feature 需要的阶段 = 计划、实现、审查(其余已裁定不需要)。
> 满足时:完成最后一个必需阶段的那个 role 把 frontmatter `status` 翻 `done`,
> 「下一步」写「功能完成 → Producer 归档 + 记 Shipped」。归档动作由 Producer 做。

## 下一步
**功能完成 → Producer 归档 + 记 Shipped**(所有必需阶段——计划、实现、审查——全 `[x]`,复审 verdict APPROVE,满足功能完成判据)。开 `/role-producer`:整目录挪 `harness/archive/`、BACKLOG 记 Shipped、触发「未决 flags」中挂 05/06/07 事项的登记。

## 决策记录(账本·按需读)
- 2026-07-05 设计/勘探/美术/接线四个可选阶段裁定不走(来源:PLAN §4,Planner)。
- 2026-07-05 关键技术决策 04-D1~D10 见 PLAN §2:tile=64px + GridConfig + Balance.grid(D1)、TowerDef 距离字段 tile 单位化(D2)、BuildGrid 几何+簿记不管实例化+buildable 注入(D3)、通用 tower.tscn 三具名子组件数据驱动(D4)、索敌=射程内 progress 最大(D5)、命中先附着后投伤+死目标整弹丢弃(D6)、弹丸追踪+目标失效自毁+位移≥剩余距离判中(D7)、4 塔占位数值统一全住 .tres(D8)、不新增 EventBus 信号(D9)、dev 摆塔输入归演武场 dev 工具(D10)。
- 2026-07-05 命中顺序裁定理由(D6,较重要):先附着使「击杀弹也能触发反应」——支柱 1 的补刀爽点;反应先结算、直伤后到,死亡由 03 终态 guard 兜底不双记账。

## 未决 flags
- (04 复审新增,REVIEW §3)两条非阻塞 Should-fix 留档:①projectile.gd:60 弹丸与目标重合时 `hit_direction` 为零向量(现无实害,真消费方向的效果出现时需回退方向);②build_grid.gd `_ready` 自接线失败无警告(06 接真实地图时顺路补 `push_warning`)。
- (04 实现新增,CHANGES §6)本机 shell PATH 仍指 Godot 4.6.3(project-context §1 旧终端坑的实证);Implementer 全程用 4.7 全路径绕开,人重启终端/清 PATH 前直接敲 `godot` 会跑旧版。
- (04 实现新增,CHANGES §6)占位数值 headless 数据点供 07:runner 4 发点杀;lava_hound 需 20 发,单座火塔射程内打不死必漏——管线正常,数值归 07。
- (04 计划新增,PLAN §5)距离标尺双轨:04 新数值 tile 制,03 敌人 speed / 02 反应 AoE 半径仍 px——统一复核挂 06(承 01 遗留);Implementer 不得顺手改旧数值。
- (04 计划新增,PLAN §5)4 塔占位数值(damage 5 / 0.8s / 2.5 格 / 6 格/s / 100 金)与手感全待 07 校准;gate 只验管线与可读性,数值难看不算失败,记观感即可。
- (04 计划新增,PLAN §5)弹丸不换目标(D7)的空弹浪费属可接受占位;gate 观感明显糟再记 flag 给 06/07。
- (04 计划新增,PLAN §5)Weapon 纯冷却计时无 FSM;后续要蓄力/多段/模式切换,先过 /state-machine-master。
- (04 计划新增,PLAN §5)cost_gold 已填占位但 04 不消费,经济扣费归 06;BuildGrid 无 release(无售塔),06 做售塔时几行扩展。
