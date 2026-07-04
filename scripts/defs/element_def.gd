class_name ElementDef
extends Resource

## 元素定义(纯数据)。
## base_status:gauge > 0 期间持续生效的基础状态积木(持续型语义由 02 的 StatusComponent 定义,PLAN D4)。

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var icon: Texture2D
@export var base_status: Array[ReactionEffect] = []
