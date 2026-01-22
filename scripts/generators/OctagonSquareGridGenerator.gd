## OctagonSquareGridGenerator.gd
##
## Generates a truncated square tiling (4.8.8) - alternating octagons and squares.
## This is a semi-regular tessellation with two polygon types.
##
## Pattern: Each octagon is surrounded by 4 squares (at N, S, E, W)
##          Each square is surrounded by 2 octagons (diagonal neighbors)
##
## Coordinate System: Grid coordinates (x, y) where each cell can be either octagon or square
## Cell ID encoding: Even cells = octagons, odd cells = squares
## Layout: Octagons in a grid pattern with squares filling the gaps

class_name OctagonSquareGridGenerator
extends GridGenerator

## Cell type enumeration
enum CellType {
	OCTAGON = 0,
	SQUARE = 1
}

## Neighbor detection mode
var use_vertex_neighbors: bool = true

## Spacing between octagon centers
const OCTAGON_SPACING = 1.5  # Factor of cell_size

## Initialize with grid dimensions and wrapping settings
func _init(w: int = 20, h: int = 20, wrap_h: bool = true, wrap_v: bool = true, use_vertex: bool = true):
	super._init(w, h, wrap_h, wrap_v)
	use_vertex_neighbors = use_vertex

## Generate a complete octagon+square grid
func generate(mine_count: int) -> GridData:
	var grid = GridData.new()

	# Truncated square tiling (4.8.8): octagons with squares at intersections
	# For an N×M grid of octagons, squares appear at all intersection points
	# Total: N×M octagons + (N+1)×(M+1) squares
	var octagon_count = width * height
	var square_count = (width + 1) * (height + 1)

	grid.cell_count = octagon_count + square_count
	grid.grid_size = Vector2i(width, height)
	grid.grid_type = GridType.Type.OCTASQUARE  # Use OCTASQUARE type
	grid.wrap_horizontal = wrap_horizontal
	grid.wrap_vertical = wrap_vertical

	# Initialize arrays
	grid.initialize(grid.cell_count)

	# Pre-compute geometry (positions and rotations) FIRST
	_compute_cell_positions(grid)

	# For octasquare, use rotation flag to indicate cell type:
	# rotation = 0 → octagon
	# rotation = 1 → square
	# This allows renderer to distinguish cell types
	for cell_id in range(grid.cell_count):
		if get_cell_type(cell_id) == CellType.SQUARE:
			grid.cell_rotations[cell_id] = 1
		else:
			grid.cell_rotations[cell_id] = 0

	# Generate neighbor relationships for each cell using vertex-based detection
	for cell_id in range(grid.cell_count):
		var neighbors = calculate_neighbors_by_vertices(cell_id, grid, use_vertex_neighbors)
		grid.set_neighbors(cell_id, neighbors)

	# Place mines randomly
	place_mines_random(grid, mine_count)

	# Validate the grid (debug only)
	validate_grid(grid)

	return grid

## Pre-compute all cell positions and rotations (called once during generation)
## Uses unit cell approach for truncated square tiling (4.8.8)
##
## Mathematical structure:
##   - Truncated square tiling has a square lattice symmetry
##   - Unit cell dimensions: (octagon_diameter + square_side) × (octagon_diameter + square_side)
##   - Each unit cell contains: 1 octagon + 4 square quarters (= 1 full square equivalent)
##   - Octagons centered at lattice points
##   - Squares centered at lattice edge midpoints (horizontal and vertical)
##
## Tiling vectors:
##   v1 = (spacing, 0)        - horizontal repeat
##   v2 = (0, spacing)        - vertical repeat
##   spacing = octagon_diameter + square_side
func _compute_cell_positions(grid: GridData) -> void:
	# Geometry calculations for truncated square tiling
	# Octagon has 8 sides with alternating edge orientations
	# When truncated from a square, the octagon side length relates to the square side
	var octagon_radius = cell_size * 0.5  # Circumradius (center to vertex)

	# For truncated square tiling (4.8.8):
	# The square side length is determined by the octagon truncation
	# Each square fits exactly between octagon edges
	var square_side = cell_size * (sqrt(2) - 1) / sqrt(2)

	# Spacing between octagon centers (one unit cell)
	var spacing = cell_size + square_side

	# Offset to center the grid (octagons start offset by square_side/2)
	var grid_offset = Vector2(square_side * 0.5, square_side * 0.5)

	var octagon_count = width * height
	var cell_id = 0

	# Phase 1: Place all octagons at lattice points
	# Octagons form a square grid pattern
	for grid_y in range(height):
		for grid_x in range(width):
			# Lattice point position
			var lattice_pos = Vector2(grid_x * spacing, grid_y * spacing)

			# Octagon is centered at lattice point + offset
			grid.cell_positions[cell_id] = lattice_pos + Vector2(octagon_radius, octagon_radius) + grid_offset
			grid.cell_rotations[cell_id] = 0  # Octagons have no rotation
			cell_id += 1

	# Phase 2: Place squares at lattice edge midpoints
	# Squares sit at the intersection points between octagons
	# In a grid of N×M octagons, there are (N+1)×(M+1) intersection points
	for grid_y in range(height + 1):
		for grid_x in range(width + 1):
			# Intersection point position (grid corner)
			var intersection_pos = Vector2(grid_x * spacing, grid_y * spacing)

			# Square is centered at intersection + offset to align with grid
			grid.cell_positions[cell_id] = intersection_pos + grid_offset
			grid.cell_rotations[cell_id] = 0  # Squares have no rotation
			cell_id += 1

