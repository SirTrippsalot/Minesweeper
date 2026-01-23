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
@export var mine_count: int = 400  # ~16% density (medium difficulty)
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

## Mouse panning state (left-click drag)
var is_panning: bool = false
var mouse_start_pos: Vector2 = Vector2.ZERO
var has_dragged: bool = false
const DRAG_THRESHOLD: float = 5.0  # Pixels before it counts as drag vs click

func _ready():
	print("\n=== Game Controller Starting ===\n")

	# Add to game_controller group for restart signal
	add_to_group("game_controller")

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
		"Octasquare":
			grid_generator = OctagonSquareGridGenerator.new(
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

	# Connect signals for win/loss detection
	game_logic.game_won.connect(_on_game_won)
	game_logic.game_lost.connect(_on_game_lost)

	print("✓ Game logic ready")

func _setup_ui() -> void:
	print("Setting up UI...")

	game_ui = GameUI.new()
	add_child(game_ui)
	game_ui.setup(game_logic, self)

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
## DEBUG: Visualize neighbor detection
## Highlights clicked cell in green and its neighbors in red
## NOTE: Kept for debugging neighbor detection - see usage in _handle_cell_click()
## Restart the game (called from UI)
## Load settings from file
## Save settings to file
## Handle cell click (reveal or flag)
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
## Load settings from file
## Save settings to file
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
		return

	# Handle left click (reveal)
	var revealed_cells = game_logic.reveal_cell(cell_id)
	if revealed_cells.size() > 0:
		grid_renderer.mark_cells_dirty(revealed_cells)
		grid_renderer.update_dirty_cells()

		# Print flood fill results
		if revealed_cells.size() > 1:
			print("Revealed %d cells via flood fill" % revealed_cells.size())

## Handle game won
func _on_game_won() -> void:
	print("🎉 YOU WIN!")
	# Reveal all mines (as flagged)
	for cell_id in range(grid_data.cell_count):
		if grid_data.is_mine(cell_id):
			grid_data.flag_cell(cell_id)
	grid_renderer.refresh_all()

## Handle game lost
func _on_game_lost() -> void:
	print("💥 GAME OVER")
	# Reveal all mines
	for cell_id in range(grid_data.cell_count):
		if grid_data.is_mine(cell_id):
			grid_data.reveal_cell(cell_id)
	grid_renderer.refresh_all()

## Restart game with current settings
func restart_game() -> void:
	print("\n=== Restarting Game ===\n")

	# Clean up existing components
	if grid_renderer:
		grid_renderer.queue_free()
	if game_ui:
		game_ui.queue_free()

	# Wait for cleanup
	await get_tree().process_frame

	# Regenerate everything
	_generate_grid()
	_setup_renderer()
	_setup_game_logic()
	_setup_ui()
	_center_camera_on_grid()

	print("Game restarted!")

## Save current settings to file
func _save_settings() -> void:
	var settings = {
		"grid_type": grid_type,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"mine_count": mine_count,
		"wrap_horizontal": wrap_horizontal,
		"wrap_vertical": wrap_vertical,
		"use_vertex_neighbors": use_vertex_neighbors
	}

	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()
		print("Settings saved")
	else:
		push_warning("Failed to save settings")

## Load settings from file
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		print("No settings file found, using defaults")
		return

	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var settings = json.data
			if settings is Dictionary:
				grid_type = settings.get("grid_type", grid_type)
				grid_width = settings.get("grid_width", grid_width)
				grid_height = settings.get("grid_height", grid_height)
				mine_count = settings.get("mine_count", mine_count)
				wrap_horizontal = settings.get("wrap_horizontal", wrap_horizontal)
				wrap_vertical = settings.get("wrap_vertical", wrap_vertical)
				use_vertex_neighbors = settings.get("use_vertex_neighbors", use_vertex_neighbors)
				print("Settings loaded")
			else:
				push_warning("Settings file invalid")
		else:
			push_warning("Failed to parse settings JSON")
	else:
		push_warning("Failed to open settings file")


# ================================================================================
# FAILED EDITS - These edits could not be applied because old_string was not found
# Review these to see if any important code is missing
# ================================================================================


# ========== FAILED EDIT #1 ==========
# OLD_STRING (not found in file):
# OLD: func _setup_camera() -> void:
# OLD: 	print("Setting up camera...")
# OLD: 
# OLD: 	game_camera = Camera2D.new()
# OLD: 	add_child(game_camera)
# OLD: 
# OLD: 	# Camera settings
# OLD: 	game_camera.enabled = true
# OLD: 
# OLD: 	# Center camera on grid (will be calculated after grid is created)
# OLD: 	# For now, start at origin
# OLD: 	game_camera.position = Vector2.ZERO
# OLD: 
# OLD: 	print("✓ Camera ready")
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _setup_camera() -> void:
# NEW: 	print("Setting up camera...")
# NEW: 
# NEW: 	game_camera = Camera2D.new()
# NEW: 	add_child(game_camera)
# NEW: 
# NEW: 	# Camera settings
# NEW: 	game_camera.enabled = true
# NEW: 	game_camera.zoom = Vector2.ONE
# NEW: 
# NEW: 	print("✓ Camera ready")

# ========== FAILED EDIT #2 ==========
# OLD_STRING (not found in file):
# OLD: func _setup_renderer() -> void:
# OLD: 	print("Setting up renderer...")
# OLD: 
# OLD: 	# Create renderer
# OLD: 	grid_renderer = GridRenderer.new()
# OLD: 	grid_renderer.cell_size = cell_size
# OLD: 	add_child(grid_renderer)
# OLD: 
# OLD: 	# Connect to grid data
# OLD: 	grid_renderer.setup(grid_data, grid_generator)
# OLD: 
# OLD: 	print("✓ Renderer ready")
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _setup_renderer() -> void:
# NEW: 	print("Setting up renderer...")
# NEW: 
# NEW: 	# Create renderer
# NEW: 	grid_renderer = GridRenderer.new()
# NEW: 	grid_renderer.cell_size = cell_size
# NEW: 	add_child(grid_renderer)
# NEW: 
# NEW: 	# Connect to grid data
# NEW: 	grid_renderer.setup(grid_data, grid_generator)
# NEW: 
# NEW: 	# Center camera on grid after renderer is set up
# NEW: 	_center_camera_on_grid()
# NEW: 
# NEW: 	print("✓ Renderer ready")

# ========== FAILED EDIT #3 ==========
# OLD_STRING (not found in file):
# OLD: ## Center camera on grid
# OLD: func center_camera() -> void:
# OLD: 	if not game_camera or not grid_generator:
# OLD: 		return
# OLD: 
# OLD: 	# Calculate grid center
# OLD: 	var grid_pixel_width = grid_width * cell_size
# OLD: 	var grid_pixel_height = grid_height * cell_size
# OLD: 	var center = Vector2(grid_pixel_width / 2.0, grid_pixel_height / 2.0)
# OLD: 
# OLD: 	game_camera.position = center
# OLD: 	print("Camera centered at: %s" % center)
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Center camera on grid
# NEW: func _center_camera_on_grid() -> void:
# NEW: 	if not game_camera or not grid_generator:
# NEW: 		return
# NEW: 
# NEW: 	# Calculate grid center
# NEW: 	var grid_pixel_width = grid_width * cell_size
# NEW: 	var grid_pixel_height = grid_height * cell_size
# NEW: 	var center = Vector2(grid_pixel_width / 2.0, grid_pixel_height / 2.0)
# NEW: 
# NEW: 	game_camera.position = center
# NEW: 	print("Camera centered at: %s" % center)

# ========== FAILED EDIT #5 ==========
# OLD_STRING (not found in file):
# OLD: 	# Set up renderer
# OLD: 	_setup_renderer()
# OLD: 
# OLD: 	print("\n=== Game Ready! ===")
# OLD: 	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
# OLD: 	print("Total cells: %d" % grid_data.cell_count)
# OLD: 	print("\nControls:")
# OLD: 	print("  - Mouse Wheel: Zoom in/out")
# OLD: 	print("  - Middle Mouse Drag: Pan camera")
# OLD: 	print("  - Arrow Keys: Pan camera\n")
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	# Set up renderer
# NEW: 	_setup_renderer()
# NEW: 
# NEW: 	# Set up game logic
# NEW: 	_setup_game_logic()
# NEW: 
# NEW: 	print("\n=== Game Ready! ===")
# NEW: 	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
# NEW: 	print("Total cells: %d" % grid_data.cell_count)
# NEW: 	print("\nControls:")
# NEW: 	print("  - Left Click: Reveal cell")
# NEW: 	print("  - Right Click: Flag/unflag cell")
# NEW: 	print("  - Mouse Wheel: Zoom in/out")
# NEW: 	print("  - Middle Mouse Drag: Pan camera")
# NEW: 	print("  - Arrow Keys: Pan camera\n")

# ========== FAILED EDIT #6 ==========
# OLD_STRING (not found in file):
# OLD: 	print("✓ Renderer ready")
# OLD: 
# OLD: func _setup_camera() -> void:
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	print("✓ Renderer ready")
# NEW: 
# NEW: func _setup_game_logic() -> void:
# NEW: 	print("Setting up game logic...")
# NEW: 
# NEW: 	game_logic = GameLogic.new()
# NEW: 	game_logic.initialize(grid_data, grid_generator)
# NEW: 
# NEW: 	print("✓ Game logic ready")
# NEW: 
# NEW: func _setup_camera() -> void:

# ========== FAILED EDIT #7 ==========
# OLD_STRING (not found in file):
# OLD: func _unhandled_input(event):
# OLD: 	if not game_camera:
# OLD: 		return
# OLD: 
# OLD: 	# Mouse wheel zoom
# OLD: 	if event is InputEventMouseButton:
# OLD: 		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
# OLD: 			_zoom_camera(1.1)
# OLD: 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
# OLD: 			_zoom_camera(0.9)
# OLD: 
# OLD: 	# Middle mouse drag panning
# OLD: 	if event is InputEventMouseMotion:
# OLD: 		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
# OLD: 			game_camera.position -= event.relative / game_camera.zoom
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _unhandled_input(event):
# NEW: 	if not game_camera:
# NEW: 		return
# NEW: 
# NEW: 	# Mouse button events
# NEW: 	if event is InputEventMouseButton:
# NEW: 		# Mouse wheel zoom
# NEW: 		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
# NEW: 			_zoom_camera(1.1)
# NEW: 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
# NEW: 			_zoom_camera(0.9)
# NEW: 
# NEW: 		# Left click - reveal cell
# NEW: 		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
# NEW: 			_handle_cell_click(event.position, false)
# NEW: 
# NEW: 		# Right click - flag cell
# NEW: 		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
# NEW: 			_handle_cell_click(event.position, true)
# NEW: 
# NEW: 	# Middle mouse drag panning
# NEW: 	if event is InputEventMouseMotion:
# NEW: 		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
# NEW: 			game_camera.position -= event.relative / game_camera.zoom

# ========== FAILED EDIT #12 ==========
# OLD_STRING (not found in file):
# OLD: func _ready():
# OLD: 	print("\n=== Game Controller Starting ===\n")
# OLD: 
# OLD: 	# Create camera first
# OLD: 	_setup_camera()
# OLD: 
# OLD: 	# Generate grid
# OLD: 	_generate_grid()
# OLD: 
# OLD: 	# Set up renderer
# OLD: 	_setup_renderer()
# OLD: 
# OLD: 	# Set up game logic
# OLD: 	_setup_game_logic()
# OLD: 
# OLD: 	print("\n=== Game Ready! ===")
# OLD: 	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
# OLD: 	print("Total cells: %d" % grid_data.cell_count)
# OLD: 	print("\nControls:")
# OLD: 	print("  - Left Click: Reveal cell")
# OLD: 	print("  - Right Click: Flag/unflag cell")
# OLD: 	print("  - Mouse Wheel: Zoom in/out")
# OLD: 	print("  - Middle Mouse Drag: Pan camera")
# OLD: 	print("  - Arrow Keys: Pan camera\n")
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _ready():
# NEW: 	print("\n=== Game Controller Starting ===\n")
# NEW: 
# NEW: 	# Add to game_controller group for restart signal
# NEW: 	add_to_group("game_controller")
# NEW: 
# NEW: 	# Create camera first
# NEW: 	_setup_camera()
# NEW: 
# NEW: 	# Generate grid
# NEW: 	_generate_grid()
# NEW: 
# NEW: 	# Set up renderer
# NEW: 	_setup_renderer()
# NEW: 
# NEW: 	# Set up game logic
# NEW: 	_setup_game_logic()
# NEW: 
# NEW: 	# Set up UI
# NEW: 	_setup_ui()
# NEW: 
# NEW: 	print("\n=== Game Ready! ===")
# NEW: 	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
# NEW: 	print("Total cells: %d" % grid_data.cell_count)
# NEW: 	print("\nControls:")
# NEW: 	print("  - Left Click: Reveal cell")
# NEW: 	print("  - Right Click: Flag/unflag cell")
# NEW: 	print("  - Mouse Wheel: Zoom in/out")
# NEW: 	print("  - Middle Mouse Drag: Pan camera")
# NEW: 	print("  - Arrow Keys: Pan camera\n")

# ========== FAILED EDIT #13 ==========
# OLD_STRING (not found in file):
# OLD: func _setup_game_logic() -> void:
# OLD: 	print("Setting up game logic...")
# OLD: 
# OLD: 	game_logic = GameLogic.new()
# OLD: 	game_logic.initialize(grid_data, grid_generator)
# OLD: 
# OLD: 	print("✓ Game logic ready")
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _setup_game_logic() -> void:
# NEW: 	print("Setting up game logic...")
# NEW: 
# NEW: 	game_logic = GameLogic.new()
# NEW: 	game_logic.initialize(grid_data, grid_generator)
# NEW: 
# NEW: 	print("✓ Game logic ready")
# NEW: 
# NEW: func _setup_ui() -> void:
# NEW: 	print("Setting up UI...")
# NEW: 
# NEW: 	game_ui = GameUI.new()
# NEW: 	add_child(game_ui)
# NEW: 	game_ui.setup(game_logic)
# NEW: 
# NEW: 	print("✓ UI ready")

# ========== FAILED EDIT #19 ==========
# OLD_STRING (not found in file):
# OLD: func _setup_ui() -> void:
# OLD: 	print("Setting up UI...")
# OLD: 
# OLD: 	game_ui = GameUI.new()
# OLD: 	add_child(game_ui)
# OLD: 	game_ui.setup(game_logic)
# OLD: 
# OLD: 	print("✓ UI ready")
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _setup_ui() -> void:
# NEW: 	print("Setting up UI...")
# NEW: 
# NEW: 	game_ui = GameUI.new()
# NEW: 	add_child(game_ui)
# NEW: 	game_ui.setup(game_logic, self)  # Pass self as controller reference
# NEW: 
# NEW: 	print("✓ UI ready")

# ========== FAILED EDIT #20 ==========
# OLD_STRING (not found in file):
# OLD: ## Grid parameters
# OLD: @export var grid_width: int = 20
# OLD: @export var grid_height: int = 20
# OLD: @export var mine_count: int = 60
# OLD: @export var wrap_horizontal: bool = true
# OLD: @export var wrap_vertical: bool = true
# OLD: 
# OLD: ## Rendering
# OLD: @export var cell_size: float = 64.0
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Grid parameters
# NEW: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# NEW: @export var grid_width: int = 20
# NEW: @export var grid_height: int = 20
# NEW: @export var mine_count: int = 60
# NEW: @export var wrap_horizontal: bool = true
# NEW: @export var wrap_vertical: bool = true
# NEW: 
# NEW: ## Rendering
# NEW: @export var cell_size: float = 64.0

# ========== FAILED EDIT #21 ==========
# OLD_STRING (not found in file):
# OLD: func _generate_grid() -> void:
# OLD: 	print("Generating %dx%d square grid..." % [grid_width, grid_height])
# OLD: 
# OLD: 	# Create square grid generator
# OLD: 	grid_generator = SquareGridGenerator.new(
# OLD: 		grid_width,
# OLD: 		grid_height,
# OLD: 		wrap_horizontal,
# OLD: 		wrap_vertical
# OLD: 	)
# OLD: 
# OLD: 	# Generate grid data
# OLD: 	grid_data = grid_generator.generate(mine_count)
# OLD: 
# OLD: 	if grid_data:
# OLD: 		print("✓ Grid generated successfully")
# OLD: 		print("  - Mines: %d" % grid_data.count_total_mines())
# OLD: 		print("  - Wrapping: H=%s V=%s" % [wrap_horizontal, wrap_vertical])
# OLD: 	else:
# OLD: 		push_error("Failed to generate grid")
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _generate_grid() -> void:
# NEW: 	print("Generating %dx%d %s grid..." % [grid_width, grid_height, grid_type])
# NEW: 
# NEW: 	# Create appropriate grid generator based on type
# NEW: 	match grid_type:
# NEW: 		"Square":
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical
# NEW: 			)
# NEW: 		"Hexagon":
# NEW: 			grid_generator = HexGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical
# NEW: 			)
# NEW: 		"Triangle":
# NEW: 			# Not implemented yet - fall back to square
# NEW: 			print("Warning: Triangle grid not implemented yet, using Square")
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical
# NEW: 			)
# NEW: 		_:
# NEW: 			# Unknown type - default to square
# NEW: 			print("Warning: Unknown grid type '%s', using Square" % grid_type)
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical
# NEW: 			)
# NEW: 
# NEW: 	# Set cell size on generator
# NEW: 	grid_generator.cell_size = cell_size
# NEW: 
# NEW: 	# Generate grid data
# NEW: 	grid_data = grid_generator.generate(mine_count)
# NEW: 
# NEW: 	if grid_data:
# NEW: 		print("✓ Grid generated successfully")
# NEW: 		print("  - Type: %s" % grid_type)
# NEW: 		print("  - Mines: %d" % grid_data.count_total_mines())
# NEW: 		print("  - Wrapping: H=%s V=%s" % [wrap_horizontal, wrap_vertical])
# NEW: 	else:
# NEW: 		push_error("Failed to generate grid")

# ========== FAILED EDIT #25 ==========
# OLD_STRING (not found in file):
# OLD: ## Components
# OLD: var grid_data: GridData
# OLD: var grid_generator: GridGenerator
# OLD: var grid_renderer: GridRenderer
# OLD: var game_camera: Camera2D
# OLD: var game_logic: GameLogic
# OLD: var game_ui: GameUI
# OLD: 
# OLD: func _ready():
# OLD: 	print("\n=== Game Controller Starting ===\n")
# OLD: 
# OLD: 	# Add to game_controller group for restart signal
# OLD: 	add_to_group("game_controller")
# OLD: 
# OLD: 	# Create camera first
# OLD: 	_setup_camera()
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Components
# NEW: var grid_data: GridData
# NEW: var grid_generator: GridGenerator
# NEW: var grid_renderer: GridRenderer
# NEW: var game_camera: Camera2D
# NEW: var game_logic: GameLogic
# NEW: var game_ui: GameUI
# NEW: 
# NEW: ## Settings file path
# NEW: const SETTINGS_FILE = "user://settings.cfg"
# NEW: 
# NEW: func _ready():
# NEW: 	print("\n=== Game Controller Starting ===\n")
# NEW: 
# NEW: 	# Add to game_controller group for restart signal
# NEW: 	add_to_group("game_controller")
# NEW: 
# NEW: 	# Load saved settings
# NEW: 	_load_settings()
# NEW: 
# NEW: 	# Create camera first
# NEW: 	_setup_camera()

# ========== FAILED EDIT #27 ==========
# OLD_STRING (not found in file):
# OLD: ## Components
# OLD: var grid_data: GridData
# OLD: var grid_generator: GridGenerator
# OLD: var grid_renderer: GridRenderer
# OLD: var game_camera: Camera2D
# OLD: var game_logic: GameLogic
# OLD: var game_ui: GameUI
# OLD: 
# OLD: ## Settings file path
# OLD: const SETTINGS_FILE = "user://settings.cfg"
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Components
# NEW: var grid_data: GridData
# NEW: var grid_generator: GridGenerator
# NEW: var grid_renderer: GridRenderer
# NEW: var game_camera: Camera2D
# NEW: var game_logic: GameLogic
# NEW: var game_ui: GameUI
# NEW: 
# NEW: ## Settings file path
# NEW: const SETTINGS_FILE = "user://settings.cfg"
# NEW: 
# NEW: ## Mouse panning state
# NEW: var is_panning: bool = false

# ========== FAILED EDIT #28 ==========
# OLD_STRING (not found in file):
# OLD: 	# Mouse button events
# OLD: 	if event is InputEventMouseButton:
# OLD: 		# Mouse wheel zoom
# OLD: 		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
# OLD: 			_zoom_camera(1.1)
# OLD: 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
# OLD: 			_zoom_camera(0.9)
# OLD: 
# OLD: 		# Left click - reveal cell
# OLD: 		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
# OLD: 			_handle_cell_click(event.position, false)
# OLD: 
# OLD: 		# Right click - flag cell
# OLD: 		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
# OLD: 			_handle_cell_click(event.position, true)
# OLD: 
# OLD: 	# Middle mouse drag panning
# OLD: 	if event is InputEventMouseMotion:
# OLD: 		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
# OLD: 			game_camera.position -= event.relative / game_camera.zoom
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	# Mouse button events
# NEW: 	if event is InputEventMouseButton:
# NEW: 		# Middle mouse button press/release
# NEW: 		if event.button_index == MOUSE_BUTTON_MIDDLE:
# NEW: 			is_panning = event.pressed
# NEW: 			if event.pressed:
# NEW: 				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
# NEW: 			else:
# NEW: 				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
# NEW: 			get_viewport().set_input_as_handled()
# NEW: 			return
# NEW: 
# NEW: 		# Mouse wheel zoom
# NEW: 		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
# NEW: 			_zoom_camera(1.1)
# NEW: 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
# NEW: 			_zoom_camera(0.9)
# NEW: 
# NEW: 		# Left click - reveal cell
# NEW: 		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
# NEW: 			_handle_cell_click(event.position, false)
# NEW: 
# NEW: 		# Right click - flag cell
# NEW: 		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
# NEW: 			_handle_cell_click(event.position, true)
# NEW: 
# NEW: 	# Middle mouse drag panning
# NEW: 	if event is InputEventMouseMotion and is_panning:
# NEW: 		game_camera.position -= event.relative / game_camera.zoom
# NEW: 		get_viewport().set_input_as_handled()

# ========== FAILED EDIT #29 ==========
# OLD_STRING (not found in file):
# OLD: ## Grid parameters
# OLD: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# OLD: @export var grid_width: int = 20
# OLD: @export var grid_height: int = 20
# OLD: @export var mine_count: int = 60
# OLD: @export var wrap_horizontal: bool = true
# OLD: @export var wrap_vertical: bool = true
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Grid parameters
# NEW: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# NEW: @export var grid_width: int = 50
# NEW: @export var grid_height: int = 50
# NEW: @export var mine_count: int = 400  # ~16% density (medium difficulty)
# NEW: @export var wrap_horizontal: bool = true
# NEW: @export var wrap_vertical: bool = true

# ========== FAILED EDIT #30 ==========
# OLD_STRING (not found in file):
# OLD: ## Grid parameters
# OLD: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# OLD: @export var grid_width: int = 20
# OLD: @export var grid_height: int = 20
# OLD: @export var mine_count: int = 60
# OLD: @export var wrap_horizontal: bool = true
# OLD: @export var wrap_vertical: bool = true
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Grid parameters
# NEW: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# NEW: @export var grid_width: int = 50
# NEW: @export var grid_height: int = 50
# NEW: @export var mine_count: int = 400
# NEW: @export var wrap_horizontal: bool = true
# NEW: @export var wrap_vertical: bool = true

# ========== FAILED EDIT #31 ==========
# OLD_STRING (not found in file):
# OLD: ## Mouse panning state
# OLD: var is_panning: bool = false
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Mouse panning state (left-click drag)
# NEW: var is_panning: bool = false
# NEW: var mouse_start_pos: Vector2 = Vector2.ZERO
# NEW: var has_dragged: bool = false
# NEW: const DRAG_THRESHOLD: float = 5.0  # Pixels before it counts as drag vs click

# ========== FAILED EDIT #32 ==========
# OLD_STRING (not found in file):
# OLD: 	print("\n=== Game Ready! ===")
# OLD: 	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
# OLD: 	print("Total cells: %d" % grid_data.cell_count)
# OLD: 	print("\nControls:")
# OLD: 	print("  - Left Click: Reveal cell")
# OLD: 	print("  - Right Click: Flag/unflag cell")
# OLD: 	print("  - Mouse Wheel: Zoom in/out")
# OLD: 	print("  - Middle Mouse Drag: Pan camera")
# OLD: 	print("  - Arrow Keys: Pan camera\n")
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	print("\n=== Game Ready! ===")
# NEW: 	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
# NEW: 	print("Total cells: %d" % grid_data.cell_count)
# NEW: 	print("\nControls:")
# NEW: 	print("  - Left Click: Reveal cell")
# NEW: 	print("  - Left Click + Drag: Pan camera")
# NEW: 	print("  - Right Click: Flag/unflag cell")
# NEW: 	print("  - Mouse Wheel: Zoom in/out")
# NEW: 	print("  - Arrow Keys: Pan camera\n")

# ========== FAILED EDIT #33 ==========
# OLD_STRING (not found in file):
# OLD: func _unhandled_input(event):
# OLD: 	if not game_camera:
# OLD: 		return
# OLD: 
# OLD: 	# Mouse button events
# OLD: 	if event is InputEventMouseButton:
# OLD: 		# Middle mouse button press/release
# OLD: 		if event.button_index == MOUSE_BUTTON_MIDDLE:
# OLD: 			is_panning = event.pressed
# OLD: 			if event.pressed:
# OLD: 				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
# OLD: 			else:
# OLD: 				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
# OLD: 			get_viewport().set_input_as_handled()
# OLD: 			return
# OLD: 
# OLD: 		# Mouse wheel zoom
# OLD: 		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
# OLD: 			_zoom_camera(1.1)
# OLD: 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
# OLD: 			_zoom_camera(0.9)
# OLD: 
# OLD: 		# Left click - reveal cell
# OLD: 		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
# OLD: 			_handle_cell_click(event.position, false)
# OLD: 
# OLD: 		# Right click - flag cell
# OLD: 		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
# OLD: 			_handle_cell_click(event.position, true)
# OLD: 
# OLD: 	# Middle mouse drag panning
# OLD: 	if event is InputEventMouseMotion and is_panning:
# OLD: 		game_camera.position -= event.relative / game_camera.zoom
# OLD: 		get_viewport().set_input_as_handled()
#
# NEW_STRING (what it wanted to replace with):
# NEW: func _unhandled_input(event):
# NEW: 	if not game_camera:
# NEW: 		return
# NEW: 
# NEW: 	# Mouse button events
# NEW: 	if event is InputEventMouseButton:
# NEW: 		# Mouse wheel zoom
# NEW: 		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
# NEW: 			_zoom_camera(1.1)
# NEW: 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
# NEW: 			_zoom_camera(0.9)
# NEW: 
# NEW: 		# Left mouse button
# NEW: 		elif event.button_index == MOUSE_BUTTON_LEFT:
# NEW: 			if event.pressed:
# NEW: 				# Start potential pan
# NEW: 				is_panning = true
# NEW: 				has_dragged = false
# NEW: 				mouse_start_pos = event.position
# NEW: 			else:
# NEW: 				# Released - check if it was a click or drag
# NEW: 				if is_panning and not has_dragged:
# NEW: 					# It was a click, not a drag
# NEW: 					_handle_cell_click(event.position, false)
# NEW: 				is_panning = false
# NEW: 				has_dragged = false
# NEW: 
# NEW: 		# Right click - flag cell
# NEW: 		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
# NEW: 			_handle_cell_click(event.position, true)
# NEW: 
# NEW: 	# Left mouse drag panning
# NEW: 	if event is InputEventMouseMotion and is_panning:
# NEW: 		# Check if we've moved enough to count as a drag
# NEW: 		var drag_distance = event.position.distance_to(mouse_start_pos)
# NEW: 		if drag_distance > DRAG_THRESHOLD:
# NEW: 			has_dragged = true
# NEW: 
# NEW: 		# Pan the camera if we're dragging
# NEW: 		if has_dragged:
# NEW: 			game_camera.position -= event.relative / game_camera.zoom
# NEW: 			get_viewport().set_input_as_handled()

# ========== FAILED EDIT #35 ==========
# OLD_STRING (not found in file):
# OLD: ## Grid parameters
# OLD: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# OLD: @export var grid_width: int = 50
# OLD: @export var grid_height: int = 50
# OLD: @export var mine_count: int = 400
# OLD: @export var wrap_horizontal: bool = true
# OLD: @export var wrap_vertical: bool = true
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## Grid parameters
# NEW: @export var grid_type: String = "Square"  # "Square", "Hexagon", "Triangle"
# NEW: @export var grid_width: int = 50
# NEW: @export var grid_height: int = 50
# NEW: @export var mine_count: int = 400
# NEW: @export var wrap_horizontal: bool = true
# NEW: @export var wrap_vertical: bool = true
# NEW: @export var use_vertex_neighbors: bool = true  # true = edge+vertex, false = edge-only

# ========== FAILED EDIT #36 ==========
# OLD_STRING (not found in file):
# OLD: 	# Create appropriate grid generator based on type
# OLD: 	match grid_type:
# OLD: 		"Square":
# OLD: 			grid_generator = SquareGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical
# OLD: 			)
# OLD: 		"Hexagon":
# OLD: 			grid_generator = HexGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical
# OLD: 			)
# OLD: 		"Triangle":
# OLD: 			# Not implemented yet - fall back to square
# OLD: 			print("Warning: Triangle grid not implemented yet, using Square")
# OLD: 			grid_generator = SquareGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical
# OLD: 			)
# OLD: 		_:
# OLD: 			# Unknown type - default to square
# OLD: 			print("Warning: Unknown grid type '%s', using Square" % grid_type)
# OLD: 			grid_generator = SquareGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical
# OLD: 			)
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	# Create appropriate grid generator based on type
# NEW: 	match grid_type:
# NEW: 		"Square":
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		"Hexagon":
# NEW: 			grid_generator = HexGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		"Triangle":
# NEW: 			grid_generator = TriangleGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		_:
# NEW: 			# Unknown type - default to square
# NEW: 			print("Warning: Unknown grid type '%s', using Square" % grid_type)
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)

