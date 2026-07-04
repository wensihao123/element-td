---
artifact: PLAN
feature: 01-data-layer
role: Planner
status: accepted
updated: 2026-07-04
inputs: [harness/project-context.md, harness/BACKLOG.md, 元素反应塔防-项目说明.md]
next: Implementer
---

# PLAN — 01-data-layer

## 1. Goal

初始化 Godot 4.6 项目骨架与 headless 测试跑道,落地 `defs/` 全部 Resource 类 + `effects/` 积木类(参数壳),并产出 `global_config` + 4 元素 + 6 反应共 11 个 `.tres` 数据文件,全部通过 headless 数据完整性测试。

## 2. Approach & key decisions

- **D1:effects/ 积木类纳入本 feature(仅参数壳)**
  - 决定:`ReactionEffect` 基类 + 6 个子类在本 feature 落地,只含 `@export` 参数与 `apply(target: Node, ctx: Dictionary) -> void` 空实现;运行时逻辑归 `02-reaction-core`。
  - 为什么:6 个反应 `.tres` 是本 feature 的交付物,组装 `effects` 数组必须先有这些资源类型和参数;数据一次写全,02 只写逻辑不再回头动数据。
  - 弃选:反应 `.tres` 先留空 `effects` 数组、02 再补——`.tres` 要动两遍,数据授权混进逻辑 feature,违背"01 = 全部数据"的切分。

- **D2:defs 保持纯数据、零 autoload 依赖**
  - 决定:`get_attach()` / `get_cost()` 显式传参:
    ```gdscript
    func get_attach(cfg: GaugeConfig) -> float:
        return attach_override if attach_override >= 0.0 else cfg.default_attach
    ```
    `Balance` autoload 只是运行时取 config 的公共入口(`Balance.config`),defs 类自身不引用它。
  - 为什么:headless 测试可直接 `GaugeConfig.new()` 构造注入,不依赖 autoload 是否被 `-s` 模式加载(该行为存在不确定性,见 Risks);数据类不藏单例耦合。
  - 弃选:defs 内直接读 `Balance` 单例——测试必须拉起完整项目环境,耦合隐蔽。

- **D3:自研微型测试跑道,不引 GUT**
  - 决定:`test/test_case.gd`(`class_name TestCase extends RefCounted`,`assert_true` / `assert_eq` 把失败信息收进 `failures` 数组)+ `test/run_tests.gd`(`extends SceneTree`,扫描 `res://test/cases/*.gd`,实例化后反射调用所有 `test_` 前缀方法,汇总打印每用例 PASSED/FAILED 与总计,显式 `quit(0/1)`)。
  - 为什么:慎引新依赖(role 约束);MVP 只测纯逻辑与数据完整性,~50 行足够;显式 quit + 退出码符合全局 headless 测试规则。
  - 弃选:GUT 框架——插件体积与版本维护成本,对当前测试面收益不成比例。

- **D4:元素基础状态复用 ReactionEffect 积木**
  - 决定:`ElementDef.base_status: Array[ReactionEffect]`(灼烧 = `DotEffect`、减速 = `StatModifierEffect(speed)`、电 = `DotEffect(慢 tick)`、腐蚀 = `StatModifierEffect(armor)`)。
  - 为什么:数值全走 `.tres`;不给 ElementDef 开 `burn_dps`、`slow_pct` 之类元素专属字段——那是变相 match 分支,每加元素就要改类定义,违背"加内容 = 加数据"。
  - 弃选:ElementDef 平铺专属数值字段(理由同上)。
  - 附带约定:`duration = -1.0` 表示"随状态存续"(gauge > 0 期间生效);持续型语义(生效/回滚)由 02 的 StatusComponent 定义,若积木接口不够,02 只调类接口、不动数据布局(已记 Flag)。

- **D5:效果类导出字段默认值一律中性哨兵(`0.0` / `-1.0`)**
  - 决定:真实数值只在 `.tres` 授权;唯一例外是 `GaugeConfig` 类默认值按项目说明 §4.3 代码快照保留,但以 `global_config.tres` 为权威(测试断言以 `.tres` 为准)。
  - 为什么:硬 NO"代码中出现游戏数值字面量 = bug"。

- **D6:`.tres` 全部手写文本(format=3),不开编辑器拼装**
  - 决定:Implementer 直接写 `.tres` 文本,`ext_resource` 用 `res://` 路径引用脚本,SubResource 内联组装 effects;正确性由 headless 加载测试兜底。
  - 为什么:全程可自动化、可 diff;因此本 feature **不需要接线(Engine Integrator)阶段**。
  - 弃选:编辑器 Inspector 手工拼装——引入人工回环,收益仅是省写文本格式。

