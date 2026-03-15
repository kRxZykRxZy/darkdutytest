extends CanvasLayer

func _ready() -> void:
	if !has_node("Loadout"):
		var label := Label.new()
		label.name = "Loadout"
		label.offset_left = 48
		label.offset_top = 560
		label.offset_right = 520
		label.offset_bottom = 620
		label.text = "1: Blaster  2: Repeater  3: RPG  4: Grenade  5: Medkit"
		add_child(label)

func _on_health_updated(health):
	$Health.text = str(health) + "%"
