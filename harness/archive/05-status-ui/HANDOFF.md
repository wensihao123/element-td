---
feature: 05-status-ui
status: done
updated: 2026-07-05
---
# HANDOFF — 05-status-ui(状态可视化:头顶图标 + gauge 环 + 反应飘字/占位特效)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。
>
> 读取顺序:**「管线状态」+「下一步」是必读状态**;「决策记录」「未决 flags」是参考/账本,
> 需要追溯才往下看。功能 `done` 后,整目录(含本文件)挪进 `harness/archive/`。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | [x] 不需要——由《元素反应塔防-项目说明.md》§1/§2.3/§5 + BACKLOG 05 条目承担(沿 01–04 先例,PLAN §4) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | [x] 不需要——Planner 制订计划时已全量实测通读相关代码与 02/03/04 产物(PLAN §2/§4) |
| 计划 | Planner | PLAN.md | [x] |
| 实现 | Implementer | CHANGES.md | [x](Auto 跑完两 Phase,22 用例 0 失败;两个 playtest gate 人工 F6 目验均 PASS,2026-07-05) |
| 审查 | Reviewer | REVIEW.md | [x] APPROVE WITH NITS(2026-07-05;must-fix 空;22 用例 0 失败 Reviewer 实跑复核;2 条非阻塞 should-fix/nit 见 REVIEW,处置随 06/记档) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | [x] 不需要——占位自绘(draw_arc 环 + 首字 Label)+ 既有 element/reaction color,零新资产;正式图标/特效等 STYLE-BIBLE,升级缝已留(PLAN 05-D3) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | [x] 不需要——场景由 Implementer 直写 `.tscn` 或经 godot-ai MCP 搭建自查;两个人工 playtest gate 属验收非接线(沿 04 先例,PLAN §4) |

> 状态记号(与 PLAN 步骤、REVIEW must-fix 同一套,全 harness 一致):
> `[ ]` 未开始 · `[~]` 进行中(含产出 draft、含被打回返工中) · `[x]` 完成或确认不需要(此阶段已了结)。
> Implementer 跑分阶段 PLAN 时可在「实现」行后缀阶段进度,如 `[~] phase 1/2`
> (细到步骤看 PLAN.md 的 `[~]/[x]`)。
> 阻塞不是第四种状态:阶段留在 `[~]`,把阻塞项写进下面「未决 flags」。

## 验收回环(三处人机来回 · 写死,严格照走)
> 1. **实现 ↔ 审查**:Implementer 完工 → 实现 `[x]`、审查 `[ ]`、开 Reviewer。Reviewer 出 REVIEW.md:
>    APPROVE / APPROVE WITH NITS → 审查 `[x]`;REQUEST CHANGES → 审查 `[~]`、实现退回 `[~]`,
>    must-fix 每条带记号当返工单,Implementer **只针对 must-fix** 逐条改完 → 实现 `[x]`、回 Reviewer 复审。
> 2. **美术 ↔ 人**:本 feature 不需要。
> 3. **接线 ↔ 人**:本 feature 不需要(但 PLAN Phase 1 与 Phase 2 各有一个**人工 playtest gate**:
>    编辑器 F6 跑 `dev_playground.tscn` 按 gate 清单目检 + MCP `editor_screenshot` 自查——属实现阶段验收动作,由人执行后把结果告知 Implementer/Reviewer)。

## 功能完成判据(写死)
> 所有**需要的**阶段都 `[x]`,且审查 verdict 非 REQUEST CHANGES。
> 本 feature 需要的阶段 = 计划、实现、审查(其余已裁定不需要)。
> 满足时:完成最后一个必需阶段的那个 role 把 frontmatter `status` 翻 `done`,
> 「下一步」写「功能完成 → Producer 归档 + 记 Shipped」。归档动作由 Producer 做。

