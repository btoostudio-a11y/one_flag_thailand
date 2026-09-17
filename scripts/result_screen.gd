extends Control
var score_label: Label
var state_label: Label
var retry: Button
var navigation: Array[Button] = []

func _ready() -> void:
	var bg := TextureRect.new()
	UIFactory.fill_parent(bg)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/backgrounds/bg_finish.png"): bg.texture = load("res://assets/backgrounds/bg_finish.png")
	add_child(bg)
	var shade := ColorRect.new()
	UIFactory.fill_parent(shade)
	shade.color = Color(0.01,0.08,0.25,0.65)
	add_child(shade)
	var stack := VBoxContainer.new()
	stack.position = Vector2(100,200)
	stack.size = Vector2(880,1500)
	stack.add_theme_constant_override("separation",24)
	add_child(stack)
	var title := UIFactory.make_label("MISSION COMPLETE!",72,Color("#ffe04b"))
	title.custom_minimum_size = Vector2(880,180)
	stack.add_child(title)
	score_label = UIFactory.make_label(str(GameManager.last_result.get("score",0)),130)
	score_label.custom_minimum_size = Vector2(880,210)
	stack.add_child(score_label)
	state_label = UIFactory.make_label("",34,Color("#8ce7ff"))
	state_label.custom_minimum_size = Vector2(880,280)
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(state_label)
	retry = action(stack,"RETRY SAVE",_retry)
	action(stack,"PLAY AGAIN",func(): GameManager.request_screen("game"))
	action(stack,"ACCOUNT / LINK MY SCORES",func(): GameManager.request_screen("login"))
	action(stack,"RANKING",func(): GameManager.request_screen("leaderboard"))
	action(stack,"HOME",func(): GameManager.request_screen("start"))
	SupabaseClient.save_changed.connect(refresh)
	refresh()

func action(parent: Node,text: String,callback: Callable) -> Button:
	var button := UIFactory.make_button(text,Color("#1769d2"),Vector2(880,115))
	button.pressed.connect(callback)
	parent.add_child(button)
	navigation.append(button)
	return button

func refresh() -> void:
	for button in navigation: button.disabled = SupabaseClient.saving or SupabaseClient.restoring
	retry.visible = false
	if not SupabaseClient.is_configured():
		state_label.text = "OFFLINE PRACTICE\nThis score is not saved to the server."
		return
	if SupabaseClient.restoring:
		state_label.text = "Loading your saved score..."
		return
	if SupabaseClient.saving:
		state_label.text = "Saving your score..."
		return
	var saved: Dictionary = SupabaseClient.last_saved
	if saved.get("saved",false):
		score_label.text = str(saved.score)
		state_label.text = "SAVED TO DATABASE\n" + ("Linked to your account." if saved.get("claimed",false) else "Saved as Guest. Sign in whenever you want\nto link this score to your account.")
		if saved.get("incomplete_inputs",false): state_label.text += "\nConnection interrupted: some taps were not confirmed."
		state_label.text += "\nRound: " + str(saved.id).left(8)
		GameManager.last_result["score"] = int(saved.score)
	elif not SupabaseClient.last_error.is_empty():
		state_label.text = "SAVE NOT CONFIRMED\n" + SupabaseClient.last_error
		retry.visible = SupabaseClient.active or SupabaseClient.valid_token(SupabaseClient.last_round_token)
		retry.text = "RETRY SAVE" if SupabaseClient.active else "RETRY LOADING"
	else:
		state_label.text = "No saved round on this device yet."

func _retry() -> void:
	if SupabaseClient.active: SupabaseClient.finish_round()
	else: SupabaseClient.restore_last_round()
