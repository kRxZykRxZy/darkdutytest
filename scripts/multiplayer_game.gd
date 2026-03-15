extends Node3D

const PLAYER_SCENE := preload("res://objects/network_player.tscn")

var players: Dictionary = {}

@onready var spawn_points: Node3D = $SpawnPoints
@onready var status_label: Label = $HUD/Status

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
		return

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		status_label.text = "Hosting lobby..."
		_spawn_player(multiplayer.get_unique_id())
	else:
		status_label.text = "Connected to lobby"

	_request_spawn.rpc_id(1, multiplayer.get_unique_id(), NetworkManager.requested_password)

func _spawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		return

	var instance = PLAYER_SCENE.instantiate()
	instance.name = "Player_%d" % peer_id
	add_child(instance)
	var spawn = spawn_points.get_child(peer_id % max(1, spawn_points.get_child_count()))
	instance.global_position = spawn.global_position
	instance.configure(peer_id == multiplayer.get_unique_id())
	players[peer_id] = instance

func _remove_player(peer_id: int) -> void:
	if !players.has(peer_id):
		return
	players[peer_id].queue_free()
	players.erase(peer_id)

func _on_peer_connected(_id: int) -> void:
	if multiplayer.is_server():
		for peer_id in players.keys():
			_sync_existing_player.rpc_id(_id, peer_id)

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
