extends Control

const SCREENS := {
	"start": preload("res://scenes/StartScreen.tscn"),
	"game": preload("res://scenes/Game.tscn"),
	"result": preload("res://scenes/ResultScreen.tscn"),
	"leaderboard": preload("res://scenes/Leaderboard.tscn"),
	"login": preload("res://scenes/LoginScreen.tscn")
}

var current_screen: Node

func _ready() -> void:
	GameManager.screen_requested.connect(show_screen)
	show_screen("start")

func show_screen(screen_name: String) -> void:
	get_tree().paused = false
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null
	if not SCREENS.has(screen_name):
		screen_name = "start"
	current_screen = SCREENS[screen_name].instantiate()
	add_child(current_screen)

