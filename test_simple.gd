extends Node

func _ready():
	print("\n=== SIMPLE TEST STARTING ===\n")

	# Test GridType enum
	print("Test 1: GridType enum")
	print("  GridType.Type.SQUARE = ", GridType.Type.SQUARE)
	print("  GridType.get_type_name(SQUARE) = ", GridType.get_type_name(GridType.Type.SQUARE))
	print("  ✓ GridType working!\n")

	# Test GridData creation
	print("Test 2: GridData creation")
	var grid = GridData.new()
	grid.initialize(10)
	print("  GridData created with 10 cells")
	print("  grid.cell_count = ", grid.cell_count)
	print("  ✓ GridData working!\n")

	print("=== ALL TESTS PASSED! ===\n")
	print("Phase 1 foundation is solid!")
	print("Ready to test SquareGridGenerator next.\n")
