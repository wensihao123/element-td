---
artifact: CHANGES
feature: 05-status-ui
role: Implementer
status: draft
updated: 2026-07-05
inputs: [project-context.md, PLAN.md]
next: Reviewer
---

# CHANGES — 05-status-ui

## 1. What changed

- `scenes/ui/status_display.gd` — 新增:敌人头顶状态视图(轮询兄弟 StatusComponent,draw_arc 画 gauge 环,首字 Label / icon 贴图双分支)。
- `scenes/ui/status_display.tscn` — 新增:StatusDisplay 场景(Node2D 根 + Glyph Label + Icon Sprite2D)。
- `test/cases/test_status_display.gd` — 新增:6 个测试方法(无兄弟/空状态隐藏、附着字段、充能消耗升降、归零隐藏、首字 fallback、贴图分支)。
- `scenes/enemies/enemy.tscn` — 挂 StatusDisplay 实例,position=(0,-20);enemy.gd 零改动。
- `data/reactions/*.tres` ×6 — 各加一行 `color = Color(...)` 占位反应色(PLAN D6 建议表原值)。
- `scenes/ui/floating_text.gd` / `.tscn` — 新增:反应飘字(setup 初始化,tick 上浮渐隐,寿命尽 queue_free)。
- `scenes/ui/reaction_vfx_layer.gd` / `.tscn` — 新增:反应表现层(订阅 reaction_triggered,位置快照生成飘字 + 内嵌类 Burst 扩散环;z_index=10)。
- `test/cases/test_reaction_vfx_layer.gd` — 新增:4 个测试方法(信号生成、多发并存、超寿命自毁、目标同帧释放不崩)。
- `scenes/maps/dev_playground.tscn` — 挂 ReactionVfxLayer 实例。

未动任何逻辑代码:status_component / reaction_system / enemy / 各 effect 零改动(PLAN 05-D7 纯增量铁则)。

## 2. Why(对应 PLAN §3 步骤)

| 变更 | PLAN 步骤 |
|------|-----------|
| status_display.gd/.tscn | Phase 1 Step 1 |
| test_status_display.gd | Phase 1 Step 2 |
| enemy.tscn 挂载 | Phase 1 Step 3 |
| 6 反应 .tres 填色 | Phase 2 Step 1 |
| floating_text.gd/.tscn | Phase 2 Step 2 |
| reaction_vfx_layer.gd/.tscn | Phase 2 Step 3 |
| test_reaction_vfx_layer.gd | Phase 2 Step 4 |
| dev_playground.tscn 挂载 | Phase 2 Step 5 |

## 3. How I verified it

全程用全路径 `G:\Godot\Godot_v4.7-stable_win64\godot.exe`(4.7;本终端 PATH 的 `godot` 仍是 4.6.3,BACKLOG 05 环境注意言中)。

- `--import`:每次新增 .gd/.tscn/.tres 改动后各跑一次(共 5 次),全部 exit 0、日志 0 条 ERROR。
- `--check-only -s`:status_display.gd / floating_text.gd / reaction_vfx_layer.gd 各 exit 0。
- 全量测试:`-s res://test/run_tests.gd` → **22 用例 0 失败**(原 20 + 新增 2;新用例共 10 个测试方法全 PASSED),每步后重跑,既有用例未破。
- 接线探针(一次性脚本,住 session scratchpad 不入库):
  - Phase 1:实例化 enemy.tscn → StatusDisplay 存在、position=(0,-20)、附着前隐藏、火附着后可见、ratio=2/3(= default_attach/max_gauge)、环色=火色、首字「火」→ OK。
  - Phase 2:dev_playground 入树 → ReactionVfxLayer 自接线真 EventBus autoload、发 reaction_triggered 生成飘字 1 + 扩散环 1、z_index=10 → OK。
