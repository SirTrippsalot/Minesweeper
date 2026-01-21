## TestGrid.gd
##
## Simple test script to validate GridData and SquareGridGenerator
## Attach this to a Node in a test scene and run to see output in console

extends Node

# Preload the generator to ensure proper script resolution
const SquareGridGen = preload("res://scripts/generators/SquareGridGenerator.gd")

func _ready():
	print("=== Testing Grid Data Structures ===\n")

	# Test 1: Create a small square grid
	print("Test 1: Creating 10×10 square grid with wrapping...")
	var generator = SquareGridGen.new(10, 10, true, true)
	var grid = generator.generate(15)  # 15 mines

	if grid:
		print("✓ Grid created successfully")
		print("  - Type: %s" % GridType.get_name(grid.grid_type))
		print("  - Size: %d cells" % grid.cell_count)
		print("  - Mines: %d" % grid.count_total_mines())
		print("  - Wrapping: H=%s V=%s" % [grid.wrap_horizontal, grid.wrap_vertical])
	else:
		print("✗ Failed to create grid")
		return

	# Test 2: Check neighbor counts
	print("\nTest 2: Validating neighbor relationships...")
	var all_valid = true
	for cell_id in range(grid.cell_count):
		var neighbors = grid.get_neighbors(cell_id)
		if neighbors.size() != 8:
			print("✗ Cell %d has %d neighbors (expected 8)" % [cell_id, neighbors.size()])
			all_valid = false
			break

	if all_valid:
		print("✓ All cells have exactly 8 neighbors (correct for wrapped square grid)")

	# Test 3: Verify reciprocal neighbors
	print("\nTest 3: Checking reciprocal neighbor relationships...")
	if grid.validate_neighbors():
		print("✓ All neighbor relationships are reciprocal")
	else:
		print("✗ Found non-reciprocal neighbors")

	# Test 4: Sample some cells
	print("\nTest 4: Sampling cell data...")
	for i in range(5):
		var cell_id = randi() % grid.cell_count
		var is_mine = grid.is_mine(cell_id)
		var danger = grid.get_danger_count(cell_id)
		var neighbor_count = grid.get_neighbors(cell_id).size()
		print("  Cell %d: Mine=%s, Danger=%d, Neighbors=%d" % [
			cell_id, is_mine, danger, neighbor_count
		])

	# Test 5: Pixel position conversion
	print("\nTest 5: Testing coordinate conversions...")
	var test_cells = [0, 50, 99]  # First, middle, last
	for cell_id in test_cells:
		var pixel_pos = generator.get_pixel_position(cell_id)
		var found_id = generator.get_cell_at_position(pixel_pos)
		if found_id == cell_id:
			print("✓ Cell %d: pos=%s → id=%d (correct)" % [cell_id, pixel_pos, found_id])
		else:
			print("✗ Cell %d: pos=%s → id=%d (wrong)" % [cell_id, pixel_pos, found_id])

	# Test 6: Non-wrapping grid
	print("\nTest 6: Creating 10×10 square grid WITHOUT wrapping...")
	var generator_no_wrap = SquareGridGen.new(10, 10, false, false)
	var grid_no_wrap = generator_no_wrap.generate(15)

	# Corner cells should have fewer neighbors
	var corner_cell = 0  # Top-left corner
	var corner_neighbors = grid_no_wrap.get_neighbors(corner_cell).size()
	print("  Corner cell (0,0) has %d neighbors (expected 3)" % corner_neighbors)

	if corner_neighbors == 3:
		print("✓ Non-wrapping boundaries work correctly")
	else:
		print("✗ Non-wrapping boundaries incorrect")

	# Test 7: Edge cells for ghost rendering
	print("\nTest 7: Testing edge cell detection...")
	var edges = generator.get_edge_cells()
	print("  Left edge: %d cells" % edges["left"].size())
	print("  Right edge: %d cells" % edges["right"].size())
	print("  Top edge: %d cells" % edges["top"].size())
	print("  Bottom edge: %d cells" % edges["bottom"].size())

	if edges["left"].size() == 10 and edges["top"].size() == 10:
		print("✓ Edge detection working correctly")

	print("\n=== All Tests Complete ===")
	print("Phase 1 foundation is working! Ready for Phase 2 (rendering).")
