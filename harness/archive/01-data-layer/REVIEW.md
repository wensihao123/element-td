---
artifact: REVIEW
feature: 01-data-layer
role: Reviewer
status: accepted
updated: 2026-07-04
inputs: [PLAN.md, CHANGES.md, harness/project-context.md, 工作区全量代码与 .tres]
next: Producer
---

# REVIEW — 01-data-layer(FIRST review)

## 1. Verdict

**APPROVE WITH NITS**

实现与 PLAN 高度一致:13 步全 `[x]` 且与实际文件一一对应,无计划外改动;11 个 `.tres` 数值、组装、占位色与 D8 表逐项核对无误;本人独立复跑 `--import`(退出码 0、无 ERROR)、headless 测试(3 用例 0 失败)、`--check-only` 抽查(退出码 0),CHANGES 的验证声称属实。无阻塞项。

## 2. Must-fix (blocking)

(无)

## 3. Should-fix (non-blocking)

- `test/run_tests.gd:38` — `case.call(method_name)` 对测试方法内的**运行时脚本错误**没有防线:GDScript 运行时错误会中止该方法但不中止跑道,若崩溃发生在任何断言之前,`failures` 为空,该用例被误报 PASSED(假绿)。本 feature 的 3 个用例都跑通了、不受影响,但 02 开始写逻辑测试后这是真实风险。建议方向:给 TestCase 加断言计数,`test_` 方法执行后断言数为 0 视为失败("零断言 = 可疑");或在跑道层比对执行前后的断言计数。归 02 或其前置小步落地即可。
- `CHANGES.md:70`(Wiring Contract)— 缺一条关键运行时约束:`.tres` 里的 effect SubResource 经 `load()` 后是**共享实例**——fire.tres 的 DotEffect 附着到 10 个敌人时是同一个 Resource 对象。02 实现 `apply()` 时必须保持效果类无状态(运行时状态住 StatusComponent / ModifierStack,不得写 effect 自身字段),否则跨目标串状态。这与硬 NO"运行时修改 .tres 字段 = bug"同源,但值得在给 02 的接口契约里点名。已由我补进 HANDOFF 未决 flags,Implementer 不必为此返工。

## 4. Nits (optional)

- `test/cases/test_data_integrity.gd:45` — 元素 `base_status` 只断言非空,未像反应侧(`:79` 检查空效果槽)那样检查数组内 null 槽;两侧不对称。忠实于 PLAN ⑥ 的字面要求,补上更稳。
- `CHANGES.md:48` — "共 12 个脚本全过"实为 Phase 2 的 12 个 defs/effects 脚本;balance.gd 与 5 个测试脚本不在此计数内,措辞易误读为全部脚本。已由 --import 与实测兜底,无实质影响。

## 5. What I checked but found fine

- **正确性 / 数据核对**:11 个 `.tres` 逐个对照 PLAN D8——global_config 五值 2/1/3/0/0.5;四元素 base_status 积木类型与数值(含 hex→线性色值换算:fire #e25822 / ice #7fdbff / lightning #f5d547 / poison #7cb518 全部精确匹配);六反应 effects 组装(steam_burst AoE 40/96、overload AoE 30/64 + 击退 48、combustion 主/传播双 DoT 8-4-0.5 + 半径 96、superconduct 主/传播双冻结 1.5 + 半径 96、brittle 易伤 +0.40/5s、electrolysis 眩晕 1.0);元素无序对恰好覆盖 6 组合,与 D7 命名一致;combustion/superconduct 传播用独立 SubResource,主目标与传播参数可分调(符合 D7 的 PropagateEffect 语义)。
- **验证复跑(不取信 CHANGES 自述)**:`--import` 退出码 0、日志无 ERROR;`run_tests.gd` 3 用例 0 失败、显式 quit;`--check-only -s` 抽查 reaction_def.gd 退出码 0——project-context §5 回填的命令逐条真实可用。
- **PLAN 忠实度**:13 步全 `[x]` 无 `[~]`,每步 Files 与工作区一致;三个 Phase 的 Playtest gate 均为纯管道型,确认项(命令退出码 0)已由我复验。Phase 2/3 gate 的"编辑器 Inspector 抽查"是**可选项**且 CHANGES 如实声明未做——headless 已等价覆盖载入与数值,不阻塞;该项保留在 HANDOFF flags 供人抽查。
- **硬 NO 逐条**:代码无游戏数值字面量(GaugeConfig 类默认值为 PLAN D5 特批的 §4.3 快照,测试断言以 .tres 为权威;效果类默认值全为 0.0/-1.0 中性哨兵)✓;无运行时改 `.tres`(全部参数壳)✓;无 match 分支(反应 = Resource 组装)✓;无跨系统直接引用(defs 零 autoload 依赖,get_attach/get_cost 显式传参,与 D2 一致)✓;无顺手重构/计划外功能(scenes/、towers/、enemies/ 仅 .gitkeep 空目录)✓。
- **约定**:18 个 .gd 全静态类型(含 for 循环变量标注)、`untyped_declaration=2` 机制化兜底;文件 snake_case、类 PascalCase;Resource 类全带 `class_name`(balance.gd 作为 autoload 正确地不带)。
- **安全**:纯数据层,无输入处理、网络、密钥面;DirAccess 仅读 res://test/cases。
- **过度工程**:自研 ~50 行跑道替代 GUT 与测试面匹配;effects 仅参数壳无预写逻辑;Balance autoload 3 行,均无多余抽象。
- **project-context 回填**:§5 命令与实测一致;§6 新增两条坑(改类后先 --import、-s 下勿依赖 autoload)与 CHANGES §4 声称吻合。
