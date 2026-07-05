---
artifact: PLAN
feature: 05-status-ui
role: Planner
status: draft
updated: 2026-07-05
inputs: [project-context.md, BACKLOG.md(05 条目 + 03/04 遗留 flags), 元素反应塔防-项目说明.md §1/§2/§5, 现有代码实测(status_component/reaction_system/event_bus/enemy/active_effects/dev_playground/element+reaction .tres/gauge_config)]
next: Implementer
---

# PLAN — 05-status-ui(状态可视化:头顶图标 + gauge 环 + 反应飘字/占位特效)

## 1. Goal

敌人头顶实时显示元素状态(图标 + gauge 环形进度),反应触发瞬间在目标位置飘出反应名与占位特效——支柱 3「战场必须可读」的 MVP 落点,质量目标「占位但可读」。

## 2. Approach & key decisions

总思路:**纯增量表现层**。不改 StatusComponent / ReactionSystem / Enemy / EventBus 任何逻辑代码,只新增 UI 节点脚本 + 场景挂载 + `.tres` 填色。头顶状态走"实体自身视图"路线,反应飘字走"订阅 EventBus"路线,两条互不依赖。

- **05-D1 表现归属两分:头顶状态 = 敌人子场景组件;反应飘字/特效 = 地图级 VFX 层**
  - What:`StatusDisplay`(Node2D)作为 enemy.tscn 直接子节点,每帧轮询兄弟节点 `StatusComponent` 的 `element` / `gauge` / `cfg.max_gauge`;`ReactionVfxLayer`(Node2D)挂在地图场景,订阅 `EventBus.reaction_triggered` 生成飘字与占位特效。
  - Why:头顶状态是实体私有视图,组件发现约定(02-D7 具名兄弟直读)本就覆盖;轮询一并解决两个坑——gauge 充能/消耗没有专用信号(只有 started/expired),以及 innate 附着发生在 Enemy `_ready` 的信号时序问题。飘字是跨系统事件的表现,铁律要求 UI 只订阅信号;且反应常与击杀同帧(先附着后投伤、AoE 补刀),飘字若挂敌人身上会随 `queue_free` 一起消失。
  - Rejected:全局层扫 `enemies` 组统一画头顶状态(引入组遍历 + 位置同步 + z 序管理,复杂零收益);为 gauge 变化新增 EventBus 信号(为纯表现需求动 02 交付物,违背最小改动)。

- **05-D2 gauge 环 = `draw_arc` 自绘**
  - What:环色 = `element.color`,弧长比例 = `gauge / cfg.max_gauge`,底环淡灰打底;轮询逻辑收在 `tick(delta)`(`_process` 转发),把结果存进可读状态字段(如 `ring_ratio: float`、`ring_color: Color`、`visible`),`_draw` 只消费这些字段。
  - Why:零贴图资产(风格基线未定,硬做即白做);状态字段与绘制分离使 headless 测试可断言(headless 无渲染,断言字段不断言像素)。
  - Rejected:`TextureProgressBar` radial(需贴图)/ shader(占位阶段杀鸡用牛刀)。

- **05-D3 图标占位 = 元素名首字 Label,`icon` 非空时优先贴图**
  - What:`element.icon != null` 时显示 `TextureRect`/`Sprite2D` 贴图,否则 fallback 为 `display_name` 首字(火/冰/电/毒)Label,染元素色。
  - Why:`ElementDef.icon` 字段已预留但 4 个 `.tres` 全空;首字 + 元素色在占位阶段可读性足够。架构缝:正式图标 = Art Spec 之后往 `.tres` 填贴图,**零代码改动**自动升级。
  - Rejected:现在生成占位图标贴图(风格未定,违背「不要自行发明风格」§6)。

