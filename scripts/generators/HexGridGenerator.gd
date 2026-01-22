## HexGridGenerator.gd
##
## Generates a hexagonal grid with optional toroidal wrapping.
## Uses pointy-top hexagons with axial (q, r) coordinate system.
##
## Coordinate System: Axial coordinates (q, r)
##   - q: Column (horizontal axis slanted)
##   - r: Row (diagonal axis)
##   - See: https://www.redblobgames.com/grids/hexagons/
##
## Neighbors: 6-way hexagonal (NW, NE, E, SE, SW, W)
## Wrapping: Supports toroidal wrapping (wraparound on both axes)

class_name HexGridGenerator
extends GridGenerator

## Hex orientation (pointy-top)
const HEX_WIDTH_TO_HEIGHT_RATIO = 0.866025404  # sqrt(3) / 2

## Neighbor detection mode (note: hex only has one mode - all neighbors share edges)
var use_vertex_neighbors: bool = true

## Axial coordinate direction offsets for the 6 neighbors
## (pointy-top orientation)
const AXIAL_DIRECTIONS = [
	Vector2i(+1,  0),  # E
	Vector2i(+1, -1),  # NE
	Vector2i( 0, -1),  # NW
	Vector2i(-1,  0),  # W
	Vector2i(-1, +1),  # SW
	Vector2i( 0, +1),  # SE
]

## Initialize with grid dimensions and wrapping settings
func _init(w: int = 20, h: int = 20, wrap_h: bool = true, wrap_v: bool = true, use_vertex: bool = true):
	super._init(w, h, wrap_h, wrap_v)
	use_vertex_neighbors = use_vertex  # For consistency, though hex only has edge neighbors

## Generate a complete hexagonal grid
func generate(mine_count: int) -> GridData:
	var grid = GridData.new()
	grid.cell_count = width * height
	grid.grid_size = Vector2i(width, height)
	grid.grid_type = GridType.Type.HEXAGON
	grid.wrap_horizontal = wrap_horizontal
	grid.wrap_vertical = wrap_vertical

	# Initialize arrays
	grid.initialize(grid.cell_count)

	# Pre-compute geometry (positions and rotations) FIRST
	# This must happen before neighbor calculation since vertex-based detection needs positions
	_compute_cell_positions(grid)

	# Generate neighbor relationships for each cell using vertex-based detection
	for r in range(height):
		for q in range(width):
			var cell_id = _axial_to_id(Vector2i(q, r))
			var neighbors = calculate_neighbors_by_vertices(cell_id, grid, use_vertex_neighbors)
			grid.set_neighbors(cell_id, neighbors)

	# Place mines randomly
	place_mines_random(grid, mine_count)

	# Validate the grid (debug only)
	validate_grid(grid)

	return grid

## Pre-compute all cell positions and rotations (called once during generation)
func _compute_cell_positions(grid: GridData) -> void:
	for r in range(height):
		for q in range(width):
			var cell_id = _axial_to_id(Vector2i(q, r))
			grid.cell_positions[cell_id] = _axial_to_pixel(Vector2i(q, r))
			grid.cell_rotations[cell_id] = 0  # Hexagons never rotate

## Implementation of abstract method from GridGenerator
## Get the 6 vertices of a hexagon at the given cell_id
## Returns an array of 6 Vector2 positions (actual world coordinates)
func get_polygon_vertices(cell_id: int, grid_data: GridData) -> Array[Vector2]:
	var center = grid_data.cell_positions[cell_id]
	var radius = cell_size / 2
	var vertices: Array[Vector2] = []

	# Pointy-top hexagon vertices (6 corners at 60° intervals, starting at 30°)
	for i in range(6):
		var angle = deg_to_rad(60.0 * i + 30.0)
		vertices.append(center + Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		))

	return vertices

