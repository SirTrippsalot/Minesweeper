## GameController.gd
##
## Main game controller that ties together:
## - Grid generation
## - Rendering
## - Camera control
## - Input handling (Phase 3)

class_name GameController
extends Node2D

## Grid parameters
@export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
@export var grid_width: int = 50
@export var grid_height: int = 50
@export var mine_count: int = 400
@export var wrap_horizontal: bool = true
@export var wrap_vertical: bool = true
@export var use_vertex_neighbors: bool = true  # true = edge+vertex, false = edge-only

## Rendering
@export var cell_size: float = 64.0

## Components
var grid_data: GridData
var grid_generator: GridGenerator
var grid_renderer: GridRenderer
var game_camera: Camera2D
var game_logic: GameLogic
var game_ui: GameUI

## Settings file path
const SETTINGS_FILE = "user://settings.cfg"

## Mouse panning state (left-click drag)
var is_panning: bool = false
var mouse_start_pos: Vector2 = Vector2.ZERO
var has_dragged: bool = false
const DRAG_THRESHOLD: float = 5.0  # Pixels before it counts as drag vs click

func _ready():
	print("\n=== Game Controller Starting ===\n")

	# Add to game_controller group for restart signal
	add_to_group("game_controller")

	# Load saved settings
	_load_settings()

	# Create camera first
	_setup_camera()

	# Generate grid
	_generate_grid()

	# Set up renderer
	_setup_renderer()

	# Set up game logic
	_setup_game_logic()

	# Set up UI
	_setup_ui()

	print("\n=== Game Ready! ===")
	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
	print("Total cells: %d" % grid_data.cell_count)
	print("\nControls:")
	print("  - Left Click: Reveal cell")
	print("  - Left Click + Drag: Pan camera")
	print("  - Right Click: Flag/unflag cell")
	print("  - Mouse Wheel: Zoom in/out")
	print("  - Arrow Keys: Pan camera\n")

func _generate_grid() -> void:
	print("Generating %dx%d %s grid..." % [grid_width, grid_height, grid_type])

	# Create appropriate grid generator based on type
	match grid_type:
		"Square":
			grid_generator = SquareGridGenerator.new(
				grid_width,
				grid_height,
				wrap_horizontal,
				wrap_vertical,
				use_vertex_neighbors
			)
		"Hexagon":
			grid_generator = HexGridGenerator.new(
				grid_width,
				grid_height,
				wrap_horizontal,
				wrap_vertical,
				use_vertex_neighbors
			)
		"Triangle":
			grid_generator = TriangleGridGenerator.new(
				grid_width,
				grid_height,
				wrap_horizontal,
				wrap_vertical,
				use_vertex_neighbors
			)
		"TruncatedSquare":
			grid_generator = TruncatedSquareGridGenerator.new(
				grid_width,
				grid_height,
				wrap_horizontal,
				wrap_vertical,
				use_vertex_neighbors
			)
		_:
			# Unknown type - default to square
			print("Warning: Unknown grid type '%s', using Square" % grid_type)
			grid_generator = SquareGridGenerator.new(
				grid_width,
				grid_height,
				wrap_horizontal,
				wrap_vertical,
				use_vertex_neighbors
			)

	# Set cell size on generator
	grid_generator.cell_size = cell_size

	# Generate grid data
	grid_data = grid_generator.generate(mine_count)

	if grid_data:
		print("✓ Grid generated successfully")
		print("  - Type: %s" % grid_type)
		print("  - Mines: %d" % grid_data.count_total_mines())
		print("  - Wrapping: H=%s V=%s" % [wrap_horizontal, wrap_vertical])
	else:
		push_error("Failed to generate grid")

func _setup_renderer() -> void:
	print("Setting up renderer...")

	# Create renderer
	grid_renderer = GridRenderer.new()
	grid_renderer.cell_size = cell_size
	add_child(grid_renderer)

	# Connect to grid data
	grid_renderer.setup(grid_data, grid_generator)

	# Center camera on grid after renderer is set up
	_center_camera_on_grid()

	print("✓ Renderer ready")

func _setup_game_logic() -> void:
	print("Setting up game logic...")

	game_logic = GameLogic.new()
	game_logic.initialize(grid_data, grid_generator)

	print("✓ Game logic ready")

func _setup_ui() -> void:
	print("Setting up UI...")

	game_ui = GameUI.new()
	add_child(game_ui)
	game_ui.setup(game_logic, self)  # Pass self as controller reference

	print("✓ UI ready")

