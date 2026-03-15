extends Node3D

const PLAYER_SCENE := preload("res://objects/network_player.tscn")
const TEAM_NAMES: Array[String] = ["SHELLSHOCKERS", "RUSHTEAM"]
const WEAPON_PATHS := [
	"res://weapons/rpg.tres",
	"res://weapons/assault_rifle.tres",
	"res://weapons/shotgun.tres",
	"res://weapons/grenade_launcher.tres",
	"res://weapons/sniper.tres",
	"res://weapons/lmg.tres",
	"res://weapons/smg.tres",
	"res://weapons/battle_rifle.tres"
]

var players: Dictionary = {}
var peer_teams: Dictionary = {}
var multiplayer_weapons: Array[Weapon] = []
var multiplayer_weapon_index := 0

@onready var spawn_points: Node3D = $SpawnPoints
@onready var status_label: Label = $HUD/Status
@onready var loadout_label: Label = $HUD/Loadout
@onready var weapon_image_rect: TextureRect = $HUD.get_node_or_null("WeaponImage") as TextureRect

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
		return

	_build_war_city()
	_load_multiplayer_weapons()
	if weapon_image_rect == null:
		weapon_image_rect = TextureRect.new()
		weapon_image_rect.name = "WeaponImage"
		weapon_image_rect.offset_left = 970
		weapon_image_rect.offset_top = 86
		weapon_image_rect.offset_right = 1040
		weapon_image_rect.offset_bottom = 156
		weapon_image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		weapon_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		$HUD.add_child(weapon_image_rect)
	_update_multiplayer_loadout_ui()

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

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer_weapons.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_multiplayer_weapon_index((multiplayer_weapon_index - 1 + multiplayer_weapons.size()) % multiplayer_weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_multiplayer_weapon_index((multiplayer_weapon_index + 1) % multiplayer_weapons.size())
	if Input.is_action_just_pressed("weapon_toggle") or Input.is_action_just_pressed("weapon_next"):
		_set_multiplayer_weapon_index((multiplayer_weapon_index + 1) % multiplayer_weapons.size())
	if Input.is_action_just_pressed("weapon_prev"):
		_set_multiplayer_weapon_index((multiplayer_weapon_index - 1 + multiplayer_weapons.size()) % multiplayer_weapons.size())
	if Input.is_action_just_pressed("weapon_slot_1"):
		_set_multiplayer_weapon_index(0)
	if Input.is_action_just_pressed("weapon_slot_2"):
		_set_multiplayer_weapon_index(1)
	if Input.is_action_just_pressed("weapon_slot_3"):
		_set_multiplayer_weapon_index(2)
	if Input.is_action_just_pressed("weapon_slot_4"):
		_set_multiplayer_weapon_index(3)
	if Input.is_action_just_pressed("weapon_slot_5"):
		_set_multiplayer_weapon_index(4)

func _load_multiplayer_weapons() -> void:
	multiplayer_weapons.clear()
	for weapon_path in WEAPON_PATHS:
		var weapon_resource := load(weapon_path) as Weapon
		if weapon_resource != null:
			multiplayer_weapons.append(weapon_resource)
	multiplayer_weapon_index = 0

func _set_multiplayer_weapon_index(index: int) -> void:
	if index < 0 or index >= multiplayer_weapons.size():
		return
	multiplayer_weapon_index = index
	_update_multiplayer_loadout_ui()

func _update_multiplayer_loadout_ui() -> void:
	var lines: Array[String] = []
	for i: int in range(multiplayer_weapons.size()):
		var prefix := str(i + 1) if i < 5 else "-"
		if i == multiplayer_weapon_index:
			prefix = ">"
		lines.append("%s %s" % [prefix, multiplayer_weapons[i].weapon_name])
	lines.append("Mouse Wheel / E: Switch")
	loadout_label.text = "\n".join(lines)

	if weapon_image_rect == null:
		return
	if multiplayer_weapons.is_empty():
		weapon_image_rect.texture = null
		return
	weapon_image_rect.texture = multiplayer_weapons[multiplayer_weapon_index].crosshair

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
