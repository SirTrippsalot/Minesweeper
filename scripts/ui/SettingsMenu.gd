## SettingsMenu.gd
##
## Modal settings menu for game configuration
## Features:
## - Grid type selection (Square, Hexagon, Triangle)
## - Game parameters (size, mine count, wrapping)
## - Apply/Cancel buttons

class_name SettingsMenu
extends CanvasLayer

## Reference to game controller for applying settings
var game_controller: Node

## UI elements
var menu_container: PanelContainer
var grid_type_dropdown: OptionButton
var neighbor_mode_checkbox: CheckBox
var size_preset_dropdown: OptionButton
var difficulty_preset_dropdown: OptionButton
var grid_width_spinbox: SpinBox
var grid_height_spinbox: SpinBox
var mine_count_spinbox: SpinBox
var wrap_h_checkbox: CheckBox
var wrap_v_checkbox: CheckBox
var apply_button: Button
var cancel_button: Button

## Current settings (cache)
var current_grid_type: String = "Square"
var current_use_vertex_neighbors: bool = true
var current_grid_width: int = 50
var current_grid_height: int = 50
var current_mine_count: int = 400
var current_wrap_h: bool = true
var current_wrap_v: bool = true

func _ready():
	# Settings menu should be above game UI but below modal overlays
	layer = 150
	visible = false

	_create_menu()

