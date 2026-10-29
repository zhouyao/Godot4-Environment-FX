extends Control

const FOG_SCENE := "res://scenes/demo/fog.tscn"
const RAIN_SCENE := "res://scenes/demo/rain_demo.tscn"
const SNOW_SCENE := "res://scenes/demo/snow_demo.tscn"

@onready var fog_button: Button = $VBox/FogButton
@onready var rain_button: Button = $VBox/RainButton
@onready var snow_button: Button = $VBox/SnowButton


func _ready() -> void:
	fog_button.pressed.connect(_on_fog_pressed)
	rain_button.pressed.connect(_on_rain_pressed)
	snow_button.pressed.connect(_on_snow_pressed)


func _on_fog_pressed() -> void:
	get_tree().change_scene_to_file(FOG_SCENE)


func _on_rain_pressed() -> void:
	get_tree().change_scene_to_file(RAIN_SCENE)


func _on_snow_pressed() -> void:
	get_tree().change_scene_to_file(SNOW_SCENE)
