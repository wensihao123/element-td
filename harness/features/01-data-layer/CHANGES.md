---
artifact: CHANGES
feature: 01-data-layer
role: Implementer
status: draft
updated: 2026-07-04
inputs: [PLAN.md, harness/project-context.md]
next: Reviewer
---

# CHANGES — 01-data-layer

## 1. What changed

**项目骨架(Phase 1)**
- `project.godot` — 新建:项目名、features "4.6"、`untyped_declaration=2`(静态类型未标注 = 编译错误)、autoload `Balance`(Phase 3 追加)。
- `.gitignore` — 新建:忽略 `.godot/`。
- `data/{balance,elements,reactions,towers,enemies}`、`scripts/{defs,effects,components,systems}`、`scenes/{towers,enemies,maps,ui}`、`test/cases` — 目录骨架,空目录含 `.gitkeep`。
- `test/test_case.gd` — 新建:TestCase 基类(assert_true / assert_eq,失败收集进 `failures`)。
- `test/run_tests.gd` — 新建:headless 测试跑道(扫描 cases → 反射执行 `test_` 方法 → 汇总 → `quit(0/1)`)。
- `test/cases/test_smoke.gd` — 新建:冒烟用例。

**Resource 类(Phase 2)**
- `scripts/defs/gauge_config.gd` — GaugeConfig 五字段(§4.3 快照)。
- `scripts/effects/reaction_effect.gd` — 积木基类,`apply()` 空实现(逻辑归 02)。
- `scripts/effects/{aoe_damage,knockback,stun,stat_modifier,dot,propagate}_effect.gd` — 6 个参数壳子类,默认值全为中性哨兵。
- `scripts/defs/element_def.gd` — ElementDef(含 `base_status: Array[ReactionEffect]`)。
- `scripts/defs/reaction_def.gd` — ReactionDef(元素资源引用无序对 + `get_cost()`)。
- `scripts/defs/tower_def.gd` / `enemy_def.gd` — 骨架定义(含 `get_attach()` / `innate_element`)。
- `test/cases/test_defs.gd` — override 解析单测(-1 回落 / >=0 覆盖 / 0.0 有效覆盖)。

**数据与 autoload(Phase 3)**
- `data/balance/global_config.tres` — 2 / 1 / 3 / 0 / 0.5(MVP 基准)。
- `data/elements/{fire,ice,lightning,poison}.tres` — id、中文名、占位色、base_status 积木(数值按 PLAN D8)。
- `data/reactions/{steam_burst,overload,combustion,superconduct,brittle,electrolysis}.tres` — 6 反应,effects 按 D8 组装;`combustion`/`superconduct` 的传播用独立 SubResource(主目标与传播参数可分调)。
- `scripts/systems/balance.gd` — autoload:preload global_config,暴露 `config: GaugeConfig`。
- `test/cases/test_data_integrity.gd` — 6 条数据约束断言(见下)。
- `harness/project-context.md` — §5 回填实测命令(含新发现的第 0 步 --import);§6 删两条已解决的坑、新增两条实测坑。

## 2. Why(映射 PLAN 步骤)

Phase 1 两步、Phase 2 六步、Phase 3 六步,PLAN.md §3 中全部 13 步均 `[x]`,一一对应上表;无计划外文件。

## 3. How I verified it

每步执行后均跑(全部退出码 0):
- `godot --headless ... --import` — 刷新导入与全局类缓存,日志无 ERROR。
- `godot --headless ... --check-only -s <script>` — 对每个新脚本单独编译检查(共 12 个脚本全过)。
- `godot --headless ... -s res://test/run_tests.gd` — 最终:**3 用例 0 失败**(smoke / defs override 解析 / 数据完整性)。

数据完整性测试覆盖:global_config 五值 = MVP 基准;4 元素 id 唯一且 base_status 非空;6 反应恰好覆盖 4 元素全部 6 个无序对(与从元素数据派生的期望集比对)、无重复无自反;effects 非空;PropagateEffect.inner 非空;autoload 注册存在。

