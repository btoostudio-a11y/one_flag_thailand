extends Node

signal login_state_changed(logged_in: bool)
signal save_changed
var state_path := "user://one_flag/standalone.json"
var access_token := ""
var refresh_token := ""
var user_id := ""
var user_name := ""
var expires_at := 0
var receipts: Array = []
var last_saved: Dictionary = {}
var last_error := ""
var round_token := ""
var last_round_token := ""
var round_plan: Array = []
var start_tick := 0.0
var active := false
var connecting := false
var saving := false
var restoring := false
var pending: Array = []
var sending := false
var failed := false

func _ready() -> void:
	if OS.get_environment("ONEFLAG_TEST_STORAGE") == "1": state_path = "user://one_flag/test-standalone.json"
	if OS.get_environment("ONEFLAG_OFFLINE") == "1": return
	if FileAccess.file_exists(state_path):
		var value = JSON.parse_string(FileAccess.get_file_as_string(state_path))
		if value is Dictionary:
			refresh_token = str(value.get("refresh_token", ""))
			last_round_token = str(value.get("last_round_token", ""))
			var stored = value.get("receipts", [])
			if stored is Array:
				for receipt in stored:
					if receipt is Dictionary and valid_token(receipt.get("token", "")): receipts.append(receipt)
	if not refresh_token.is_empty(): await refresh_session()
	if not valid_token(last_round_token):
		for receipt in receipts:
			if receipt.get("saved",false): last_round_token = str(receipt.token)
	if valid_token(last_round_token) and not active and not connecting:
		await restore_last_round()

func restore_last_round() -> void:
	if restoring or saving or connecting: return
	restoring = true
	active = false
	last_saved = {}
	last_error = ""
	save_changed.emit()
	if valid_token(last_round_token):
		var expected_round := round_token
		var recent := await api("result",last_round_token)
		if round_token != expected_round: return
		if recent.get("saved",false): last_saved = recent
		else: last_error = "Unable to load the last saved round. Please retry."
	else:
		last_error = "No saved round on this device yet."
	restoring = false
	save_changed.emit()

func is_configured() -> bool:
	return OS.get_environment("ONEFLAG_OFFLINE") != "1" and SupabaseConfig.SUPABASE_URL.begins_with("https://") and not SupabaseConfig.SUPABASE_ANON_KEY.is_empty()

func is_logged_in() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()

func get_user_id() -> String:
	return user_id

func get_user_name() -> String:
	return user_name if not user_name.is_empty() else "Player"

func persist() -> void:
	if OS.get_environment("ONEFLAG_OFFLINE") == "1": return
	DirAccess.make_dir_recursive_absolute("user://one_flag")
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"refresh_token":refresh_token,"receipts":receipts,"last_round_token":last_round_token}))

