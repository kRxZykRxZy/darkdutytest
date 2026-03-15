extends CanvasLayer

func _ready() -> void:
	if !has_node("Loadout"):
		var label := Label.new()
		label.name = "Loadout"
		label.offset_left = 48
		label.offset_top = 520
		label.offset_right = 680
		label.offset_bottom = 700
		label.text = ""
		add_child(label)

	if !has_node("Ammo"):
		var ammo := Label.new()
		ammo.name = "Ammo"
		ammo.offset_left = 1040
		ammo.offset_top = 620
		ammo.offset_right = 1250
		ammo.offset_bottom = 700
		ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ammo.text = ""
		add_child(ammo)

	if !has_node("WeaponImage"):
		var weapon_image := TextureRect.new()
		weapon_image.name = "WeaponImage"
		weapon_image.offset_left = 965
		weapon_image.offset_top = 610
		weapon_image.offset_right = 1035
		weapon_image.offset_bottom = 680
		weapon_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		weapon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(weapon_image)

func _on_health_updated(health):
	$Health.text = str(health) + "%"

func _on_ammo_updated(current: int, reserve: int, weapon_name: String, weapon_image: Texture2D = null) -> void:
	var ammo_label := get_node_or_null("Ammo") as Label
	if ammo_label == null:
		return
	ammo_label.text = "%s\n%d / %d" % [weapon_name, current, reserve]
	var weapon_image_rect := get_node_or_null("WeaponImage") as TextureRect
	if weapon_image_rect != null:
		weapon_image_rect.texture = weapon_image

func _on_loadout_updated(lines: Array[String]) -> void:
	var loadout_label := get_node_or_null("Loadout") as Label
	if loadout_label == null:
		return
	loadout_label.text = "\n".join(lines)
