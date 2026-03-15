extends Node

const MULTIPLAYER_SCENE := "res://scenes/multiplayer_arena.tscn"

var is_host := false
var server_password := ""
var requested_password := ""
var max_players := 8

func _on_peer_connected(id: int) -> void:
	print("Peer connected:", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected:", id)

func _on_connection_failed() -> void:
	push_error("Failed to connect to server")
	shutdown_network()
	get_tree().change_scene_to_file("res://scenes/home.tscn")

func _on_server_disconnected() -> void:
	push_warning("Disconnected from server")
	shutdown_network()
	get_tree().change_scene_to_file("res://scenes/home.tscn")

func _register_peer_callbacks() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_host(port: int, lobby_max_players: int, password: String) -> bool:
	shutdown_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, lobby_max_players)
	if err != OK:
		push_error("Could not host server on port %d" % port)
		return false

	is_host = true
	max_players = lobby_max_players
	server_password = password.strip_edges()
	requested_password = server_password
	multiplayer.multiplayer_peer = peer
	_register_peer_callbacks()
	get_tree().change_scene_to_file(MULTIPLAYER_SCENE)
	return true

func join_server(address: String, port: int, password: String) -> bool:
	shutdown_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		push_error("Could not connect to %s:%d" % [address, port])
		return false

	is_host = false
	requested_password = password.strip_edges()
	multiplayer.multiplayer_peer = peer
	_register_peer_callbacks()
	get_tree().change_scene_to_file(MULTIPLAYER_SCENE)
	return true

func shutdown_network() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	is_host = false
	server_password = ""
	requested_password = ""