func valid_token(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true

func random_token() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()

func request_id() -> String:
	var raw := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-4%s-8%s-%s" % [raw.substr(0,8),raw.substr(8,4),raw.substr(13,3),raw.substr(17,3),raw.substr(20,12)]

func http(path: String, body: Dictionary, bearer := "") -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 10.0
	request.body_size_limit = 262144
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + SupabaseConfig.SUPABASE_ANON_KEY])
	if not bearer.is_empty(): headers.append("Authorization: Bearer " + bearer)
	var code := request.request(SupabaseConfig.SUPABASE_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if code != OK:
		request.queue_free()
		return {"error":"network_error","http":0}
	var reply: Array = await request.request_completed
	request.queue_free()
	if int(reply[0]) != HTTPRequest.RESULT_SUCCESS: return {"error":"network_error","http":0}
	var parsed = JSON.parse_string((reply[3] as PackedByteArray).get_string_from_utf8())
	if int(reply[1]) < 200 or int(reply[1]) >= 300:
		return {"error":str(parsed.get("error_description",parsed.get("msg",parsed.get("error","request_failed")))) if parsed is Dictionary else "request_failed","http":int(reply[1])}
	return {"data":parsed,"http":int(reply[1])}

func api(action: String, token := "", extra: Dictionary = {}, auth := "") -> Dictionary:
	var error_message := "network_error"
	var body := {"action":action}
	if not token.is_empty(): body["token"] = token
	body.merge(extra)
	for attempt in range(3):
		var response := await http("/functions/v1/standalone-game",body,auth)
		if response.has("data"):
			if response.data is Dictionary: return response.data
			return {"rows":response.data}
		error_message = str(response.get("error","network_error"))
		if int(response.get("http",0)) >= 400 and int(response.get("http",0)) < 500: return {"error":error_message}
		if attempt < 2: await get_tree().create_timer(0.3 * (attempt+1)).timeout
	return {"error":error_message}

func start_round() -> bool:
	if saving or sending or connecting: return false
	restoring = false
	active = false
	failed = false
	pending.clear()
	last_saved = {}
	last_error = ""
	if not is_configured(): return true
	connecting = true
	round_token = random_token()
	# Save the guest capability before any network operation.
	receipts.append({"token":round_token,"created":Time.get_unix_time_from_system()})
	while receipts.size()>100: receipts.pop_front()
	persist()
	var result := await api("begin",round_token)
	connecting = false
	if result.has("error"):
		last_error = str(result.error)
		return false
	round_plan = result.plan
	start_tick = Time.get_ticks_msec() + float(result.startsAt) - float(result.serverNow)
	active = true
	return true

func elapsed() -> float:
	return (Time.get_ticks_msec()-start_tick)/1000.0

func hit(object_id: int) -> void:
	if not active or saving: return
	pending.append({"objectId":object_id,"requestId":request_id()})
	if not sending: _drain()

func _drain() -> void:
	sending = true
	while not pending.is_empty():
		var result := await api("hit",round_token,pending.pop_front())
		if result.has("error"): failed = true
	sending = false

func finish_round() -> void:
	if not active or saving: return
	saving = true
	last_error = ""
	save_changed.emit()
	while sending: await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var result := await api("finish",round_token)
	if result.has("error"):
		last_error = "Could not confirm saving. Retry before leaving."
	else:
		last_saved = result
		last_saved["incomplete_inputs"] = failed
		last_round_token = round_token
		for receipt in receipts:
			if receipt.token == round_token: receipt["saved"] = true
		persist()
		if is_logged_in(): await claim_scores()
	saving = false
	save_changed.emit()

func claim_scores() -> void:
	if not is_logged_in(): return
	if Time.get_unix_time_from_system() >= expires_at-30: await refresh_session()
	if not is_logged_in(): return
	for receipt in receipts.duplicate():
		var token: String = receipt.token
		var result := await api("result",token)
		if result.get("saved",false):
			var claimed := await api("claim",token,{},access_token)
			if claimed.get("claimed",false):
				receipts.erase(receipt)
				if token==round_token or last_saved.get("id","")==result.get("id","-"): last_saved["claimed"] = true
	persist()

func signup(email: String, password: String, display_name: String) -> bool:
	var result := await http("/auth/v1/signup",{"email":email.strip_edges(),"password":password,"data":{"display_name":display_name.strip_edges().left(40)}})
	if result.has("error"):
		last_error = result.error
		return false
	return true

func login(email: String, password: String) -> bool:
	var result := await http("/auth/v1/token?grant_type=password",{"email":email.strip_edges(),"password":password})
	if result.has("error"):
		last_error = result.error
		return false
	if not accept_session(result.data): return false
	await claim_scores()
	save_changed.emit()
	return true

func accept_session(data: Dictionary) -> bool:
	var user: Dictionary = data.get("user",{})
	if not user.get("email_confirmed_at") or user.get("is_anonymous",false):
		last_error = "Verify your email before signing in."
		return false
	access_token = str(data.get("access_token",""))
	refresh_token = str(data.get("refresh_token",""))
	user_id = str(user.get("id",""))
	user_name = str(user.get("user_metadata",{}).get("display_name","Player"))
	expires_at = int(Time.get_unix_time_from_system()) + int(data.get("expires_in",3600))
	persist()
	login_state_changed.emit(true)
	return true

func refresh_session() -> void:
	var expected_token := refresh_token
	var result := await http("/auth/v1/token?grant_type=refresh_token",{"refresh_token":refresh_token})
	if refresh_token != expected_token: return
	if result.has("data"): accept_session(result.data)
	elif int(result.get("http",0)) in [400,401,403]: clear_session()

func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	user_name = ""
	persist()
	login_state_changed.emit(false)

func logout() -> void:
	# Local removal is immediate; revoke server refresh sessions when reachable.
	var old_token := access_token
	clear_session()
	if not old_token.is_empty(): await http("/auth/v1/logout",{},old_token)

func fetch_top10() -> Array:
	if not is_configured(): return []
	var result := await api("leaderboard")
	return result.get("rows",[])
