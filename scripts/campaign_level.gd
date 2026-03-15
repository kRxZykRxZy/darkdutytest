extends Node3D

@export_file("*.tscn") var next_level_path := ""
@export var intro_text := ""
@export var additional_enemy_positions: Array[Vector3] = []
@export var mission_stages: Array[String] = []
@export var reinforcements_delay := 15.0

@onready var enemies: Node = $Enemies
@onready var hud: CanvasLayer = $HUD

var reinforcements_spawned := false

func _ready() -> void:
	_spawn_extra_enemies()
	_ensure_status_label()
	_update_status_label()

func _process(_delta: float) -> void:
	_update_status_label()
	if !reinforcements_spawned and enemies.get_child_count() <= 2 and !additional_enemy_positions.is_empty():
		reinforcements_spawned = true
		_spawn_reinforcements()
	if enemies.get_child_count() == 0:
		if next_level_path.is_empty():
			_show_campaign_complete()
		else:
			get_tree().change_scene_to_file(next_level_path)

func _spawn_extra_enemies() -> void:
	if additional_enemy_positions.is_empty():
		return

	var enemy_scene := preload("res://objects/enemy.tscn")
	for spawn_pos in additional_enemy_positions:
		var enemy := enemy_scene.instantiate()
		enemy.position = spawn_pos
		enemy.player = get_node("Player")
		enemies.add_child(enemy)
		if enemy.has_node("RayCast"):
			enemy.get_node("RayCast").target_position = Vector3(0, 0, -12)

func _spawn_reinforcements() -> void:
	var label: Label = hud.get_node("Objective")
	label.text = "%s\nReinforcements incoming..." % intro_text
	await get_tree().create_timer(reinforcements_delay / 8.0).timeout
	_spawn_extra_enemies()

func _ensure_status_label() -> void:
	if hud.has_node("Objective"):
		return
	var label := Label.new()
	label.name = "Objective"
	label.offset_left = 48
	label.offset_top = 48
	label.offset_right = 1000
	label.offset_bottom = 96
	label.text = intro_text
	hud.add_child(label)

func _update_status_label() -> void:
	var label: Label = hud.get_node("Objective")
	var stage_text := ""
	if !mission_stages.is_empty():
		var progress := 1.0 - (float(enemies.get_child_count()) / max(1.0, float(mission_stages.size() * 2)))
		var stage_index := clamp(int(floor(progress * mission_stages.size())), 0, mission_stages.size() - 1)
		stage_text = "\nMission: %s" % mission_stages[stage_index]
	label.text = "%s%s\nEnemies Remaining: %d" % [intro_text, stage_text, enemies.get_child_count()]

func _show_campaign_complete() -> void:
	var label: Label = hud.get_node("Objective")
	label.text = "Campaign complete! Returning to home..."
	await get_tree().create_timer(2.0).timeout
	NetworkManager.shutdown_network()
	get_tree().change_scene_to_file("res://scenes/home.tscn")
