## TriangleGridGenerator.gd
##
## Generates a triangular grid with optional toroidal wrapping.
## Uses alternating up/down triangles in a rhombus layout.
##
## Coordinate System: (x, y) where cells alternate orientation
## Neighbors: 3-way (edge-only) or 12-way (edge+vertex)
## Wrapping: Supports toroidal wrapping (wraparound on both axes)

class_name TriangleGridGenerator
extends GridGenerator

## Neighbor detection mode
var use_vertex_neighbors: bool = true

## Initialize with grid dimensions and wrapping settings
func _init(w: int = 20, h: int = 20, wrap_h: bool = true, wrap_v: bool = true, use_vertex: bool = true):
	super._init(w, h, wrap_h, wrap_v)
	use_vertex_neighbors = use_vertex

## Generate a complete triangular grid
func generate(mine_count: int) -> GridData:
	var grid = GridData.new()
	grid.cell_count = width * height
	grid.grid_size = Vector2i(width, height)
	grid.grid_type = GridType.Type.TRIANGLE
	grid.wrap_horizontal = wrap_horizontal
	grid.wrap_vertical = wrap_vertical

	# Initialize arrays
	grid.initialize(grid.cell_count)

	# Pre-compute geometry (positions and rotations) FIRST
	# This must happen before neighbor calculation since vertex-based detection needs positions
	_compute_cell_positions(grid)

	# Generate neighbor relationships for each cell
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
## This eliminates repeated geometry calculations in the rendering hot loop
func _compute_cell_positions(grid: GridData) -> void:
	# Horizontal spacing reduced by half for tighter packing
	var tri_width = cell_size * 0.5
	# Triangle mesh has height of 2 units (from -1 to +1), scaled by cell_size/2
	# So actual rendered height is cell_size
	var tri_height = cell_size

	for cell_id in range(grid.cell_count):
		var pos = _id_to_pos(cell_id)

		# Grid arrangement with row offset:
		# - Triangles alternate orientation every column
		# - Each triangle occupies half cell_size width (tighter packing)
		# - Even rows are shifted 0.5 tri_width to the right for interlocking
		var row = pos.y
		var col = pos.x

		# Positioning with half-width spacing
		var x = col * tri_width
		var y = row * tri_height


		# Round to whole pixels to avoid sub-pixel anti-aliasing issues
		x = round(x)
		y = round(y)

		# Checkerboard pattern: alternate based on row + column
		# Even rows start with up, odd rows start with down (proper interlocking)
		if (col + row) % 2 == 0:
			grid.cell_rotations[cell_id] = 0  # Up-pointing
			y += 1  # Move down 1px to eliminate overlap
		else:
			grid.cell_rotations[cell_id] = 1  # Down-pointing (180° flip)
			y -= 1  # Move up 1px to eliminate overlap

		grid.cell_positions[cell_id] = Vector2(x, y)

## Check if triangle at position points up or down
## Pattern: Even rows alternate based on x, odd rows are offset
func _is_pointing_up(pos: Vector2i) -> bool:
	# Checkerboard pattern: (x + y) % 2 == 0 means pointing up
	return (pos.x + pos.y) % 2 == 0

## Temporarily compute position for a cell (used during neighbor calculation)
## Uses the same logic as _compute_cell_positions
func _get_temp_position(pos: Vector2i) -> Vector2:
	var tri_width = cell_size * 0.5
	var tri_height = cell_size

	var row = pos.y
	var col = pos.x

	var x = col * tri_width
	var y = row * tri_height

	# Compensate for rendering gaps: shift each row up by 2px per row
	y -= row * 2

	return Vector2(round(x), round(y))

## Implementation of abstract method from GridGenerator
## Get the 3 vertices of a triangle at the given cell_id
## Returns an array of 3 Vector2 positions (actual world coordinates)
func get_polygon_vertices(cell_id: int, grid_data: GridData) -> Array[Vector2]:
	var center = grid_data.cell_positions[cell_id]
	var is_up = (grid_data.cell_rotations[cell_id] == 0)

	var half_size = cell_size / 2
	var vertices: Array[Vector2] = []

	if is_up:
		# Up-pointing: top, bottom-left, bottom-right
		vertices.append(center + Vector2(0, -1) * half_size)       # Top
		vertices.append(center + Vector2(-1, 1) * half_size)       # Bottom-left
		vertices.append(center + Vector2(1, 1) * half_size)        # Bottom-right
	else:
		# Down-pointing: flipped vertically, so top becomes bottom
		vertices.append(center + Vector2(0, 1) * half_size)        # Bottom (was top)
		vertices.append(center + Vector2(-1, -1) * half_size)      # Top-left (was bottom-left)
		vertices.append(center + Vector2(1, -1) * half_size)       # Top-right (was bottom-right)

	return vertices

