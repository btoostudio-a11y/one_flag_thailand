extends Node

signal screen_requested(screen_name: String)
signal thai_flag_collected(points: int)
signal wrong_flag_tapped(kind: String)
signal bomb_tapped
signal altitude_changed(altitude: int)
signal game_finished

var last_result := {"score": 0, "flags": 0, "best_combo": 0, "rank": 128}
var logged_in := false

func _ready() -> void:
	logged_in = SupabaseClient.is_logged_in()
	SupabaseClient.login_state_changed.connect(func(_state: bool): logged_in = _state)

func is_logged_in() -> bool:
	return logged_in

func request_screen(screen_name: String) -> void:
	screen_requested.emit(screen_name)

func set_result(score: int, flags: int, best_combo: int) -> void:
	last_result = {
		"score": score,
		"flags": flags,
		"best_combo": best_combo,
		"rank": LeaderboardManager.estimate_rank(score)
	}