## Get cell type (octagon or square)
func get_cell_type(cell_id: int) -> CellType:
	var octagon_count = width * height
	if cell_id < octagon_count:
		return CellType.OCTAGON
	else:
		return CellType.SQUARE

## Implementation of abstract method from GridGenerator
## Get the vertices of a polygon at the given cell_id
## Returns an array of Vector2 positions (actual world coordinates)
func get_polygon_vertices(cell_id: int, grid_data: GridData) -> Array[Vector2]:
	var center = grid_data.cell_positions[cell_id]
	var vertices: Array[Vector2] = []

	if get_cell_type(cell_id) == CellType.OCTAGON:
		# Regular octagon with 8 vertices
		var radius = cell_size * 0.5
		for i in range(8):
			var angle = deg_to_rad(45.0 * i + 22.5)  # Start at 22.5° for flat top/bottom
			vertices.append(center + Vector2(
				cos(angle) * radius,
				sin(angle) * radius
			))
	else:
		# Square
		var square_size = cell_size * (sqrt(2) - 1) / sqrt(2)
		var half_size = square_size * 0.5
		vertices.append(center + Vector2(-half_size, -half_size))  # Top-left
		vertices.append(center + Vector2(half_size, -half_size))   # Top-right
		vertices.append(center + Vector2(half_size, half_size))    # Bottom-right
		vertices.append(center + Vector2(-half_size, half_size))   # Bottom-left

	return vertices

## Convert cell_id to pixel position for rendering
func get_pixel_position(cell_id: int) -> Vector2:
	# This should not be called - use cached positions instead
	push_warning("get_pixel_position() is deprecated - use cached positions")
	return Vector2.ZERO

## Find cell at world position (click detection using point-in-polygon)
func get_cell_at_position(world_pos: Vector2, grid_data: GridData = null) -> int:
	if not grid_data:
		return -1

	# Calculate grid pixel dimensions
	var octagon_radius = cell_size * 0.5
	var square_size = cell_size * (sqrt(2) - 1) / sqrt(2)
	var spacing = octagon_radius * 2 + square_size

	var grid_pixel_width = width * spacing + square_size
	var grid_pixel_height = height * spacing + square_size

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

	# Approximate grid position
	var grid_x = int(normalized_pos.x / spacing)
	var grid_y = int(normalized_pos.y / spacing)

	# Check nearby cells (both octagons and squares)
	# Need to check a wider area since squares are at intersections
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			# Check octagon at this position
			var oct_x = grid_x + dx
			var oct_y = grid_y + dy

			if oct_x >= 0 and oct_x < width and oct_y >= 0 and oct_y < height:
				var oct_id = oct_y * width + oct_x
				var vertices = get_polygon_vertices(oct_id, grid_data)
				if point_in_polygon(normalized_pos, vertices):
					return oct_id

			# Check squares at intersections
			for sq_dy in range(2):
				for sq_dx in range(2):
					var sq_x = oct_x + sq_dx
					var sq_y = oct_y + sq_dy

					if sq_x >= 0 and sq_x <= width and sq_y >= 0 and sq_y <= height:
						var octagon_count = width * height
						var sq_id = octagon_count + sq_y * (width + 1) + sq_x

						if sq_id < grid_data.cell_count:
							var sq_vertices = get_polygon_vertices(sq_id, grid_data)
							if point_in_polygon(normalized_pos, sq_vertices):
								return sq_id

	return -1

## Get all cells on the edge (for ghost chunk rendering)
func get_edge_cells() -> Dictionary:
	var edges = {
		"left": PackedInt32Array(),
		"right": PackedInt32Array(),
		"top": PackedInt32Array(),
		"bottom": PackedInt32Array()
	}

	# Left edge octagons (x = 0)
	for y in range(height):
		edges["left"].append(y * width + 0)

	# Right edge octagons (x = width - 1)
	for y in range(height):
		edges["right"].append(y * width + (width - 1))

	# Top edge octagons (y = 0)
	for x in range(width):
		edges["top"].append(0 * width + x)

	# Bottom edge octagons (y = height - 1)
	for x in range(width):
		edges["bottom"].append((height - 1) * width + x)

	return edges

## Get the ghost position offset for a given edge direction
func get_ghost_offset(direction: String) -> Vector2:
	var octagon_radius = cell_size * 0.5
	var square_size = cell_size * (sqrt(2) - 1) / sqrt(2)
	var spacing = octagon_radius * 2 + square_size

	var grid_pixel_width = width * spacing + square_size
	var grid_pixel_height = height * spacing + square_size

	match direction:
		"left":
			return Vector2(-grid_pixel_width, 0)
		"right":
			return Vector2(grid_pixel_width, 0)
		"top":
			return Vector2(0, -grid_pixel_height)
		"bottom":
			return Vector2(0, grid_pixel_height)
		_:
			return Vector2.ZERO