# ========== FAILED EDIT #42 ==========
# OLD_STRING (not found in file):
# OLD: ## TEMPORARY: Debug function to highlight clicked cell and its neighbors
# OLD: func _debug_highlight_neighbors(cell_id: int) -> void:
# OLD: 	# Get neighbors from grid data
# OLD: 	var neighbors = grid_data.get_neighbors(cell_id)
# OLD: 
# OLD: 	# Reset all cells to hidden color first
# OLD: 	for i in range(grid_data.cell_count):
# OLD: 		grid_data.set_state(i, GridData.CellState.HIDDEN)
# OLD: 
# OLD: 	# Set clicked cell to revealed (will show as green)
# OLD: 	grid_data.set_state(cell_id, GridData.CellState.REVEALED)
# OLD: 
# OLD: 	# Set all neighbors to flagged (will show as red)
# OLD: 	for neighbor_id in neighbors:
# OLD: 		grid_data.set_state(neighbor_id, GridData.CellState.FLAGGED)
# OLD: 
# OLD: 	# Mark all cells dirty to force re-render
# OLD: 	var all_cells = PackedInt32Array()
# OLD: 	for i in range(grid_data.cell_count):
# OLD: 		all_cells.append(i)
# OLD: 	grid_renderer.mark_cells_dirty(all_cells)
# OLD: 	grid_renderer.update_dirty_cells()
# OLD: 
# OLD: 	print("Cell %d has %d neighbors" % [cell_id, neighbors.size()])
#
# NEW_STRING (what it wanted to replace with):
# NEW: ## TEMPORARY: Debug function to highlight clicked cell and its neighbors
# NEW: func _debug_highlight_neighbors(cell_id: int) -> void:
# NEW: 	# Get neighbors from grid data
# NEW: 	var neighbors = grid_data.get_neighbors(cell_id)
# NEW: 
# NEW: 	# Reset all cells to hidden color first
# NEW: 	for i in range(grid_data.cell_count):
# NEW: 		grid_data.cell_state[i] = GridData.CellState.HIDDEN
# NEW: 
# NEW: 	# Set clicked cell to revealed (will show as green)
# NEW: 	grid_data.cell_state[cell_id] = GridData.CellState.REVEALED
# NEW: 
# NEW: 	# Set all neighbors to flagged (will show as red)
# NEW: 	for neighbor_id in neighbors:
# NEW: 		grid_data.cell_state[neighbor_id] = GridData.CellState.FLAGGED
# NEW: 
# NEW: 	# Mark all cells dirty to force re-render
# NEW: 	var all_cells = PackedInt32Array()
# NEW: 	for i in range(grid_data.cell_count):
# NEW: 		all_cells.append(i)
# NEW: 	grid_renderer.mark_cells_dirty(all_cells)
# NEW: 	grid_renderer.update_dirty_cells()
# NEW: 
# NEW: 	print("Cell %d has %d neighbors: %s" % [cell_id, neighbors.size(), neighbors])

