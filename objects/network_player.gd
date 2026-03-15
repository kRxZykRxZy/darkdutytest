extends CharacterBody3D

@export var move_speed := 6.0
@export var jump_strength := 8.0

var gravity := 0.0
var local_controlled := false
var look_x := 0.0
var team_name := "SHELLSHOCKERS"

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var team_label: Label3D = $TeamLabel

func configure(is_local: bool, assigned_team: String = "SHELLSHOCKERS") -> void:
	local_controlled = is_local
	team_name = assigned_team
	camera.current = is_local
	team_label.text = assigned_team
	if assigned_team == "RUSHTEAM":
		body_mesh.modulate = Color(0.85, 0.25, 0.2, 1)
	else:
		body_mesh.modulate = Color(0.2, 0.5, 0.95, 1)
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false

func _physics_process(delta: float) -> void:
	if !local_controlled:
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move := (transform.basis * Vector3(input.x, 0, input.y)).normalized() * move_speed

	gravity += 20.0 * delta
	if is_on_floor():
		gravity = 0.0
		if Input.is_action_just_pressed("jump"):
			gravity = -jump_strength

	velocity.x = move.x
	velocity.z = move.z
	velocity.y = -gravity
	move_and_slide()

	_send_transform.rpc_unreliable(global_transform, head.rotation.x)

func _input(event: InputEvent) -> void:
	if !local_controlled:
		return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / 700.0
		look_x = clamp(look_x - event.relative.y / 700.0, deg_to_rad(-80), deg_to_rad(80))
		head.rotation.x = look_x
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

@rpc("any_peer", "unreliable")
func _send_transform(new_transform: Transform3D, head_x: float) -> void:
	if local_controlled:
		return
	global_transform = new_transform
	head.rotation.x = head_x
