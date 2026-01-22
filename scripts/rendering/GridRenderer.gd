## GridRenderer.gd
##
## MultiMesh-based rendering system for grid visualization
## Renders 10,000+ cells efficiently in a single draw call
## Uses ocean/island theme (water=mines, land=safe)

class_name GridRenderer
extends Node2D

## The grid data to render
var grid_data: GridData

## The generator (for pixel positions)
var grid_generator: GridGenerator

## Visual settings
var cell_size: float = 64.0
var cell_gap: float = 0.0  # No gaps - cells touch like traditional minesweeper
var border_width: float = 2.0  # Width of cell borders

## Ocean theme colors
var color_border: Color = Color(0.15, 0.2, 0.3, 1.0)       # Darker blue for borders
var color_hidden: Color = Color(0.7, 0.75, 0.8, 0.95)      # Foggy/cloudy (can't see below)
var color_beach: Color = Color(0.95, 0.85, 0.65, 1.0)      # Sandy beach (island edge)
var color_vegetation: Color = Color(0.3, 0.7, 0.4, 1.0)    # Green vegetation (island interior)
var color_water: Color = Color(0.2, 0.5, 0.8, 1.0)         # Blue water (has mines nearby)
var color_deep_water: Color = Color(0.1, 0.15, 0.25, 1.0)  # Deep water (revealed mine)
var color_flagged: Color = Color(0.15, 0.4, 0.7, 1.0)      # Darker water with flag

## Danger count colors (numbers on revealed safe cells)
var danger_colors: Array[Color] = [
	Color(0.7, 0.7, 0.7, 1.0),   # 0 neighbors: light gray
	Color(0.4, 0.7, 1.0, 1.0),   # 1 neighbor: light blue (stands out on water)
	Color(0.2, 0.7, 0.3, 1.0),   # 2 neighbors: green
	Color(0.9, 0.3, 0.2, 1.0),   # 3 neighbors: red
	Color(0.5, 0.2, 0.8, 1.0),   # 4 neighbors: purple
	Color(0.8, 0.4, 0.1, 1.0),   # 5 neighbors: orange
	Color(0.2, 0.8, 0.8, 1.0),   # 6 neighbors: cyan
	Color(0.1, 0.1, 0.1, 1.0),   # 7 neighbors: black
	Color(0.5, 0.5, 0.5, 1.0),   # 8 neighbors: gray
]

## MultiMesh instances
var cell_multimesh: MultiMeshInstance2D
var cell_mesh: Mesh  # Can be QuadMesh or custom hex mesh
var border_multimesh: MultiMeshInstance2D
var border_mesh: Mesh  # Can be QuadMesh or custom hex mesh

## For mixed-type grids (octasquare), separate MultiMesh instances
var octagon_multimesh: MultiMeshInstance2D  # For octagons
var square_multimesh: MultiMeshInstance2D   # For squares
var octagon_border_multimesh: MultiMeshInstance2D  # Octagon borders
var square_border_multimesh: MultiMeshInstance2D   # Square borders

## Number labels for danger counts
var number_labels: Array[Label] = []
var labels_container: Node2D

## Track which cells need visual updates
var dirty_cells: PackedInt32Array = PackedInt32Array()

## Infinite tiling for visual wrapping (camera-relative dynamic tiling)
var tile_instances: Array[Dictionary] = []  # Array of {cells: MultiMeshInstance2D, borders: MultiMeshInstance2D, labels: Node2D, grid_offset: Vector2i}
var grid_pixel_width: float = 0.0
var grid_pixel_height: float = 0.0
var camera: Camera2D = null  # Reference to camera for position tracking

## Debug border reference
var debug_border: Line2D = null

func _ready():
	# Initialize rendering when added to scene tree
	if grid_data and grid_generator:
		_initialize_rendering()

## Set up the grid to render
func setup(data: GridData, generator: GridGenerator) -> void:
	grid_data = data
	grid_generator = generator

	if is_inside_tree():
		_initialize_rendering()

## Create appropriate mesh based on grid type
func _create_cell_mesh(with_border: bool = false) -> Mesh:
	var size_offset = 0.0 if with_border else border_width * 2
	var mesh_size = cell_size - size_offset

	match grid_data.grid_type:
		GridType.Type.SQUARE:
			var quad = QuadMesh.new()
			quad.size = Vector2(mesh_size, mesh_size)
			return quad

		GridType.Type.HEXAGON:
			# Create hexagon mesh using ArrayMesh
			return _create_hexagon_mesh(mesh_size)

		GridType.Type.TRIANGLE:
			# Create triangle mesh using ArrayMesh
			return _create_triangle_mesh(mesh_size)

		GridType.Type.OCTASQUARE:
			# For mixed grids, we'll handle rendering differently
			# This creates an octagon mesh (squares will be handled separately)
			return _create_octagon_mesh(mesh_size)

		_:
			# Default to quad for unsupported types
			var quad = QuadMesh.new()
			quad.size = Vector2(mesh_size, mesh_size)
			return quad