- **05-D4 飘字/特效生命周期 = 显式 `tick(delta)` 驱动,不用 Tween**
  - What:飘字(上浮 + 渐隐)与占位特效(扩散环 flash)各自持 `age`/`lifetime`,`tick(delta)` 推进,寿命尽 `queue_free()`;`_process` 转发 tick。
  - Why:headless 测试手动驱动、确定性,与 02/03/04 全部组件先例一致;Tween 依赖树内自动播放,headless 验证脆。
  - Rejected:Tween/AnimationPlayer(gate 目验没问题,但 headless 不可确定性断言)。

- **05-D5 表现常量住 UI 场景 `@export`(.tscn 数据);玩法语义数据住 `.tres`**
  - What:环半径/线宽/字号/头顶偏移/上浮距离/寿命等 = UI 场景节点 `@export`,值存 `.tscn`;元素色、反应色、显示名 = 既有 `.tres` 字段。
  - Why:硬 NO「数值住 .tres」针对的是**游戏数值**(平衡语义、07 要仿真的数);表现参数与平衡无关,住场景与 03 占位 Visual(16px 多边形住 enemy.tscn)先例一致,且 07 的 CSV 管线不该被表现参数污染。
  - Rejected:新建 UiConfig `.tres`(把表现参数伪装成平衡数据)。→ **边界裁定挂 §5 flag 请人认可**。

- **05-D6 反应色住既有 `ReactionDef.color` 字段,本 feature 填 6 个占位色**(ReactionDef 注释「05-status-ui 再定」的销案)
  - 建议值(Implementer 可在 gate 中微调,准绳 = 六反应互相可区分、且不与四元素色混淆):
    | 反应 | 文件 | 建议色 |
    |------|------|--------|
    | 蒸汽爆破 | steam_burst.tres | 雾白 `Color(0.9, 0.93, 0.95)` |
    | 过载 | overload.tres | 品红 `Color(1.0, 0.35, 0.55)` |
    | 燃爆 | combustion.tres | 橙 `Color(1.0, 0.55, 0.1)` |
    | 超导 | superconduct.tres | 淡紫 `Color(0.7, 0.62, 1.0)` |
    | 脆化 | brittle.tres | 青绿 `Color(0.3, 0.9, 0.75)` |
    | 电解 | electrolysis.tres | 紫罗兰 `Color(0.62, 0.25, 0.9)` |

- **05-D7 纯增量铁则**:不新增 EventBus 信号;不改 `status_component.gd` / `reaction_system.gd` / `enemy.gd` / 各 effect 代码;对既有场景只做挂载(enemy.tscn 加一个子场景实例、dev_playground.tscn 加一个层实例)。enemy.gd 的 `_tint_visual` innate 染色保留(与头顶图标不冲突,多一重远距可读性)。

执行手段(BACKLOG 05 条目):Implementer 可经 godot-ai MCP 直操编辑器搭场景 + `editor_screenshot` 自查可读性;人工 gate 只验最终手感。手写 `.tscn` 同样可接受——**注意 Node 型 `@export` 的 `node_paths` 标记坑**(project-context §6)。

验证命令一律走 project-context §5 流程(--import → --check-only → 全量测试);**先 `godot --version` 自查是 4.7**,旧终端 PATH 仍指 4.6.3 时用全路径 `G:\Godot\Godot_v4.7-stable_win64\godot.exe`(BACKLOG 05 环境注意)。

## 3. Phased steps

### Phase 1: 头顶状态显示(图标 + gauge 环)

- [x] Step: 新建 `StatusDisplay` 场景与脚本——Node2D 根,`tick(delta)` 轮询兄弟 `StatusComponent`(经 `get_parent().get_node_or_null("StatusComponent")`,02-D7 约定),产出状态字段(`ring_ratio` / `ring_color` / 可见性 / 图标模式),`_draw` 画底环 + 元素色弧,子 Label 显示首字(icon 非空时切贴图);无组件或空状态整体隐藏;表现参数全部 `@export`(含头顶偏移,由挂载方场景赋值)。
  - Files: `scenes/ui/status_display.gd`、`scenes/ui/status_display.tscn`
  - Verify: `--import` 无新增 ERROR(godot-ai 插件缺失豁免条除外);`--check-only -s res://scenes/ui/status_display.gd` 通过