# ========== FAILED EDIT #48 ==========
# OLD_STRING (not found in file):
# OLD: 	# Create appropriate grid generator based on type
# OLD: 	match grid_type:
# OLD: 		"Square":
# OLD: 			grid_generator = SquareGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical,
# OLD: 				use_vertex_neighbors
# OLD: 			)
# OLD: 		"Hexagon":
# OLD: 			grid_generator = HexGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical,
# OLD: 				use_vertex_neighbors
# OLD: 			)
# OLD: 		"Triangle":
# OLD: 			grid_generator = TriangleGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical,
# OLD: 				use_vertex_neighbors
# OLD: 			)
# OLD: 		_:
# OLD: 			# Unknown type - default to square
# OLD: 			print("Warning: Unknown grid type '%s', using Square" % grid_type)
# OLD: 			grid_generator = SquareGridGenerator.new(
# OLD: 				grid_width,
# OLD: 				grid_height,
# OLD: 				wrap_horizontal,
# OLD: 				wrap_vertical,
# OLD: 				use_vertex_neighbors
# OLD: 			)
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	# Create appropriate grid generator based on type
# NEW: 	match grid_type:
# NEW: 		"Square":
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		"Hexagon":
# NEW: 			grid_generator = HexGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		"Triangle":
# NEW: 			grid_generator = TriangleGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		"Octasquare":
# NEW: 			grid_generator = OctagonSquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)
# NEW: 		_:
# NEW: 			# Unknown type - default to square
# NEW: 			print("Warning: Unknown grid type '%s', using Square" % grid_type)
# NEW: 			grid_generator = SquareGridGenerator.new(
# NEW: 				grid_width,
# NEW: 				grid_height,
# NEW: 				wrap_horizontal,
# NEW: 				wrap_vertical,
# NEW: 				use_vertex_neighbors
# NEW: 			)