## Create a hexagon mesh (pointy-top orientation)
func _create_hexagon_mesh(size: float) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	# Hexagon vertices (pointy-top)
	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Center point
	var center = Vector2.ZERO

	# Generate 6 vertices around center
	var radius = size * 0.5
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)  # Start at -30° for pointy-top
		var vertex = Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		)
		vertices.append(vertex)
		# UV coordinates (0-1 range)
		uvs.append((vertex / size) + Vector2(0.5, 0.5))

	# Create triangles from center to each edge
	# We'll create a fan of triangles
	var center_vertices = PackedVector2Array()
	var center_uvs = PackedVector2Array()

	# Add center vertex
	center_vertices.append(center)
	center_uvs.append(Vector2(0.5, 0.5))

	# Add all edge vertices
	for v in vertices:
		center_vertices.append(v)
	for uv in uvs:
		center_uvs.append(uv)

	# Create triangle fan indices
	for i in range(6):
		indices.append(0)  # Center
		indices.append(i + 1)
		indices.append((i + 1) % 6 + 1)

	arrays[Mesh.ARRAY_VERTEX] = center_vertices
	arrays[Mesh.ARRAY_TEX_UV] = center_uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh

## Create a triangle mesh (equilateral, can point up or down)
func _create_triangle_mesh(size: float) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Simple equilateral triangle with centroid at origin
	# Vertices: (0, -1), (-1, 1), (1, 1) scaled by size/2
	var half_size = size / 2

	vertices.append(Vector2(0, -1) * half_size)       # Top: (0, -1)
	vertices.append(Vector2(-1, 1) * half_size)       # Bottom-left: (-1, 1)
	vertices.append(Vector2(1, 1) * half_size)        # Bottom-right: (1, 1)

	# UV coordinates
	uvs.append(Vector2(0.5, 0.0))
	uvs.append(Vector2(0.0, 1.0))
	uvs.append(Vector2(1.0, 1.0))

	# Triangle indices
	indices.append(0)
	indices.append(1)
	indices.append(2)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh

## Create an octagon mesh (regular 8-sided polygon)
func _create_octagon_mesh(size: float) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Center point
	var center = Vector2.ZERO

	# Generate 8 vertices around center
	var radius = size * 0.5
	for i in range(8):
		var angle = deg_to_rad(45.0 * i + 22.5)  # Start at 22.5° for flat top/bottom
		var vertex = Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		)
		vertices.append(vertex)
		# UV coordinates (0-1 range)
		uvs.append((vertex / size) + Vector2(0.5, 0.5))

	# Create triangle fan from center
	var center_vertices = PackedVector2Array()
	var center_uvs = PackedVector2Array()

	# Add center vertex
	center_vertices.append(center)
	center_uvs.append(Vector2(0.5, 0.5))

	# Add all edge vertices
	for v in vertices:
		center_vertices.append(v)
	for uv in uvs:
		center_uvs.append(uv)

	# Create triangle fan indices
	for i in range(8):
		indices.append(0)  # Center
		indices.append(i + 1)
		indices.append((i + 1) % 8 + 1)

	arrays[Mesh.ARRAY_VERTEX] = center_vertices
	arrays[Mesh.ARRAY_TEX_UV] = center_uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh

## Create a square mesh (for octasquare grids)
func _create_square_mesh(size: float) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var half_size = size * 0.5

	# Four corners of the square
	vertices.append(Vector2(-half_size, -half_size))  # Top-left
	vertices.append(Vector2(half_size, -half_size))   # Top-right
	vertices.append(Vector2(half_size, half_size))    # Bottom-right
	vertices.append(Vector2(-half_size, half_size))   # Bottom-left

	# UV coordinates
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))

	# Two triangles to form the square
	indices.append(0)  # Triangle 1
	indices.append(1)
	indices.append(2)
	indices.append(0)  # Triangle 2
	indices.append(2)
	indices.append(3)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh

