extends Node3D

const PLAYER_SCENE := preload("res://objects/network_player.tscn")
const TEAM_NAMES: Array[String] = ["SHELLSHOCKERS", "RUSHTEAM"]

var players: Dictionary = {}
var peer_teams: Dictionary = {}

@onready var spawn_points: Node3D = $SpawnPoints
@onready var status_label: Label = $HUD/Status
@onready var loadout_label: Label = $HUD/Loadout

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
		return

	_build_war_city()
	loadout_label.text = "1 RPG  2 Assault  3 Shotgun  4 Grenade  5 Sniper\n+ LMG + SMG + Battle Rifle\nMouse Wheel: Switch  |  R Reload  |  RMB Scope  |  H Heal"

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		status_label.text = "Hosting large map... Team mode: Shellshockers vs Rushteam"
		_spawn_player(multiplayer.get_unique_id())
	else:
		status_label.text = "Connected to lobby"
		_request_spawn.rpc_id(1, multiplayer.get_unique_id(), NetworkManager.requested_password)

func _team_for_peer(peer_id: int) -> String:
	if peer_teams.has(peer_id):
		return peer_teams[peer_id]
	var team: String = TEAM_NAMES[peer_teams.size() % TEAM_NAMES.size()]
	peer_teams[peer_id] = team
	return team

func _spawn_player(peer_id: int, forced_team: String = "") -> void:
	if players.has(peer_id):
		return

	var team: String = forced_team if !forced_team.is_empty() else _team_for_peer(peer_id)
	peer_teams[peer_id] = team

	var instance = PLAYER_SCENE.instantiate()
	instance.name = "Player_%d" % peer_id
	add_child(instance)
	var spawn = spawn_points.get_child(peer_id % max(1, spawn_points.get_child_count()))
	instance.global_position = spawn.global_position
	instance.configure(peer_id == multiplayer.get_unique_id(), team)
	players[peer_id] = instance

func _remove_player(peer_id: int) -> void:
	if !players.has(peer_id):
		return
	players[peer_id].queue_free()
	players.erase(peer_id)
	peer_teams.erase(peer_id)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		for peer_id in players.keys():
			_sync_existing_player.rpc_id(id, peer_id, _team_for_peer(peer_id))

func _on_peer_disconnected(id: int) -> void:
	_remove_player(id)

@rpc("any_peer")
func _request_spawn(peer_id: int, password: String) -> void:
	if !multiplayer.is_server():
		return
	if NetworkManager.server_password != "" and NetworkManager.server_password != password:
		_kick_with_error.rpc_id(peer_id, "Wrong password")
		return
	var team: String = _team_for_peer(peer_id)
	_spawn_player(peer_id, team)
	_sync_existing_player.rpc(peer_id, team)

@rpc("any_peer", "call_local")
func _sync_existing_player(peer_id: int, team: String) -> void:
	_spawn_player(peer_id, team)

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

	_create_block(Vector3(0, -1, 0), Vector3(160, 2, 160), Color(0.2, 0.2, 0.24))

	for x in [-56, -40, -24, -8, 8, 24, 40, 56]:
		_create_block(Vector3(x, 2.0, -44), Vector3(10, 4, 10), Color(0.34, 0.34, 0.37))
		_create_block(Vector3(x, 3.0, 44), Vector3(10, 6, 10), Color(0.31, 0.31, 0.35))

	for z in [-52, -36, -20, -4, 12, 28, 44]:
		_create_block(Vector3(-48, 2.5, z), Vector3(8, 5, 12), Color(0.28, 0.28, 0.31))
		_create_block(Vector3(48, 2.5, z), Vector3(8, 5, 12), Color(0.28, 0.28, 0.31))

	_create_block(Vector3(0, 2, 0), Vector3(26, 4, 26), Color(0.22, 0.24, 0.27))
	_create_block(Vector3(0, 6, 0), Vector3(12, 4, 12), Color(0.24, 0.26, 0.3))

	_create_ramp(Vector3(-24, 0, -10), Vector3(16, 2, 8), 0.30)
	_create_ramp(Vector3(26, 0, -16), Vector3(14, 2, 8), -0.30)
	_create_ramp(Vector3(-30, 0, 24), Vector3(18, 2, 8), 0.24)
	_create_ramp(Vector3(30, 0, 22), Vector3(18, 2, 8), -0.24)

	_create_vehicle(Vector3(-38, 0, 12), Color(0.26, 0.3, 0.24))
	_create_vehicle(Vector3(35, 0, -14), Color(0.3, 0.26, 0.24))
	_create_vehicle(Vector3(0, 0, 38), Color(0.24, 0.27, 0.22))
	_create_helicopter(Vector3(-10, 10, -40))
	_create_helicopter(Vector3(26, 12, 34))

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


func _create_vehicle(position: Vector3, color: Color) -> void:
	_create_block(position + Vector3(0, 0.8, 0), Vector3(4.8, 1.4, 2.6), color)
	_create_block(position + Vector3(-0.8, 1.9, 0), Vector3(2.4, 1.0, 2.0), color.darkened(0.15))
	_create_block(position + Vector3(2.0, 1.15, 0), Vector3(1.0, 0.45, 2.6), Color(0.18, 0.18, 0.18))


func _create_helicopter(position: Vector3) -> void:
	_create_block(position, Vector3(6, 1.6, 2.2), Color(0.2, 0.24, 0.2))
	_create_block(position + Vector3(-3.6, 0.1, 0), Vector3(3.6, 0.4, 0.35), Color(0.15, 0.17, 0.15))
	_create_block(position + Vector3(0, 1.4, 0), Vector3(7.4, 0.2, 0.2), Color(0.05, 0.05, 0.05))
	_create_block(position + Vector3(2.6, -1.2, 0.7), Vector3(0.2, 1.0, 0.2), Color(0.12, 0.12, 0.12))
	_create_block(position + Vector3(2.6, -1.2, -0.7), Vector3(0.2, 1.0, 0.2), Color(0.12, 0.12, 0.12))
