class_name SpawnManager
extends Node

signal object_tapped(kind: String, object: FallingObject)

const SCENES := {
	"thai": preload("res://objects/ThaiFlag.tscn"),
	"usa": preload("res://objects/USAFlag.tscn"),
	"uae": preload("res://objects/UAEFlag.tscn"),
	"bomb": preload("res://objects/Bomb.tscn")
}

var target_layer: Node2D
var elapsed := 0.0
var accumulator := 0.0
var running := false
var last_x := -999.0
var last_kind := ""
var bonus_thai_spawned := 0
var server_plan: Array = []
var server_index := 0

var rng := RandomNumberGenerator.new()

func setup(layer: Node2D) -> void:
	target_layer = layer
	if SupabaseClient.active:
		server_plan = SupabaseClient.round_plan
	rng.randomize()
	elapsed = 0.0
	accumulator = 0.35
	bonus_thai_spawned = 0
	running = true

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running or target_layer == null:
		return
	if SupabaseClient.active:
		elapsed = SupabaseClient.elapsed()
		while server_index < server_plan.size() and float(server_plan[server_index]["at"]) <= elapsed * 1000.0:
			spawn_server_object(server_plan[server_index])
			server_index += 1
		return
	elapsed += delta
	accumulator += delta
	var data := GameConfig.speed_data(elapsed)
	var final_rush := elapsed >= GameConfig.GAME_DURATION - GameConfig.FINAL_RUSH_SECONDS
	var current_interval: float = float(data["interval"])
	if accumulator >= current_interval:
		accumulator = 0.0
		spawn_one(float(data["speed"]))
		if final_rush:
			spawn_one(float(data["speed"]))
	# Eight guaranteed Thai flags are spread evenly across the full run.
	var bonus_step := GameConfig.GAME_DURATION / float(GameConfig.BONUS_THAI_FLAGS + 1)
	if bonus_thai_spawned < GameConfig.BONUS_THAI_FLAGS and elapsed >= bonus_step * float(bonus_thai_spawned + 1):
		spawn_one(float(data["speed"]), "thai")
		bonus_thai_spawned += 1

func spawn_server_object(item: Dictionary) -> void:
	var object := SCENES[str(item["kind"])].instantiate() as FallingObject
	object.speed = float(item["speed"])
	object.set_meta("server_id", int(item["id"]))
	object.set_meta("spawn_ms", float(item["at"]))
	object.position = Vector2(float(item["x"]), 2050.0)
	object.tapped.connect(_relay_tap)
	target_layer.add_child(object)

func spawn_one(object_speed: float, forced_kind: String = "") -> void:
	var kind := forced_kind if not forced_kind.is_empty() else choose_kind()
	if kind == "bomb" and get_tree().get_nodes_in_group("bombs").size() >= GameConfig.MAX_BOMBS:
		kind = "thai"
	# Keep play rewarding: never allow three distractors in a row.
	if last_kind != "thai" and kind != "thai" and rng.randf() < 0.42:
		kind = "thai"
	var object := SCENES[kind].instantiate() as FallingObject
	object.speed = object_speed * rng.randf_range(0.92, 1.08)
	var spawn_x := rng.randf_range(125.0, 955.0)
	var tries := 0
	while absf(spawn_x - last_x) < 190.0 and tries < 6:
		spawn_x = rng.randf_range(125.0, 955.0)
		tries += 1
	object.position = Vector2(spawn_x, 2050.0)
	object.rotation = rng.randf_range(-0.12, 0.12)
	object.tapped.connect(_relay_tap)
	target_layer.add_child(object)
	last_x = spawn_x
	last_kind = kind

func choose_kind() -> String:
	var weights := GameConfig.weights(elapsed)
	var roll := rng.randf_range(0.0, 100.0)
	var total := 0.0
	for kind in ["thai", "usa", "uae", "bomb"]:
		total += float(weights[kind])
		if roll <= total:
			return kind
	return "thai"

func _relay_tap(kind: String, object: FallingObject) -> void:
	object_tapped.emit(kind, object)
