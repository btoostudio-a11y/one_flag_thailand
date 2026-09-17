extends Control

var spawn_manager: SpawnManager
var background: BackgroundManager
var object_layer: Node2D
var player: Node2D
var score_value: Label
var combo_value: Label
var altitude_value: Label
var countdown_label: Label
var red_flash: ColorRect
var pause_panel: Control

var countdown_elapsed := 0.0
var elapsed := 0.0
var game_started := false
var preparing := true
var finishing := false
var shake_time := 0.0
var base_position := Vector2.ZERO

func _ready() -> void:
	ScoreManager.reset()
	background = BackgroundManager.new()
	UIFactory.fill_parent(background)
	add_child(background)
	object_layer = Node2D.new()
	object_layer.name = "ObjectLayer"
	add_child(object_layer)
	player = preload("res://objects/Player.tscn").instantiate()
	player.position = Vector2(540, 900)
	add_child(player)
	build_hud()
	build_countdown()
	build_pause_menu()
	red_flash = ColorRect.new()
	UIFactory.fill_parent(red_flash)
	red_flash.color = Color(1, 0.05, 0.05, 0)
	red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(red_flash)
	spawn_manager = SpawnManager.new()
	spawn_manager.object_tapped.connect(_on_object_tapped)
	add_child(spawn_manager)
	ScoreManager.score_changed.connect(func(value): score_value.text = str(value))
	ScoreManager.combo_changed.connect(func(multiplier, _chain): combo_value.text = "x%d" % multiplier)
	base_position = position
	_prepare_round()

func _prepare_round() -> void:
	countdown_label.text = "CONNECTING"
	countdown_label.add_theme_font_size_override("font_size", 80)
	var ok := await SupabaseClient.start_round()
	if not ok:
		countdown_label.text = "CONNECTION FAILED"
		var back := UIFactory.make_button("BACK / RETRY", Color("1769d2"), Vector2(700, 120))
		back.position = Vector2(190, 1150)
		back.pressed.connect(func(): GameManager.request_screen("start"))
		add_child(back)
		return
	countdown_label.add_theme_font_size_override("font_size", 210)
	preparing = false

func build_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_bottom = 270
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hud)
	var bg_panel := Panel.new()
	bg_panel.position = Vector2(25, 28)
	bg_panel.size = Vector2(1030, 205)
	bg_panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color(0.02, 0.16, 0.43, 0.91), 38, Color("66d6ff"), 5))
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bg_panel)
	score_value = make_hud_cell(hud, "SCORE", "0", Vector2(55, 52), 260)
	combo_value = make_hud_cell(hud, "COMBO", "x1", Vector2(350, 52), 260)
	altitude_value = make_hud_cell(hud, "ALTITUDE", "3000 m", Vector2(645, 52), 285)
	var pause_button := UIFactory.make_button("Ⅱ", Color("1769d2"), Vector2(105, 105))
	pause_button.position = Vector2(935, 78)
	pause_button.add_theme_font_size_override("font_size", 48)
	pause_button.pressed.connect(_pause_game)
	pause_button.visible = not SupabaseClient.is_configured()
	hud.add_child(pause_button)

func make_hud_cell(parent: Control, title: String, value: String, pos: Vector2, width: float) -> Label:
	var title_label := UIFactory.make_label(title, 27, Color("98e8ff"))
	title_label.position = pos
	title_label.size = Vector2(width, 45)
	parent.add_child(title_label)
	var value_label := UIFactory.make_label(value, 48)
	value_label.position = pos + Vector2(0, 45)
	value_label.size = Vector2(width, 72)
	parent.add_child(value_label)
	return value_label

func build_countdown() -> void:
	countdown_label = UIFactory.make_label("3", 210, Color("ffe14d"))
	countdown_label.position = Vector2(190, 690)
	countdown_label.size = Vector2(700, 360)
	add_child(countdown_label)

func build_pause_menu() -> void:
	pause_panel = Control.new()
	UIFactory.fill_parent(pause_panel)
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.visible = false
	add_child(pause_panel)
	var dim := ColorRect.new()
	UIFactory.fill_parent(dim)
	dim.color = Color(0.01, 0.03, 0.12, 0.82)
	pause_panel.add_child(dim)
	var card := Panel.new()
	card.position = Vector2(150, 440)
	card.size = Vector2(780, 960)
	card.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("08367c"), 52, Color("65d7ff"), 6))
	pause_panel.add_child(card)
	var stack := VBoxContainer.new()
	stack.position = Vector2(80, 70)
	stack.size = Vector2(620, 810)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 30)
	card.add_child(stack)
	var title := UIFactory.make_label("PAUSED", 92, Color("ffe14d"))
	title.custom_minimum_size = Vector2(620, 170)
	stack.add_child(title)
	for item in [["RESUME", "resume"], ["RESTART", "game"], ["HOME", "start"]]:
		var button := UIFactory.make_button(item[0], Color("1769d2") if item[1] == "resume" else Color("ef3340"), Vector2(620, 125))
		var action: String = item[1]
		button.pressed.connect(func(): _pause_action(action))
		stack.add_child(button)

