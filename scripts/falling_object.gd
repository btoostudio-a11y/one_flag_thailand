class_name FallingObject
extends Area2D

signal tapped(kind: String, object: FallingObject)

@export_enum("thai", "usa", "uae", "bomb") var object_type := "thai"
@export var speed := 350.0
@export var spin_speed := 0.35
var active := true

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	if object_type == "bomb":
		add_to_group("bombs")
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture == null:
		load_optional_art(sprite)
	if sprite == null or sprite.texture == null:
		queue_redraw()

func load_optional_art(sprite: Sprite2D) -> void:
	var standalone := "res://assets/flags/%s_flag.png" % object_type
	var sheet := "res://assets/flags/flags_sheet.png"
	var region: Rect2 = Rect2()
	if object_type == "thai": region = Rect2(0, 0, 374, 350)
	elif object_type == "usa": region = Rect2(374, 0, 374, 350)
	elif object_type == "uae": region = Rect2(748, 0, 374, 350)
	elif object_type == "bomb":
		standalone = "res://assets/obstacles/bomb.png"
		sheet = "res://assets/obstacles/bomb_sheet.png"
		region = Rect2(0, 0, 374, 701)
	if ResourceLoader.exists(standalone):
		sprite.texture = load(standalone)
		return
	if ResourceLoader.exists(sheet):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(sheet)
		atlas.region = region
		sprite.texture = atlas


func _process(delta: float) -> void:
	if SupabaseClient.active:
		position.y = 2050.0 - speed * (SupabaseClient.elapsed() - float(get_meta("spawn_ms", 0.0)) / 1000.0)
	else:
		position.y -= speed * delta
	rotation += spin_speed * delta * (0.35 if object_type == "bomb" else 0.10)
	if position.y < -240.0:
		queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and active:
		active = false
		input_pickable = false
		tapped.emit(object_type, self)
		get_viewport().set_input_as_handled()

func pop_and_remove() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.28, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.20).set_delay(0.09)
	tween.chain().tween_callback(queue_free)

func wrong_and_remove() -> void:
	var start_x := position.x
	var tween := create_tween()
	tween.tween_property(self, "position:x", start_x - 18.0, 0.045)
	tween.tween_property(self, "position:x", start_x + 18.0, 0.065)
	tween.tween_property(self, "position:x", start_x, 0.045)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		return
	var color := Color("ef3340")
	if object_type == "thai": color = Color("2d2a8c")
	elif object_type == "usa": color = Color("e63946")
	elif object_type == "uae": color = Color("149954")
	elif object_type == "bomb": color = Color("232936")
	draw_circle(Vector2.ZERO, 90.0, color)
	draw_circle(Vector2.ZERO, 90.0, Color.WHITE, false, 8.0)
