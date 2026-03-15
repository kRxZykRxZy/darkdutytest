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

func _on_health_updated(health):
	$Health.text = str(health) + "%"

func _on_ammo_updated(current: int, reserve: int, weapon_name: String) -> void:
	var ammo_label := get_node_or_null("Ammo") as Label
	if ammo_label == null:
		return
	ammo_label.text = "%s\n%d / %d" % [weapon_name, current, reserve]

func _on_loadout_updated(lines: Array[String]) -> void:
	$Loadout.text = "\n".join(lines)
