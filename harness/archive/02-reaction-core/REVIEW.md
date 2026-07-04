---
artifact: REVIEW
feature: 02-reaction-core
role: Reviewer
status: accepted
updated: 2026-07-04
inputs: [harness/project-context.md, harness/features/02-reaction-core/PLAN.md, harness/features/02-reaction-core/CHANGES.md, 实际代码全量(scripts/ test/ data/ project.godot diff), headless 实测复跑]
next: Producer
---

# REVIEW — 02-reaction-core(首次审查)

## 1. Verdict

**APPROVE WITH NITS**

实现忠实于 PLAN D1–D10,无正确性阻断项。所有验证结论我均亲测复现,不是转抄 CHANGES:
- `--import` exit 0、0 ERROR;`run_tests.gd` exit 0,**10 用例 0 失败**,六反应 e2e 逐条 PASSED。
- 断言计数防线亲测有效:插入零断言探针用例 → 整体 exit 1 且指名该方法;删除后回绿。

## 2. Must-fix (blocking)

无。

## 3. Should-fix (non-blocking)

- `scripts/systems/reaction_system.gd:24` — **导出包地雷**:`_ready()` 自接线用 `file_name.ends_with(".tres")` 过滤 DirAccess 列表,但 Godot 导出 PCK 后资源文件名会变成 `*.tres.remap`,该过滤全部落空 → 导出版反应表为空且**无任何报错**(目录打得开,只是没匹配)。MVP 编辑器/dev 运行不受影响,但首次导出前必须处理。建议:匹配时剥掉 `.remap` 后缀(`file_name.trim_suffix(".remap")` 再判 `.tres`),或改用显式清单 + `ResourceLoader`。若本轮不改,须作为 flag 挂到 BACKLOG,别等导出当天踩。
- `scripts/effects/propagate_effect.gd:23` — `ctx.duplicate(false)` 浅拷贝后 `handle_sink` 数组仍与主目标共享(CHANGES §6 已自曝)。当前数据 base_status 无传播效果、反应路径不带 sink,确无实害,但这是一颗已知的埋雷,一行就能拆:`neighbor_ctx.erase("handle_sink")`(邻居的持续效果自有 duration 自然到期,本就不该进主目标的回滚列表)。改掉后 CHANGES/HANDOFF 该 flag 可直接销案,好过留一条"未来重审"的债。
- `harness/features/02-reaction-core/CHANGES.md` §5 Wiring Contract — **补一条对 03 的硬约束**:`take_damage` 的实现**不得在调用内同步 `free()` 敌人**(死亡走 `queue_free`)。理由:`reaction_effect.gd:61-64` 的组员遍历与 `active_effects.gd:38-49` 的 tick 循环都会在迭代中途调用 `take_damage`,同步释放 = 迭代中 use-after-free。这是文档补充,不动代码;现在写清楚,03 就不会踩。

## 4. Nits

- `scripts/components/modifier_stack.gd:32` — `resolve` 无下限保护,叠负 pct 可算出负值(如两个 -60% → 速度为负)。MVP 数据最多单实例 -30% 触发不了;留给 03 消费端 `maxf(0.0, ...)` 或将来在契约里约定,先记一笔。
- `test/cases/test_reactions_e2e.gd:84-89` — `_count_damage` 靠伤害数值区分 dot 来源(灼烧跳伤 2.5 vs 燃爆跳伤 4.0)。若将来平衡改数导致两值相撞,计数会上翻使测试**响亮失败**(不是假绿),可接受;改平衡数值时留意此耦合。
- `"ActiveEffects"` / `"ModifierStack"` 等具名子节点字符串散在三处(`reaction_effect.gd:40/44`、`status_component.gd:81`、`stub_enemy.gd`),可收拢为常量。低价值,顺手时再做。

## 5. What I checked but found fine

- **正确性**:ActiveEffects 计时/取消语义(`keys()` 快照迭代 + `has` 防卫,cancel 幂等,-1 永续,到期恰好一次 on_end);DotEffect 首跳满间隔后、while 累加器补跳、到期停伤;ModifierStack 公式 `(base+Σflat)*(1+Σpct)`、句柄移除幂等、双眩晕计数不误清;StatusComponent 附着 clamp/同元素叠层/衰减归零/过期句柄回滚/异元素纯转发不自决;try_react 定序与 D8/D9 逐条吻合(ICD 拦截 → 查表 → 设 ICD → 扣量 → 效果 → 信号,incoming 吞掉不附着);扣到 0 先回滚 base 再执行反应效果(D9「效果见终值」设计如述);ICD 存活在组件上、跨状态存续 = per-enemy 冷却语义,自洽。
- **数据互derive**:6 反应 `.tres` 与 e2e 期望全部从 cfg/def/效果字段推导核对过;燃爆主 dot(4.0/跳)与火 base 灼烧(2.5/跳)数值不同,`_count_damage` 过滤不互污(见 Nit 2 的耦合备注)。
- **忠实度**:PLAN 全步骤 `[x]`、无 `[~]` 搁浅;diff 与 CHANGES §1 清单一致;三条偏差核实为真且均合理(跑道首帧执行有探针实据并回填 §6;recording_bus 确有两个消费者;基类 helpers 是 D6/D7/D10 授权机制的收拢)。四个 Playtest gate 均为「headless 全绿」型,已亲测复现;CHANGES 声明的遗留人工确认项(编辑器开项目无报错 + autoload 面板三条)按 role 规范**保持为未验开放项**,列入 HANDOFF flags,不视为已过。
- **安全**:无外部输入面;DirAccess 限定 `res://data/reactions`;鸭子调用全程 `has_method` 防卫 fail-soft;无秘钥/注入面。
- **过度工程**:未见——组件均薄(30–90 行),无预留泛化,RecordingBus 有两个真实消费者,helper 收拢在基类合理。
- **约定**(project-context §3/§4):静态类型全覆盖;信号过去式;运行时零数值字面量(`&"stunned"` +1 为计划明示的布尔编码);无 match 分支,加反应 = 加 `.tres`;运行时零 `.tres` 写入,增益全走 ModifierStack;效果自身零字段写入(享元,flag ① 回归测试在案)。
- **文档回填**:project-context §3 新约定与 §6 新坑(autoload 已加载、`_initialize` root 未入树)与实测一致;Wiring Contract 点名了 03/04/05 需消费的全部契约(除 Should-fix 3 待补的一条)。