## 下一步
**功能完成 → Producer 归档 + 记 Shipped**:`/role-producer`。审查 verdict = APPROVE WITH NITS(REVIEW.md,must-fix 空),三个必需阶段(计划/实现/审查)全 `[x]`,frontmatter `status` 已翻 `done`——满足功能完成判据。Producer 归档时请一并处理:
1. 把整个 `harness/features/05-status-ui/` 目录挪进 `harness/archive/`;BACKLOG 记 Shipped。
2. **BACKLOG 措辞更新**(05 计划遗留):dev 网格叠加层删除裁定归 06,把 06 条目「05/06 …记得删除」收窄为仅 06(见下方 flag)。
3. 分流 REVIEW 的 2 条非阻塞项 + 承 03/04 遗留 flags 至 06/07/Later(见下方 flags):飘字与层变换耦合 → 请 06 接线时带进 INTEGRATION-STEPS;innate 教学手感 → 06 共担;中文字形/导出闸门 → Later。

## 决策记录(账本·按需读)
- 2026-07-05 设计/勘探/美术/接线四个可选阶段裁定不走(来源:PLAN §4,Planner)。
- 2026-07-05 关键技术决策 05-D1~D7 见 PLAN §2:表现归属两分——头顶状态 = 敌人子组件轮询兄弟 StatusComponent、反应飘字 = 地图级层订阅 EventBus(D1);gauge 环 draw_arc 自绘 + 状态字段与绘制分离供 headless 断言(D2);图标占位 = 首字 Label,icon 非空自动切贴图零代码升级(D3);飘字/特效显式 tick 驱动不用 Tween(D4);表现常量住场景 @export、玩法语义数据住 .tres(D5,待人认可);反应色住既有 ReactionDef.color,6 占位色建议表(D6);纯增量铁则——不新增信号、不改 02/03/04 逻辑代码(D7)。
- 2026-07-05 dev 网格叠加层删除时机裁定:归 06(它属 dev 摆塔工具,05 不动建造交互;BACKLOG「05/06 记得删除」按此收窄,见下方 flag)。
- 2026-07-05 人认可 05-D5(表现常量住场景 `@export`),Implementer 以 Auto 模式执行;头顶偏移以实例 position 存 enemy.tscn、Burst 参数由层 @export 代持、测试发射端复用 RecordingBus(三处小偏差记 CHANGES §4)。

## 未决 flags
- (05 实现新增,CHANGES §6)godot-ai MCP `project_run` 游戏侧 helper 握手失败(helper_live 恒 false),截图自查降级为 headless 探针 + 人工 F6;dev 工具问题不阻塞交付,建议有空排查 addons 游戏侧组件。
- (已了结)~~两个 playtest gate 画面目验~~ → 2026-07-05 F6 均 PASS。
- (已了结)~~反应占位 6 色区分度~~ → gate 目验足够,D6 建议值定稿。
- (05 计划新增,PLAN §4)dev 网格叠加层删除裁定归 06——请 Producer 在 05 归档时把 BACKLOG 06 条目的「05/06 …记得删除」措辞更新为仅 06。
- (05 审查新增,REVIEW should-fix)飘字上浮改 local `position.y`、扩散环锚 `global_position`——依赖「ReactionVfxLayer 保持默认变换(原点/无缩放)」隐式契约,05 内无害;请 06 正式地图接线时把该约束显式带进 INTEGRATION-STEPS,别让它只活在 05 CHANGES §5。
- (承 03 遗留,BACKLOG 05 条目)innate 一次性附着教学持续性:05 只做可见化 + gate 记录手感观察,处置归 06 共担。
- (承 04 遗留,BACKLOG 05 条目)环境注意:旧终端 PATH 仍指 Godot 4.6.3,headless 验证前 `godot --version` 自查,不对就用全路径 `G:\Godot\Godot_v4.7-stable_win64\godot.exe`。
- (05 计划新增,PLAN §5)中文字形靠系统字体回退,导出 PCK 后可能豆腐块——与 Later「导出闸门」同筐,v1 不导出不触雷,记档。
- (05 计划新增,PLAN §5)飘字同帧同点重叠属占位可接受;Phase 2 gate 观感明显糟再记 flag 给 06/07。