func _setup_camera() -> void:
	print("Setting up camera...")

	game_camera = Camera2D.new()
	add_child(game_camera)

	# Camera settings
	game_camera.enabled = true
	game_camera.zoom = Vector2.ONE

	print("✓ Camera ready")

func _process(_delta):
	# Camera controls
	_handle_camera_input()

## Simple camera controls for Phase 2
func _handle_camera_input() -> void:
	if not game_camera:
		return

	var move_speed = 500.0 / game_camera.zoom.x
	var move_delta = Vector2.ZERO

	# Arrow key panning
	if Input.is_key_pressed(KEY_LEFT):
		move_delta.x -= move_speed * get_process_delta_time()
	if Input.is_key_pressed(KEY_RIGHT):
		move_delta.x += move_speed * get_process_delta_time()
	if Input.is_key_pressed(KEY_UP):
		move_delta.y -= move_speed * get_process_delta_time()
	if Input.is_key_pressed(KEY_DOWN):
		move_delta.y += move_speed * get_process_delta_time()

	game_camera.position += move_delta

func _unhandled_input(event):
	if not game_camera:
		return

	# Mouse button events
	if event is InputEventMouseButton:
		# Mouse wheel zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(0.9)

		# Left mouse button
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start potential pan
				is_panning = true
				has_dragged = false
				mouse_start_pos = event.position
			else:
				# Released - check if it was a click or drag
				if is_panning and not has_dragged:
					# It was a click, not a drag
					_handle_cell_click(event.position, false)
				is_panning = false
				has_dragged = false

		# Right click - flag cell
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_cell_click(event.position, true)

	# Left mouse drag panning
	if event is InputEventMouseMotion and is_panning:
		# Check if we've moved enough to count as a drag
		var drag_distance = event.position.distance_to(mouse_start_pos)
		if drag_distance > DRAG_THRESHOLD:
			has_dragged = true

		# Pan the camera if we're dragging
		if has_dragged:
			game_camera.position -= event.relative / game_camera.zoom
			get_viewport().set_input_as_handled()

func _zoom_camera(factor: float) -> void:
	var new_zoom = game_camera.zoom * factor
	# Clamp zoom levels
	new_zoom.x = clamp(new_zoom.x, 0.1, 5.0)
	new_zoom.y = clamp(new_zoom.y, 0.1, 5.0)
	game_camera.zoom = new_zoom

## Center camera on grid
func _center_camera_on_grid() -> void:
	if not game_camera or not grid_generator:
		return

	# Calculate grid center
	var grid_pixel_width = grid_width * cell_size
	var grid_pixel_height = grid_height * cell_size
	var center = Vector2(grid_pixel_width / 2.0, grid_pixel_height / 2.0)

	game_camera.position = center
	print("Camera centered at: %s" % center)

## Handle cell click (reveal or flag)
func _handle_cell_click(screen_pos: Vector2, is_right_click: bool) -> void:
	if not game_logic or not grid_renderer:
		return

	# Convert screen position to world position
	var world_pos = game_camera.get_global_mouse_position()

	# Get cell at this position
	var cell_id = grid_renderer.get_cell_at_position(world_pos)
	if cell_id < 0:
		return  # Clicked outside grid

	# Handle right click (flagging)
	if is_right_click:
		if game_logic.toggle_flag(cell_id):
			grid_renderer.mark_cell_dirty(cell_id)
			grid_renderer.update_dirty_cells()
			# Update UI stats (mines remaining changes)
			if game_ui:
				game_ui.update_stats()
		return

	# DEBUG: Uncomment to visualize neighbors instead of normal gameplay
	#_debug_highlight_neighbors(cell_id)
	#return

	# Handle left click (reveal)
	var revealed_cells = game_logic.reveal_cell(cell_id)
	if revealed_cells.size() > 0:
		grid_renderer.mark_cells_dirty(revealed_cells)
		grid_renderer.update_dirty_cells()

		# Update UI stats
		if game_ui:
			game_ui.update_stats()

		# Check if game ended
		var game_state = game_logic.get_state()
		if game_state == GameLogic.GameState.LOST:
			# Show all mines and flag accuracy
			grid_renderer.reveal_all_mines()
			grid_renderer.show_flag_accuracy()
		elif game_state == GameLogic.GameState.WON:
			# Show flag accuracy on win too
			grid_renderer.show_flag_accuracy()

		# Print flood fill results
		if revealed_cells.size() > 1:
			print("Revealed %d cells via flood fill" % revealed_cells.size())