## Calculate 6 hexagonal neighbors for a cell at axial position (q, r) (DEPRECATED - kept for reference)
func _calculate_neighbors(axial_pos: Vector2i) -> PackedInt32Array:
	var neighbors = PackedInt32Array()

	for direction in AXIAL_DIRECTIONS:
		var neighbor_pos = axial_pos + direction

		# Handle wrapping or boundary checking
		if wrap_horizontal or wrap_vertical:
			# Hex wrapping is more complex than square grids
			# We need to wrap in both q and r coordinates
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
			if not _is_valid_axial(neighbor_pos):
				continue

		neighbors.append(_axial_to_id(neighbor_pos))

	return neighbors

## Convert axial coordinates (q, r) to cell_id
func _axial_to_id(axial: Vector2i) -> int:
	return axial.y * width + axial.x

## Convert cell_id to axial coordinates (q, r)
func _id_to_axial(cell_id: int) -> Vector2i:
	var q = cell_id % width
	var r = int(cell_id / width)
	return Vector2i(q, r)

## Check if axial coordinates are within grid bounds
func _is_valid_axial(axial: Vector2i) -> bool:
	return axial.x >= 0 and axial.x < width and axial.y >= 0 and axial.y < height

## Convert axial coordinates to pixel position (pointy-top orientation)
func _axial_to_pixel(axial: Vector2i) -> Vector2:
	var q = axial.x
	var r = axial.y

	# Pointy-top hexagon layout
	# x = size * (sqrt(3) * q + sqrt(3)/2 * r)
	# y = size * (3/2 * r)
	var x = cell_size * (HEX_WIDTH_TO_HEIGHT_RATIO * q + HEX_WIDTH_TO_HEIGHT_RATIO * 0.5 * r)
	var y = cell_size * (0.75 * r)

	# Progressive left-shift to create more rectangular boundary
	# Rows 0,1: no shift
	# Rows 2,3: shift 1 left
	# Rows 4,5: shift 2 left, etc.
	var row_pair = int(r / 2)  # Which pair of rows (0,1 = pair 0; 2,3 = pair 1; etc)
	if row_pair > 0:
		x -= row_pair * cell_size * HEX_WIDTH_TO_HEIGHT_RATIO

	# Offset to center hexagons
	x += cell_size * HEX_WIDTH_TO_HEIGHT_RATIO
	y += cell_size * 0.5

	return Vector2(x, y)

## Convert cell_id to pixel position for rendering
func get_pixel_position(cell_id: int) -> Vector2:
	var axial = _id_to_axial(cell_id)
	return _axial_to_pixel(axial)

## Convert pixel position to axial coordinates (click detection)
func _pixel_to_axial(pixel_pos: Vector2) -> Vector2i:
	# Adjust for centering offset
	var x = pixel_pos.x - cell_size * HEX_WIDTH_TO_HEIGHT_RATIO
	var y = pixel_pos.y - cell_size * 0.5

	# First, estimate the row to determine the shift amount
	var r_estimate = y / (cell_size * 0.75)
	var row_pair = int(r_estimate / 2)

	# Reverse the progressive left-shift before computing q
	if row_pair > 0:
		x += row_pair * cell_size * HEX_WIDTH_TO_HEIGHT_RATIO

	# Reverse the axial-to-pixel transform
	# This is an approximation - we'll round to nearest hex
	var q_float = (HEX_WIDTH_TO_HEIGHT_RATIO * x - 0.5 * y) / (cell_size * HEX_WIDTH_TO_HEIGHT_RATIO * HEX_WIDTH_TO_HEIGHT_RATIO)
	var r_float = y / (cell_size * 0.75)

	# Use cube coordinate rounding for accuracy
	return _cube_round(q_float, r_float)

## Round fractional cube coordinates to nearest hexagon
## This ensures clicks near hex boundaries select the correct hex
func _cube_round(q_float: float, r_float: float) -> Vector2i:
	# Convert axial (q, r) to cube (x, y, z) where x + y + z = 0
	var x = q_float
	var z = r_float
	var y = -x - z

	# Round to integers
	var rx = round(x)
	var ry = round(y)
	var rz = round(z)

	# Find which coordinate had the largest rounding error
	var x_diff = abs(rx - x)
	var y_diff = abs(ry - y)
	var z_diff = abs(rz - z)

	# Reset the coordinate with largest error to maintain x + y + z = 0
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	# Convert cube back to axial
	return Vector2i(int(rx), int(rz))