- **两个 playtest gate 人工 F6 目验:均 PASS**(2026-07-05 人回报「都 OK」):
  - Phase 1 gate:1152×648 全视野缩放下环与首字肉眼可辨、同元素连击满环、lava_hound 出生火图标 —— 通过。
  - Phase 2 gate:反应瞬间飘字(反应色)+ 扩散环、消耗后环变短归零消失、飘字不与头顶状态遮挡、击杀弹同帧反应有飘字、六反应色肉眼可区分 —— 通过。
  - 反应占位 6 色画面区分度足够,未提微调需求(PLAN D6 建议值原样定稿)。
  - 原计划的 MCP `editor_screenshot` 自查未能执行:`project_run` 两次都在 game helper 握手前停止(helper_live 一直 false),按 2 次尝试规则不再纠缠,见 §6 flag——已由人工 F6 目验覆盖,不影响 gate 结论。

## 4. Deviations from the plan

- **头顶偏移**:PLAN 写「表现参数全部 @export(含头顶偏移)」;实际用实例节点 `position` 存 enemy.tscn(=Godot 惯例的挂载方场景赋值,同为 .tscn 场景数据,D5 精神一致,少一个冗余字段)。
- **扩散环 Burst 为 reaction_vfx_layer.gd 内嵌类**(PLAN 文件清单未给它独立场景):其表现参数(寿命/半径/线宽)由层脚本 `@export` 代持,值存 reaction_vfx_layer.tscn,仍符合 D5。
- **测试发射端未新增 support 文件**:直接复用 `RecordingBus`(信号面与 EventBus 同步,emit 即发射 stub);PLAN 措辞为「必要时加」,不必要。

## 5. Wiring Contract

**当前所需挂载已全部完成**(enemy.tscn + dev_playground.tscn,本次交付含),以下供 Reviewer 复核与 06 正式地图接线参考:

- 脚本 `status_display.gd`(class_name `StatusDisplay`)→ 挂 Node2D,作为**敌人实体根的直接子节点**(已在 enemy.tscn 完成,position=(0,-20) 即头顶偏移,由挂载场景改)。
  - `@export ring_radius: float = 10`、`ring_width: float = 2`、`backdrop_color: Color` — 环表现参数,值存 .tscn。
  - 无信号;每帧轮询**兄弟具名节点** `StatusComponent`(02-D7 约定),找不到即整体隐藏,不报错。
  - 正式元素图标升级缝:往 `data/elements/*.tres` 的 `icon` 字段填贴图即自动切换,零代码改动(05-D3)。
- 脚本 `floating_text.gd`(class_name `FloatingText`)→ 挂 Node2D;**不需要手动挂载**,由 ReactionVfxLayer 运行时生成。
  - `@export lifetime: float = 1.0`、`rise_distance: float = 24` — 值存 .tscn。
  - 程序接口 `setup(text, color, world_pos)`:生成方须**先 add_child 再 setup**(setup 内设 global_position,需在树内)。
- 脚本 `reaction_vfx_layer.gd`(class_name `ReactionVfxLayer`)→ 挂 Node2D,**地图场景根的直接子节点**(dev_playground 已挂;**06 正式地图须同样挂一份** reaction_vfx_layer.tscn 实例)。
  - 保持默认变换(原点、无缩放);z_index=10 已存场景,保证盖过敌人。
  - `@export floating_text_scene: PackedScene` — 场景里已预填 floating_text.tscn,不用动。
  - `@export burst_lifetime / burst_max_radius / burst_width` — 扩散环表现参数,值存 .tscn。
  - 依赖 autoload `EventBus`:`_ready` 时 bus 字段为空则自接 `/root/EventBus` 的 `reaction_triggered`;测试经 `setup(bus)` 注入 stub。

## 6. Flags / Open questions

- ~~[待人工] 两个 playtest gate 画面目验~~ → **已完成,均 PASS**(2026-07-05 人 F6 回报,见 §3)。
- ~~反应占位 6 色未经画面验证~~ → **已 gate 目验,区分度足够,D6 建议值定稿**(§3)。
- **godot-ai MCP `project_run` 游戏侧 helper 握手失败**(编辑器侧连通正常,游戏运行后 helper_live 恒 false、报「ignored mcp:hello with no active game run」),导致截图自查降级。dev 工具问题不阻塞交付,建议人有空排查 addons 插件游戏侧组件。
- (承 PLAN §5)innate 教学手感观察、飘字同帧重叠观感 → 记在 gate 清单里,处置归 06/07。
