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
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var mine_count: int = 60
@export var wrap_horizontal: bool = true
@export var wrap_vertical: bool = true

## Rendering
@export var cell_size: float = 64.0

## Components
var grid_data: GridData
var grid_generator: GridGenerator
var grid_renderer: GridRenderer
var game_camera: Camera2D
var game_logic: GameLogic

func _ready():
	print("\n=== Game Controller Starting ===\n")

	# Create camera first
	_setup_camera()

	# Generate grid
	_generate_grid()

	# Set up renderer
	_setup_renderer()

	# Set up game logic
	_setup_game_logic()

	print("\n=== Game Ready! ===")
	print("Grid: %dx%d with %d mines" % [grid_width, grid_height, mine_count])
	print("Total cells: %d" % grid_data.cell_count)
	print("\nControls:")
	print("  - Left Click: Reveal cell")
	print("  - Right Click: Flag/unflag cell")
	print("  - Mouse Wheel: Zoom in/out")
	print("  - Middle Mouse Drag: Pan camera")
	print("  - Arrow Keys: Pan camera\n")

func _generate_grid() -> void:
	print("Generating %dx%d square grid..." % [grid_width, grid_height])

	# Create square grid generator
	grid_generator = SquareGridGenerator.new(
		grid_width,
		grid_height,
		wrap_horizontal,
		wrap_vertical
	)

	# Generate grid data
	grid_data = grid_generator.generate(mine_count)

	if grid_data:
		print("✓ Grid generated successfully")
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

		# Left click - reveal cell
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_cell_click(event.position, false)

		# Right click - flag cell
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_cell_click(event.position, true)

	# Middle mouse drag panning
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			game_camera.position -= event.relative / game_camera.zoom

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
		return

	# Handle left click (reveal)
	var revealed_cells = game_logic.reveal_cell(cell_id)
	if revealed_cells.size() > 0:
		grid_renderer.mark_cells_dirty(revealed_cells)
		grid_renderer.update_dirty_cells()

		# Print flood fill results
		if revealed_cells.size() > 1:
			print("Revealed %d cells via flood fill" % revealed_cells.size())
