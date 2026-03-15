extends CharacterBody3D

const VEHICLE_INTERACTION_RANGE := 4.0
const VEHICLE_EXIT_OFFSET := 2.2
const MAX_NUMBERED_WEAPONS := 5

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []
@export_range(0, 5) var medkits: int = 2
@export_range(1, 100) var heal_per_medkit: int = 35
@export_range(1, 30) var heal_cooldown_seconds: float = 8.0

var weapon: Weapon
var weapon_index := 0
var current_ammo: Array[int] = []
var reserve_ammo: Array[int] = []
var is_reloading := false
var is_scoping := false

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

var movement_velocity: Vector3
var rotation_target: Vector3
var input_mouse: Vector2

var health: int = 100
var gravity := 0.0
var jumps_remaining: int
var default_fov := 80.0
var active_vehicle: Vehicle = null
var vehicle_seat := ""

var container_offset = Vector3(1.2, -1.1, -2.75)
var tween: Tween

signal health_updated
signal ammo_updated
signal loadout_updated

@onready var camera = $Head/Camera
@onready var raycast = $Head/Camera/RayCast
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown
@onready var reload_timer: Timer = $ReloadTimer
@onready var heal_timer: Timer = $HealTimer

@export var crosshair: TextureRect


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	default_fov = camera.fov

	for item in weapons:
		current_ammo.append(item.magazine_size)
		reserve_ammo.append(item.reserve_ammo)

	if weapons.is_empty():
		push_error("Player has no weapons configured.")
		health_updated.emit(health)
		loadout_updated.emit([])
		return

	weapon = weapons[weapon_index]
	change_weapon()
	if !heal_timer.timeout.is_connected(_on_heal_timer_timeout):
		heal_timer.timeout.connect(_on_heal_timer_timeout)

	health_updated.emit(health)
	loadout_updated.emit(_get_loadout_lines())
	_emit_ammo()


# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

func _process(delta):
	_update_actions()
	_update_vehicle(delta)
	if active_vehicle:
		return
	handle_gravity(delta)
	_update_movement()

	velocity = velocity.lerp(movement_velocity, delta * 10)
	velocity.y = -gravity

	move_and_slide()


# --------------------------------------------------
# INPUT
# --------------------------------------------------

func _input(event):
	if event is InputEventMouseMotion:
		handle_rotation(event.relative.x, event.relative.y)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_weapon_index((weapon_index - 1 + weapons.size()) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_weapon_index((weapon_index + 1) % weapons.size())


# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func handle_gravity(delta):
	gravity += 20 * delta

	if is_on_floor():
		gravity = 0
		jumps_remaining = number_of_jumps


func handle_rotation(xRot: float, yRot: float):
	rotation_target += Vector3(-yRot, -xRot, 0) / mouse_sensitivity
	rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))

	camera.rotation.x = rotation_target.x
	rotation.y = rotation_target.y


func action_jump():
	if jumps_remaining <= 0:
		return

	gravity = -jump_strength
	jumps_remaining -= 1


func _update_movement() -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move: Vector3 = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized() * movement_speed
	movement_velocity.x = move.x
	movement_velocity.z = move.z


func _update_actions() -> void:
	if weapons.is_empty():
		return

	if Input.is_action_just_pressed("jump"):
		action_jump()

	if Input.is_action_pressed("shoot"):
		action_shoot()

	if Input.is_action_just_pressed("weapon_toggle") or Input.is_action_just_pressed("weapon_next"):
		_set_weapon_index((weapon_index + 1) % weapons.size())

	if Input.is_action_just_pressed("weapon_prev"):
		_set_weapon_index((weapon_index - 1 + weapons.size()) % weapons.size())

	if Input.is_action_just_pressed("weapon_slot_1"):
		_set_weapon_index(0)
	if Input.is_action_just_pressed("weapon_slot_2"):
		_set_weapon_index(1)
	if Input.is_action_just_pressed("weapon_slot_3"):
		_set_weapon_index(2)
	if Input.is_action_just_pressed("weapon_slot_4"):
		_set_weapon_index(3)
	if Input.is_action_just_pressed("weapon_slot_5"):
		_set_weapon_index(4)

	if Input.is_action_just_pressed("reload"):
		action_reload()

	if Input.is_action_pressed("scope"):
		action_scope(true)
	elif is_scoping:
		action_scope(false)

	if Input.is_action_just_pressed("heal"):
		action_heal()

	if Input.is_action_just_pressed("vehicle_interact"):
		action_vehicle_interact()

	if Input.is_action_just_pressed("vehicle_switch_seat"):
		action_vehicle_switch_seat()

	if Input.is_action_just_pressed("vehicle_exit"):
		action_vehicle_exit()


func _update_vehicle(delta: float) -> void:
	if !active_vehicle:
		return

	var seat_transform := active_vehicle.seat_transform(vehicle_seat)
	global_position = seat_transform.origin
	if vehicle_seat == "driver":
		rotation.y = active_vehicle.rotation.y
		rotation_target.y = rotation.y
	velocity = Vector3.ZERO

	if vehicle_seat == "driver":
		var move_axis := Input.get_axis("move_back", "move_forward")
		var turn_axis := Input.get_axis("move_right", "move_left")
		var firing := Input.is_action_pressed("shoot")
		active_vehicle.drive_and_fire(delta, move_axis, turn_axis, firing)


# --------------------------------------------------
# SHOOTING
# --------------------------------------------------

