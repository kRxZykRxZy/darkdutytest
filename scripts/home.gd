extends Control

@onready var menu_stack: VBoxContainer = %MenuStack
@onready var campaign_panel: VBoxContainer = %CampaignPanel
@onready var multiplayer_panel: VBoxContainer = %MultiplayerPanel
@onready var host_port: SpinBox = %HostPort
@onready var host_max_players: SpinBox = %HostMaxPlayers
@onready var host_password: LineEdit = %HostPassword
@onready var join_address: LineEdit = %JoinAddress
@onready var join_port: SpinBox = %JoinPort
@onready var join_password: LineEdit = %JoinPassword
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	menu_stack.visible = true
	campaign_panel.visible = false
	multiplayer_panel.visible = false
	status_label.text = ""

func _on_campaign_pressed() -> void:
	menu_stack.visible = false
	campaign_panel.visible = true

func _on_local_multiplayer_pressed() -> void:
	menu_stack.visible = false
	multiplayer_panel.visible = true

func _on_back_pressed() -> void:
	_show_main_menu()

func _on_start_campaign_pressed() -> void:
	NetworkManager.shutdown_network()
	get_tree().change_scene_to_file("res://scenes/campaign_level_1.tscn")

func _on_level_two_pressed() -> void:
	NetworkManager.shutdown_network()
	get_tree().change_scene_to_file("res://scenes/campaign_level_2.tscn")

func _on_level_three_pressed() -> void:
	NetworkManager.shutdown_network()
	get_tree().change_scene_to_file("res://scenes/campaign_level_3.tscn")

func _on_host_lobby_pressed() -> void:
	var ok := NetworkManager.start_host(int(host_port.value), int(host_max_players.value), host_password.text)
	if !ok:
		status_label.text = "Failed to host lobby. Check port and try again."

func _on_join_lobby_pressed() -> void:
	var address_text := join_address.text.strip_edges()
	if address_text.is_empty():
		status_label.text = "Enter a host URL/IP first (example: 192.168.1.20)."
		return

	var ok := NetworkManager.join_server(address_text, int(join_port.value), join_password.text)
	if !ok:
		status_label.text = "Failed to join lobby."