## DEBUG: Visualize neighbor detection
## Highlights clicked cell in green and its neighbors in red
## NOTE: Kept for debugging neighbor detection - see usage in _handle_cell_click()
func _debug_highlight_neighbors(cell_id: int) -> void:
	# Get neighbors from grid data
	var neighbors = grid_data.get_neighbors(cell_id)

	# Reset all cells to hidden color first
	for i in range(grid_data.cell_count):
		grid_data.cell_state[i] = GridData.CellState.HIDDEN

	# Set clicked cell to revealed (will show as green)
	grid_data.cell_state[cell_id] = GridData.CellState.REVEALED

	# Set all neighbors to flagged (will show as red)
	for neighbor_id in neighbors:
		grid_data.cell_state[neighbor_id] = GridData.CellState.FLAGGED

	# Mark all cells dirty to force re-render
	var all_cells = PackedInt32Array()
	for i in range(grid_data.cell_count):
		all_cells.append(i)
	grid_renderer.mark_cells_dirty(all_cells)
	grid_renderer.update_dirty_cells()

	print("Cell %d has %d neighbors: %s" % [cell_id, neighbors.size(), neighbors])

## Restart the game (called from UI)
func restart_game() -> void:
	print("\n=== Restarting Game ===")
	print("restart_game() function called!")

	# Regenerate grid with current settings (grid_type may have changed!)
	_generate_grid()

	# Recreate game logic with new grid
	game_logic.initialize(grid_data, grid_generator)

	# Clean up old renderer
	if grid_renderer.labels_container:
		grid_renderer.labels_container.queue_free()
	if grid_renderer.cell_multimesh:
		grid_renderer.cell_multimesh.queue_free()
	if grid_renderer.border_multimesh:
		grid_renderer.border_multimesh.queue_free()

	# Clean up infinite tiles
	for tile in grid_renderer.tile_instances:
		if tile.has("cells") and tile["cells"]:
			tile["cells"].queue_free()
		if tile.has("borders") and tile["borders"]:
			tile["borders"].queue_free()
		if tile.has("labels") and tile["labels"]:
			tile["labels"].queue_free()
	grid_renderer.tile_instances.clear()

	# Update renderer with new grid data and generator
	grid_renderer.grid_data = grid_data
	grid_renderer.grid_generator = grid_generator
	grid_renderer.cell_size = cell_size

	# Reinitialize everything
	grid_renderer.number_labels.clear()
	grid_renderer.dirty_cells.clear()
	grid_renderer._initialize_rendering()

	# Recenter camera on new grid
	_center_camera_on_grid()

	# Update UI
	if game_ui:
		game_ui.update_stats()

	print("Game restarted!")

## Load settings from file
func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)

	if err != OK:
		print("No saved settings found, using defaults")
		return

	# Load grid settings
	grid_type = config.get_value("game", "grid_type", "Square")
	grid_width = config.get_value("game", "grid_width", 50)
	grid_height = config.get_value("game", "grid_height", 50)
	mine_count = config.get_value("game", "mine_count", 400)
	wrap_horizontal = config.get_value("game", "wrap_horizontal", true)
	wrap_vertical = config.get_value("game", "wrap_vertical", true)
	use_vertex_neighbors = config.get_value("game", "use_vertex_neighbors", true)

	print("Settings loaded from %s" % SETTINGS_FILE)
	print("  Grid Type: %s" % grid_type)
	print("  Grid Size: %dx%d" % [grid_width, grid_height])
	print("  Mines: %d" % mine_count)
	print("  Wrapping: H=%s V=%s" % [wrap_horizontal, wrap_vertical])

## Save settings to file
func _save_settings() -> void:
	var config = ConfigFile.new()

	# Save grid settings
	config.set_value("game", "grid_type", grid_type)
	config.set_value("game", "grid_width", grid_width)
	config.set_value("game", "grid_height", grid_height)
	config.set_value("game", "mine_count", mine_count)
	config.set_value("game", "wrap_horizontal", wrap_horizontal)
	config.set_value("game", "wrap_vertical", wrap_vertical)
	config.set_value("game", "use_vertex_neighbors", use_vertex_neighbors)

	var err = config.save(SETTINGS_FILE)
	if err == OK:
		print("Settings saved to %s" % SETTINGS_FILE)
	else:
		print("Error saving settings: %d" % err)
