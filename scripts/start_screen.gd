extends Control

func _ready() -> void:
	var bg := TextureRect.new()
	UIFactory.fill_parent(bg)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/backgrounds/bg_aircraft.png"):
		bg.texture = load("res://assets/backgrounds/bg_aircraft.png")
	else:
		bg.modulate = Color("58c7f3")
	add_child(bg)

	var shade := ColorRect.new()
	UIFactory.fill_parent(shade)
	shade.color = Color(0.01, 0.08, 0.25, 0.20)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var logo := TextureRect.new()
	logo.position = Vector2(90, 190)
	logo.size = Vector2(900, 600)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/logo_one_flag_thailand.png"):
		logo.texture = load("res://assets/ui/logo_one_flag_thailand.png")
	add_child(logo)

	var subtitle := UIFactory.make_label("FALLING TAP GAME", 52, Color("ffe36e"))
	subtitle.position = Vector2(150, 720)
	subtitle.size = Vector2(780, 90)
	add_child(subtitle)

	var stack := VBoxContainer.new()
	stack.position = Vector2(190, 1100)
	stack.size = Vector2(700, 400)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 26)
	add_child(stack)
	var start_button := UIFactory.make_button("▶  TAP TO START", Color("ef3340"), Vector2(700, 150))
	start_button.pressed.connect(func(): GameManager.request_screen("game"))
	stack.add_child(start_button)
	var instruction := UIFactory.make_label("แตะธงไทย เก็บคะแนน!", 38)
	instruction.custom_minimum_size = Vector2(700, 70)
	stack.add_child(instruction)
	var ranking := UIFactory.make_button("🏆  RANKING", Color("145cc9"), Vector2(520, 105))
	ranking.pressed.connect(func(): GameManager.request_screen("leaderboard"))
	stack.add_child(ranking)
	var account_label := "👤  SIGN IN"
	var account_color := Color("1769d2")
	if SupabaseClient.is_logged_in():
		account_label = "👤  " + SupabaseClient.get_user_name()
		account_color = Color("0a9169")
	var account := UIFactory.make_button(account_label, account_color, Vector2(520, 105))
	account.pressed.connect(func(): GameManager.request_screen("login"))
	stack.add_child(account)
	if SupabaseClient.valid_token(SupabaseClient.last_round_token):
		var saved := UIFactory.make_button("LAST SAVED SCORE", Color("1769d2"), Vector2(520,105))
		saved.pressed.connect(func(): SupabaseClient.restore_last_round(); GameManager.request_screen("result"))
		stack.add_child(saved)

	var tween := create_tween().set_loops()
	tween.tween_property(start_button, "scale", Vector2(1.035, 1.035), 0.65).set_trans(Tween.TRANS_SINE)
	tween.tween_property(start_button, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE)

