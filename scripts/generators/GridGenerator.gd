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
## @param mine_count: Number of mines to place
## @return: Fully initialized GridData
func generate(mine_count: int) -> GridData:
	push_error("GridGenerator.generate() must be overridden by subclass")
	return null

## Convert cell_id to pixel position for rendering
## @param cell_id: The cell index
## @return: World position in pixels
func get_pixel_position(cell_id: int) -> Vector2:
	push_error("GridGenerator.get_pixel_position() must be overridden by subclass")
	return Vector2.ZERO

## Find cell_id at given world position (for click detection)
## @param world_pos: Position in world coordinates
## @return: cell_id, or -1 if no cell at that position
func get_cell_at_position(world_pos: Vector2) -> int:
	push_error("GridGenerator.get_cell_at_position() must be overridden by subclass")
	return -1

# ===== COMMON HELPER METHODS (Available to all subclasses) =====

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