- **D7:命名与引用方式**
  - 元素 id / 文件:`fire` / `ice` / `lightning` / `poison`。
  - 反应 id / 文件:`steam_burst`(火+冰)/ `overload`(火+电)/ `combustion`(火+毒 燃爆)/ `superconduct`(冰+电)/ `brittle`(冰+毒 脆化)/ `electrolysis`(电+毒)。
  - `ReactionDef.element_a / element_b` 用 **ElementDef 资源引用**(非裸 StringName):Inspector 可校验、改名不断链;02 的 ReactionSystem 建表时从 `def.element_x.id` 派生排序 key。弃选:存字符串 id——易拼错、无编辑器校验。
  - `PropagateEffect` 语义:包装 `inner: ReactionEffect`,只作用于**周围敌人**(半径内、不含主目标);需要主目标也吃效果时,在 effects 数组里并列一个未包装的同类效果(见占位数值表)。

- **D8:占位数值裁定表(项目说明未指定的数值由本计划裁定,07-balance-sim 前均为占位)**

  | 文件 | 组装 | 数值 |
  |------|------|------|
  | `global_config.tres` | GaugeConfig | attach 2.0 / cost 1.0 / max 3.0 / decay 0.0 / icd 0.5(项目说明指定) |
  | `fire.tres` base_status | DotEffect | dps 5.0, tick_interval 0.5, duration -1 |
  | `ice.tres` base_status | StatModifierEffect | stat=`speed`, add_percent -0.30(指定 30%), duration -1 |
  | `lightning.tres` base_status | DotEffect | dps 3.0, tick_interval 1.0, duration -1 |
  | `poison.tres` base_status | StatModifierEffect | stat=`armor`, add_flat -2.0, duration -1 |
  | `steam_burst.tres` | AoeDamageEffect | damage 40, radius 96 |
  | `overload.tres` | AoeDamageEffect + KnockbackEffect | damage 30, radius 64;distance 48 |
  | `combustion.tres` | DotEffect + PropagateEffect(DotEffect) | 主目标与传播均 dps 8, duration 4, tick 0.5;传播 radius 96 |
  | `superconduct.tres` | StunEffect + PropagateEffect(StunEffect) | 冻结 duration 1.5;传导 radius 96 |
  | `brittle.tres` | StatModifierEffect | stat=`damage_taken`, add_percent +0.40(指定), duration 5.0 |
  | `electrolysis.tres` | StunEffect | duration 1.0(指定"眩晕 1 秒") |

  元素占位色(可读性支柱,UI 未建前先入数据):fire `#e25822` / ice `#7fdbff` / lightning `#f5d547` / poison `#7cb518`。反应 `color` 字段 MVP 留默认,05-status-ui 再定。

## 3. Phased steps

### Phase 1: Godot 项目骨架 + 测试跑道

- [x] Step: 创建 `project.godot`(项目名 element-td,`config/features` 含 `"4.6"`,GDScript 警告 `untyped_declaration` 设为 error 以机制化"全程静态类型"约定;不设主场景)+ `.gitignore`(至少 `.godot/`)+ 目录骨架:`data/{balance,elements,reactions,towers,enemies}`、`scripts/{defs,effects,components,systems}`、`scenes/{towers,enemies,maps,ui}`、`test/cases`,空目录放 `.gitkeep`。
  - Files: `project.godot`、`.gitignore`、各目录 `.gitkeep`
  - Verify: `timeout 120 godot --headless --display-driver headless --audio-driver Dummy --quit-after 2000 --path . --import > /tmp/godot_import.log 2>&1; echo "exit: $?"` 退出码 0,日志无 ERROR
- [x] Step: 落地测试跑道:`test/test_case.gd`(TestCase 基类,断言失败收集进 `failures: Array[String]`)+ `test/run_tests.gd`(extends SceneTree,发现→执行→汇总→`quit(0/1)`,见 D3)+ 冒烟用例 `test/cases/test_smoke.gd`(断言 `1 + 1 == 2`)。
  - Files: `test/test_case.gd`、`test/run_tests.gd`、`test/cases/test_smoke.gd`
  - Verify: `timeout 120 godot --headless --display-driver headless --audio-driver Dummy --quit-after 2000 --path . -s res://test/run_tests.gd > /tmp/godot_test.log 2>&1; echo "exit: $?"` 退出码 0,日志含 smoke PASSED 与汇总行
- Playtest gate (Phase 1): 纯管道,无画面可玩点。确认项 = 上述两条命令退出码 0;游戏本体不可运行(无主场景)是预期。

### Phase 2: defs/ 与 effects/ Resource 类

