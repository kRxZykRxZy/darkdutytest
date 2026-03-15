extends CharacterBody3D

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

	for item in weapons:
		current_ammo.append(item.magazine_size)
		reserve_ammo.append(item.reserve_ammo)

	weapon = weapons[weapon_index]
	change_weapon()

	health_updated.emit(health)
	loadout_updated.emit(_get_loadout_lines())
	_emit_ammo()


# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

func _process(delta):
	handle_gravity(delta)

	velocity = velocity.lerp(movement_velocity, delta * 10)
	velocity.y = -gravity

	move_and_slide()


# --------------------------------------------------
# INPUT
# --------------------------------------------------

func _input(event):
	if event is InputEventMouseMotion:
		handle_rotation(event.relative.x, event.relative.y)


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


# --------------------------------------------------
# SHOOTING
# --------------------------------------------------

func action_shoot():
	if is_reloading:
		return

	if !blaster_cooldown.is_stopped():
		return

	if current_ammo[weapon_index] <= 0:
		return

	current_ammo[weapon_index] -= 1
	_emit_ammo()

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
	movement_velocity += Vector3(0, 0, weapon.knockback)


# --------------------------------------------------
# WEAPON SYSTEM
# --------------------------------------------------

func change_weapon():
	weapon = weapons[weapon_index]

	for child in container.get_children():
		child.queue_free()

	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)

	# Allow weapon to configure itself
	if weapon.has_method("configure_model"):
		weapon.configure_model(weapon_model)

	if weapon.has_method("configure_aiming"):
		weapon.configure_aiming(self)

	_emit_ammo()


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
	return [
		"1 RPG",
		"2 Assault Rifle",
		"3 Shotgun",
		"4 Grenade Launcher",
		"5 Sniper",
		"Mouse Wheel: Switch",
		"R: Reload | Right Click: Scope",
		"H: Heal"
	]
