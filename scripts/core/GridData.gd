## GridData.gd
##
## Core data structure for the minesweeper graph using Struct-of-Arrays pattern.
## This is the heart of the game - stores all cell information efficiently.
##
## CRITICAL: This uses graph-based logic (adjacency lists), NOT 2D arrays.
## Each cell is referenced by ID (array index). Neighbor relationships are
## stored as adjacency lists, making this approach work for ANY tessellation.
##
## Memory efficiency: 100,000 cells = ~100KB (vs 100MB+ with object-per-cell)

class_name GridData
extends Resource

## Total number of cells in the grid
@export var cell_count: int = 0

## Grid dimensions (for reference/UI, not used for logic)
@export var grid_size: Vector2i = Vector2i.ZERO

## Grid type identifier
@export var grid_type: GridType.Type = GridType.Type.SQUARE

## Wrapping configuration
@export var wrap_horizontal: bool = true
@export var wrap_vertical: bool = true

# ===== STRUCT OF ARRAYS (SoA) PATTERN =====
# Each array is indexed by cell_id (0 to cell_count-1)
# This pattern is memory-efficient and cache-friendly

## Which cells contain mines (1 = mine, 0 = safe)
var cell_is_mine: PackedByteArray

## Cell reveal/marking state
## 0 = hidden, 1 = revealed, 2 = flagged, 3 = questioned
var cell_state: PackedByteArray

## Number of neighboring mines (calculated once, cached)
var cell_danger_count: PackedByteArray

## Adjacency lists - each cell's array contains IDs of neighboring cells
## This is the CORE of the graph-based architecture
var cell_neighbors: Array[PackedInt32Array]

# ===== INITIALIZATION =====

## Initialize all arrays to hold 'count' cells
func initialize(count: int) -> void:
	cell_count = count

	# Allocate arrays
	cell_is_mine.resize(count)
	cell_state.resize(count)
	cell_danger_count.resize(count)
	cell_neighbors.resize(count)

	# Fill with defaults
	cell_is_mine.fill(0)
	cell_state.fill(0)  # All hidden
	cell_danger_count.fill(0)

# ===== CELL QUERIES =====

## Check if a cell contains a mine
func is_mine(cell_id: int) -> bool:
	if cell_id < 0 or cell_id >= cell_count:
		return false
	return cell_is_mine[cell_id] == 1

## Check if a cell has been revealed
func is_revealed(cell_id: int) -> bool:
	if cell_id < 0 or cell_id >= cell_count:
		return false
	return cell_state[cell_id] == 1

## Check if a cell is flagged
func is_flagged(cell_id: int) -> bool:
	if cell_id < 0 or cell_id >= cell_count:
		return false
	return cell_state[cell_id] == 2

## Check if a cell is questioned
func is_questioned(cell_id: int) -> bool:
	if cell_id < 0 or cell_id >= cell_count:
		return false
	return cell_state[cell_id] == 3

## Check if a cell is hidden (not revealed, flagged, or questioned)
func is_hidden(cell_id: int) -> bool:
	if cell_id < 0 or cell_id >= cell_count:
		return false
	return cell_state[cell_id] == 0

## Get the neighbor IDs for a cell
func get_neighbors(cell_id: int) -> PackedInt32Array:
	if cell_id < 0 or cell_id >= cell_count:
		return PackedInt32Array()
	return cell_neighbors[cell_id]

## Get the danger count (number of neighboring mines)
func get_danger_count(cell_id: int) -> int:
	if cell_id < 0 or cell_id >= cell_count:
		return 0
	return cell_danger_count[cell_id]

# ===== CELL MODIFICATIONS =====

## Set whether a cell contains a mine
func set_mine(cell_id: int, is_mine_val: bool) -> void:
	if cell_id < 0 or cell_id >= cell_count:
		return
	cell_is_mine[cell_id] = 1 if is_mine_val else 0

## Reveal a cell
func reveal_cell(cell_id: int) -> void:
	if cell_id < 0 or cell_id >= cell_count:
		return
	cell_state[cell_id] = 1

## Flag a cell as containing a mine
func flag_cell(cell_id: int) -> void:
	if cell_id < 0 or cell_id >= cell_count:
		return
	cell_state[cell_id] = 2

## Mark a cell with a question mark
func question_cell(cell_id: int) -> void:
	if cell_id < 0 or cell_id >= cell_count:
		return
	cell_state[cell_id] = 3

## Clear any marking from a cell (return to hidden state)
func clear_marking(cell_id: int) -> void:
	if cell_id < 0 or cell_id >= cell_count:
		return
	cell_state[cell_id] = 0

# ===== NEIGHBOR MANAGEMENT =====

## Set the neighbor list for a cell (called during grid generation)
func set_neighbors(cell_id: int, neighbor_ids: PackedInt32Array) -> void:
	if cell_id < 0 or cell_id >= cell_count:
		return
	cell_neighbors[cell_id] = neighbor_ids

## Calculate danger counts for all cells
## Call this ONCE after mines are placed
func calculate_danger_counts() -> void:
	for cell_id in range(cell_count):
		if is_mine(cell_id):
			cell_danger_count[cell_id] = 0  # Mines don't show numbers
			continue

		var count = 0
		for neighbor_id in get_neighbors(cell_id):
			if is_mine(neighbor_id):
				count += 1

		cell_danger_count[cell_id] = count

# ===== UTILITY FUNCTIONS =====

## Count total number of mines in the grid
func count_total_mines() -> int:
	var count = 0
	for i in range(cell_count):
		if is_mine(i):
			count += 1
	return count

## Count number of flagged cells
func count_flagged() -> int:
	var count = 0
	for i in range(cell_count):
		if is_flagged(i):
			count += 1
	return count

## Count number of revealed cells
func count_revealed() -> int:
	var count = 0
	for i in range(cell_count):
		if is_revealed(i):
			count += 1
	return count

## Validate that neighbor relationships are reciprocal
## Useful for debugging grid generation
func validate_neighbors() -> bool:
	for cell_id in range(cell_count):
		var neighbors = get_neighbors(cell_id)
		for neighbor_id in neighbors:
			var reverse_neighbors = get_neighbors(neighbor_id)
			if not reverse_neighbors.has(cell_id):
				push_error("Non-reciprocal neighbor: %d -> %d" % [cell_id, neighbor_id])
				return false
	return true

## Get debug string representation
func get_debug_info() -> String:
	return "GridData: %d cells (%s), %d mines, %d revealed" % [
		cell_count,
		GridType.get_name(grid_type),
		count_total_mines(),
		count_revealed()
	]