**Auto 模式局限(需人工时可补验,不阻塞)**:
- Phase 2/3 gate 的"编辑器 Inspector 抽查"(新建资源对话框可见各类型;点开 steam_burst.tres 看到 AoeDamageEffect damage=40/radius=96)未做——headless 已等价验证载入与数值,建议 Reviewer 或人抽查一次。
- 未做 commit(未获授权);每个 Phase 末尾均为干净停点。

## 4. Deviations from the plan

- 无功能性偏差。两处按 PLAN 预留的弹性落地:① `--check-only` 实测必须搭配 `-s`(PLAN Phase 2 第一步 Verify 已预案),已按实测回填 §5;② §6 回填除删两条旧坑外,新增"改类后先 --import"与"-s 下勿依赖 autoload"两条实测发现(属回填步"与实际一致"的应有之义)。

## 5. Wiring Contract

本 feature **无需编辑器接线**(HANDOFF 已裁定):无场景、无节点挂载;autoload 已由代码在 `project.godot` 注册完成。以下记录给后续 feature(02–05)的接口事实:

- **Autoload `Balance`**(`scripts/systems/balance.gd`,已注册)
  - `Balance.config: GaugeConfig` — 运行时读全局数值的唯一入口;**defs 的查询方法不隐式用它**,调用方需显式传:`tower_def.get_attach(Balance.config)`。
- **GaugeConfig 字段**:`default_attach / max_gauge / decay_per_sec / default_cost / reaction_icd`,权威值在 `res://data/balance/global_config.tres`。
- **ElementDef**:`id: StringName`(fire/ice/lightning/poison)、`display_name`、`color`(状态图标/gauge 环用占位色)、`icon`(**现为 null**,美术基线定稿后由 Art Spec 流程补)、`base_status: Array[ReactionEffect]`(约定:gauge > 0 期间持续生效,`duration = -1.0` = 随状态存续——02 的 StatusComponent 负责实现该语义)。
- **ReactionDef**:`element_a/element_b` 为 ElementDef 引用的**无序对**,02 的 ReactionSystem 建表时按两 id 排序拼接作 key;`get_cost(cfg)` 解析消耗;`display_name` 即反应飘字文案;`color` 现为默认白,05 再定。
- **ReactionEffect 子类参数语义**(apply() 由 02 实现):
  - `AoeDamageEffect(damage, radius)`:命中点圆形 AoE。
  - `KnockbackEffect(distance)`:沿命中方向击退。
  - `StunEffect(duration)`:眩晕/冻结通用。
  - `StatModifierEffect(stat, add_flat, add_percent, duration)`:经 ModifierStack 生效;已用 stat 名:`speed`、`armor`、`damage_taken`——02+ 实现属性系统时须支持这三个键。
  - `DotEffect(dps, duration, tick_interval)`。
  - `PropagateEffect(inner, radius)`:**只作用周围敌人,不含主目标**(PLAN D7);主目标要同吃效果时 effects 里并列未包装副本(combustion/superconduct 即此结构)。
- **TowerDef / EnemyDef**:类已备,`.tres` 数值授权归 03/04;`EnemyDef.innate_element` 非空表示自带附着(自带火怪)。
- **测试接入**:新系统的用例放 `res://test/cases/`,`extends TestCase`,`test_` 前缀方法;跑道自动发现。

## 6. Flags / Open questions

- (承 PLAN)D8 占位数值与元素占位色未经过平衡/美术校准;07-balance-sim 与 STYLE-BIBLE 落地前不作承诺。
- (承 PLAN)base_status 持续型语义待 02 实现时确认,仅允许调类接口不动数据布局。
- (承 PLAN)毒 `armor -2.0` 待 03 护甲量表复核;px 距离类数值待 06 地图尺度复核。
- 新发现:`-s` 模式下 autoload 是否实例化未验证(测试未依赖它);02 落地 ReactionSystem 时验证并把结论回填 project-context §6。
- 无 REQUEST CHANGES 遗留;下一棒 Reviewer。