# ========== FAILED EDIT #50 ==========
# OLD_STRING (not found in file):
# OLD: 	# Handle right click (flagging)
# OLD: 	if is_right_click:
# OLD: 		if game_logic.toggle_flag(cell_id):
# OLD: 			grid_renderer.mark_cell_dirty(cell_id)
# OLD: 			grid_renderer.update_dirty_cells()
# OLD: 			# Update UI stats (mines remaining changes)
# OLD: 			if game_ui:
# OLD: 				game_ui.update_stats()
# OLD: 		return
# OLD: 
# OLD: 	# DEBUG: Uncomment to visualize neighbors instead of normal gameplay
# OLD: 	_debug_highlight_neighbors(cell_id)
# OLD: 	return
# OLD: 
# OLD: 	# Handle left click (reveal)
# OLD: 	var revealed_cells = game_logic.reveal_cell(cell_id)
#
# NEW_STRING (what it wanted to replace with):
# NEW: 	# Handle right click (flagging)
# NEW: 	if is_right_click:
# NEW: 		if game_logic.toggle_flag(cell_id):
# NEW: 			grid_renderer.mark_cell_dirty(cell_id)
# NEW: 			grid_renderer.update_dirty_cells()
# NEW: 			# Update UI stats (mines remaining changes)
# NEW: 			if game_ui:
# NEW: 				game_ui.update_stats()
# NEW: 		return
# NEW: 
# NEW: 	# DEBUG: Uncomment to visualize neighbors instead of normal gameplay
# NEW: 	#_debug_highlight_neighbors(cell_id)
# NEW: 	#return
# NEW: 
# NEW: 	# Handle left click (reveal)
# NEW: 	var revealed_cells = game_logic.reveal_cell(cell_id)
