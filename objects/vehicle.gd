extends CharacterBody3D
class_name Vehicle

@export var acceleration := 22.0
@export var max_speed := 16.0
@export var turn_speed := 1.7
@export var mounted_gun_damage := 28.0
@export var mounted_gun_cooldown := 0.24

@onready var driver_seat: Marker3D = $DriverSeat
@onready var passenger_seat: Marker3D = $PassengerSeat
@onready var gun_muzzle: Marker3D = $GunMuzzle
@onready var gun_raycast: RayCast3D = $GunMuzzle/RayCast3D

var driver: Node3D = null
var passenger: Node3D = null
var speed := 0.0
var gun_cooldown_left := 0.0

func _physics_process(delta: float) -> void:
	gun_cooldown_left = max(0.0, gun_cooldown_left - delta)

func has_seat_for(player: Node3D) -> bool:
	return driver == null or passenger == null or player == driver or player == passenger

func enter(player: Node3D, preferred_passenger := false) -> String:
	if preferred_passenger and passenger == null:
		passenger = player
		return "passenger"
	if driver == null:
		driver = player
		return "driver"
	if passenger == null:
		passenger = player
		return "passenger"
	if player == driver:
		return "driver"
	if player == passenger:
		return "passenger"
	return ""

func switch_seat(player: Node3D) -> String:
	if player == driver and passenger == null:
		driver = null
		passenger = player
		return "passenger"
	if player == passenger and driver == null:
		passenger = null
		driver = player
		return "driver"
	return _seat_of(player)

func exit(player: Node3D) -> void:
	if player != driver and player != passenger:
		return
	if player == driver:
		driver = null
	elif player == passenger:
		passenger = null

func _seat_of(player: Node3D) -> String:
	if player == driver:
		return "driver"
	if player == passenger:
		return "passenger"
	return ""

func seat_transform(seat_name: String) -> Transform3D:
	if seat_name == "passenger":
		return passenger_seat.global_transform
	return driver_seat.global_transform

func drive_and_fire(delta: float, move_axis: float, turn_axis: float, firing: bool) -> void:
	speed = move_toward(speed, move_axis * max_speed, acceleration * delta)
	rotation.y -= turn_axis * turn_speed * delta
	velocity = -transform.basis.z * speed
	move_and_slide()
	if firing:
		_fire_mounted_gun()

func _fire_mounted_gun() -> void:
	if gun_cooldown_left > 0.0:
		return
	gun_cooldown_left = mounted_gun_cooldown
	gun_raycast.force_raycast_update()
	if gun_raycast.is_colliding():
		var collider := gun_raycast.get_collider()
		if collider and collider.has_method("damage"):
			collider.damage(mounted_gun_damage)
