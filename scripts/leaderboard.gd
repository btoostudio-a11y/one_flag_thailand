extends Control

func _ready() -> void:
	var bg := TextureRect.new()
	UIFactory.fill_parent(bg)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/backgrounds/bg_sky.png"):
		bg.texture = load("res://assets/backgrounds/bg_sky.png")
	add_child(bg)
	var shade := ColorRect.new()
	UIFactory.fill_parent(shade)
	shade.color = Color(0.01, 0.08, 0.25, 0.50)
	add_child(shade)
	var title := UIFactory.make_label("🏆  RANKING", 88, Color("ffe04b"))
	title.position = Vector2(100, 110)
	title.size = Vector2(880, 180)
	add_child(title)
	var card := Panel.new()
	card.position = Vector2(80, 320)
	card.size = Vector2(920, 1240)
	card.add_theme_stylebox_override("panel", UIFactory.panel_style(Color(0.02, 0.16, 0.43, 0.94), 48, Color("68ddff"), 6))
	add_child(card)
	var stack := VBoxContainer.new()
	stack.position = Vector2(55, 50)
	stack.size = Vector2(810, 1120)
	stack.add_theme_constant_override("separation", 16)
	card.add_child(stack)
	var entries: Array = await LeaderboardManager.get_entries(int(GameManager.last_result.get("score", 0)))
	if entries.is_empty():
		var empty := UIFactory.make_label("No verified account scores yet.\nGuest scores are saved privately.", 34)
		empty.custom_minimum_size = Vector2(810,200)
		stack.add_child(empty)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(810, 92)
		var is_you := str(entry.get("name", "")) == "You"
		row.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("165fc4") if is_you else Color(0.04, 0.25, 0.55, 0.86), 28, Color("ffe04b") if is_you else Color(1, 1, 1, 0.18), 4))
		stack.add_child(row)
		var rank := UIFactory.make_label("#%d" % (index + 1), 40, Color("ffe04b"))
		rank.position = Vector2(18, 15)
		rank.size = Vector2(130, 95)
		row.add_child(rank)
		var name_label := UIFactory.make_label(str(entry.get("name", "Player")), 38)
		name_label.position = Vector2(150, 15)
		name_label.size = Vector2(380, 95)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)
		var score_label := UIFactory.make_label(format_score(int(entry.get("score", 0))), 38, Color("8ce7ff"))
		score_label.position = Vector2(535, 15)
		score_label.size = Vector2(245, 95)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(score_label)
	var back := UIFactory.make_button("←  BACK", Color("ef3340"), Vector2(480, 120))
	back.position = Vector2(300, 1650)
	back.pressed.connect(func(): GameManager.request_screen("start"))
	add_child(back)

func format_score(value: int) -> String:
	var raw := str(value)
	var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			formatted += ","
		formatted += raw[index]
	return formatted