## Create the settings menu UI
func _create_menu() -> void:
	# Semi-transparent background overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game
	add_child(overlay)

	# Main menu container (centered)
	menu_container = PanelContainer.new()
	menu_container.set_anchors_preset(Control.PRESET_CENTER)
	menu_container.custom_minimum_size = Vector2(400, 500)
	menu_container.position = Vector2(-200, -250)  # Center offset
	menu_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_container)

	# Margin for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	menu_container.add_child(margin)

	# Vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)

	# Grid Type Section
	_add_section_label(vbox, "Grid Type")
	grid_type_dropdown = OptionButton.new()
	grid_type_dropdown.add_item("Square Grid", 0)
	grid_type_dropdown.add_item("Hexagon Grid", 1)
	grid_type_dropdown.add_item("Triangle Grid", 2)
	grid_type_dropdown.add_item("Octagon+Square Grid", 3)
	grid_type_dropdown.selected = 0
	grid_type_dropdown.item_selected.connect(_on_grid_type_changed)
	vbox.add_child(grid_type_dropdown)

	# Neighbor Detection Mode
	neighbor_mode_checkbox = CheckBox.new()
	neighbor_mode_checkbox.text = "Include Vertex Neighbors"
	neighbor_mode_checkbox.button_pressed = current_use_vertex_neighbors
	vbox.add_child(neighbor_mode_checkbox)

	# Add helper text
	var helper_label = Label.new()
	helper_label.text = "  (Square: 4→8, Triangle: 3→12)"
	helper_label.add_theme_font_size_override("font_size", 12)
	helper_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(helper_label)

	# Grid Size Section
	_add_section_label(vbox, "Grid Size")

	size_preset_dropdown = OptionButton.new()
	size_preset_dropdown.add_item("Small (10x10)", 0)
	size_preset_dropdown.add_item("Medium (20x20)", 1)
	size_preset_dropdown.add_item("Large (30x30)", 2)
	size_preset_dropdown.add_item("Extra Large (50x50)", 3)
	size_preset_dropdown.add_item("Custom", 4)
	size_preset_dropdown.selected = 3  # Default to Extra Large
	size_preset_dropdown.item_selected.connect(_on_size_preset_changed)
	vbox.add_child(size_preset_dropdown)

	var width_hbox = HBoxContainer.new()
	width_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(width_hbox)

	var width_label = Label.new()
	width_label.text = "Width:"
	width_label.custom_minimum_size = Vector2(80, 0)
	width_hbox.add_child(width_label)

	grid_width_spinbox = SpinBox.new()
	grid_width_spinbox.min_value = 5
	grid_width_spinbox.max_value = 100
	grid_width_spinbox.value = current_grid_width
	grid_width_spinbox.editable = false
	grid_width_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_width_spinbox.value_changed.connect(_on_custom_size_changed)
	width_hbox.add_child(grid_width_spinbox)

	var height_hbox = HBoxContainer.new()
	height_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(height_hbox)

	var height_label = Label.new()
	height_label.text = "Height:"
	height_label.custom_minimum_size = Vector2(80, 0)
	height_hbox.add_child(height_label)

	grid_height_spinbox = SpinBox.new()
	grid_height_spinbox.min_value = 5
	grid_height_spinbox.max_value = 100
	grid_height_spinbox.value = current_grid_height
	grid_height_spinbox.editable = false
	grid_height_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_height_spinbox.value_changed.connect(_on_custom_size_changed)
	height_hbox.add_child(grid_height_spinbox)

	# Difficulty Section
	_add_section_label(vbox, "Difficulty")

	difficulty_preset_dropdown = OptionButton.new()
	difficulty_preset_dropdown.add_item("Easy (10% mines)", 0)
	difficulty_preset_dropdown.add_item("Medium (16% mines)", 1)
	difficulty_preset_dropdown.add_item("Hard (22% mines)", 2)
	difficulty_preset_dropdown.add_item("Expert (28% mines)", 3)
	difficulty_preset_dropdown.add_item("Custom", 4)
	difficulty_preset_dropdown.selected = 1  # Default to Medium
	difficulty_preset_dropdown.item_selected.connect(_on_difficulty_preset_changed)
	vbox.add_child(difficulty_preset_dropdown)

	var mine_hbox = HBoxContainer.new()
	mine_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(mine_hbox)

	var mine_label = Label.new()
	mine_label.text = "Mines:"
	mine_label.custom_minimum_size = Vector2(80, 0)
	mine_hbox.add_child(mine_label)

	mine_count_spinbox = SpinBox.new()
	mine_count_spinbox.min_value = 1
	mine_count_spinbox.max_value = 9999
	mine_count_spinbox.value = current_mine_count
	mine_count_spinbox.editable = false
	mine_count_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine_count_spinbox.value_changed.connect(_on_custom_mine_count_changed)
	mine_hbox.add_child(mine_count_spinbox)

	# Wrapping Section
	_add_section_label(vbox, "Wrapping")

	wrap_h_checkbox = CheckBox.new()
	wrap_h_checkbox.text = "Wrap Horizontally"
	wrap_h_checkbox.button_pressed = current_wrap_h
	vbox.add_child(wrap_h_checkbox)

	wrap_v_checkbox = CheckBox.new()
	wrap_v_checkbox.text = "Wrap Vertically"
	wrap_v_checkbox.button_pressed = current_wrap_v
	vbox.add_child(wrap_v_checkbox)

	# Expanding spacer
	var expanding_spacer = Control.new()
	expanding_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(expanding_spacer)

	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(button_hbox)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 40)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_button)

	apply_button = Button.new()
	apply_button.text = "Apply & Restart"
	apply_button.custom_minimum_size = Vector2(100, 40)
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_on_apply_pressed)
	button_hbox.add_child(apply_button)

## Add a section label
func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)

## Handle size preset selection
func _on_size_preset_changed(index: int) -> void:
	# Check if we're using triangle grid (need to double width)
	var is_triangle = grid_type_dropdown.selected == 2
	var width_multiplier = 2 if is_triangle else 1

	match index:
		0:  # Small (10x10 for square/hex, 20x10 for triangle)
			grid_width_spinbox.value = 10 * width_multiplier
			grid_height_spinbox.value = 10
			grid_width_spinbox.editable = false
			grid_height_spinbox.editable = false
		1:  # Medium (20x20 for square/hex, 40x20 for triangle)
			grid_width_spinbox.value = 20 * width_multiplier
			grid_height_spinbox.value = 20
			grid_width_spinbox.editable = false
			grid_height_spinbox.editable = false
		2:  # Large (30x30 for square/hex, 60x30 for triangle)
			grid_width_spinbox.value = 30 * width_multiplier
			grid_height_spinbox.value = 30
			grid_width_spinbox.editable = false
			grid_height_spinbox.editable = false
		3:  # Extra Large (50x50 for square/hex, 100x50 for triangle)
			grid_width_spinbox.value = 50 * width_multiplier
			grid_height_spinbox.value = 50
			grid_width_spinbox.editable = false
			grid_height_spinbox.editable = false
		4:  # Custom
			grid_width_spinbox.editable = true
			grid_height_spinbox.editable = true

	# Update mine count based on new grid size
	_update_mine_count_from_difficulty()