## Calculate 3-way edge-only neighbors (DEPRECATED - kept for reference)
func _calculate_3way_neighbors(pos: Vector2i, is_up: bool) -> PackedInt32Array:
	var neighbors = PackedInt32Array()
	var offsets: Array[Vector2i] = []

	if is_up:
		# Up-pointing triangle has neighbors: left, right, down
		offsets = [
			Vector2i(-1, 0),  # Left
			Vector2i(1, 0),   # Right
			Vector2i(0, 1),   # Down (inverted triangle below)
		]
	else:
		# Down-pointing triangle has neighbors: left, right, up
		offsets = [
			Vector2i(-1, 0),  # Left
			Vector2i(1, 0),   # Right
			Vector2i(0, -1),  # Up (inverted triangle above)
		]

	for offset in offsets:
		var neighbor_pos = pos + offset
		if _is_valid_neighbor(neighbor_pos):
			neighbors.append(_pos_to_id(neighbor_pos))

	return neighbors

## Calculate 12-way edge+vertex neighbors
func _calculate_12way_neighbors(pos: Vector2i, is_up: bool) -> PackedInt32Array:
	var neighbors = PackedInt32Array()
	var offsets: Array[Vector2i] = []

	# Current row determines offset behavior
	var current_row = pos.y
	var is_even_row = (current_row % 2 == 0)

	if is_up:
		# Up-pointing triangle: 3 edges + 9 vertices
		# Base offsets for same row
		offsets = [
			# Edge neighbors (3)
			Vector2i(-1, 0),  # Left edge
			Vector2i(1, 0),   # Right edge
		]

		# Bottom edge neighbor (row below)
		# When moving to different row, account for row offset change
		if is_even_row:
			# Current row is even (shifted), next row is odd (not shifted)
			offsets.append(Vector2i(-1, 1))  # Bottom edge shifts left
		else:
			# Current row is odd (not shifted), next row is even (shifted)
			offsets.append(Vector2i(1, 1))  # Bottom edge shifts right

		# Vertex neighbors - same row
		offsets.append(Vector2i(-2, 0))  # Far left
		offsets.append(Vector2i(2, 0))   # Far right

		# Vertex neighbors - row above
		if is_even_row:
			# Moving from even (shifted) to odd (not shifted) row above
			offsets.append(Vector2i(1, -1))   # Top vertex (center)
			offsets.append(Vector2i(0, -1))   # Top-left
			offsets.append(Vector2i(2, -1))   # Top-right
		else:
			# Moving from odd (not shifted) to even (shifted) row above
			offsets.append(Vector2i(-1, -1))  # Top vertex (center)
			offsets.append(Vector2i(-2, -1))  # Top-left
			offsets.append(Vector2i(0, -1))   # Top-right

		# Vertex neighbors - row below
		if is_even_row:
			# Moving from even (shifted) to odd (not shifted) row below
			offsets.append(Vector2i(-2, 1))  # Bottom-left
			offsets.append(Vector2i(0, 1))   # Bottom-right
			offsets.append(Vector2i(-1, 2))  # Far bottom (2 rows down)
		else:
			# Moving from odd (not shifted) to even (shifted) row below
			offsets.append(Vector2i(0, 1))   # Bottom-left
			offsets.append(Vector2i(2, 1))   # Bottom-right
			offsets.append(Vector2i(1, 2))   # Far bottom (2 rows down)
	else:
		# Down-pointing triangle: 3 edges + 9 vertices
		# Base offsets for same row
		offsets = [
			# Edge neighbors (3)
			Vector2i(-1, 0),  # Left edge
			Vector2i(1, 0),   # Right edge
		]

		# Top edge neighbor (row above)
		if is_even_row:
			# Current row is even (shifted), prev row is odd (not shifted)
			offsets.append(Vector2i(1, -1))  # Top edge shifts right
		else:
			# Current row is odd (not shifted), prev row is even (shifted)
			offsets.append(Vector2i(-1, -1))  # Top edge shifts left

		# Vertex neighbors - same row
		offsets.append(Vector2i(-2, 0))  # Far left
		offsets.append(Vector2i(2, 0))   # Far right

		# Vertex neighbors - row above
		if is_even_row:
			# Moving from even (shifted) to odd (not shifted) row above
			offsets.append(Vector2i(0, -1))   # Top-left
			offsets.append(Vector2i(2, -1))   # Top-right
			offsets.append(Vector2i(1, -2))   # Far top (2 rows up)
		else:
			# Moving from odd (not shifted) to even (shifted) row above
			offsets.append(Vector2i(-2, -1))  # Top-left
			offsets.append(Vector2i(0, -1))   # Top-right
			offsets.append(Vector2i(-1, -2))  # Far top (2 rows up)

		# Vertex neighbors - row below
		if is_even_row:
			# Moving from even (shifted) to odd (not shifted) row below
			offsets.append(Vector2i(-1, 1))  # Bottom vertex (center)
			offsets.append(Vector2i(-2, 1))  # Bottom-left
			offsets.append(Vector2i(0, 1))   # Bottom-right
		else:
			# Moving from odd (not shifted) to even (shifted) row below
			offsets.append(Vector2i(1, 1))   # Bottom vertex (center)
			offsets.append(Vector2i(0, 1))   # Bottom-left
			offsets.append(Vector2i(2, 1))   # Bottom-right

	for offset in offsets:
		var neighbor_pos = pos + offset
		if _is_valid_neighbor(neighbor_pos):
			neighbors.append(_pos_to_id(neighbor_pos))

	return neighbors

