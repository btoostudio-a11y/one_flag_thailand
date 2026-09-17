extends Node

func _ready() -> void:
	OS.set_environment("ONEFLAG_OFFLINE", "1")
	SupabaseClient.clear_session()
	var main := preload("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(main.current_screen != null and main.current_screen.name == "StartScreen")
	assert(not SupabaseClient.is_logged_in(), "fresh run should be a guest")
	assert(not SupabaseClient.is_configured(), "smoke test explicitly uses offline mode")

	GameManager.request_screen("login")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(main.current_screen != null and main.current_screen.name == "LoginScreen")
	GameManager.request_screen("game")
	await get_tree().process_frame
	await get_tree().process_frame
	var game = main.current_screen
	assert(game != null and game.name == "Game")
	assert(ScoreManager.score == 0)

	var thai := preload("res://objects/ThaiFlag.tscn").instantiate() as FallingObject
	game.object_layer.add_child(thai)
	game.game_started = true
	game._on_object_tapped("thai", thai)
	assert(ScoreManager.score == 100 and ScoreManager.consecutive == 1)
	var wrong := preload("res://objects/USAFlag.tscn").instantiate() as FallingObject
	game.object_layer.add_child(wrong)
	game._on_object_tapped("usa", wrong)
	assert(ScoreManager.score == 100 and ScoreManager.consecutive == 0)
	var bomb := preload("res://objects/Bomb.tscn").instantiate() as FallingObject
	game.object_layer.add_child(bomb)
	game._on_object_tapped("bomb", bomb)
	assert(ScoreManager.score == 0 and ScoreManager.consecutive == 0)

	game._pause_game()
	assert(get_tree().paused)
	game._pause_action("resume")
	assert(not get_tree().paused)
	game.finish_game()
	await get_tree().create_timer(1.3).timeout
	assert(main.current_screen != null and main.current_screen.name == "ResultScreen")
	GameManager.request_screen("game")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(main.current_screen != null and main.current_screen.name == "Game")
	assert(ScoreManager.score == 0 and ScoreManager.thai_flags == 0)
	print("SMOKE_TEST_PASS: input outcomes, pause, finish, and replay")
	get_tree().quit(0)

