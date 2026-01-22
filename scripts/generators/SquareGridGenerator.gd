## SquareGridGenerator.gd
##
## Generates a regular square grid with optional toroidal wrapping.
## This is the simplest grid type and serves as the tutorial/foundation level.
##
## Coordinate System: Standard Cartesian (x, y)
## Neighbors: 8-way Moore neighborhood (or 4-way Von Neumann if using contact-only mode)
## Wrapping: Full torus support (left-right, top-bottom, or both)

class_name SquareGridGenerator
extends GridGenerator

## Neighbor detection mode
var use_vertex_neighbors: bool = true

## Initialize with grid dimensions and wrapping settings
func _init(w: int = 20, h: int = 20, wrap_h: bool = true, wrap_v: bool = true, use_vertex: bool = true):
	super._init(w, h, wrap_h, wrap_v)
	use_vertex_neighbors = use_vertex

## Generate a complete square grid
func generate(mine_count: int) -> GridData:
	var grid = GridData.new()
	grid.cell_count = width * height
	grid.grid_size = Vector2i(width, height)
	grid.grid_type = GridType.Type.SQUARE
	grid.wrap_horizontal = wrap_horizontal
	grid.wrap_vertical = wrap_vertical

	# Initialize arrays
	grid.initialize(grid.cell_count)

	# Pre-compute geometry (positions and rotations) FIRST
	# This must happen before neighbor calculation since vertex-based detection needs positions
	_compute_cell_positions(grid)

	# Generate neighbor relationships for each cell using vertex-based detection
	for y in range(height):
		for x in range(width):
			var cell_id = _pos_to_id(Vector2i(x, y))
			var neighbors = calculate_neighbors_by_vertices(cell_id, grid, use_vertex_neighbors)
			grid.set_neighbors(cell_id, neighbors)

	# Place mines randomly
	place_mines_random(grid, mine_count)

	# Validate the grid (debug only)
	validate_grid(grid)

	return grid

## Pre-compute all cell positions and rotations (called once during generation)
func _compute_cell_positions(grid: GridData) -> void:
	for y in range(height):
		for x in range(width):
			var cell_id = _pos_to_id(Vector2i(x, y))
			grid.cell_positions[cell_id] = Vector2(
				x * cell_size + cell_size * 0.5,  # Center of cell
				y * cell_size + cell_size * 0.5
			)
			grid.cell_rotations[cell_id] = 0  # Squares never rotate

## Implementation of abstract method from GridGenerator
## Get the 4 vertices of a square at the given cell_id
## Returns an array of 4 Vector2 positions (actual world coordinates)
func get_polygon_vertices(cell_id: int, grid_data: GridData) -> Array[Vector2]:
	var center = grid_data.cell_positions[cell_id]
	var half_size = cell_size / 2
	var vertices: Array[Vector2] = []

	# Square vertices: top-left, top-right, bottom-right, bottom-left
	vertices.append(center + Vector2(-half_size, -half_size))  # Top-left
	vertices.append(center + Vector2(half_size, -half_size))   # Top-right
	vertices.append(center + Vector2(half_size, half_size))    # Bottom-right
	vertices.append(center + Vector2(-half_size, half_size))   # Bottom-left

	return vertices

## Calculate neighbors for a cell at position (x, y) (DEPRECATED - kept for reference)
func _calculate_neighbors(pos: Vector2i) -> PackedInt32Array:
	var neighbors = PackedInt32Array()

	# Choose neighborhood based on mode
	var offsets: Array[Vector2i] = []
	if use_vertex_neighbors:
		# 8-way Moore neighborhood (edges + vertices)
		offsets = [
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1,  0),                  Vector2i(1,  0),
			Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
		]
	else:
		# 4-way Von Neumann neighborhood (edges only)
		offsets = [
						   Vector2i(0, -1),
			Vector2i(-1, 0),               Vector2i(1, 0),
						   Vector2i(0,  1),
		]

	for offset in offsets:
		var neighbor_pos = pos + offset

		# Handle wrapping or boundary checking
		if wrap_horizontal or wrap_vertical:
			# Wrap coordinates
			if wrap_horizontal:
				neighbor_pos.x = neighbor_pos.x % width
				if neighbor_pos.x < 0:
					neighbor_pos.x += width

			if wrap_vertical:
				neighbor_pos.y = neighbor_pos.y % height
				if neighbor_pos.y < 0:
					neighbor_pos.y += height

			# If only one axis wraps, check bounds on the other axis
			if not wrap_horizontal and (neighbor_pos.x < 0 or neighbor_pos.x >= width):
				continue
			if not wrap_vertical and (neighbor_pos.y < 0 or neighbor_pos.y >= height):
				continue
		else:
			# No wrapping - skip neighbors outside bounds
			if not is_in_bounds(neighbor_pos, Vector2i(width, height)):
				continue

		neighbors.append(_pos_to_id(neighbor_pos))

	return neighbors

## Convert grid position to cell_id
func _pos_to_id(pos: Vector2i) -> int:
	return pos.y * width + pos.x

