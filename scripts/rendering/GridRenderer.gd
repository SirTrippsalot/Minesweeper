## GridRenderer.gd
##
## MultiMesh-based rendering system for grid visualization
## Renders 10,000+ cells efficiently in a single draw call
## Uses ocean/island theme (water=mines, land=safe)

class_name GridRenderer
extends Node2D

## The grid data to render
var grid_data: GridData

## The generator (for pixel positions)
var grid_generator: GridGenerator

## Visual settings
var cell_size: float = 64.0
var cell_gap: float = 0.0  # No gaps - cells touch like traditional minesweeper
var border_width: float = 2.0  # Width of cell borders

## Ocean theme colors
var color_border: Color = Color(0.15, 0.2, 0.3, 1.0)  # Darker blue for borders
var color_hidden: Color = Color(0.2, 0.3, 0.4, 1.0)        # Dark ocean blue
var color_revealed_safe: Color = Color(0.85, 0.75, 0.6, 1.0)  # Sandy beach
var color_revealed_mine: Color = Color(0.1, 0.15, 0.25, 1.0)  # Deep water
var color_flagged: Color = Color(0.9, 0.3, 0.2, 1.0)       # Red flag
var color_question: Color = Color(0.9, 0.7, 0.2, 1.0)      # Yellow question

## Danger count colors (numbers on revealed safe cells)
var danger_colors: Array[Color] = [
	Color(0.7, 0.7, 0.7, 1.0),   # 0 neighbors: light gray
	Color(0.2, 0.5, 0.9, 1.0),   # 1 neighbor: blue
	Color(0.2, 0.7, 0.3, 1.0),   # 2 neighbors: green
	Color(0.9, 0.3, 0.2, 1.0),   # 3 neighbors: red
	Color(0.5, 0.2, 0.8, 1.0),   # 4 neighbors: purple
	Color(0.8, 0.4, 0.1, 1.0),   # 5 neighbors: orange
	Color(0.2, 0.8, 0.8, 1.0),   # 6 neighbors: cyan
	Color(0.1, 0.1, 0.1, 1.0),   # 7 neighbors: black
	Color(0.5, 0.5, 0.5, 1.0),   # 8 neighbors: gray
]

## MultiMesh instances
var cell_multimesh: MultiMeshInstance2D
var cell_mesh: QuadMesh
var border_multimesh: MultiMeshInstance2D
var border_mesh: QuadMesh

## Track which cells need visual updates
var dirty_cells: PackedInt32Array = PackedInt32Array()

func _ready():
	# Initialize rendering when added to scene tree
	if grid_data and grid_generator:
		_initialize_rendering()

## Set up the grid to render
func setup(data: GridData, generator: GridGenerator) -> void:
	grid_data = data
	grid_generator = generator

	if is_inside_tree():
		_initialize_rendering()

## Initialize MultiMesh rendering
func _initialize_rendering() -> void:
	if not grid_data or not grid_generator:
		push_error("GridRenderer: Cannot initialize without grid_data and grid_generator")
		return

	# Create borders first (rendered behind cells)
	_create_borders()

	# Create quad mesh for cell visualization
	cell_mesh = QuadMesh.new()
	cell_mesh.size = Vector2(cell_size - border_width * 2, cell_size - border_width * 2)

	# Create MultiMeshInstance2D
	cell_multimesh = MultiMeshInstance2D.new()
	add_child(cell_multimesh)

	# Configure MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.mesh = cell_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = grid_data.cell_count

	cell_multimesh.multimesh = multimesh

	# Initialize all cell visuals
	_update_all_cells()

	print("GridRenderer initialized: %d cells" % grid_data.cell_count)

## Create border MultiMesh (rendered behind cells)
func _create_borders() -> void:
	# Create quad mesh for borders (full cell size)
	border_mesh = QuadMesh.new()
	border_mesh.size = Vector2(cell_size, cell_size)

	# Create MultiMeshInstance2D for borders
	border_multimesh = MultiMeshInstance2D.new()
	border_multimesh.z_index = -1  # Behind cells
	add_child(border_multimesh)

	# Configure MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.mesh = border_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = grid_data.cell_count

	border_multimesh.multimesh = multimesh

	# Set all border positions and colors
	for cell_id in range(grid_data.cell_count):
		var pixel_pos = grid_generator.get_pixel_position(cell_id)
		var transform = Transform2D()
		transform.origin = pixel_pos
		multimesh.set_instance_transform_2d(cell_id, transform)
		multimesh.set_instance_color(cell_id, color_border)

## Update all cell visuals (initial render)
func _update_all_cells() -> void:
	if not cell_multimesh or not cell_multimesh.multimesh:
		return

	var multimesh = cell_multimesh.multimesh

	for cell_id in range(grid_data.cell_count):
		# Get pixel position from generator
		var pixel_pos = grid_generator.get_pixel_position(cell_id)

		# Set transform (position and scale)
		var transform = Transform2D()
		transform.origin = pixel_pos
		multimesh.set_instance_transform_2d(cell_id, transform)

		# Set color based on cell state
		var color = _get_cell_color(cell_id)
		multimesh.set_instance_color(cell_id, color)

## Get the color for a cell based on its state
func _get_cell_color(cell_id: int) -> Color:
	var state = grid_data.get_state(cell_id)

	match state:
		GridData.CellState.HIDDEN:
			return color_hidden

		GridData.CellState.REVEALED:
			if grid_data.is_mine(cell_id):
				return color_revealed_mine
			else:
				# Safe cell - use danger count color
				var danger = grid_data.get_danger_count(cell_id)
				if danger >= 0 and danger < danger_colors.size():
					return danger_colors[danger]
				return color_revealed_safe

		GridData.CellState.FLAGGED:
			return color_flagged

		GridData.CellState.QUESTION:
			return color_question

		_:
			return color_hidden

## Mark a cell for visual update
func mark_cell_dirty(cell_id: int) -> void:
	if cell_id >= 0 and cell_id < grid_data.cell_count:
		if not dirty_cells.has(cell_id):
			dirty_cells.append(cell_id)

## Mark multiple cells for visual update
func mark_cells_dirty(cell_ids: PackedInt32Array) -> void:
	for cell_id in cell_ids:
		mark_cell_dirty(cell_id)

## Update visuals for all dirty cells
func update_dirty_cells() -> void:
	if dirty_cells.is_empty():
		return

	if not cell_multimesh or not cell_multimesh.multimesh:
		return

	var multimesh = cell_multimesh.multimesh

	for cell_id in dirty_cells:
		var color = _get_cell_color(cell_id)
		multimesh.set_instance_color(cell_id, color)

	dirty_cells.clear()

## Force refresh all cell visuals
func refresh_all() -> void:
	_update_all_cells()

## Update color theme at runtime
func set_color_theme(
	hidden: Color,
	revealed_safe: Color,
	revealed_mine: Color,
	flagged: Color,
	question: Color
) -> void:
	color_hidden = hidden
	color_revealed_safe = revealed_safe
	color_revealed_mine = revealed_mine
	color_flagged = flagged
	color_question = question

	# Refresh all cells with new colors
	refresh_all()

## Get the cell at a world position (for input handling)
func get_cell_at_position(world_pos: Vector2) -> int:
	if grid_generator:
		return grid_generator.get_cell_at_position(world_pos)
	return -1
