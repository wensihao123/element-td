# Project Context (shared by all roles)

updated: 2026-07-05

> 所有 role 的共享内存。每个 session 先读这一份。
> 事实来源:本文件是 [../元素反应塔防-项目说明.md](../元素反应塔防-项目说明.md) 的蒸馏;机制/架构细节冲突时以项目说明为准。

## 0. 游戏一句话 + 支柱
- 这是个什么游戏,给谁玩:元素反应塔防(Godot 4.x)——炮塔为敌人附着元素,异元素相触发生反应产生战术效果;给喜欢构筑与摆位策略的 TD 玩家。
- 设计支柱(所有 feature 都要服务它们):
  1. **反应 > 单体输出**:任何单元素流派效率必须低于合理双元素组合;高难必须玩反应。
  2. **顺序即策略**:塔的摆放位置与顺序决定反应发生的地点与时机。
  3. **战场必须可读**:状态图标、元素量环、反应特效、飘字极其清晰;看不懂反应 = 深度变噪音。
- v1 的完成定义(给 Producer 用):**MVP 可玩原型**——4 基础塔 + 6 反应 + Gauge 制、1 张交叉口地图、10 波敌人(含 1 种自带火附着怪)、单货币金币、状态可视化(图标 + gauge 环 + 反应飘字/占位特效)。验证目标:**触发反应的瞬间爽不爽、看不看得懂**。目标周期 2–3 周。

## 1. 引擎与技术栈
- 引擎 + 版本:Godot **4.6.3 stable**(本机 `godot` 命令已在 PATH)
- 脚本语言:GDScript,**全程静态类型标注**(`: float`、`-> void`),Resource 类必须 `class_name`
- 目标平台:PC (Windows) 优先,其余待定
- 美术风格基线:**待定** — 由 Art Spec 建 STYLE-BIBLE.md 时确立;MVP 阶段允许占位图形
- 测试:headless 单元/集成测试(gauge、反应表、效果执行先于画面);命令构造与超时规则见用户全局 CLAUDE.md「Godot Headless 测试规则」
- 平衡工作流(尽早搭):headless 仿真场景批量跑波次×塔组合 → CSV 报表;`.tres` ↔ CSV 双向同步脚本

## 2. 目录约定
```
element-td/               [Godot 项目根,= res://]
  project.godot
  data/                   [全部数值,.tres 资源]
    balance/global_config.tres    # GaugeConfig 全局默认(MVP 唯一数值文件)
    elements/  reactions/  towers/  enemies/  waves/    # waves/ = WaveDef 单波表(03)
  scripts/
    defs/          # Resource 类定义(ElementDef / TowerDef / ReactionDef / EnemyDef / GaugeConfig)
    effects/       # ReactionEffect 及其子类(可组合积木)
    components/    # StatusComponent、HealthComponent 等
    systems/       # ReactionSystem、EventBus、Balance(autoload)
  scenes/
    towers/  enemies/  maps/  ui/
    # 实体根脚本随场景放(03-D10):enemies/enemy.gd+enemy.tscn(通用敌人,EnemyDef 注入);
    # maps/dev_playground.tscn = dev 演武场(仅开发验证);系统逻辑仍归 scripts/systems/(如 wave_spawner.gd)
  test/                   [headless 测试]
  harness/                [role artifact,纳入版本控制]
```

## 3. 代码约定
- 命名:文件 snake_case,节点/类 PascalCase,signal 过去式(如 `status_expired`、`reaction_triggered`)
- 反应效果 = 可组合积木:`ReactionEffect extends Resource` + `apply(target, ctx)`,`ReactionDef.effects` 数组拼装;**禁止 match 大分支**
- 数值解析模式:全局默认(GaugeConfig)+ 局部覆盖(override 字段默认 `-1.0` 表示用全局),经 `get_attach()` / `get_cost()` 查询
- 反应归属:反应伤害记给触发方塔(source_tower)
- MVP 基准数值(全走 global_config):附着 2U / 消耗 1U / 上限 3U / 衰减 0 / ICD 0.5s
- 组件发现约定(02-D7):敌人实体根(Node2D)下挂**具名直接子节点** `StatusComponent` / `ModifierStack` / `ActiveEffects`;敌人实体根一律入 `&"enemies"` 组(02-D6,空间查询 = 组扫描 + 距离过滤)
- 效果享元(02-D3):`ReactionEffect` 共享实例自身零字段写入;逐宿主可变状态住宿主 `ActiveEffects` 的 state 字典(on_start 返回、on_tick/on_end 读写);计时唯一权威 = ActiveEffects
- 鸭子/键位契约(02-D4/D10,03/04 必须消费):`take_damage(amount: float, source: Node)`、`apply_knockback(distance: float, direction: Vector2)`;ModifierStack 保留键 `&"speed"` / `&"armor"` / `&"damage_taken"` / `&"stunned"`,移动/攻击逻辑须查 `resolve(&"stunned", 0.0) > 0.0`;`take_damage` **禁止同步 `free()` 敌人**,死亡一律 `queue_free`(AoE 组遍历与 ActiveEffects.tick 都在迭代中投伤,同步释放 = use-after-free;02 REVIEW)
- 03 落地契约:敌人根第四具名子组件 `HealthComponent`,护甲公式 `final = maxf(amount - armor, 0.0) * resolve(&"damage_taken", 1.0)`(armor 经 resolve,负甲增伤);击退 = 路径进度回退 clamp 0(03-D2,忽略 direction);innate 附着走 `StatusComponent.apply_innate`(只设元素/量,不挂 base_status,03-D5);EventBus 五信号 `enemy_spawned` / `enemy_died` / `enemy_reached_exit` / `wave_started` / `wave_spawn_finished`(**= 生成完毕,非清波**,清波判定归 06;03-D8);`WaveSpawner.start_wave(WaveDef)` 只播单波,波次序列归 06

