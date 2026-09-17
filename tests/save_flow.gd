extends Node

class FakeClient extends "res://scripts/supabase_client.gd":
	var fail_request := false
	var hit_requests := 0
	func _ready() -> void:
		pass
	func persist() -> void:
		pass
	func api(_action: String, _token := "", _extra: Dictionary = {}, _auth := "") -> Dictionary:
		if _action == "hit": hit_requests += 1
		await get_tree().create_timer(0.01).timeout
		if fail_request: return {"error":"network_error"}
		return {"id":"test-round","saved":true,"score":100,"claimed":false}

	func http(_path: String, _body: Dictionary, _bearer := "") -> Dictionary:
		await get_tree().create_timer(0.01).timeout
		return {"error":"expired_refresh","http":401}

func _ready() -> void:
	var client := FakeClient.new()
	add_child(client)
	assert(client.valid_token("a".repeat(64)))
	assert(not client.valid_token(null))
	assert(not client.valid_token({"token":"a".repeat(64)}))
	assert(not client.valid_token("z".repeat(64)))
	var states: Array = []
	client.save_changed.connect(func(): states.append(client.saving))
	client.active = true
	client.round_token = "a".repeat(64)
	client.finish_round()
	assert(client.saving)
	assert(states == [true], "retry must immediately notify UI to lock navigation")
	assert(not await client.start_round(), "cannot start a new round while saving")
	while client.saving: await get_tree().process_frame
	assert(states == [true,false])
	assert(client.last_saved.score == 100)
	assert(client.last_round_token == client.round_token, "remember saved token independently of unclaimed receipts")
	client.receipts.clear()
	assert(client.last_round_token == "a".repeat(64))
	client.fail_request = true
	client.finish_round()
	assert(client.saving)
	while client.saving: await get_tree().process_frame
	assert(not client.last_error.is_empty())
	assert(states == [true,false,true,false], "failed retry unlocks UI")
	client.active = true
	client.hit(0)
	while client.sending: await get_tree().process_frame
	assert(client.failed)
	client.fail_request = false
	client.hit(1)
	while client.sending: await get_tree().process_frame
	assert(client.hit_requests == 2, "network recovery must allow later taps")
	await client.finish_round()
	assert(client.last_saved.get("incomplete_inputs",false))
	client.fail_request = true
	await client.restore_last_round()
	assert(not client.restoring and not client.last_error.is_empty())
	client.fail_request = false
	await client.restore_last_round()
	assert(client.last_saved.score == 100 and not client.restoring)
	client.refresh_token = "old-refresh"
	client.refresh_session()
	client.refresh_token = "new-refresh"
	client.access_token = "new-access"
	await get_tree().create_timer(0.03).timeout
	assert(client.access_token == "new-access", "stale refresh cannot clear newer login")
	print("RECOVERY_PASS: later hits, partial warning, saved-result retry, stale auth rejection")
	print("SAVE_FLOW_PASS: retry lock, completion/failure, retained last round, malformed token rejection")
	get_tree().quit(0)
