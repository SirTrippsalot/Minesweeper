## MinimalTileSystem.gd
##
## Lightweight 3x3 tile system ONLY for zoomed-out views.
## Uses ViewportTexture rendering to avoid duplicating geometry.
##
## This system only activates when zoom level shows multiple grid copies.
## At normal zoom (where only one grid is visible), this does nothing.

class_name MinimalTileSystem
extends Node2D

## References
var camera: Camera2D
var main_grid_renderer: Node2D  # The GridRenderer node
var grid_pixel_width: float
var grid_pixel_height: float

## Tile system state
var tiles_active: bool = false
var tile_sprites: Array[Sprite2D] = []

## Viewport for texture capture
var grid_viewport: SubViewport
var grid_texture: ViewportTexture

func _ready():
	set_process(true)

## Setup with camera and grid renderer
func setup(cam: Camera2D, renderer: Node2D, pixel_width: float, pixel_height: float) -> void:
	camera = cam
	main_grid_renderer = renderer
	grid_pixel_width = pixel_width
	grid_pixel_height = pixel_height

	print("MinimalTileSystem initialized")
	print("  Tiles will activate when zoomed out enough to see multiple grids")

func _process(_delta):
	if not camera:
		return

	_update_tile_visibility()

## Check if we need tiles and enable/disable accordingly
func _update_tile_visibility() -> void:
	var should_show_tiles = _should_use_tiles()

	if should_show_tiles and not tiles_active:
		_activate_tiles()
	elif not should_show_tiles and tiles_active:
		_deactivate_tiles()

## Check if camera is zoomed out enough to need tiles
func _should_use_tiles() -> bool:
	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom.x

	var visible_width = viewport_size.x / zoom
	var visible_height = viewport_size.y / zoom

	# Use tiles if viewport shows more than 80% of grid size in either direction
	# This means we're zoomed out enough to potentially see edges
	return visible_width > grid_pixel_width * 0.8 or visible_height > grid_pixel_height * 0.8

## Activate the 3x3 tile system using viewport texture
func _activate_tiles() -> void:
	print("Activating minimal tile system (zoomed out)")

	# Create SubViewport to capture main grid rendering
	grid_viewport = SubViewport.new()
	grid_viewport.size = Vector2i(int(grid_pixel_width), int(grid_pixel_height))
	grid_viewport.transparent_bg = true
	grid_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(grid_viewport)

	# Reparent main grid to viewport (will restore later)
	# NOTE: This is complex - might be better to just use shader repetition
	# For now, we'll create 8 surrounding tiles using Sprite2D with the viewport texture

	grid_texture = grid_viewport.get_texture()

	# Create 3x3 grid of sprites (excluding center which is the real grid)
	var offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	for offset in offsets:
		var sprite = Sprite2D.new()
		sprite.texture = grid_texture
		sprite.centered = false
		sprite.position = Vector2(
			offset.x * grid_pixel_width,
			offset.y * grid_pixel_height
		)
		add_child(sprite)
		tile_sprites.append(sprite)

	tiles_active = true

## Deactivate tiles when zoomed back in
func _deactivate_tiles() -> void:
	print("Deactivating minimal tile system (zoomed in)")

	# Clean up sprites
	for sprite in tile_sprites:
		sprite.queue_free()
	tile_sprites.clear()

	# Clean up viewport
	if grid_viewport:
		grid_viewport.queue_free()
		grid_viewport = null

	tiles_active = false