## Handle difficulty preset selection
func _on_difficulty_preset_changed(index: int) -> void:
	if index == 4:  # Custom
		mine_count_spinbox.editable = true
	else:
		mine_count_spinbox.editable = false
		_update_mine_count_from_difficulty()

## Update mine count based on current difficulty and grid size
func _update_mine_count_from_difficulty() -> void:
	var total_cells = int(grid_width_spinbox.value) * int(grid_height_spinbox.value)
	var mine_percentage = 0.16  # Default to medium

	match difficulty_preset_dropdown.selected:
		0:  # Easy (10%)
			mine_percentage = 0.10
		1:  # Medium (16%)
			mine_percentage = 0.16
		2:  # Hard (22%)
			mine_percentage = 0.22
		3:  # Expert (28%)
			mine_percentage = 0.28
		4:  # Custom - don't update
			return

	var new_mine_count = max(1, int(total_cells * mine_percentage))
	mine_count_spinbox.value = new_mine_count

## Handle custom size changes - switch to Custom preset
func _on_custom_size_changed(_value: float) -> void:
	size_preset_dropdown.selected = 4  # Switch to Custom
	_update_mine_count_from_difficulty()

## Handle custom mine count changes - switch to Custom preset
func _on_custom_mine_count_changed(_value: float) -> void:
	difficulty_preset_dropdown.selected = 4  # Switch to Custom

## Handle grid type changes - update neighbor mode checkbox text
func _on_grid_type_changed(index: int) -> void:
	# Hexagon only has one neighbor mode (all neighbors share edges)
	if index == 1:  # Hexagon
		neighbor_mode_checkbox.disabled = true
		neighbor_mode_checkbox.button_pressed = true
		neighbor_mode_checkbox.text = "Include Vertex Neighbors (N/A for Hexagon)"
	elif index == 3:  # Octasquare
		neighbor_mode_checkbox.disabled = true
		neighbor_mode_checkbox.button_pressed = true
		neighbor_mode_checkbox.text = "Include Vertex Neighbors (Mixed)"
	else:
		neighbor_mode_checkbox.disabled = false
		match index:
			0:  # Square
				neighbor_mode_checkbox.text = "Include Vertex Neighbors (4→8)"
			2:  # Triangle
				neighbor_mode_checkbox.text = "Include Vertex Neighbors (3→12)"

	# Update grid size based on current preset (to apply width multiplier for triangles)
	var current_preset = size_preset_dropdown.selected
	if current_preset != 4:  # Not custom
		_on_size_preset_changed(current_preset)

## Show the menu
func show_menu() -> void:
	# Load current settings from controller
	if game_controller:
		current_grid_width = game_controller.grid_width
		current_grid_height = game_controller.grid_height
		current_mine_count = game_controller.mine_count
		current_wrap_h = game_controller.wrap_horizontal
		current_wrap_v = game_controller.wrap_vertical
		current_grid_type = game_controller.grid_type
		current_use_vertex_neighbors = game_controller.use_vertex_neighbors

		# Update UI
		grid_width_spinbox.value = current_grid_width
		grid_height_spinbox.value = current_grid_height
		mine_count_spinbox.value = current_mine_count
		wrap_h_checkbox.button_pressed = current_wrap_h
		wrap_v_checkbox.button_pressed = current_wrap_v
		neighbor_mode_checkbox.button_pressed = current_use_vertex_neighbors

		# Set grid type dropdown
		match current_grid_type:
			"Square":
				grid_type_dropdown.selected = 0
			"Hexagon":
				grid_type_dropdown.selected = 1
			"Triangle":
				grid_type_dropdown.selected = 2
			"Octasquare":
				grid_type_dropdown.selected = 3
			_:
				grid_type_dropdown.selected = 0

		# Update neighbor checkbox based on grid type
		_on_grid_type_changed(grid_type_dropdown.selected)

		# Detect size preset
		_detect_size_preset()

		# Detect difficulty preset
		_detect_difficulty_preset()

	visible = true