- [x] Step: `scripts/defs/gauge_config.gd` — `class_name GaugeConfig extends Resource`,五字段照项目说明 §4.3 快照(`default_attach` / `max_gauge` / `decay_per_sec` / `default_cost` / `reaction_icd`,全 `: float`)。
  - Files: `scripts/defs/gauge_config.gd`
  - Verify: `timeout 120 godot --headless --display-driver headless --audio-driver Dummy --check-only --quit-after 2000 --path . -s res://scripts/defs/gauge_config.gd` 退出码 0(若 `--check-only` 组合在 4.6 不生效,以 Phase 1 的 --import 命令替代,并在最后回填步修正 project-context §5)
- [x] Step: `scripts/effects/reaction_effect.gd` 基类(`class_name ReactionEffect extends Resource`,`func apply(target: Node, ctx: Dictionary) -> void` 空实现)+ 6 个子类壳:`aoe_damage_effect.gd`(damage, radius)、`knockback_effect.gd`(distance)、`stun_effect.gd`(duration)、`stat_modifier_effect.gd`(stat: StringName, add_flat, add_percent, duration = -1.0)、`dot_effect.gd`(dps, duration = -1.0, tick_interval)、`propagate_effect.gd`(inner: ReactionEffect, radius)。全部 `class_name`、导出字段中性默认值(D5)。
  - Files: `scripts/effects/reaction_effect.gd` 及 6 个子类文件
  - Verify: 同上编译检查全部通过
- [x] Step: `scripts/defs/element_def.gd` — id: StringName、display_name: String、color: Color、icon: Texture2D(MVP 置空)、base_status: Array[ReactionEffect]。
  - Files: `scripts/defs/element_def.gd`
  - Verify: 编译检查通过
- [x] Step: `scripts/defs/reaction_def.gd` — id: StringName、display_name: String(反应飘字直接用它)、color: Color、element_a / element_b: ElementDef、gauge_cost_override: float = -1.0、`get_cost(cfg: GaugeConfig) -> float`、effects: Array[ReactionEffect]。
  - Files: `scripts/defs/reaction_def.gd`
  - Verify: 编译检查通过
- [x] Step: `scripts/defs/tower_def.gd`(id、display_name、element: ElementDef、damage、fire_interval、attack_range、projectile_speed、cost_gold: int、attach_override: float = -1.0、`get_attach(cfg)`)+ `scripts/defs/enemy_def.gd`(id、display_name、max_hp、speed、armor、gold_reward: int、innate_element: ElementDef 可空)。字段集为骨架,03/04 规划时可增列(加 `@export` 向后兼容)。
  - Files: `scripts/defs/tower_def.gd`、`scripts/defs/enemy_def.gd`
  - Verify: 编译检查通过
- [x] Step: 单测 `test/cases/test_defs.gd`:构造 GaugeConfig 注入,断言 `TowerDef.get_attach` 与 `ReactionDef.get_cost` 的 override 解析——`-1.0` → 返回全局默认;`>= 0` → 返回覆盖值;边界 `0.0` 算有效覆盖。
  - Files: `test/cases/test_defs.gd`
  - Verify: headless 测试命令退出码 0,test_defs 全 PASSED
- Playtest gate (Phase 2): 纯管道。可选人工抽查:编辑器打开项目无脚本报错,新建资源对话框能看到 GaugeConfig / ElementDef / ReactionDef / TowerDef / EnemyDef / 各 Effect 类型。

### Phase 3: 数据 .tres + Balance autoload + 完整性测试

- [x] Step: `data/balance/global_config.tres`(数值见 D8 表首行)。
  - Files: `data/balance/global_config.tres`
  - Verify: headless 下 `load()` 成功且五字段值正确(并入下方完整性测试;此步先以 --import 无 ERROR 为过)
- [x] Step: `scripts/systems/balance.gd`(autoload:preload `global_config.tres`,暴露 `config: GaugeConfig`)+ 在 `project.godot` 注册 autoload `Balance`。
  - Files: `scripts/systems/balance.gd`、`project.godot`
  - Verify: --import 无 ERROR;完整性测试断言 `ProjectSettings.has_setting("autoload/Balance")`(不依赖 `-s` 模式下单例实际加载,见 Risks)
- [x] Step: 4 个元素 `.tres`(`data/elements/fire|ice|lightning|poison.tres`):id、display_name(火/冰/电/毒)、占位色、base_status 积木按 D8 表组装(SubResource 内联)。
  - Files: `data/elements/*.tres`
  - Verify: --import 无 ERROR(数值断言并入完整性测试)
