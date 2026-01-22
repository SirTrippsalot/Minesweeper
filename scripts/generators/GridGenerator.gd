## GridGenerator.gd
##
## Abstract base class for all grid generation strategies.
## Each grid type (Square, Hexagon, etc.) extends this to implement
## its specific coordinate system and neighbor calculation logic.
##
## The generator is responsible for:
## 1. Creating the GridData structure
## 2. Calculating neighbor relationships (the graph)
## 3. Placing mines randomly
## 4. Converting cell_id to pixel position (for rendering)
## 5. Converting pixel position to cell_id (for input)

class_name GridGenerator
extends RefCounted

## Grid dimensions
var width: int
var height: int

## Wrapping configuration
var wrap_horizontal: bool = true
var wrap_vertical: bool = true

## Cell size for rendering (pixels)
var cell_size: float = 64.0

## Initialize the generator with dimensions and wrapping settings
func _init(w: int = 20, h: int = 20, wrap_h: bool = true, wrap_v: bool = true):
	width = w
	height = h
	wrap_horizontal = wrap_h
	wrap_vertical = wrap_v

# ===== ABSTRACT METHODS (Must be overridden by subclasses) =====

## Generate a complete grid with neighbor relationships and mines
## @param _mine_count: Number of mines to place
## @return: Fully initialized GridData
func generate(_mine_count: int) -> GridData:
	push_error("GridGenerator.generate() must be overridden by subclass")
	return null

## Convert cell_id to pixel position for rendering
## @param _cell_id: The cell index
## @return: World position in pixels
func get_pixel_position(_cell_id: int) -> Vector2:
	push_error("GridGenerator.get_pixel_position() must be overridden by subclass")
	return Vector2.ZERO

## Find cell_id at given world position (for click detection)
## @param _world_pos: Position in world coordinates
## @param _grid_data: Optional GridData for accessing cached positions
## @return: cell_id, or -1 if no cell at that position
func get_cell_at_position(_world_pos: Vector2, _grid_data: GridData = null) -> int:
	push_error("GridGenerator.get_cell_at_position() must be overridden by subclass")
	return -1

## Pre-compute all cell positions during generation
## Subclasses MUST implement this to populate grid.cell_positions and grid.cell_rotations
## @param _grid: The GridData to populate with cached geometry
func _compute_cell_positions(_grid: GridData) -> void:
	push_error("GridGenerator._compute_cell_positions() must be overridden by subclass")

## Get the vertices of a polygon at the given cell_id
## Subclasses MUST implement this to return the actual world coordinates of the polygon's vertices
## @param _cell_id: The cell index
## @param _grid_data: The GridData (for accessing cached positions)
## @return: Array of Vector2 positions representing the polygon's vertices
func get_polygon_vertices(_cell_id: int, _grid_data: GridData) -> Array[Vector2]:
	push_error("GridGenerator.get_polygon_vertices() must be overridden by subclass")
	return []

# ===== COMMON HELPER METHODS (Available to all subclasses) =====

