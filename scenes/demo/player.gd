extends CharacterBody2D

## 演示用角色：WASD 或方向键移动，自动加入 "player" 组，
## 以便 Fog / Rain 节点的 activate_with_player 能检测到它。

@export var speed: float = 380.0

func _ready() -> void:
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
