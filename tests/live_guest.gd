extends Node
var tapped := false
var deadline := 0
func _ready() -> void:
	deadline = Time.get_ticks_msec() + 90000
	var main := preload("res://scenes/Main.tscn").instantiate()
	add_child(main)
	GameManager.request_screen("game")
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var game = main.current_screen
		if game.name == "Game" and game.game_started and not tapped:
			for object in game.object_layer.get_children():
				if object is FallingObject and object.object_type == "thai" and object.position.y < 1850:
					game._on_object_tapped("thai",object)
					tapped = true
					break
		if SupabaseClient.last_saved.get("saved",false):
			if int(SupabaseClient.last_saved.score)!=100:
				push_error("Expected one real server-verified hit: "+JSON.stringify(SupabaseClient.last_saved))
				get_tree().quit(1)
				return
			if not OS.get_environment("ONEFLAG_TEST_EMAIL").is_empty():
				var ok := await SupabaseClient.login(OS.get_environment("ONEFLAG_TEST_EMAIL"), OS.get_environment("ONEFLAG_TEST_PASSWORD"))
				if not ok or not SupabaseClient.last_saved.get("claimed", false):
					push_error("Godot login/claim failed: " + SupabaseClient.last_error)
					get_tree().quit(1)
					return
				print("LIVE_ACCOUNT_PASS: Godot login linked guest score")
			print("LIVE_GUEST_PASS: id="+str(SupabaseClient.last_saved.id)+" score=100")
			get_tree().quit(0)
			return
	push_error("Live round failed: "+SupabaseClient.last_error)
	get_tree().quit(1)