- [x] Step: headless 测试 `test_status_display.gd`——用例至少覆盖:①无 StatusComponent 兄弟 → 隐藏且不报错;②空状态 → 隐藏;③ `apply_element` 后 tick → 可见、`ring_color` = 元素色、`ring_ratio` = gauge/max_gauge;④同元素补充后 ratio 上升、`consume` 后下降、归零 → 隐藏;⑤ icon 为空走首字 fallback、icon 非空(`PlaceholderTexture2D` 造)走贴图分支。测试显式构造注入 cfg,不依赖 autoload(02-D1 先例)。
  - Files: `test/cases/test_status_display.gd`
  - Verify: 全量测试 0 失败
- [x] Step: `enemy.tscn` 挂 `StatusDisplay` 实例,头顶偏移(约 y=-20,占位值存场景)。不改 enemy.gd。
  - Files: `scenes/enemies/enemy.tscn`
  - Verify: 全量测试仍 0 失败(既有 enemy/e2e 用例不破);`--import` 干净
- Playtest gate (Phase 1): 编辑器 F6 跑 `dev_playground.tscn`,数字键 1–4 摆两种塔。应看到:敌人被命中附着后头顶出现元素色 gauge 环 + 首字图标;同元素连续命中环变满;反应消耗后环变短;归零后整体消失;lava_hound 出生即带火图标(innate)。MCP `editor_screenshot` 自查:1152×648 全视野缩放下环与首字肉眼可辨(支柱 3)。

### Phase 2: 反应飘字 + 占位特效层

- [x] Step: 6 个反应 `.tres` 填 `color` 占位值(§2 D6 表)。
  - Files: `data/reactions/*.tres` ×6
  - Verify: `--import` 干净;全量测试 0 失败
- [x] Step: 新建飘字场景——Label 根(或 Node2D+Label),`setup(text, color, world_pos)` 初始化,`tick(delta)` 上浮渐隐,寿命尽 `queue_free()`;上浮距离/寿命/字号 `@export` 存 `.tscn`。
  - Files: `scenes/ui/floating_text.gd`、`scenes/ui/floating_text.tscn`
  - Verify: `--import` + `--check-only` 通过
- [x] Step: 新建 `ReactionVfxLayer` 场景——Node2D 根,`bus` 可注入、`_ready` 空字段时自接线 `/root/EventBus`(02-D1 先例);收 `reaction_triggered(def, target, source)` → 以 `target.global_position` **快照**为锚,生成飘字(text=`def.display_name`,色=`def.color`)+ 占位特效(自绘扩散环 flash,一次性 tick 驱动,色同反应色);**不持有 target 引用**(目标常在同帧 queue_free);`z_index` 抬高保证盖过敌人。
  - Files: `scenes/ui/reaction_vfx_layer.gd`、`scenes/ui/reaction_vfx_layer.tscn`
  - Verify: `--import` + `--check-only` 通过
- [x] Step: headless 测试 `test_reaction_vfx_layer.gd`——用例至少覆盖:①注入 stub bus(沿 `test/support/recording_bus.gd` 思路反向造发射端)发 `reaction_triggered` → 层内生成 1 个飘字,text/色/位置正确;②连发多次 → 多飘字并存;③ tick 推进超寿命 → 全部自毁、层内清空;④信号发出后目标立即 `queue_free` 再 tick → 不崩(位置快照生效)。
  - Files: `test/cases/test_reaction_vfx_layer.gd`(必要时 `test/support/` 加发射 stub)
  - Verify: 全量测试 0 失败
- [x] Step: `dev_playground.tscn` 挂 `ReactionVfxLayer` 实例。
  - Files: `scenes/maps/dev_playground.tscn`
  - Verify: 全量测试 0 失败;`--import` 干净