func action_shoot():
	if active_vehicle and vehicle_seat == "driver":
		return

	if is_reloading:
		return

	if !blaster_cooldown.is_stopped():
		return

	if current_ammo[weapon_index] <= 0:
		return

	current_ammo[weapon_index] -= 1
	_emit_ammo()

	if muzzle:
		muzzle.frame = 0
		muzzle.play("default")

	blaster_cooldown.start(weapon.cooldown)

	for i in weapon.shot_count:
		raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
		raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
		raycast.force_raycast_update()

		if raycast.is_colliding():
			var collider = raycast.get_collider()

			if collider.has_method("damage"):
				collider.damage(weapon.damage)

	# Knockback
	if !active_vehicle:
		movement_velocity += transform.basis.z * weapon.knockback

	if current_ammo[weapon_index] == 0 and reserve_ammo[weapon_index] > 0:
		action_reload()


# --------------------------------------------------
# WEAPON SYSTEM
# --------------------------------------------------

func _set_weapon_index(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == weapon_index:
		return
	weapon_index = index
	change_weapon()


func change_weapon():
	weapon = weapons[weapon_index]
	is_scoping = false
	camera.fov = default_fov

	for child in container.get_children():
		child.queue_free()

	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)

	# Allow weapon to configure itself
	if weapon.has_method("configure_model"):
		weapon.configure_model(weapon_model)

	if weapon.has_method("configure_aiming"):
		weapon.configure_aiming(self)

	if crosshair and weapon.crosshair:
		crosshair.texture = weapon.crosshair

	_emit_ammo()
	loadout_updated.emit(_get_loadout_lines())


func action_reload() -> void:
	if is_reloading:
		return
	var ammo_in_mag := current_ammo[weapon_index]
	if ammo_in_mag >= weapon.magazine_size:
		return
	if reserve_ammo[weapon_index] <= 0:
		return
	is_reloading = true
	reload_timer.start(weapon.reload_time)


func _on_reload_timer_timeout() -> void:
	if !is_reloading:
		return
	var ammo_needed := weapon.magazine_size - current_ammo[weapon_index]
	var ammo_to_load := min(ammo_needed, reserve_ammo[weapon_index])
	current_ammo[weapon_index] += ammo_to_load
	reserve_ammo[weapon_index] -= ammo_to_load
	is_reloading = false
	_emit_ammo()


func action_scope(enable: bool) -> void:
	is_scoping = enable
	camera.fov = weapon.scope_fov if enable else default_fov


func action_heal() -> void:
	if medkits <= 0:
		return
	if health >= 100:
		return
	if !heal_timer.is_stopped():
		return
	medkits -= 1
	health = min(100, health + heal_per_medkit)
	health_updated.emit(health)
	heal_timer.start(heal_cooldown_seconds)


func _on_heal_timer_timeout() -> void:
	pass


func action_vehicle_interact() -> void:
	if active_vehicle:
		return
	var nearby_vehicle := _find_nearby_vehicle()
	if !nearby_vehicle:
		return
	var new_seat := nearby_vehicle.enter(self)
	if new_seat.is_empty():
		return
	active_vehicle = nearby_vehicle
	vehicle_seat = new_seat
	is_reloading = false
	action_scope(false)


func action_vehicle_switch_seat() -> void:
	if !active_vehicle:
		return
	var new_seat := active_vehicle.switch_seat(self)
	if new_seat.is_empty():
		return
	vehicle_seat = new_seat


func action_vehicle_exit() -> void:
	if !active_vehicle:
		return
	var current_vehicle := active_vehicle
	current_vehicle.exit(self)
	active_vehicle = null
	vehicle_seat = ""
	gravity = 0.0
	var exit_pos := current_vehicle.global_transform.origin + current_vehicle.global_transform.basis.x * VEHICLE_EXIT_OFFSET
	if current_vehicle.has_node("ExitPoint"):
		exit_pos = current_vehicle.get_node("ExitPoint").global_position
	global_position = exit_pos


func _find_nearby_vehicle() -> Vehicle:
	var nearest: Vehicle = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("drivable_vehicle"):
		var candidate := node as Vehicle
		if candidate == null:
			continue
		if !candidate.has_seat_for(self):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < VEHICLE_INTERACTION_RANGE and distance < best_dist:
			best_dist = distance
			nearest = candidate
	return nearest


# --------------------------------------------------
# DAMAGE SYSTEM
# --------------------------------------------------

func damage(amount: float) -> void:
	health = max(0, health - int(amount))
	health_updated.emit(health)

	if health <= 0:
		get_tree().reload_current_scene()


# --------------------------------------------------
# HELPERS
# --------------------------------------------------

func random_vec2(min: Vector2, max: Vector2) -> Vector2:
	return Vector2(
		randf_range(min.x, max.x),
		randf_range(min.y, max.y)
	)


func _emit_ammo():
	ammo_updated.emit(
		current_ammo[weapon_index],
		reserve_ammo[weapon_index],
		weapon.weapon_name
	)


func _get_loadout_lines() -> Array[String]:
	var lines: Array[String] = []
	for i in range(weapons.size()):
		var prefix := str(i + 1)
		if i >= MAX_NUMBERED_WEAPONS:
			prefix = "-"
		lines.append("%s %s" % [prefix, weapons[i].weapon_name])
	lines.append("Mouse Wheel / E: Switch")
	lines.append("R: Reload | Right Click: Scope")
	lines.append("H: Heal")
	lines.append("F: Enter Vehicle | G: Swap Seat | X: Exit Vehicle")
	return lines