## Create border mesh (wireframe outlines using lines)
func _create_border_mesh() -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices = PackedVector2Array()

	match grid_data.grid_type:
		GridType.Type.SQUARE:
			# Square outline (4 lines forming a closed loop)
			var half = cell_size / 2
			vertices.append(Vector2(-half, -half))  # Top-left
			vertices.append(Vector2(half, -half))   # Top-right
			vertices.append(Vector2(half, half))    # Bottom-right
			vertices.append(Vector2(-half, half))   # Bottom-left
			vertices.append(Vector2(-half, -half))  # Back to start (close loop)

		GridType.Type.HEXAGON:
			# Hexagon outline (6 lines forming a closed loop)
			var radius = cell_size / 2
			for i in range(7):  # 7 vertices to close the loop (0-6, where 6 == 0)
				var angle = deg_to_rad(60.0 * i - 30.0)
				vertices.append(Vector2(
					cos(angle) * radius,
					sin(angle) * radius
				))

		GridType.Type.TRIANGLE:
			# Triangle outline - draw left and right edges only (omit bottom to avoid double-thickness)
			# Use PRIMITIVE_LINES with 4 vertices to draw 2 separate line segments:
			#   Line 1: Top → Bottom-left (vertices 0-1)
			#   Line 2: Bottom-right → Top (vertices 2-3, reversed order to avoid center artifact)
			var half_size = cell_size / 2
			vertices.append(Vector2(0, -1) * half_size)       # Line 1: start at Top
			vertices.append(Vector2(-1, 1) * half_size)       # Line 1: end at Bottom-left
			vertices.append(Vector2(1, 1) * half_size)        # Line 2: start at Bottom-right
			vertices.append(Vector2(0, -1) * half_size)       # Line 2: end at Top

		GridType.Type.OCTASQUARE:
			# Octagon outline (8 lines forming a closed loop)
			var radius = cell_size / 2
			for i in range(9):  # 9 vertices to close the loop (0-8, where 8 == 0)
				var angle = deg_to_rad(45.0 * i + 22.5)
				vertices.append(Vector2(
					cos(angle) * radius,
					sin(angle) * radius
				))

	arrays[Mesh.ARRAY_VERTEX] = vertices

	var mesh = ArrayMesh.new()
	# Triangles use PRIMITIVE_LINES (pairs of vertices = separate line segments)
	# Other shapes use LINE_STRIP (connected vertices = closed loops)
	var primitive_type = Mesh.PRIMITIVE_LINES if grid_data.grid_type == GridType.Type.TRIANGLE else Mesh.PRIMITIVE_LINE_STRIP
	mesh.add_surface_from_arrays(primitive_type, arrays)

	# Create a material to control line width
	var material = CanvasItemMaterial.new()
	# Note: Godot 2D doesn't have direct line width control in materials
	# Line width is controlled at the rendering level, not mesh level
	# The default is typically 1.0 pixels

	return mesh

## Initialize MultiMesh rendering
func _initialize_rendering() -> void:
	if not grid_data or not grid_generator:
		push_error("GridRenderer: Cannot initialize without grid_data and grid_generator")
		return

	# Special handling for octasquare (mixed polygon types)
	if grid_data.grid_type == GridType.Type.OCTASQUARE:
		_initialize_octasquare_rendering()
	else:
		# Standard single-type grid rendering
		_initialize_standard_rendering()

	# Create labels container and number labels
	_create_number_labels()

	# Initialize all cell visuals
	_update_all_cells()

	# Create infinite tiling for wrapping visualization
	if grid_data.wrap_horizontal or grid_data.wrap_vertical:
		_create_infinite_tiles()

	print("GridRenderer initialized: %d cells" % grid_data.cell_count)

## Initialize rendering for standard single-type grids (square, hex, triangle)
func _initialize_standard_rendering() -> void:
	# Create borders first (rendered behind cells)
	_create_borders()

	# Create mesh for cell visualization (type-specific)
	cell_mesh = _create_cell_mesh(false)

	# Create MultiMeshInstance2D
	cell_multimesh = MultiMeshInstance2D.new()
	add_child(cell_multimesh)

	# Configure MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.mesh = cell_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = grid_data.cell_count

	cell_multimesh.multimesh = multimesh