- Playtest gate (Phase 2): F6,在预置火塔射程叠冰塔制造蒸汽爆破,再换电/毒塔组合验其余反应。应看到:反应瞬间目标位置飘出反应名(反应色)+ 扩散环占位特效;飘字上浮约 1 秒内清晰可读、不与头顶状态互相遮挡;**击杀弹同帧反应也有飘字**(04-D6 补刀爽点的可视化);六反应色肉眼可区分。MCP `editor_screenshot` 自查可读性。顺带记录 innate 一次性附着「耗尽变白板」的教学手感观察(03 遗留,只记观感不改逻辑,处置归 06 共担)。

## 4. Out of scope

- **HP 血条**——MVP 范围(项目说明 §5)未列;06 做胜负判定时若可读性需要再议。
- **正式美术**:元素图标贴图、粒子特效、音效、字体资产——全部等 STYLE-BIBLE(Art Spec);本 feature 交付的是占位形态 + 零代码升级缝(D3)。
- **建造 UI**(射程预览、放置光标、售塔)→ 06;`dev_playground.gd` 的 dev 网格叠加层**本 feature 不删**——它属 dev 摆塔工具而非状态 UI,删除时机 = 06 交付正式地图/建造交互时(BACKLOG「05/06 记得删除」按此裁定归 06,已挂 HANDOFF flag 请 Producer 归档时更新 BACKLOG 措辞)。
- **游戏级 HUD**(金币、波次计数、开始/暂停)→ 06。
- **不动任何玩法数值与逻辑**:GaugeConfig、敌人/塔数值、反应效果一概不碰;不新增 EventBus 信号(D7)。
- 可选管线阶段裁定(HANDOFF 同步标 `[x]` 不需要):**设计**(项目说明 §1/§2.3/§5 + BACKLOG 05 条目承担,沿 01–04 先例)、**勘探**(本 PLAN 已全量实测通读相关代码)、**美术**(占位自绘 + 既有 element/reaction color,零新资产)、**接线**(场景由 Implementer 直写 `.tscn` 或经 MCP 搭建自查;两个 playtest gate 属验收动作由人 F6 执行,非接线,沿 04 先例)。

## 5. Risks & Flags / Open questions

- **[请人裁定] D5 表现常量边界**:环半径/字号/上浮距离等表现参数住 UI 场景 `@export`(.tscn),不进 `.tres`——我判定硬 NO 的「游戏数值」不含纯表现参数(理由见 D5)。若你不认可,改走 `data/ui/ui_config.tres`,迁移成本几行;请在 Implementer 开工前表态,默认按 D5 执行。
- **中文字形依赖系统字体回退**:占位首字与飘字用中文,Godot 4 默认字体无 CJK,靠 4.1+ 系统字体回退(Windows 本机开发 OK,已是 v1 全部场景)。导出 PCK 到无中文字体环境会豆腐块——与 Later「导出闸门」同筐,v1 不导出不触雷,记档即可。
- **飘字重叠**:多反应同帧同点(如超导传导链)飘字会叠——占位阶段接受,gate 观感明显糟再记 flag(处置选项:小幅错位偏移,留 06/07 期间顺手调)。
- **性能**:头顶 UI 每帧轮询 + `queue_redraw`,MVP 敌人量(每波十几只)无顾虑;headless 仿真(07)无渲染路径,不受影响。记知即可。
- **反应占位色**为表现数据,建议值(D6 表)未经画面验证,Implementer 在 Phase 2 gate 按「互相可区分 + 不与元素色混淆」微调,微调结果回写 `.tres` 即可,不必回报 Planner。
- **innate 教学持续性**(03 遗留):05 只负责让它**可见**(lava_hound 火图标 + 耗尽消失),手感结论记进 gate 观察,处置归 06(BACKLOG 已挂)。
- **测试对 `_draw` 的边界**:headless 断言的是状态字段非像素(D2 设计使然);像素级可读性由 MCP 截图 + 人工 gate 兜底——两层验证合起来才算完整,Implementer 不得以 headless 全绿跳过 gate。