## 4. 禁止事项(hard NOs)
- 代码中出现游戏数值字面量 = bug;所有数字住 `res://data/` 的 `.tres`
- 运行时修改 `.tres` 字段 = bug;运行时增益走 ModifierStack 修饰层
- 新反应/新效果禁止在 ReactionSystem 内写分支,只能新增 Resource
- 跨系统通信一律走 EventBus 信号,禁止系统间直接引用调用
- 不做计划外的"顺手重构 / 顺手加功能"
- 不为 MVP 之外的系统写实现(塔分支、中立塔、科技树、Boss 等只留架构缝,不写代码)

## 5. 验证一次改动是否 OK 的标准流程
按顺序,全绿才算通过(Godot 4.6.3 实测命令,01-data-layer 回填):
```
# 0. 新增/改名 .gd(class_name)或 .tres 后,先刷新导入与全局类缓存(-s 运行解析新类依赖它)
timeout 120 godot --headless --display-driver headless --audio-driver Dummy --quit-after 2000 --path . --import > /tmp/godot_import.log 2>&1; echo "exit: $?"
#    期望退出码 0 且日志无 ERROR
# 1. 脚本编译检查(实测:--check-only 必须搭配 -s 单脚本;不带 -s 会报错退出)
timeout 120 godot --headless --display-driver headless --audio-driver Dummy --check-only --quit-after 2000 --path . -s res://<改动的脚本>.gd
# 2. headless 测试
timeout 120 godot --headless --display-driver headless --audio-driver Dummy --quit-after 2000 --path . -s res://test/run_tests.gd > /tmp/godot_test.log 2>&1; echo "exit: $?"
#    期望退出码 0,输出含「0 失败」
# 3. 涉及画面/交互的功能:人工开场景 Play 验证(Integrator/人执行)
```
测试用例规范:放 `res://test/cases/`、`extends TestCase`、方法名 `test_` 前缀;跑道 `run_tests.gd` 反射执行并以退出码回报(0 = 全过,1 = 有失败)。

## 6. 当前已知的坑 / 临时约束
- 美术风格基线未定,UI/特效一律先用占位,不要自行发明风格
- 新增带 `class_name` 的脚本或 `.tres` 后必须先跑一次 `--import`(§5 第 0 步),否则 `-s` 模式解析不到新类(全局类缓存过期)
- `-s` 模式下 autoload 单例**已加载**(02 实测,Godot 4.6.3:`root.get_node_or_null("Balance")` 非空;探针 `test/probe_autoload.gd` 保留,引擎升级后复测)。测试仍一律显式 `load()`/构造注入,不依赖单例(PLAN 02-D1,可测性设计选择)
- `-s` 模式 `_initialize` 阶段 **root 尚未入树**(02 实测):组查询、`is_inside_tree()` 全部失效;SceneTree 脚本的树操作必须放首个 `process_frame` 之后(`run_tests.gd` 已改为首帧执行测试体)
- godot-ai 插件为**本机 dev 工具**(非游戏系统):project.godot 的 `_mcp_game_helper` autoload 与 `[editor_plugins]` 配置随仓库提交,但 `addons/` 不入库(.gitignore 有意忽略,人裁定 2026-07-05)。**无插件的干净 checkout 首启/`--import` 会报一条插件脚本缺失 ERROR,属预期**(自装插件或编辑器里禁用即消);§5 的"日志无 ERROR"全绿标准据此豁免该条。游戏代码禁止依赖 `_mcp_game_helper`
- 手写 `.tscn` 给 **Node 类型的 `@export`** 赋值时,节点头必须带 `node_paths=PackedStringArray("字段名")` 标记,否则 NodePath 不解析、字段**静默为 null**(03 实测,dev_playground 踩坑)
- headless 跑场景时物理模拟按墙钟推进:`--quit-after 2000` 只保证约 10 秒出头的模拟时长,验证长流程(如敌人走完全程)需加大迭代数(03 实测 6000 次够 30+ 秒)