## Initialize rendering for octasquare grids (mixed octagons and squares)
func _initialize_octasquare_rendering() -> void:
	# Count octagons and squares separately
	var octagon_count = 0
	var square_count = 0
	for cell_id in range(grid_data.cell_count):
		if grid_data.cell_rotations[cell_id] == 0:
			octagon_count += 1
		else:
			square_count += 1

	# Create octagon borders
	border_mesh = _create_octagon_mesh(cell_size)
	octagon_border_multimesh = MultiMeshInstance2D.new()
	octagon_border_multimesh.z_index = 1  # In front of cells
	add_child(octagon_border_multimesh)

	var octagon_border_mm = MultiMesh.new()
	octagon_border_mm.mesh = border_mesh
	octagon_border_mm.transform_format = MultiMesh.TRANSFORM_2D
	octagon_border_mm.use_colors = true
	octagon_border_mm.instance_count = octagon_count
	octagon_border_multimesh.multimesh = octagon_border_mm

	# Create square borders
	var square_border_mesh = _create_square_mesh(cell_size)
	square_border_multimesh = MultiMeshInstance2D.new()
	square_border_multimesh.z_index = 2  # Squares render on top of octagons
	add_child(square_border_multimesh)

	var square_border_mm = MultiMesh.new()
	square_border_mm.mesh = square_border_mesh
	square_border_mm.transform_format = MultiMesh.TRANSFORM_2D
	square_border_mm.use_colors = true
	square_border_mm.instance_count = square_count
	square_border_multimesh.multimesh = square_border_mm

	# Create octagon cells
	var octagon_cell_mesh = _create_octagon_mesh(cell_size - border_width * 2)
	octagon_multimesh = MultiMeshInstance2D.new()
	add_child(octagon_multimesh)

	var octagon_mm = MultiMesh.new()
	octagon_mm.mesh = octagon_cell_mesh
	octagon_mm.transform_format = MultiMesh.TRANSFORM_2D
	octagon_mm.use_colors = true
	octagon_mm.instance_count = octagon_count
	octagon_multimesh.multimesh = octagon_mm

	# Create square cells
	var square_cell_mesh = _create_square_mesh(cell_size - border_width * 2)
	square_multimesh = MultiMeshInstance2D.new()
	square_multimesh.z_index = 1  # Squares render above octagons
	add_child(square_multimesh)

	var square_mm = MultiMesh.new()
	square_mm.mesh = square_cell_mesh
	square_mm.transform_format = MultiMesh.TRANSFORM_2D
	square_mm.use_colors = true
	square_mm.instance_count = square_count
	square_multimesh.multimesh = square_mm

## Create number labels for all cells
func _create_number_labels() -> void:
	# Create container for labels
	labels_container = Node2D.new()
	labels_container.z_index = 1  # Above cells
	add_child(labels_container)

	# Pre-create all labels (hidden by default)
	number_labels.resize(grid_data.cell_count)
	for cell_id in range(grid_data.cell_count):
		var label = Label.new()
		var pixel_pos = grid_data.cell_positions[cell_id]  # Use cached position

		# Position label at cell - offset by half size to center
		var label_pos = pixel_pos - Vector2(cell_size / 2, cell_size / 2)

		# For triangles, adjust y-position to compensate for visual center vs centroid
		if grid_data.grid_type == GridType.Type.TRIANGLE:
			var y_offset = cell_size * 0.17  # Visual adjustment
			if grid_data.cell_rotations[cell_id] == 0:
				# Up-pointing: shift label DOWN (centroid is too high visually)
				label_pos.y += y_offset
			else:
				# Down-pointing: shift label UP (centroid is too low visually)
				label_pos.y -= y_offset

		label.position = label_pos
		label.size = Vector2(cell_size, cell_size)
		label.pivot_offset = Vector2.ZERO

		# Center text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		# Font settings
		label.add_theme_font_size_override("font_size", int(cell_size * 0.6))

		# Hidden by default
		label.visible = false

		labels_container.add_child(label)
		number_labels[cell_id] = label

## Create border MultiMesh (rendered in front of cells)
func _create_borders() -> void:
	# Create mesh for borders (wireframe outline, type-specific)
	border_mesh = _create_border_mesh()

	# Create MultiMeshInstance2D for borders
	border_multimesh = MultiMeshInstance2D.new()
	border_multimesh.z_index = 1  # In front of cells to show wireframe outlines

	# Set line width (Godot default is 1.0, we use 1.5 so doubled edges look like 3px)
	# Note: This requires the texture to have a specific width, or use a shader
	# For now, default rendering will use ~1px lines

	add_child(border_multimesh)

	# Configure MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.mesh = border_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = grid_data.cell_count

	border_multimesh.multimesh = multimesh

	# Set all border positions and colors
	for cell_id in range(grid_data.cell_count):
		var transform = Transform2D()

		# Flip triangles vertically if needed (using cached rotation flag)
		# Apply scale BEFORE translation to avoid positioning issues
		if grid_data.cell_rotations[cell_id] == 1:
			transform = transform.scaled(Vector2(1, -1))  # Vertical flip

		transform.origin = grid_data.cell_positions[cell_id]  # Use cached position

		multimesh.set_instance_transform_2d(cell_id, transform)
		multimesh.set_instance_color(cell_id, color_border)

	# Add purple debug border around the primary grid
	_create_debug_grid_border()

