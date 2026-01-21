## GameLogic.gd
##
## Core game logic for minesweeper
## Handles:
## - Cell reveal with flood fill
## - Flagging/unflagging
## - First-click safety
## - Win/loss detection
## - Game state management

class_name GameLogic
extends RefCounted

## Game state enum
enum GameState {
	NOT_STARTED,  # No cells revealed yet
	PLAYING,      # Game in progress
	WON,          # All safe cells revealed
	LOST          # Mine was revealed
}

## The grid data
var grid_data: GridData

## The grid generator (for first-click mine relocation)
var grid_generator: GridGenerator

## Current game state
var current_state: GameState = GameState.NOT_STARTED

## Track if this is the first reveal (for first-click safety)
var first_reveal: bool = true

## Statistics
var cells_revealed: int = 0
var flags_placed: int = 0
var start_time: float = 0.0
var end_time: float = 0.0

## Initialize with grid data and generator
func initialize(data: GridData, generator: GridGenerator) -> void:
	grid_data = data
	grid_generator = generator
	current_state = GameState.NOT_STARTED
	first_reveal = true
	cells_revealed = 0
	flags_placed = 0

## Attempt to reveal a cell
## Returns array of cell IDs that were revealed (for visual updates)
func reveal_cell(cell_id: int) -> PackedInt32Array:
	var revealed_cells = PackedInt32Array()

	# Validate cell ID
	if cell_id < 0 or cell_id >= grid_data.cell_count:
		return revealed_cells

	# Can't reveal if game is over
	if current_state == GameState.WON or current_state == GameState.LOST:
		return revealed_cells

	# Can't reveal flagged or already revealed cells
	if grid_data.is_flagged(cell_id) or grid_data.is_revealed(cell_id):
		return revealed_cells

	# First click safety: relocate mine if necessary
	if first_reveal:
		_ensure_safe_start(cell_id)
		first_reveal = false
		current_state = GameState.PLAYING
		start_time = Time.get_ticks_msec() / 1000.0

	# Check if it's a mine
	if grid_data.is_mine(cell_id):
		# Game over - reveal the mine
		grid_data.reveal_cell(cell_id)
		revealed_cells.append(cell_id)
		current_state = GameState.LOST
		end_time = Time.get_ticks_msec() / 1000.0
		print("💥 GAME OVER - Mine hit!")
		return revealed_cells

	# Safe cell - flood fill reveal
	revealed_cells = _flood_fill_reveal(cell_id)
	cells_revealed += revealed_cells.size()

	# Check for win condition
	_check_win_condition()

	return revealed_cells

## Toggle flag on a cell
## Returns true if flag state changed
func toggle_flag(cell_id: int) -> bool:
	# Validate cell ID
	if cell_id < 0 or cell_id >= grid_data.cell_count:
		return false

	# Can't flag if game is over
	if current_state == GameState.WON or current_state == GameState.LOST:
		return false

	# Can't flag already revealed cells
	if grid_data.is_revealed(cell_id):
		return false

	# Toggle flag
	if grid_data.is_flagged(cell_id):
		grid_data.clear_marking(cell_id)
		flags_placed -= 1
	else:
		grid_data.flag_cell(cell_id)
		flags_placed += 1

	return true

## Ensure first click is safe by relocating mine if necessary
func _ensure_safe_start(cell_id: int) -> void:
	if not grid_data.is_mine(cell_id):
		return  # Already safe

	print("First click safety: relocating mine from cell %d" % cell_id)

	# Find a safe cell to move the mine to
	# Avoid the clicked cell and its neighbors
	var forbidden_cells = PackedInt32Array([cell_id])
	for neighbor_id in grid_data.get_neighbors(cell_id):
		forbidden_cells.append(neighbor_id)

	# Find first available safe cell
	for candidate_id in range(grid_data.cell_count):
		if not forbidden_cells.has(candidate_id) and not grid_data.is_mine(candidate_id):
			# Move mine here
			grid_data.set_mine(cell_id, false)
			grid_data.set_mine(candidate_id, true)

			# Recalculate danger counts
			grid_data.calculate_danger_counts()

			print("  → Moved to cell %d" % candidate_id)
			return

	# If we get here, grid is too densely mined (shouldn't happen in normal play)
	push_warning("Could not relocate mine - grid too dense")

## Flood fill reveal algorithm
## Reveals cell and recursively reveals neighbors if danger count is 0
func _flood_fill_reveal(start_cell_id: int) -> PackedInt32Array:
	var revealed = PackedInt32Array()
	var to_process = PackedInt32Array([start_cell_id])
	var processed = {}  # Use dictionary as set

	while to_process.size() > 0:
		var cell_id = to_process[0]
		to_process.remove_at(0)

		# Skip if already processed
		if processed.has(cell_id):
			continue
		processed[cell_id] = true

		# Skip if already revealed, flagged, or out of bounds
		if cell_id < 0 or cell_id >= grid_data.cell_count:
			continue
		if grid_data.is_revealed(cell_id) or grid_data.is_flagged(cell_id):
			continue

		# Skip if it's a mine (shouldn't happen, but safety check)
		if grid_data.is_mine(cell_id):
			continue

		# Reveal this cell
		grid_data.reveal_cell(cell_id)
		revealed.append(cell_id)

		# If danger count is 0, add neighbors to process queue
		if grid_data.get_danger_count(cell_id) == 0:
			for neighbor_id in grid_data.get_neighbors(cell_id):
				if not processed.has(neighbor_id):
					to_process.append(neighbor_id)

	return revealed

## Check if player has won
func _check_win_condition() -> void:
	if current_state != GameState.PLAYING:
		return

	# Count unrevealed safe cells
	var unrevealed_safe = 0
	for cell_id in range(grid_data.cell_count):
		if not grid_data.is_mine(cell_id) and not grid_data.is_revealed(cell_id):
			unrevealed_safe += 1

	# Win if all safe cells are revealed
	if unrevealed_safe == 0:
		current_state = GameState.WON
		end_time = Time.get_ticks_msec() / 1000.0
		var time_elapsed = end_time - start_time
		print("🎉 YOU WIN! Time: %.1f seconds" % time_elapsed)

## Get current game state
func get_state() -> GameState:
	return current_state

## Get elapsed play time
func get_elapsed_time() -> float:
	if current_state == GameState.NOT_STARTED:
		return 0.0
	elif current_state == GameState.PLAYING:
		return (Time.get_ticks_msec() / 1000.0) - start_time
	else:
		return end_time - start_time

## Get remaining mines (total mines - flags placed)
func get_remaining_mines() -> int:
	return grid_data.count_total_mines() - flags_placed

## Reset game (regenerate grid)
func reset(mine_count: int) -> void:
	# Regenerate grid with new mine positions
	grid_data = grid_generator.generate(mine_count)

	# Reset state
	current_state = GameState.NOT_STARTED
	first_reveal = true
	cells_revealed = 0
	flags_placed = 0
	start_time = 0.0
	end_time = 0.0

	print("Game reset - new grid generated")