func _process(delta: float) -> void:
	if finishing or preparing:
		return
	if not game_started:
		if SupabaseClient.active:
			countdown_elapsed = SupabaseClient.elapsed() + 4.0
		else:
			countdown_elapsed += delta
		var next_text := "3"
		if countdown_elapsed >= 3.0: next_text = "GO!"
		elif countdown_elapsed >= 2.0: next_text = "1"
		elif countdown_elapsed >= 1.0: next_text = "2"
		if countdown_label.text != next_text:
			countdown_label.text = next_text
			AudioManager.play("countdown" if next_text != "GO!" else "game_start")
			countdown_label.scale = Vector2(1.35, 1.35)
			create_tween().tween_property(countdown_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
		if countdown_elapsed >= 4.0:
			game_started = true
			countdown_label.visible = false
			spawn_manager.setup(object_layer)
		return
	if SupabaseClient.active:
		elapsed = maxf(0.0, SupabaseClient.elapsed())
	else:
		elapsed += delta
	var altitude := maxi(0, int(round((1.0 - elapsed / GameConfig.GAME_DURATION) * GameConfig.START_ALTITUDE)))
	altitude_value.text = "%d m" % altitude
	background.set_altitude(altitude)
	GameManager.altitude_changed.emit(altitude)
	player.position.y = 900.0 + sin(elapsed * 2.4) * 22.0
	player.rotation = sin(elapsed * 1.7) * 0.035
	if shake_time > 0.0:
		shake_time -= delta
		position = base_position + Vector2(randf_range(-14, 14), randf_range(-12, 12))
	else:
		position = base_position
	if elapsed >= GameConfig.GAME_DURATION:
		finish_game()

# Direct screen-space picking is reliable on both Web touch and desktop mouse,
# even when responsive Control nodes are layered above the Area2D objects.
func _input(event: InputEvent) -> void:
	if not game_started or finishing or get_tree().paused or object_layer == null:
		return
	var pressed := false
	var tap_position := Vector2.ZERO
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		tap_position = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		tap_position = event.position
	if not pressed or tap_position.y < 270.0:
		return
	var closest: FallingObject
	var closest_distance := 190.0
	for child in object_layer.get_children():
		if child is FallingObject and child.active:
			var distance := tap_position.distance_to(child.global_position)
			if distance < closest_distance:
				closest = child
				closest_distance = distance
	if closest != null:
		closest.active = false
		closest.input_pickable = false
		_on_object_tapped(closest.object_type, closest)
		get_viewport().set_input_as_handled()

func _on_object_tapped(kind: String, object: FallingObject) -> void:
	if finishing or not game_started:
		return
	if SupabaseClient.active:
		SupabaseClient.hit(int(object.get_meta("server_id", -1)))
	if kind == "thai":
		var gained := ScoreManager.collect_thai()
		AudioManager.play("tap_correct")
		if ScoreManager.consecutive >= 3:
			AudioManager.play("combo")
		show_feedback(object.position, "+%d" % gained, Color("ffd83d"), "✦")
		GameManager.thai_flag_collected.emit(gained)
	elif kind == "bomb":
		ScoreManager.hit_bomb()
		AudioManager.play("bomb")
		show_feedback(object.position, "-300", Color("ff4e54"), "⚠")
		show_smoke(object.position)
		shake_time = 0.30
		red_flash.color = Color(1, 0.05, 0.05, 0.38)
		create_tween().tween_property(red_flash, "color:a", 0.0, 0.35)
		GameManager.bomb_tapped.emit()
	else:
		ScoreManager.reset_combo()
		AudioManager.play("tap_wrong")
		show_feedback(object.position, "MISS!", Color("ff4e54"), "✕")
		GameManager.wrong_flag_tapped.emit(kind)
	if kind == "usa" or kind == "uae":
		object.wrong_and_remove()
	else:
		object.pop_and_remove()

func show_feedback(world_position: Vector2, message: String, color: Color, icon: String) -> void:
	var label := UIFactory.make_label(icon + " " + message, 52, color)
	label.position = world_position - Vector2(180, 80)
	label.size = Vector2(360, 100)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 145.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.30).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)

func show_smoke(world_position: Vector2) -> void:
	for index in range(4):
		var puff := UIFactory.make_label("●", 78 - index * 8, Color(0.86, 0.94, 1.0, 0.88))
		puff.position = world_position + Vector2(-80 + index * 45, -20 + abs(index - 2) * 18)
		puff.size = Vector2(90, 90)
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(puff)
		var drift := Vector2((index - 2) * 42, -120 - index * 18)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(puff, "position", puff.position + drift, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector2(1.55, 1.55), 0.55)
		tween.tween_property(puff, "modulate:a", 0.0, 0.40).set_delay(0.15)
		tween.chain().tween_callback(puff.queue_free)

func finish_game() -> void:
	finishing = true
	if SupabaseClient.active:
		SupabaseClient.finish_round()
	spawn_manager.stop()
	for child in object_layer.get_children():
		child.queue_free()
	GameManager.set_result(ScoreManager.score, ScoreManager.thai_flags, ScoreManager.best_combo)
	GameManager.game_finished.emit()
	AudioManager.play("game_finish")
	var landing := create_tween()
	landing.tween_property(player, "position", Vector2(540, 1420), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	landing.tween_interval(0.25)
	landing.tween_callback(func(): GameManager.request_screen("result"))

func _pause_game() -> void:
	if SupabaseClient.active:
		return
	pause_panel.visible = true
	get_tree().paused = true

func _pause_action(action: String) -> void:
	get_tree().paused = false
	pause_panel.visible = false
	if action != "resume":
		GameManager.request_screen(action)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_pause_action("resume")
		else:
			_pause_game()