## Update all cell visuals (initial render)
func _update_all_cells() -> void:
	# Special handling for octasquare grids (mixed types)
	if grid_data.grid_type == GridType.Type.OCTASQUARE:
		_update_all_octasquare_cells()
		return

	# Standard single-type grid
	if not cell_multimesh or not cell_multimesh.multimesh:
		return

	var multimesh = cell_multimesh.multimesh

	for cell_id in range(grid_data.cell_count):
		# Set transform (position and scale) using cached data
		var transform = Transform2D()

		# Flip vertically if needed (using cached rotation flag)
		# Apply scale BEFORE translation to avoid positioning issues
		if grid_data.cell_rotations[cell_id] == 1:
			transform = transform.scaled(Vector2(1, -1))  # Vertical flip (triangles only)

		transform.origin = grid_data.cell_positions[cell_id]  # Use cached position

		multimesh.set_instance_transform_2d(cell_id, transform)

		# Set color based on cell state
		var color = _get_cell_color(cell_id)
		multimesh.set_instance_color(cell_id, color)

		# Update number label
		if number_labels.size() > 0:
			_update_number_label(cell_id)

## Update cells for octasquare grids (separate MultiMesh instances)
func _update_all_octasquare_cells() -> void:
	if not octagon_multimesh or not square_multimesh:
		return

	var octagon_mm = octagon_multimesh.multimesh
	var square_mm = square_multimesh.multimesh
	var octagon_border_mm = octagon_border_multimesh.multimesh
	var square_border_mm = square_border_multimesh.multimesh

	var octagon_instance = 0
	var square_instance = 0

	for cell_id in range(grid_data.cell_count):
		var is_square = (grid_data.cell_rotations[cell_id] == 1)
		var pos = grid_data.cell_positions[cell_id]
		var color = _get_cell_color(cell_id)

		# Create transform
		var transform = Transform2D()
		transform.origin = pos

		# Border transform (same position, no offset)
		var border_transform = Transform2D()
		border_transform.origin = pos

		if is_square:
			# Update square MultiMesh
			square_mm.set_instance_transform_2d(square_instance, transform)
			square_mm.set_instance_color(square_instance, color)
			square_border_mm.set_instance_transform_2d(square_instance, border_transform)
			square_border_mm.set_instance_color(square_instance, color_border)
			square_instance += 1
		else:
			# Update octagon MultiMesh
			octagon_mm.set_instance_transform_2d(octagon_instance, transform)
			octagon_mm.set_instance_color(octagon_instance, color)
			octagon_border_mm.set_instance_transform_2d(octagon_instance, border_transform)
			octagon_border_mm.set_instance_color(octagon_instance, color_border)
			octagon_instance += 1

		# Update number label
		if number_labels.size() > 0:
			_update_number_label(cell_id)

## Get the color for a cell based on its state
func _get_cell_color(cell_id: int) -> Color:
	var state = grid_data.get_state(cell_id)

	match state:
		GridData.CellState.HIDDEN:
			# Foggy/cloudy - can't see what's below
			return color_hidden

		GridData.CellState.REVEALED:
			if grid_data.is_mine(cell_id):
				# Revealed mine = deep dark water
				return color_deep_water
			else:
				var danger = grid_data.get_danger_count(cell_id)

				if danger == 0:
					# Safe cell with no nearby mines - island!
					# Check if ANY neighbor has >0 danger (beach vs vegetation)
					var has_water_neighbor = false
					for neighbor_id in grid_data.get_neighbors(cell_id):
						if grid_data.is_revealed(neighbor_id) and grid_data.get_danger_count(neighbor_id) > 0:
							has_water_neighbor = true
							break

					# Beach (sandy edge) if next to water, vegetation (green) if interior
					return color_beach if has_water_neighbor else color_vegetation
				else:
					# Has mines nearby = water
					return color_water

		GridData.CellState.FLAGGED:
			# Darker water with flag marker
			return color_flagged

		GridData.CellState.QUESTION:
			# Not used in island metaphor
			return color_flagged

		_:
			return color_hidden

## Mark a cell for visual update
func mark_cell_dirty(cell_id: int) -> void:
	if cell_id >= 0 and cell_id < grid_data.cell_count:
		if not dirty_cells.has(cell_id):
			dirty_cells.append(cell_id)

## Mark multiple cells for visual update
func mark_cells_dirty(cell_ids: PackedInt32Array) -> void:
	for cell_id in cell_ids:
		mark_cell_dirty(cell_id)

