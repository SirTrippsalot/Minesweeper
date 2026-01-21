## GridType.gd
## Defines all supported grid tessellations
##
## Each grid type has different neighbor counts and wrapping behavior.
## Use this enum throughout the codebase for type-safe grid identification.

class_name GridType

## All supported tessellation types
enum Type {
	SQUARE,      ## Regular square grid (4 or 8 neighbors)
	HEXAGON,     ## Hexagonal honeycomb (6 neighbors)
	TRIANGLE,    ## Triangular grid (3 or 12 neighbors)
	CAIRO,       ## Cairo pentagonal tiling (5 neighbors)
	RHOMBILLE,   ## Rhombic tiling (4-6 neighbors)
	SNUB_SQUARE, ## Snub square (3.3.4.3.4) tiling
	OCTASQUARE,  ## Truncated square (4.8.8) tiling
	PENROSE      ## Aperiodic Penrose tiling (cannot wrap)
}

## Human-readable names for UI display
static func get_name(type: Type) -> String:
	match type:
		Type.SQUARE: return "Square"
		Type.HEXAGON: return "Hexagon"
		Type.TRIANGLE: return "Triangle"
		Type.CAIRO: return "Cairo"
		Type.RHOMBILLE: return "Rhombille"
		Type.SNUB_SQUARE: return "Snub Square"
		Type.OCTASQUARE: return "Octasquare"
		Type.PENROSE: return "Penrose"
		_: return "Unknown"

## Check if grid type supports toroidal wrapping
static func supports_wrapping(type: Type) -> bool:
	# Penrose is aperiodic and cannot wrap on a torus
	return type != Type.PENROSE

## Get typical neighbor count for a grid type
## Note: Some grids have variable neighbor counts per cell
static func get_typical_neighbor_count(type: Type, use_vertex_neighbors: bool = false) -> int:
	match type:
		Type.SQUARE:
			return 8 if use_vertex_neighbors else 4
		Type.HEXAGON:
			return 6  # Hex has no vertex-only neighbors (vertices = edges)
		Type.TRIANGLE:
			return 12 if use_vertex_neighbors else 3
		Type.CAIRO:
			return 5
		Type.RHOMBILLE:
			return 6 if use_vertex_neighbors else 4
		Type.SNUB_SQUARE:
			return -1  # Variable (3-5 depending on cell shape)
		Type.OCTASQUARE:
			return -1  # Variable (3-8 depending on cell shape)
		Type.PENROSE:
			return -1  # Variable (typically 5-7)
		_:
			return 0

## Get biome name for visual theming
static func get_biome_name(type: Type) -> String:
	match type:
		Type.SQUARE, Type.HEXAGON:
			return "Open Sea"
		Type.TRIANGLE, Type.CAIRO, Type.RHOMBILLE:
			return "Sunken Ruins"
		Type.SNUB_SQUARE, Type.OCTASQUARE, Type.PENROSE:
			return "Continental Shelf"
		_:
			return "Unknown Waters"
