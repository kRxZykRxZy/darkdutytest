extends Node3D

const PLAYER_SCENE := preload("res://objects/network_player.tscn")

var players: Dictionary = {}
const TEAM_NAMES := ["SHELLSHOCKERS", "RUSHTEAM"]

var players: Dictionary = {}
var peer_teams: Dictionary = {}

@onready var spawn_points: Node3D = $SpawnPoints
@onready var status_label: Label = $HUD/Status

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
		return

	_build_war_city()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		status_label.text = "Hosting lobby..."
		status_label.text = "Hosting lobby... Team mode: Shellshockers vs Rushteam"
		_spawn_player(multiplayer.get_unique_id())
	else:
		status_label.text = "Connected to lobby"

	_request_spawn.rpc_id(1, multiplayer.get_unique_id(), NetworkManager.requested_password)

func _team_for_peer(peer_id: int) -> String:
	if peer_teams.has(peer_id):
		return peer_teams[peer_id]
	var team := TEAM_NAMES[peer_teams.size() % TEAM_NAMES.size()]
	peer_teams[peer_id] = team
	return team

func _spawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		return

	var instance = PLAYER_SCENE.instantiate()
	instance.name = "Player_%d" % peer_id
	add_child(instance)
	var spawn = spawn_points.get_child(peer_id % max(1, spawn_points.get_child_count()))
	instance.global_position = spawn.global_position
	instance.configure(peer_id == multiplayer.get_unique_id())
	instance.configure(peer_id == multiplayer.get_unique_id(), _team_for_peer(peer_id))
	players[peer_id] = instance

func _remove_player(peer_id: int) -> void:
	if !players.has(peer_id):
		return
	players[peer_id].queue_free()
	players.erase(peer_id)
	peer_teams.erase(peer_id)

func _on_peer_connected(_id: int) -> void:
	if multiplayer.is_server():
		for peer_id in players.keys():
			_sync_existing_player.rpc_id(_id, peer_id)
			_sync_existing_player.rpc_id(_id, peer_id, _team_for_peer(peer_id))

func _on_peer_disconnected(id: int) -> void:
	_remove_player(id)

@rpc("any_peer")
func _request_spawn(peer_id: int, password: String) -> void:
	if !multiplayer.is_server():
		return
	if NetworkManager.server_password != "" and NetworkManager.server_password != password:
		_kick_with_error.rpc_id(peer_id, "Wrong password")
		return
	_spawn_player(peer_id)
	_sync_existing_player.rpc(peer_id)

@rpc("any_peer", "call_local")
func _sync_existing_player(peer_id: int) -> void:
	var team := _team_for_peer(peer_id)
	_spawn_player(peer_id)
	_sync_existing_player.rpc(peer_id, team)

@rpc("any_peer", "call_local")
func _sync_existing_player(peer_id: int, team: String) -> void:
	peer_teams[peer_id] = team
	_spawn_player(peer_id)

@rpc("authority")
func _kick_with_error(reason: String) -> void:
	status_label.text = reason
	await get_tree().create_timer(1.0).timeout
	NetworkManager.shutdown_network()
	get_tree().change_scene_to_file("res://scenes/home.tscn")

func _on_leave_pressed() -> void:
	NetworkManager.shutdown_network()
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _build_war_city() -> void:
	for child in $CityGeometry.get_children():
		child.queue_free()

	_create_block(Vector3(0, -1, 0), Vector3(90, 2, 90), Color(0.2, 0.2, 0.24))

	for x in [-26, -12, 0, 12, 26]:
		_create_block(Vector3(x, 1.5, -26), Vector3(8, 3, 8), Color(0.35, 0.35, 0.38))
		_create_block(Vector3(x, 3.5, 10), Vector3(8, 7, 8), Color(0.3, 0.3, 0.34))

	for z in [-18, -6, 6, 18]:
		_create_block(Vector3(-30, 2.0, z), Vector3(6, 4, 10), Color(0.28, 0.28, 0.31))
		_create_block(Vector3(30, 2.5, z), Vector3(6, 5, 10), Color(0.28, 0.28, 0.31))

	_create_ramp(Vector3(-8, 0, -5), Vector3(12, 2, 6), 0.35)
	_create_ramp(Vector3(14, 0, 12), Vector3(10, 2, 6), -0.35)
	_create_ramp(Vector3(-16, 0, 18), Vector3(14, 2, 6), 0.28)

	_create_block(Vector3(0, 2, 0), Vector3(16, 4, 16), Color(0.22, 0.24, 0.27))
	_create_block(Vector3(0, 6, 0), Vector3(8, 4, 8), Color(0.24, 0.26, 0.3))

func _create_block(position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position
	$CityGeometry.add_child(body)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

func _create_ramp(position: Vector3, size: Vector3, angle: float) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.rotation.z = angle
	$CityGeometry.add_child(body)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.25, 0.3)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