## Update visuals for all dirty cells
func update_dirty_cells() -> void:
	if dirty_cells.is_empty():
		return

	if not cell_multimesh or not cell_multimesh.multimesh:
		return

	var multimesh = cell_multimesh.multimesh
	var border_mm = border_multimesh.multimesh if border_multimesh else null

	# Store dirty cells before clearing for ghost update
	var cells_to_update = dirty_cells.duplicate()

	# Update cell colors and labels
	for cell_id in dirty_cells:
		var color = _get_cell_color(cell_id)
		multimesh.set_instance_color(cell_id, color)
		_update_number_label(cell_id)

	# Update infinite tiles with same cells
	_update_tiles(cells_to_update)

	dirty_cells.clear()

## Update number label for a cell
func _update_number_label(cell_id: int) -> void:
	if cell_id < 0 or cell_id >= number_labels.size():
		return

	var label = number_labels[cell_id]
	var state = grid_data.get_state(cell_id)

	# Show flag icon on flagged cells
	if state == GridData.CellState.FLAGGED:
		label.text = "⚑"  # Flag symbol
		label.add_theme_color_override("font_color", Color.RED)
		label.visible = true
		return

	# Show mine icon on revealed mines
	if state == GridData.CellState.REVEALED and grid_data.is_mine(cell_id):
		label.text = "💣"  # Mine symbol
		label.add_theme_color_override("font_color", Color.WHITE)
		label.visible = true
		return

	# Only show numbers on revealed water cells (danger > 0)
	if state == GridData.CellState.REVEALED and not grid_data.is_mine(cell_id):
		var danger = grid_data.get_danger_count(cell_id)
		if danger > 0:
			# Water cell - show number
			label.text = str(danger)
			label.add_theme_color_override("font_color", danger_colors[danger])
			label.visible = true
			return

	# Hide label for all other cases
	label.visible = false

## Force refresh all cell visuals
func refresh_all() -> void:
	_update_all_cells()

## Show all mines and flag accuracy (called on game over)
func reveal_all_mines() -> void:
	var cells_to_update = PackedInt32Array()

	for cell_id in range(grid_data.cell_count):
		var is_mine = grid_data.is_mine(cell_id)
		var is_flagged = grid_data.is_flagged(cell_id)

		# Reveal all unflagged mines
		if is_mine and not is_flagged:
			grid_data.reveal_cell(cell_id)
			cells_to_update.append(cell_id)

	# Update visuals for revealed mines
	mark_cells_dirty(cells_to_update)
	update_dirty_cells()

## Update labels to show flag accuracy (called on game over)
func show_flag_accuracy() -> void:
	var updated_cells = PackedInt32Array()

	for cell_id in range(grid_data.cell_count):
		if grid_data.is_flagged(cell_id):
			var label = number_labels[cell_id]
			var is_mine = grid_data.is_mine(cell_id)

			if is_mine:
				# Correct flag - green checkmark
				label.text = "✓"
				label.add_theme_color_override("font_color", Color.GREEN)
			else:
				# Wrong flag - red X
				label.text = "✗"
				label.add_theme_color_override("font_color", Color.RED)

			label.visible = true
			updated_cells.append(cell_id)

	# Update tiles to show check/X marks
	_update_tiles(updated_cells)

## Update color theme at runtime
func set_color_theme(
	hidden: Color,
	beach: Color,
	vegetation: Color,
	water: Color,
	flagged: Color
) -> void:
	color_hidden = hidden
	color_beach = beach
	color_vegetation = vegetation
	color_water = water
	color_flagged = flagged

	# Refresh all cells with new colors
	refresh_all()

## Get the cell at a world position (for input handling)
func get_cell_at_position(world_pos: Vector2) -> int:
	if grid_generator:
		return grid_generator.get_cell_at_position(world_pos, grid_data)
	return -1

## Create infinite tiling (viewport-based dynamic tiling)
func _create_infinite_tiles() -> void:
	# Get camera reference
	camera = get_viewport().get_camera_2d()
	if not camera:
		print("Warning: No camera found for infinite tiling")
		return

	# Calculate grid dimensions in pixels
	grid_pixel_width = grid_data.grid_size.x * cell_size
	grid_pixel_height = grid_data.grid_size.y * cell_size

	# For hex grids, use actual width/height
	if grid_data.grid_type == GridType.Type.HEXAGON:
		var hex_width_ratio = 0.866025404  # sqrt(3) / 2
		grid_pixel_width = grid_data.grid_size.x * cell_size * hex_width_ratio
		grid_pixel_height = grid_data.grid_size.y * cell_size * 0.75

	# For triangle grids, use actual spacing (half-width horizontally, full height vertically)
	# Triangle mesh has height of 2 units (from -1 to +1), scaled by cell_size/2
	# So actual rendered height is cell_size
	# Horizontal spacing is reduced by half for tighter packing
	if grid_data.grid_type == GridType.Type.TRIANGLE:
		grid_pixel_width = grid_data.grid_size.x * cell_size * 0.5
		grid_pixel_height = grid_data.grid_size.y * cell_size

	# Don't create tiles yet - they'll be created on-demand in _process
	print("Infinite tiling system initialized (viewport-based)")