## Point-in-polygon test using ray casting algorithm
## Works for ANY convex or concave polygon
## @param point: The point to test
## @param vertices: Array of polygon vertices in order (clockwise or counter-clockwise)
## @return: true if point is inside the polygon
func point_in_polygon(point: Vector2, vertices: Array[Vector2]) -> bool:
	if vertices.size() < 3:
		return false

	var inside = false
	var j = vertices.size() - 1

	for i in range(vertices.size()):
		var vi = vertices[i]
		var vj = vertices[j]

		# Ray casting: count intersections with edges
		if ((vi.y > point.y) != (vj.y > point.y)) and \
		   (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = !inside

		j = i

	return inside

## Generic vertex-based neighbor calculation
## Works for ANY polygon type (triangle, square, hexagon, pentagon, etc.)
## Polygons sharing 2+ vertices = edge neighbors
## Polygons sharing 1 vertex = vertex-only neighbors
## @param cell_id: The cell to find neighbors for
## @param grid_data: The grid data structure
## @param use_vertex_neighbors: If true, include vertex neighbors; if false, only edge neighbors
## @param search_width: How many cells wide to search (default 4)
## @param search_height: How many cells tall to search (default 3)
## @return: Array of neighbor cell_ids
func calculate_neighbors_by_vertices(cell_id: int, grid_data: GridData, use_vertex_neighbors: bool, search_width: int = 4, search_height: int = 3) -> PackedInt32Array:
	var my_vertices = get_polygon_vertices(cell_id, grid_data)

	# Dictionary to count shared vertices with each candidate polygon
	var shared_vertex_count = {}  # cell_id -> count

	# Check all cells in a reasonable search area around this cell
	# The search area depends on the grid type and should be provided by the caller
	var total_cells = grid_data.cell_count

	# Tolerance for vertex matching - 5% of cell size to account for rounding and positioning quirks
	var vertex_tolerance = cell_size * 0.05

	for test_id in range(total_cells):
		if test_id == cell_id:
			continue  # Skip self

		# Get vertices for the test polygon (at its actual position)
		var test_vertices = get_polygon_vertices(test_id, grid_data)

		# Count how many vertices match (within tolerance)
		var matches = 0
		for my_v in my_vertices:
			for test_v in test_vertices:
				if my_v.distance_to(test_v) < vertex_tolerance:
					matches += 1
					break  # Don't count the same vertex twice

		if matches > 0:
			shared_vertex_count[test_id] = matches

		# If wrapping is enabled, also check ghost positions
		# Ghost positions are the same cell rendered at wrapped coordinates
		if wrap_horizontal or wrap_vertical:
			# Calculate grid dimensions for wrapping offsets
			var grid_pixel_width = grid_data.grid_size.x * cell_size
			var grid_pixel_height = grid_data.grid_size.y * cell_size

			# For hex grids, use actual width/height
			if grid_data.grid_type == GridType.Type.HEXAGON:
				var hex_width_ratio = 0.866025404  # sqrt(3) / 2
				grid_pixel_width = grid_data.grid_size.x * cell_size * hex_width_ratio
				grid_pixel_height = grid_data.grid_size.y * cell_size * 0.75

			# For triangle grids, use actual spacing
			# IMPORTANT: Account for the -2px per row vertical compensation
			if grid_data.grid_type == GridType.Type.TRIANGLE:
				grid_pixel_width = grid_data.grid_size.x * cell_size * 0.5
				# Height includes the 2px compensation per row
				grid_pixel_height = grid_data.grid_size.y * cell_size - (grid_data.grid_size.y * 2)

			# Check ghost positions in all 8 directions (including diagonals)
			var ghost_offsets: Array[Vector2] = []

			if wrap_horizontal:
				ghost_offsets.append(Vector2(-grid_pixel_width, 0))  # Left wrap
				ghost_offsets.append(Vector2(grid_pixel_width, 0))   # Right wrap

			if wrap_vertical:
				ghost_offsets.append(Vector2(0, -grid_pixel_height))  # Top wrap
				ghost_offsets.append(Vector2(0, grid_pixel_height))   # Bottom wrap

			if wrap_horizontal and wrap_vertical:
				# Corner wraps
				ghost_offsets.append(Vector2(-grid_pixel_width, -grid_pixel_height))  # Top-left
				ghost_offsets.append(Vector2(grid_pixel_width, -grid_pixel_height))   # Top-right
				ghost_offsets.append(Vector2(-grid_pixel_width, grid_pixel_height))   # Bottom-left
				ghost_offsets.append(Vector2(grid_pixel_width, grid_pixel_height))    # Bottom-right

			# Check each ghost position
			for ghost_offset in ghost_offsets:
				var ghost_matches = 0
				for my_v in my_vertices:
					for test_v in test_vertices:
						var ghost_v = test_v + ghost_offset
						if my_v.distance_to(ghost_v) < vertex_tolerance:
							ghost_matches += 1
							break

				# If ghost position has more matches, use that instead
				if ghost_matches > 0:
					shared_vertex_count[test_id] = max(shared_vertex_count.get(test_id, 0), ghost_matches)

	# Build neighbor list based on sharing mode
	var neighbors = PackedInt32Array()

	for test_id in shared_vertex_count.keys():
		var shared_count = shared_vertex_count[test_id]

		if use_vertex_neighbors:
			# Include both edge (2+ vertices) and vertex (1 vertex) neighbors
			if shared_count >= 1:
				neighbors.append(test_id)
		else:
			# Only edge neighbors (2+ vertices shared)
			if shared_count >= 2:
				neighbors.append(test_id)

	return neighbors

## Place mines randomly in the grid, avoiding a safe start cell
## @param grid: The GridData to populate with mines
## @param mine_count: Number of mines to place
## @param safe_start_id: Optional cell_id that should never have a mine
func place_mines_random(grid: GridData, mine_count: int, safe_start_id: int = -1) -> void:
	# Clamp mine count to reasonable limits
	var max_mines = grid.cell_count - 1  # Leave at least one safe cell
	mine_count = mini(mine_count, max_mines)

	# Build list of available cells (excluding safe start)
	var available_cells: Array[int] = []
	for i in range(grid.cell_count):
		if i != safe_start_id:
			available_cells.append(i)

	# Shuffle and place mines in first N cells
	available_cells.shuffle()
	for i in range(mine_count):
		grid.set_mine(available_cells[i], true)

	# Calculate danger counts after all mines are placed
	grid.calculate_danger_counts()

## Wrap a coordinate to stay within grid bounds (handles negative modulo)
## @param pos: Position to wrap
## @param map_size: Size of the map
## @return: Wrapped position
func wrap_position(pos: Vector2i, map_size: Vector2i) -> Vector2i:
	var wrapped = Vector2i(
		pos.x % map_size.x,
		pos.y % map_size.y
	)

	# Fix negative modulo (GDScript can return negative)
	if wrapped.x < 0:
		wrapped.x += map_size.x
	if wrapped.y < 0:
		wrapped.y += map_size.y

	return wrapped

## Check if a position is within grid bounds (for non-wrapping grids)
## @param pos: Position to check
## @param map_size: Size of the map
## @return: true if position is valid
func is_in_bounds(pos: Vector2i, map_size: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < map_size.x and pos.y >= 0 and pos.y < map_size.y

## Simple centroid-based hit testing (works for most grids)
## Override if you need more sophisticated testing
## @param world_pos: Click position in world coordinates
## @param grid: The GridData being tested
## @return: Closest cell_id, or -1 if none found
func get_closest_cell(world_pos: Vector2, grid: GridData) -> int:
	var closest_cell = -1
	var min_distance = INF

	for cell_id in range(grid.cell_count):
		var centroid = get_pixel_position(cell_id)
		var dist = world_pos.distance_squared_to(centroid)

		if dist < min_distance:
			min_distance = dist
			closest_cell = cell_id

	return closest_cell

## Validate that all neighbor relationships are reciprocal
## Useful for debugging grid generation
## @param grid: The GridData to validate
## @return: true if all neighbors are valid
func validate_grid(grid: GridData) -> bool:
	if not grid.validate_neighbors():
		push_error("Grid validation failed: non-reciprocal neighbors found")
		return false

	# Additional validation: check that all cells have reasonable neighbor counts
	var grid_type = grid.grid_type
	var expected_neighbors = GridType.get_typical_neighbor_count(grid_type)

	if expected_neighbors > 0:  # Only for grids with uniform neighbor counts
		for cell_id in range(grid.cell_count):
			var neighbor_count = grid.get_neighbors(cell_id).size()
			if neighbor_count != expected_neighbors:
				# This might be OK for boundary cells in non-wrapping grids
				if not wrap_horizontal or not wrap_vertical:
					continue
				push_warning("Cell %d has %d neighbors, expected %d" % [
					cell_id, neighbor_count, expected_neighbors
				])

	print("Grid validation passed: %s" % grid.get_debug_info())
	return true
