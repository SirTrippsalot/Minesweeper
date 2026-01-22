## GameUI.gd
##
## Top menu bar with game stats and controls
## Displays:
## - Mines remaining
## - Elapsed time
## - Restart button

class_name GameUI
extends CanvasLayer

## References to UI elements
var mines_label: Label
var time_label: Label
var restart_button: Button
var settings_button: Button
var game_state_label: Label

## Reference to game logic for stats
var game_logic: GameLogic

## Reference to game controller for restart
var game_controller: Node

## UI container
var ui_container: PanelContainer

## Settings menu
var settings_menu: Node

func _ready():
	# Set layer to be on top
	layer = 100

	_create_ui()
	_create_settings_menu()

## Create the UI elements
func _create_ui() -> void:
	# Main container
	ui_container = PanelContainer.new()
	ui_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ui_container.offset_bottom = 60
	ui_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure it receives input
	add_child(ui_container)

	# Add some padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	ui_container.add_child(margin)

	# Horizontal box for layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	# Mines remaining label
	mines_label = Label.new()
	mines_label.text = "Mines: --"
	mines_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(mines_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer1)

	# Time label
	time_label = Label.new()
	time_label.text = "Time: 0:00"
	time_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(time_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer2)

	# Game state label
	game_state_label = Label.new()
	game_state_label.text = ""
	game_state_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(game_state_label)

	# Expanding spacer to push buttons to the right
	var expanding_spacer = Control.new()
	expanding_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(expanding_spacer)

	# Settings button with gear icon
	settings_button = Button.new()
	settings_button.text = "⚙"  # Gear icon
	settings_button.add_theme_font_size_override("font_size", 32)
	settings_button.custom_minimum_size = Vector2(50, 40)
	settings_button.tooltip_text = "Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	hbox.add_child(settings_button)

	# Small spacer between buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(button_spacer)

	# Restart button with reload icon
	restart_button = Button.new()
	restart_button.text = "↻"  # Circular reload arrow
	restart_button.add_theme_font_size_override("font_size", 32)
	restart_button.custom_minimum_size = Vector2(50, 40)
	restart_button.tooltip_text = "Restart game"
	restart_button.pressed.connect(_on_restart_pressed)
	hbox.add_child(restart_button)

## Create settings menu
func _create_settings_menu() -> void:
	settings_menu = SettingsMenu.new()
	add_child(settings_menu)

## Connect to game logic and controller
func setup(logic: GameLogic, controller: Node = null) -> void:
	game_logic = logic
	game_controller = controller

	# Setup settings menu with controller reference
	if settings_menu:
		settings_menu.setup(controller)

	update_stats()

## Update all stats
func update_stats() -> void:
	if not game_logic:
		return

	# Update mines remaining
	var remaining = game_logic.get_remaining_mines()
	mines_label.text = "Mines: %d" % remaining

	# Update time
	var elapsed = game_logic.get_elapsed_time()
	var minutes = int(elapsed / 60)
	var seconds = int(elapsed) % 60
	time_label.text = "Time: %d:%02d" % [minutes, seconds]

	# Update game state
	match game_logic.get_state():
		GameLogic.GameState.NOT_STARTED:
			game_state_label.text = ""
		GameLogic.GameState.PLAYING:
			game_state_label.text = ""
		GameLogic.GameState.WON:
			game_state_label.text = "YOU WIN!"
			game_state_label.add_theme_color_override("font_color", Color.GREEN)
		GameLogic.GameState.LOST:
			game_state_label.text = "GAME OVER"
			game_state_label.add_theme_color_override("font_color", Color.RED)

func _process(_delta: float) -> void:
	# Update time continuously while playing
	if game_logic and game_logic.get_state() == GameLogic.GameState.PLAYING:
		update_stats()

## Handle restart button press
func _on_restart_pressed() -> void:
	print("Restart button pressed!")

	# Try direct reference first
	if game_controller and game_controller.has_method("restart_game"):
		print("Calling restart_game directly on controller")
		game_controller.restart_game()
	else:
		print("No direct controller reference, using call_group")
		# Fallback to group call
		get_tree().call_group("game_controller", "restart_game")

## Handle settings button press
func _on_settings_pressed() -> void:
	print("Settings button pressed!")

	# Toggle settings menu
	if settings_menu:
		if settings_menu.visible:
			settings_menu.hide_menu()
		else:
			settings_menu.show_menu()
	else:
		print("Warning: No settings menu attached")
