## InfiniteGridWrapper.gd
##
## Provides seamless infinite grid illusion using camera position wrapping.
## This approach uses ZERO extra memory compared to ghost tile systems.
##
## How it works:
## - When camera pans beyond grid boundary, seamlessly wrap it to opposite edge
## - Uses modulo math to keep camera within grid bounds while feeling infinite
## - Works at any zoom level without creating duplicate geometry
##
## For zoomed-out views where multiple copies would be visible:
## - Uses VisualServer to create shader-based repetition (future enhancement)
## - OR uses a small (3x3) tile system only when zoomed out enough

class_name InfiniteGridWrapper
extends Node2D

## References
var camera: Camera2D
var grid_data: GridData
var grid_pixel_width: float
var grid_pixel_height: float

## Configuration
var wrap_horizontal: bool = true
var wrap_vertical: bool = true
var enable_wrapping: bool = true

## Teleport threshold (how far from edge before wrapping)
## Set to half grid size to wrap at edges
var wrap_margin: float = 0.0

func _ready():
	set_process(true)

## Setup with camera and grid references
func setup(cam: Camera2D, grid: GridData, pixel_width: float, pixel_height: float) -> void:
	camera = cam
	grid_data = grid
	grid_pixel_width = pixel_width
	grid_pixel_height = pixel_height
	wrap_horizontal = grid.wrap_horizontal
	wrap_vertical = grid.wrap_vertical

	# Only enable if at least one axis wraps
	enable_wrapping = wrap_horizontal or wrap_vertical

	print("InfiniteGridWrapper initialized:")
	print("  Grid size: %.1f x %.1f pixels" % [grid_pixel_width, grid_pixel_height])
	print("  Wrapping: H=%s V=%s" % [wrap_horizontal, wrap_vertical])

func _process(_delta):
	if not enable_wrapping or not camera:
		return

	_update_camera_wrapping()

## Wrap camera position to create infinite illusion
func _update_camera_wrapping() -> void:
	var cam_pos = camera.position
	var wrapped = false

	# Wrap horizontal (modulo to keep within 0 to grid_pixel_width)
	if wrap_horizontal:
		# Use modulo to wrap seamlessly
		while cam_pos.x > grid_pixel_width:
			cam_pos.x -= grid_pixel_width
			wrapped = true
		while cam_pos.x < 0:
			cam_pos.x += grid_pixel_width
			wrapped = true

	# Wrap vertical (modulo to keep within 0 to grid_pixel_height)
	if wrap_vertical:
		# Use modulo to wrap seamlessly
		while cam_pos.y > grid_pixel_height:
			cam_pos.y -= grid_pixel_height
			wrapped = true
		while cam_pos.y < 0:
			cam_pos.y += grid_pixel_height
			wrapped = true

	if wrapped:
		camera.position = cam_pos

## Check if camera is zoomed out enough to see multiple grid copies
func is_multi_grid_visible() -> bool:
	if not camera:
		return false

	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom.x

	var visible_width = viewport_size.x / zoom
	var visible_height = viewport_size.y / zoom

	# If viewport is larger than grid, multiple copies are visible
	var horizontal_overflow = visible_width > grid_pixel_width * 0.9
	var vertical_overflow = visible_height > grid_pixel_height * 0.9

	return horizontal_overflow or vertical_overflow

## Get camera bounds in world space
func get_camera_bounds() -> Rect2:
	if not camera:
		return Rect2()

	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom.x

	var visible_width = viewport_size.x / zoom
	var visible_height = viewport_size.y / zoom

	return Rect2(
		camera.position.x - visible_width / 2,
		camera.position.y - visible_height / 2,
		visible_width,
		visible_height
	)