## Find cell at world position (click detection using point-in-polygon)
func get_cell_at_position(world_pos: Vector2, grid_data: GridData = null) -> int:
	if not grid_data:
		# Fallback to approximate axial conversion if no grid data
		var axial = _pixel_to_axial(world_pos)

		# Handle wrapping or out-of-bounds
		if wrap_horizontal or wrap_vertical:
			if wrap_horizontal:
				axial.x = axial.x % width
				if axial.x < 0:
					axial.x += width

			if wrap_vertical:
				axial.y = axial.y % height
				if axial.y < 0:
					axial.y += height

			# If only one axis wraps, check bounds on the other
			if not wrap_horizontal and (axial.x < 0 or axial.x >= width):
				return -1
			if not wrap_vertical and (axial.y < 0 or axial.y >= height):
				return -1
		else:
			# No wrapping - return -1 if out of bounds
			if not _is_valid_axial(axial):
				return -1

		return _axial_to_id(axial)

	# Precise point-in-polygon detection
	# Calculate grid pixel dimensions for wrapping
	var grid_pixel_width = width * cell_size * HEX_WIDTH_TO_HEIGHT_RATIO
	var grid_pixel_height = height * cell_size * 0.75

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

	var axial = _pixel_to_axial(normalized_pos)

	# Check the hex and its neighbors (for edge cases near hex boundaries)
	for dr in range(-1, 2):
		for dq in range(-1, 2):
			var test_axial = axial + Vector2i(dq, dr)

			# Apply wrapping to test position
			var wrapped_test_axial = test_axial
			if wrap_horizontal:
				wrapped_test_axial.x = wrapped_test_axial.x % width
				if wrapped_test_axial.x < 0:
					wrapped_test_axial.x += width
			elif test_axial.x < 0 or test_axial.x >= width:
				continue

			if wrap_vertical:
				wrapped_test_axial.y = wrapped_test_axial.y % height
				if wrapped_test_axial.y < 0:
					wrapped_test_axial.y += height
			elif test_axial.y < 0 or test_axial.y >= height:
				continue

			var cell_id = _axial_to_id(wrapped_test_axial)
			var vertices = get_polygon_vertices(cell_id, grid_data)

			# Use precise point-in-polygon test with normalized position
			if point_in_polygon(normalized_pos, vertices):
				return cell_id

	return -1

## Get all cells on the edge (for potential ghost rendering later)
func get_edge_cells() -> Dictionary:
	var edges = {
		"left": PackedInt32Array(),
		"right": PackedInt32Array(),
		"top": PackedInt32Array(),
		"bottom": PackedInt32Array()
	}

	# Left edge (q = 0)
	for r in range(height):
		edges["left"].append(_axial_to_id(Vector2i(0, r)))

	# Right edge (q = width - 1)
	for r in range(height):
		edges["right"].append(_axial_to_id(Vector2i(width - 1, r)))

	# Top edge (r = 0)
	for q in range(width):
		edges["top"].append(_axial_to_id(Vector2i(q, 0)))

	# Bottom edge (r = height - 1)
	for q in range(width):
		edges["bottom"].append(_axial_to_id(Vector2i(q, height - 1)))

	return edges

## Get the ghost position offset for a given edge direction
func get_ghost_offset(direction: String) -> Vector2:
	match direction:
		"left":
			return Vector2(-width * cell_size * HEX_WIDTH_TO_HEIGHT_RATIO, 0)
		"right":
			return Vector2(width * cell_size * HEX_WIDTH_TO_HEIGHT_RATIO, 0)
		"top":
			return Vector2(0, -height * cell_size * 0.75)
		"bottom":
			return Vector2(0, height * cell_size * 0.75)
		_:
			return Vector2.ZERO