## Process function to update tile positions based on viewport
func _process(_delta):
	if not camera:
		return

	if not grid_data.wrap_horizontal and not grid_data.wrap_vertical:
		return  # No wrapping, no need for infinite tiling

	_update_viewport_tiles()

## Update tiles based on what's visible in viewport (+ 10% buffer)
func _update_viewport_tiles() -> void:
	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom.x

	# Calculate visible area in world space with 10% buffer
	var buffer_multiplier = 1.1
	var visible_width = (viewport_size.x / zoom) * buffer_multiplier
	var visible_height = (viewport_size.y / zoom) * buffer_multiplier

	# Calculate which grid tiles are needed to cover viewport
	var camera_pos = camera.position
	var min_x = floor((camera_pos.x - visible_width / 2) / grid_pixel_width)
	var max_x = ceil((camera_pos.x + visible_width / 2) / grid_pixel_width)
	var min_y = floor((camera_pos.y - visible_height / 2) / grid_pixel_height)
	var max_y = ceil((camera_pos.y + visible_height / 2) / grid_pixel_height)

	# Build set of required grid offsets (excluding 0,0 which is the main grid)
	var required_offsets = {}
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var offset = Vector2i(x, y)
			# Skip (0,0) since that's where the main grid is
			if offset != Vector2i(0, 0):
				required_offsets[offset] = true

	# Remove tiles that are no longer needed
	var tiles_to_remove = []
	for i in range(tile_instances.size()):
		var tile = tile_instances[i]
		if not required_offsets.has(tile["grid_offset"]):
			tiles_to_remove.append(i)

	# Remove from back to front to preserve indices
	tiles_to_remove.reverse()
	for i in tiles_to_remove:
		var tile = tile_instances[i]
		tile["cells"].queue_free()
		tile["borders"].queue_free()
		tile["labels"].queue_free()
		tile_instances.remove_at(i)

	# Create tiles that are needed but don't exist
	var existing_offsets = {}
	for tile in tile_instances:
		existing_offsets[tile["grid_offset"]] = true

	for offset in required_offsets.keys():
		if not existing_offsets.has(offset):
			_create_tile_at_grid_offset(offset)

## Update tile's transform to new offset
func _update_tile_transform(tile: Dictionary, pixel_offset: Vector2) -> void:
	var cell_mm = tile["cells"].multimesh
	var border_mm = tile["borders"].multimesh
	var label_container = tile["labels"]

	# Update all cell positions in this tile
	for cell_id in range(grid_data.cell_count):
		var base_pos = grid_data.cell_positions[cell_id]  # Use cached position
		var tile_pos = base_pos + pixel_offset

		var transform = Transform2D()
		transform.origin = tile_pos
		cell_mm.set_instance_transform_2d(cell_id, transform)
		border_mm.set_instance_transform_2d(cell_id, transform)

	# Update label container position
	label_container.position = pixel_offset

