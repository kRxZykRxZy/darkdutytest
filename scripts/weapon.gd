extends Resource
class_name Weapon

@export_subgroup("Identity")
@export var weapon_name := "Weapon"

@export_subgroup("Model")
@export var model: PackedScene # Model of the weapon
@export var position: Vector3 # On-screen position
@export var rotation: Vector3 # On-screen rotation
@export var muzzle_position: Vector3 # On-screen position of muzzle flash

@export_subgroup("Properties")
@export_range(0.1, 1.5) var cooldown: float = 0.1 # Firerate
@export_range(1, 20) var max_distance: int = 10 # Fire distance
@export_range(0, 100) var damage: float = 25 # Damage per hit
@export_range(0, 8) var spread: float = 0 # Spread of each shot
@export_range(1, 12) var shot_count: int = 1 # Amount of shots
@export_range(0, 50) var knockback: int = 20 # Amount of knockback

@export var min_knockback: Vector2 = Vector2(0.001, 0.001) # x for vertical knockback, y for horizontal knockback
@export var max_knockback: Vector2 = Vector2(0.0025, 0.002) # x for vertical knockback, y for horizontal knockback
@export_range(1, 80) var magazine_size: int = 30
@export_range(0, 240) var reserve_ammo: int = 90
@export_range(0.2, 4.0) var reload_time: float = 1.2
@export_range(25, 90) var scope_fov: float = 45.0

@export_subgroup("Sounds")
@export var sound_shoot: String # Sound path

@export_subgroup("Crosshair")
@export var crosshair: Texture2D # Image of crosshair on-screen