## Detect which size preset matches current settings
func _detect_size_preset() -> void:
	if current_grid_width == current_grid_height:
		match current_grid_width:
			10:
				size_preset_dropdown.selected = 0
				grid_width_spinbox.editable = false
				grid_height_spinbox.editable = false
				return
			20:
				size_preset_dropdown.selected = 1
				grid_width_spinbox.editable = false
				grid_height_spinbox.editable = false
				return
			30:
				size_preset_dropdown.selected = 2
				grid_width_spinbox.editable = false
				grid_height_spinbox.editable = false
				return
			50:
				size_preset_dropdown.selected = 3
				grid_width_spinbox.editable = false
				grid_height_spinbox.editable = false
				return

	# Custom size
	size_preset_dropdown.selected = 4
	grid_width_spinbox.editable = true
	grid_height_spinbox.editable = true

## Detect which difficulty preset matches current settings
func _detect_difficulty_preset() -> void:
	var total_cells = current_grid_width * current_grid_height
	var mine_ratio = float(current_mine_count) / float(total_cells)

	# Check if mine count matches a preset (within 1% tolerance)
	if abs(mine_ratio - 0.10) < 0.01:
		difficulty_preset_dropdown.selected = 0  # Easy
		mine_count_spinbox.editable = false
	elif abs(mine_ratio - 0.16) < 0.01:
		difficulty_preset_dropdown.selected = 1  # Medium
		mine_count_spinbox.editable = false
	elif abs(mine_ratio - 0.22) < 0.01:
		difficulty_preset_dropdown.selected = 2  # Hard
		mine_count_spinbox.editable = false
	elif abs(mine_ratio - 0.28) < 0.01:
		difficulty_preset_dropdown.selected = 3  # Expert
		mine_count_spinbox.editable = false
	else:
		difficulty_preset_dropdown.selected = 4  # Custom
		mine_count_spinbox.editable = true

## Hide the menu
func hide_menu() -> void:
	visible = false

## Handle cancel button
func _on_cancel_pressed() -> void:
	print("Settings cancelled")
	hide_menu()

## Handle apply button
func _on_apply_pressed() -> void:
	print("Applying settings...")

	# Read values from UI
	var new_width = int(grid_width_spinbox.value)
	var new_height = int(grid_height_spinbox.value)
	var new_mines = int(mine_count_spinbox.value)
	var new_wrap_h = wrap_h_checkbox.button_pressed
	var new_wrap_v = wrap_v_checkbox.button_pressed
	var new_use_vertex = neighbor_mode_checkbox.button_pressed

	# Get selected grid type
	var new_grid_type = "Square"
	match grid_type_dropdown.selected:
		0:
			new_grid_type = "Square"
		1:
			new_grid_type = "Hexagon"
		2:
			new_grid_type = "Triangle"
		3:
			new_grid_type = "Octasquare"

	# Validate mine count (can't exceed total cells - 9 for first-click safety)
	var max_mines = (new_width * new_height) - 9
	if new_mines > max_mines:
		print("Warning: Too many mines! Clamping to %d" % max_mines)
		new_mines = max_mines
		mine_count_spinbox.value = new_mines

	# Apply to controller
	if game_controller:
		game_controller.grid_type = new_grid_type
		game_controller.grid_width = new_width
		game_controller.grid_height = new_height
		game_controller.mine_count = new_mines
		game_controller.wrap_horizontal = new_wrap_h
		game_controller.wrap_vertical = new_wrap_v
		game_controller.use_vertex_neighbors = new_use_vertex

		# Save settings to file
		game_controller._save_settings()

		# Restart game with new settings
		game_controller.restart_game()

	hide_menu()
	print("Settings applied!")

## Setup with controller reference
func setup(controller: Node) -> void:
	game_controller = controller