## Create a single tile instance at the given grid offset
func _create_tile_at_grid_offset(grid_offset: Vector2i) -> void:
	var pixel_offset = Vector2(
		grid_offset.x * grid_pixel_width,
		grid_offset.y * grid_pixel_height
	)

	# Create cell MultiMesh
	var tile_cell_mm = MultiMeshInstance2D.new()
	tile_cell_mm.z_index = 0
	add_child(tile_cell_mm)

	var cell_multimesh_instance = MultiMesh.new()
	cell_multimesh_instance.mesh = cell_mesh
	cell_multimesh_instance.transform_format = MultiMesh.TRANSFORM_2D
	cell_multimesh_instance.use_colors = true
	cell_multimesh_instance.instance_count = grid_data.cell_count
	tile_cell_mm.multimesh = cell_multimesh_instance

	# Create border MultiMesh
	var tile_border_mm = MultiMeshInstance2D.new()
	tile_border_mm.z_index = 1  # In front of cells to show wireframe outlines
	add_child(tile_border_mm)

	var border_multimesh_instance = MultiMesh.new()
	border_multimesh_instance.mesh = border_mesh
	border_multimesh_instance.transform_format = MultiMesh.TRANSFORM_2D
	border_multimesh_instance.use_colors = true
	border_multimesh_instance.instance_count = grid_data.cell_count
	tile_border_mm.multimesh = border_multimesh_instance

	# Create labels container
	var tile_labels = Node2D.new()
	tile_labels.z_index = 1
	tile_labels.position = pixel_offset
	add_child(tile_labels)

	# Populate all cells in this tile
	for cell_id in range(grid_data.cell_count):
		var pixel_pos = grid_data.cell_positions[cell_id]  # Use cached position
		var tile_pos = pixel_pos + pixel_offset

		# Set cell transform and color using cached rotation
		var transform = Transform2D()

		# Flip vertically if needed (using cached rotation flag)
		# Apply scale BEFORE translation to avoid positioning issues
		if grid_data.cell_rotations[cell_id] == 1 and grid_data.grid_type != GridType.Type.OCTASQUARE:
			transform = transform.scaled(Vector2(1, -1))  # Vertical flip (triangles only)

		transform.origin = tile_pos

		cell_multimesh_instance.set_instance_transform_2d(cell_id, transform)
		cell_multimesh_instance.set_instance_color(cell_id, _get_cell_color(cell_id))

		# Set border transform and color
		border_multimesh_instance.set_instance_transform_2d(cell_id, transform)
		border_multimesh_instance.set_instance_color(cell_id, color_border)

		# Create tile label (mirroring main label)
		var main_label = number_labels[cell_id]
		var tile_label = Label.new()

		# Calculate label position
		var label_pos = pixel_pos - Vector2(cell_size / 2, cell_size / 2)

		# Apply centroid adjustment for triangles
		if grid_data.grid_type == GridType.Type.TRIANGLE:
			var y_offset = cell_size * 0.17  # Visual adjustment for triangle centroid
			if grid_data.cell_rotations[cell_id] == 0:
				# Up-pointing: shift label DOWN (centroid is too high visually)
				label_pos.y += y_offset
			else:
				# Down-pointing: shift label UP (centroid is too low visually)
				label_pos.y -= y_offset

		tile_label.position = label_pos
		tile_label.size = Vector2(cell_size, cell_size)
		tile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile_label.add_theme_font_size_override("font_size", int(cell_size * 0.6))
		tile_label.text = main_label.text
		tile_label.visible = main_label.visible
		if main_label.has_theme_color_override("font_color"):
			tile_label.add_theme_color_override("font_color", main_label.get_theme_color("font_color"))
		tile_labels.add_child(tile_label)

	# Store tile reference
	tile_instances.append({
		"cells": tile_cell_mm,
		"borders": tile_border_mm,
		"labels": tile_labels,
		"grid_offset": grid_offset
	})

## Update all tiles when cells change
func _update_tiles(cell_ids: PackedInt32Array) -> void:
	if tile_instances.size() == 0:
		return

	# Update each tile
	for tile in tile_instances:
		var cell_mm = tile["cells"].multimesh
		var label_container = tile["labels"]

		for cell_id in cell_ids:
			# Update color
			cell_mm.set_instance_color(cell_id, _get_cell_color(cell_id))

			# Update label
			var main_label = number_labels[cell_id]
			var tile_label = label_container.get_child(cell_id)
			tile_label.text = main_label.text
			tile_label.visible = main_label.visible
			if main_label.has_theme_color_override("font_color"):
				tile_label.add_theme_color_override("font_color", main_label.get_theme_color("font_color"))

## Create a purple debug border around the primary grid
func _create_debug_grid_border() -> void:
	# Clean up old border if it exists
	if debug_border:
		debug_border.queue_free()
		debug_border = null

	# Calculate grid bounds from cached cell positions
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for cell_id in range(grid_data.cell_count):
		var pos = grid_data.cell_positions[cell_id]
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)

	# Expand bounds by half cell size to encompass full cells
	var margin = cell_size * 0.5

	min_x -= margin
	max_x += margin
	min_y -= margin
	max_y += margin

	# Create a Line2D node for the border
	debug_border = Line2D.new()
	debug_border.z_index = 10  # Render on top of everything
	debug_border.default_color = Color.PURPLE
	debug_border.width = 4.0

	# Add corner points to create a rectangle
	debug_border.add_point(Vector2(min_x, min_y))  # Top-left
	debug_border.add_point(Vector2(max_x, min_y))  # Top-right
	debug_border.add_point(Vector2(max_x, max_y))  # Bottom-right
	debug_border.add_point(Vector2(min_x, max_y))  # Bottom-left
	debug_border.add_point(Vector2(min_x, min_y))  # Close the rectangle

	add_child(debug_border)

	print("Debug grid border created: bounds (%.1f, %.1f) to (%.1f, %.1f)" % [min_x, min_y, max_x, max_y])
