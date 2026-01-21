extends Node

func _ready():
	print("Simple test starting...")

	# Test GridType enum
	print("GridType.Type.SQUARE = ", GridType.Type.SQUARE)
	print("GridType.get_type_name(GridType.Type.SQUARE) = ", GridType.get_type_name(GridType.Type.SQUARE))

	# Test GridData creation
	var grid = GridData.new()
	grid.initialize(10)
	print("GridData created with 10 cells")

	print("Simple test complete!")