## Convert cell_id to grid position
func _id_to_pos(cell_id: int) -> Vector2i:
	var x = cell_id % width
	var y = int(cell_id / width)
	return Vector2i(x, y)

## Convert cell_id to pixel position for rendering
func get_pixel_position(cell_id: int) -> Vector2:
	var pos = _id_to_pos(cell_id)
	return Vector2(
		pos.x * cell_size + cell_size * 0.5,  # Center of cell
		pos.y * cell_size + cell_size * 0.5
	)

## Find cell at world position (click detection using point-in-polygon)
func get_cell_at_position(world_pos: Vector2, grid_data: GridData = null) -> int:
	# For square grids, the grid-based approach is already very accurate
	# but we use point-in-polygon for consistency with other grid types

	if not grid_data:
		# Fallback to simple grid-based detection if no grid data
		var grid_x = int(world_pos.x / cell_size)
		var grid_y = int(world_pos.y / cell_size)
		var grid_pos = Vector2i(grid_x, grid_y)

		# Handle wrapping or out-of-bounds
		if wrap_horizontal or wrap_vertical:
			if wrap_horizontal:
				grid_pos.x = grid_pos.x % width
				if grid_pos.x < 0:
					grid_pos.x += width

			if wrap_vertical:
				grid_pos.y = grid_pos.y % height
				if grid_pos.y < 0:
					grid_pos.y += height

			# If only one axis wraps, check bounds on the other
			if not wrap_horizontal and (grid_pos.x < 0 or grid_pos.x >= width):
				return -1
			if not wrap_vertical and (grid_pos.y < 0 or grid_pos.y >= height):
				return -1
		else:
			# No wrapping - return -1 if out of bounds
			if not is_in_bounds(grid_pos, Vector2i(width, height)):
				return -1

		return _pos_to_id(grid_pos)

	# Precise point-in-polygon detection
	# Calculate grid pixel dimensions for wrapping
	var grid_pixel_width = width * cell_size
	var grid_pixel_height = height * cell_size

	# Normalize world position to primary grid if wrapping is enabled
	var normalized_pos = world_pos
	if wrap_horizontal or wrap_vertical:
		if wrap_horizontal:
			normalized_pos.x = fmod(normalized_pos.x, grid_pixel_width)
			if normalized_pos.x < 0:
				normalized_pos.x += grid_pixel_width
		if wrap_vertical:
			normalized_pos.y = fmod(normalized_pos.y, grid_pixel_height)
			if normalized_pos.y < 0:
				normalized_pos.y += grid_pixel_height

	var grid_x = int(normalized_pos.x / cell_size)
	var grid_y = int(normalized_pos.y / cell_size)

	# Check the cell and its neighbors (for edge cases)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var test_pos = Vector2i(grid_x + dx, grid_y + dy)

			# Apply wrapping to test position
			var wrapped_test_pos = test_pos
			if wrap_horizontal:
				wrapped_test_pos.x = wrapped_test_pos.x % width
				if wrapped_test_pos.x < 0:
					wrapped_test_pos.x += width
			elif test_pos.x < 0 or test_pos.x >= width:
				continue

			if wrap_vertical:
				wrapped_test_pos.y = wrapped_test_pos.y % height
				if wrapped_test_pos.y < 0:
					wrapped_test_pos.y += height
			elif test_pos.y < 0 or test_pos.y >= height:
				continue

			var cell_id = _pos_to_id(wrapped_test_pos)
			var vertices = get_polygon_vertices(cell_id, grid_data)

			# Use precise point-in-polygon test with normalized position
			if point_in_polygon(normalized_pos, vertices):
				return cell_id

	return -1

## Get all cells on the edge (for ghost chunk rendering)
func get_edge_cells() -> Dictionary:
	var edges = {
		"left": PackedInt32Array(),
		"right": PackedInt32Array(),
		"top": PackedInt32Array(),
		"bottom": PackedInt32Array()
	}

	# Left edge (x = 0)
	for y in range(height):
		edges["left"].append(_pos_to_id(Vector2i(0, y)))

	# Right edge (x = width - 1)
	for y in range(height):
		edges["right"].append(_pos_to_id(Vector2i(width - 1, y)))

	# Top edge (y = 0)
	for x in range(width):
		edges["top"].append(_pos_to_id(Vector2i(x, 0)))

	# Bottom edge (y = height - 1)
	for x in range(width):
		edges["bottom"].append(_pos_to_id(Vector2i(x, height - 1)))

	return edges

## Get the ghost position offset for a given edge direction
## Used for rendering ghost chunks that create the wrapping illusion
func get_ghost_offset(direction: String) -> Vector2:
	match direction:
		"left":
			return Vector2(-width * cell_size, 0)
		"right":
			return Vector2(width * cell_size, 0)
		"top":
			return Vector2(0, -height * cell_size)
		"bottom":
			return Vector2(0, height * cell_size)
		_:
			return Vector2.ZERO