- [x] Step: 6 个反应 `.tres`(`data/reactions/steam_burst|overload|combustion|superconduct|brittle|electrolysis.tres`):id、display_name(蒸汽爆破/过载/燃爆/超导/脆化/电解)、element_a/element_b 引用元素 `.tres`、effects 按 D8 表组装。
  - Files: `data/reactions/*.tres`
  - Verify: --import 无 ERROR
- [x] Step: 数据完整性测试 `test/cases/test_data_integrity.gd`:载入全部 11 个 `.tres`,断言——① global_config 五值 = 2/1/3/0/0.5;② 4 元素 id 非空且唯一;③ 6 反应的 (element_a, element_b) 无序对恰好覆盖 4 元素的全部 6 个组合、无重复、无自反(a != b);④ 每个反应 effects 非空;⑤ 每个 PropagateEffect 的 inner 非空;⑥ 每个元素 base_status 非空。
  - Files: `test/cases/test_data_integrity.gd`
  - Verify: headless 测试命令退出码 0,三个用例文件全 PASSED
- [x] Step: 回填与收尾:project-context.md §5 固化实测可用的编译检查 + 测试命令;§6 删除"无 project.godot"、"test/run_tests.gd 不存在"两条已解决的坑;更新本 feature `HANDOFF.md`(实现行翻 `[x]`、下一步指向 Reviewer)并写 `CHANGES.md`。
  - Files: `harness/project-context.md`、`harness/features/01-data-layer/HANDOFF.md`、`harness/features/01-data-layer/CHANGES.md`
  - Verify: 三份文档内容与实际命令/状态一致;§5 中的命令逐条实跑过退出码 0
- Playtest gate (Phase 3): 纯管道,无画面。人工确认(可选但建议):编辑器 FileSystem 点开 `steam_burst.tres`,Inspector 中能看到 element_a/element_b 引用与 AoeDamageEffect(damage 40 / radius 96)组装;headless 测试全绿即视为本 feature 数据层验收通过。

## 4. Out of scope

本 feature 不做(对应 HANDOFF 中标 `[x]` 不需要的可选阶段):
- **勘探(Explorer)**:全新空仓,无既有代码可勘探 → 不需要。
- **美术(Art Spec)**:纯数据层,无任何资产需求(icon 字段置空,占位色直接入 `.tres`)→ 不需要。
- **接线(Engine Integrator)**:`.tres` 全部手写文本 + headless 验证(D6),无编辑器手工步骤 → 不需要。
- (设计阶段由《元素反应塔防-项目说明.md》承担,BACKLOG 2026-07-04 决策已裁,HANDOFF 中同样记 `[x]`。)

功能边界之外:
- 各 Effect 的 `apply()` 运行时逻辑及其测试 → 02-reaction-core。
- EventBus / ReactionSystem / StatusComponent 及 gauge 运行时规则(充能/消耗/ICD/衰减)→ 02。
- towers / enemies 的 `.tres` 数值授权 → 03 / 04(本 feature 只建类和空目录)。
- ModifierStack 修饰层 → 后续(StatModifierEffect 只留参数缝)。
- 任何场景、UI、可运行游戏画面。

## 5. Risks & Flags / Open questions

- **占位数值系本计划裁定**(项目说明只指定 gauge 五值、减速 30%、易伤 +40%、眩晕 1s):已集中在 D8 表,07-balance-sim 前不作平衡承诺。若想先建 BALANCE.md 数值框架,可在 02 之前跑 `/num-smith`;**建议不阻塞**——数值全在 `.tres`,后调零代码成本。
- **ElementDef.base_status 复用 ReactionEffect 的持续型语义待 02 确认**(D4):02 Planner 若发现 apply 一次性接口撑不住"gauge > 0 期间持续生效/失效回滚",只调类接口、不动数据布局。
- **毒腐蚀 add_flat -2.0 是盲猜**:敌人护甲量表 03 才定,届时复核该值量级。
- **距离单位为 px 但地图 tile 尺度未定**(06):radius / distance / speed 类数值届时可能整体缩放。
- **`-s` 模式下 autoload 是否加载不确定**:测试一律显式构造/加载资源,不依赖 `Balance` 单例(D2);02 落地 ReactionSystem 时一并验证 autoload 在测试环境的行为。
- **手写 `.tres` 的 uid 告警**:Godot 4.6 对无 uid 的 `ext_resource` 会在 --import 时告警并可能回写 uid;首次 --import 后若有回写 diff,直接提交即可,不算错误。
- **`--check-only` 命令组合在 4.6 的实际行为待实证**:Phase 2 第一步 Verify 已给出回退方案,最终以回填进 project-context §5 的实测命令为准。