## Check if neighbor position is valid (respecting wrapping)
func _is_valid_neighbor(neighbor_pos: Vector2i) -> bool:
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
			return false
		if not wrap_vertical and (neighbor_pos.y < 0 or neighbor_pos.y >= height):
			return false
	else:
		# No wrapping - skip neighbors outside bounds
		if not is_in_bounds(neighbor_pos, Vector2i(width, height)):
			return false

	return true

## Convert grid position to cell_id
func _pos_to_id(pos: Vector2i) -> int:
	return pos.y * width + pos.x

## Convert cell_id to grid position
func _id_to_pos(cell_id: int) -> Vector2i:
	var x = cell_id % width
	var y = int(cell_id / width)
	return Vector2i(x, y)

## Convert cell_id to pixel position for rendering
## @deprecated Use grid_data.cell_positions[cell_id] instead for better performance
func get_pixel_position(cell_id: int) -> Vector2:
	# This method is kept for backwards compatibility during the transition
	# New code should access cached positions directly from GridData

	# Fallback calculation if positions haven't been cached yet
	var pos = _id_to_pos(cell_id)
	var is_up = _is_pointing_up(pos)

	# Triangle dimensions
	var tri_width = cell_size
	var tri_height = cell_size * 0.866025404  # sqrt(3)/2

	# For proper tessellation:
	# - Each column is offset by half the triangle width
	# - Each row is offset by the triangle height
	# - Up and down triangles share the same base x position in a column
	var x = pos.x * (tri_width * 0.5)
	var y = pos.y * tri_height

	# Adjust for centroid position
	# The centroid of an equilateral triangle is 1/3 of the height from the base
	if is_up:
		# Up-pointing triangle: centroid is 1/3 from bottom, 2/3 from top
		y += tri_height * (2.0 / 3.0)
	else:
		# Down-pointing triangle: centroid is 1/3 from top, 2/3 from bottom
		y += tri_height * (1.0 / 3.0)

	return Vector2(x, y)

## Find cell at world position (click detection using point-in-polygon)
func get_cell_at_position(world_pos: Vector2, grid_data: GridData = null) -> int:
	if not grid_data:
		return -1

	# Use updated triangle dimensions matching _compute_cell_positions
	var tri_width = cell_size * 0.5  # Half-width for tighter packing
	var tri_height = cell_size  # Actual rendered height

	# Calculate grid pixel dimensions for wrapping
	var grid_pixel_width = width * tri_width
	var grid_pixel_height = height * tri_height - (height * 2)  # Account for -2px per row

	# Normalize world position to primary grid if wrapping is enabled
	var normalized_pos = world_pos
	if wrap_horizontal or wrap_vertical:
		if wrap_horizontal:
			# Wrap x coordinate to primary grid
			normalized_pos.x = fmod(normalized_pos.x, grid_pixel_width)
			if normalized_pos.x < 0:
				normalized_pos.x += grid_pixel_width
		if wrap_vertical:
			# Wrap y coordinate to primary grid
			normalized_pos.y = fmod(normalized_pos.y, grid_pixel_height)
			if normalized_pos.y < 0:
				normalized_pos.y += grid_pixel_height

	# Approximate grid position for optimization (narrow down search area)
	var grid_y = int(normalized_pos.y / (tri_height - 2))

	# Calculate grid_x accounting for even-row offset
	var adjusted_x = normalized_pos.x
	if grid_y % 2 == 0:
		adjusted_x -= tri_width
	var grid_x = int(adjusted_x / tri_width)

	# Check surrounding triangles using point-in-polygon test
	for dy in range(-1, 2):
		for dx in range(-2, 3):
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

			# Get the actual triangle vertices for this cell
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
func get_ghost_offset(direction: String) -> Vector2:
	# Horizontal spacing reduced by half for tighter packing
	var tri_width = cell_size * 0.5
	# Triangle mesh has height of 2 units (from -1 to +1), scaled by cell_size/2
	# So actual rendered height is cell_size
	var tri_height = cell_size

	match direction:
		"left":
			return Vector2(-width * tri_width, 0)
		"right":
			return Vector2(width * tri_width, 0)
		"top":
			return Vector2(0, -height * tri_height)
		"bottom":
			return Vector2(0, height * tri_height)
		_:
			return Vector2.ZERO
