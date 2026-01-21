# Grid Mathematics Reference
## Coordinate Systems & Neighbor Calculations for All Tessellations

This document contains the mathematical foundations for implementing all grid types in the Topology Sweeper project.

---

## 📐 Coordinate System Overview

### Why This Matters
Different tessellations require different coordinate representations. Some fit naturally into `(x, y)` pairs, while others require offset systems, axial coordinates, or even graph-only representations.

### Implementation Strategy
1. **Internal Storage**: Always use abstract Cell IDs (0, 1, 2, ...)
2. **Position Calculation**: Use grid-specific math to convert ID → Pixel Position
3. **Neighbor Finding**: Use grid-specific math to find adjacent cell IDs

---

## 1️⃣ SQUARE GRID (Easiest)

### Coordinate System
Standard Cartesian: `(x, y)`

### Cell ID Mapping
```gdscript
# For a grid of width W, height H
func pos_to_id(pos: Vector2i, width: int) -> int:
    return pos.y * width + pos.x

func id_to_pos(id: int, width: int) -> Vector2i:
    return Vector2i(id % width, id / width)
```

### Pixel Position
```gdscript
const CELL_SIZE = 64  # pixels

func grid_to_pixel(pos: Vector2i) -> Vector2:
    return Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
```

### Neighbor Calculation (8-way, Moore Neighborhood)
```gdscript
const SQUARE_NEIGHBOR_OFFSETS = [
    Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
    Vector2i(-1,  0),                  Vector2i(1,  0),
    Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
]

func get_square_neighbors(pos: Vector2i, map_size: Vector2i, wrapping: bool) -> Array[Vector2i]:
    var neighbors: Array[Vector2i] = []
    
    for offset in SQUARE_NEIGHBOR_OFFSETS:
        var neighbor_pos = pos + offset
        
        if wrapping:
            neighbor_pos = wrap_coordinate(neighbor_pos, map_size)
        elif !is_in_bounds(neighbor_pos, map_size):
            continue
            
        neighbors.append(neighbor_pos)
    
    return neighbors

func wrap_coordinate(pos: Vector2i, map_size: Vector2i) -> Vector2i:
    var x = pos.x % map_size.x
    var y = pos.y % map_size.y
    if x < 0: x += map_size.x
    if y < 0: y += map_size.y
    return Vector2i(x, y)
```

### Wrapping Notes
- Simple modulo math
- Works perfectly for torus topology
- No special cases needed

---

## 2️⃣ HEXAGON GRID (Intermediate)

### Coordinate Systems (Choose One)

#### Option A: Offset Coordinates (Recommended for Beginners)
- Even rows start at x=0
- Odd rows offset by +0.5
- Easier to visualize, harder to calculate neighbors

#### Option B: Axial Coordinates (Recommended for This Project)
- Uses `(q, r)` instead of `(x, y)`
- q = column, r = row (diagonal)
- Cleaner neighbor math

We'll use **Axial Coordinates** below.

### Axial Coordinate System
```gdscript
# Axial: (q, r) where q+r+s=0 (implicit s coordinate)
# This is also called "cube coordinates" with s = -q - r

class HexAxial:
    var q: int  # Column
    var r: int  # Row
    
    func _init(q_val: int, r_val: int):
        q = q_val
        r = r_val
    
    func get_s() -> int:
        return -q - r
```

### Pixel Position (Flat-Top Hexagons)
```gdscript
const HEX_SIZE = 32.0  # Radius of hexagon

func hex_to_pixel(hex: HexAxial) -> Vector2:
    var x = HEX_SIZE * (3.0/2.0 * hex.q)
    var y = HEX_SIZE * (sqrt(3.0)/2.0 * hex.q + sqrt(3.0) * hex.r)
    return Vector2(x, y)
```

### Pixel Position (Pointy-Top Hexagons)
```gdscript
func hex_to_pixel_pointy(hex: HexAxial) -> Vector2:
    var x = HEX_SIZE * (sqrt(3.0) * hex.q + sqrt(3.0)/2.0 * hex.r)
    var y = HEX_SIZE * (3.0/2.0 * hex.r)
    return Vector2(x, y)
```

### Neighbor Calculation (6-way)
```gdscript
const HEX_NEIGHBOR_DIRECTIONS = [
    Vector2i(+1,  0), Vector2i(+1, -1), Vector2i( 0, -1),
    Vector2i(-1,  0), Vector2i(-1, +1), Vector2i( 0, +1),
]

func get_hex_neighbors(hex: HexAxial, wrapping: bool) -> Array[HexAxial]:
    var neighbors: Array[HexAxial] = []
    
    for dir in HEX_NEIGHBOR_DIRECTIONS:
        var neighbor = HexAxial.new(hex.q + dir.x, hex.r + dir.y)
        
        if wrapping:
            neighbor = wrap_hex_coordinate(neighbor)
        elif !is_hex_in_bounds(neighbor):
            continue
            
        neighbors.append(neighbor)
    
    return neighbors
```

### Wrapping (CRITICAL: Requires Even Width)
```gdscript
# WARNING: Hex wrapping only works cleanly if map width is EVEN
func wrap_hex_coordinate(hex: HexAxial, map_width: int, map_height: int) -> HexAxial:
    # This is complex - refer to Red Blob Games for full implementation
    # Basic principle: convert to offset, wrap, convert back
    
    # Simplified (assumes rectangular hex map in offset coordinates)
    var offset_x = hex.q
    var offset_y = hex.r + (hex.q - (hex.q & 1)) / 2  # Convert axial to offset
    
    offset_x = offset_x % map_width
    offset_y = offset_y % map_height
    
    if offset_x < 0: offset_x += map_width
    if offset_y < 0: offset_y += map_height
    
    # Convert back to axial
    var q = offset_x
    var r = offset_y - (offset_x - (offset_x & 1)) / 2
    
    return HexAxial.new(q, r)
```

### Critical Wrapping Rule
**Force map width to be EVEN in hex mode** to avoid zigzag seams:
```gdscript
func validate_hex_map_size(size: Vector2i) -> Vector2i:
    if size.x % 2 != 0:
        size.x += 1
        push_warning("Hex map width forced to even number: %d" % size.x)
    return size
```

---

## 3️⃣ TRIANGULAR GRID

### Coordinate System
Two types of triangles: Upright (△) and Inverted (▽)

Use `(x, y, orientation)` where orientation is 0 or 1.

Alternatively, treat as "dual of hex grid" — each hex becomes 6 triangles.

### Pixel Position (Equilateral Triangles)
```gdscript
const TRI_SIZE = 32.0  # Side length

func triangle_to_pixel(x: int, y: int, upright: bool) -> Vector2:
    var base_x = x * TRI_SIZE * 0.5
    var base_y = y * TRI_SIZE * sqrt(3.0) / 2.0
    
    if !upright:
        base_y += TRI_SIZE * sqrt(3.0) / 6.0  # Offset inverted triangles
    
    return Vector2(base_x, base_y)
```

### Neighbor Calculation
- **Upright Triangle**: 3 neighbors (all inverted)
- **Inverted Triangle**: 3 neighbors (all upright)

```gdscript
func get_triangle_neighbors(x: int, y: int, upright: bool) -> Array:
    var neighbors = []
    
    if upright:
        # Upright △ touches 3 inverted ▽
        neighbors.append([x,   y,   false])  # Below
        neighbors.append([x-1, y,   false])  # Bottom-left
        neighbors.append([x,   y-1, false])  # Bottom-right
    else:
        # Inverted ▽ touches 3 upright △
        neighbors.append([x,   y,   true])   # Above
        neighbors.append([x+1, y,   true])   # Top-right
        neighbors.append([x,   y+1, true])   # Top-left
    
    return neighbors
```

### Wrapping Notes
- Straightforward with modulo on x and y
- Orientation stays the same during wrapping

---

## 4️⃣ CAIRO PENTAGONAL GRID

### The Trick: Dual Hex Overlay
Cairo pentagons can be generated by overlaying two offset hexagonal grids.

**Do not implement pentagons directly.** Instead:
1. Generate two hex grids (offset from each other)
2. The intersection points form the centers of pentagons
3. Each pentagon's position = pair of (hex_A_id, hex_B_id)

### Conceptual Implementation
```gdscript
# Pseudo-code (not complete implementation)
class CairoPentagon:
    var hex_a: HexAxial
    var hex_b: HexAxial
    
    func get_pixel_position() -> Vector2:
        var pos_a = hex_to_pixel(hex_a)
        var pos_b = hex_to_pixel_offset(hex_b)
        return (pos_a + pos_b) / 2.0  # Midpoint
```

### Neighbor Calculation
Each pentagon touches exactly 5 other pentagons (uniform).
Calculate by finding which hex pairs are adjacent.

**Recommendation**: Use the graph approach here. Pre-calculate all neighbor relationships during grid generation.

---

## 5️⃣ RHOMBILLE GRID (Diamond/Rhombus Grid)

### Coordinate System
Rhombille is the **dual of triangular** or can be seen as **split hexagons**.

Each hex can be split into 3 rhombi with 60° angles.

Use `(hex_x, hex_y, rhombus_index)` where `rhombus_index` is 0, 1, or 2.

### Pixel Position
```gdscript
func rhombus_to_pixel(hex_pos: HexAxial, rhombus_index: int) -> Vector2:
    var hex_center = hex_to_pixel(hex_pos)
    
    # Offsets for the 3 rhombi within a hex
    const OFFSETS = [
        Vector2(0, -10),     # Top rhombus
        Vector2(-8.66, 5),   # Bottom-left
        Vector2(8.66, 5),    # Bottom-right
    ]
    
    return hex_center + OFFSETS[rhombus_index]
```

### Neighbor Calculation
- Each rhombus has 4 edge neighbors (other rhombi)
- Optionally 2 vertex neighbors

**Fairness Issue**: Need to define if vertex-touching counts as neighbors (affects mine counts).

### Visual Rendering Note
Rhombille creates the "Q*bert cube" optical illusion. Consider rendering with shading to enhance this 3D effect in the "Crystalline Reef" biome.

---

## 6️⃣ OCTASQUARE GRID (4.8.8 Semi-Regular Tessellation)

### Shape Distribution
Pattern repeats: **1 Square + 2 Octagons** (hence "octa-quad")

### Coordinate Challenge
**Cannot use simple (x, y)** because shapes are not uniform.

**Solution**: Use a **Superposition Grid**
- Treat each "Square + 2 Octagons" as a single mega-tile
- Give the mega-tile coordinates (x, y)
- Each mega-tile contains 3 sub-cells (IDs: 0=square, 1=octagon_a, 2=octagon_b)

### Pixel Position
```gdscript
const OCTA_SIZE = 40.0  # Octagon side length
const SQUARE_SIZE = OCTA_SIZE * (1 + sqrt(2))  # Derived size

func octasquare_to_pixel(mega_x: int, mega_y: int, sub_id: int) -> Vector2:
    var base = Vector2(mega_x * SQUARE_SIZE, mega_y * SQUARE_SIZE)
    
    match sub_id:
        0:  # Square (center)
            return base + Vector2(OCTA_SIZE, OCTA_SIZE)
        1:  # Octagon (left)
            return base + Vector2(0, OCTA_SIZE)
        2:  # Octagon (right)
            return base + Vector2(OCTA_SIZE * 2, OCTA_SIZE)
    
    return base
```

### Neighbor Calculation
**Highly irregular:**
- Squares touch 4 octagons
- Octagons touch 1 square + 2 other octagons

**Must use graph/pre-calculation approach.**

### Fairness Visualization Required
A "3" on an octagon touching 3 neighbors = 100% danger.  
Display this visually (color-coded or ratio display).

---

## 7️⃣ SNUB SQUARE GRID (3.3.4.3.4 Tessellation)

### Shape Distribution
Alternating **Squares** and **Triangles** in a specific "twisted" pattern.

### Coordinate System
Similar to Octasquare: use a **base grid + sub-cell index**.

### Neighbor Calculation
- Triangles: 3-4 neighbors
- Squares: 5 neighbors typically

**Extreme fairness issue**: Must display danger ratio, not just raw count.

---

## 8️⃣ PENROSE TILING (Aperiodic)

### Mathematical Properties
- **Non-Periodic**: Never repeats exactly
- **Quasicrystalline**: Has 5-fold rotational symmetry
- **Infinite**: Can tile the plane infinitely
- **Cannot Wrap on Torus**: Fundamentally incompatible with toroidal topology

### Two Tile Types
- **Kite**: 4-sided, dart-shaped
- **Dart**: 4-sided, opposite of kite

### Generation Algorithm
Use **Inflation/Deflation** method:
1. Start with a few large tiles
2. Subdivide each tile into smaller tiles following specific rules
3. Repeat until desired resolution

### Neighbor Calculation
**Pure graph approach required.** Cannot use coordinates.

1. Generate tiles as polygon objects
2. For each tile, check edge-sharing or vertex-sharing with other tiles
3. Store result in adjacency list

```gdscript
# Pseudo-code
func calculate_penrose_neighbors(tiles: Array[PenroseTile]) -> Array[PackedInt32Array]:
    var neighbor_lists: Array[PackedInt32Array] = []
    
    for i in range(tiles.size()):
        var neighbors = PackedInt32Array()
        
        for j in range(tiles.size()):
            if i == j:
                continue
            
            if tiles[i].shares_edge_with(tiles[j]):
                neighbors.append(j)
        
        neighbor_lists.append(neighbors)
    
    return neighbor_lists
```

### Wrapping Strategy
**DO NOT ATTEMPT TO WRAP.**

Instead:
1. **Large Bounded Area**: Generate a huge patch (e.g., 10,000 tiles)
2. **Void Boundary**: Tiles at the edge simply end—visualize as "world fracture"
3. **Thematic Integration**: This is "The Continental Shelf" where geometry breaks down

---

## 🔄 Wrapping Logic (General)

### Torus Wrapping Formula (Generic)
```gdscript
func wrap_position(pos: Vector2i, map_size: Vector2i) -> Vector2i:
    var wrapped = Vector2i(
        pos.x % map_size.x,
        pos.y % map_size.y
    )
    
    # Fix negative modulo (GDScript can return negative)
    if wrapped.x < 0: wrapped.x += map_size.x
    if wrapped.y < 0: wrapped.y += map_size.y
    
    return wrapped
```

### Wrapping Rules by Grid Type
| Grid Type | Wrapping Support | Special Requirements |
|-----------|------------------|---------------------|
| Square | ✅ Full | None |
| Hexagon | ✅ Full | Map width must be EVEN |
| Triangle | ✅ Full | None |
| Cairo | ✅ Full | Requires careful neighbor pre-calc |
| Rhombille | ✅ Full | Requires hex-based wrapping |
| Octasquare | ⚠️ Complex | Mega-tile boundaries need special handling |
| Snub Square | ⚠️ Complex | Rotational alignment issues at seams |
| Penrose | ❌ Impossible | Non-periodic—cannot repeat |

---

## 🎯 Implementation Priority

### Phase 1: Simple Grids (Do First)
1. **Square**: Use as testing ground for entire engine
2. **Hexagon**: Validate the "non-trivial but clean" coordinate systems work

### Phase 2: Graph-Heavy Grids (Do Second)
3. **Cairo**: Test dual-grid approach
4. **Rhombille**: Test split-hex approach
5. **Triangle**: Validate alternating-type neighbor logic

### Phase 3: Complex Grids (Do Last)
6. **Octasquare**: Test mega-tile abstraction
7. **Snub Square**: Test extreme neighbor variance
8. **Penrose**: The final boss—pure graph, no coordinates

---

## 📚 References & Further Reading

### Essential Resources
- **Red Blob Games - Hexagonal Grids**: https://www.redblobgames.com/grids/hexagons/
  (The definitive guide for hex coordinate systems)

- **Wikipedia - Tessellation**: https://en.wikipedia.org/wiki/Tessellation
  (Mathematical background)

- **Penrose Tiling on Wikipedia**: https://en.wikipedia.org/wiki/Penrose_tiling
  (Inflation/deflation rules)

- **Euclidean Tilings by Convex Regular Polygons**: 
  https://en.wikipedia.org/wiki/Euclidean_tilings_by_convex_regular_polygons
  (Formal classification of the grids we're using)

### Code References
- Amit's Hex Grid Code (Red Blob Games): Provides reference implementations in multiple languages
- Three.js Penrose Tiling Examples: Visual references for generation algorithms

---

## 🔍 Debugging Tips

### Visualizing Coordinate Systems
Create a debug overlay that shows:
- Cell IDs as text
- Neighbor connections as lines
- Grid boundaries

### Validation Tests
For each grid type, create a validation function:
```gdscript
func validate_grid_neighbors(grid: GridData) -> bool:
    for cell_id in range(grid.cell_count):
        var neighbors = grid.get_neighbors(cell_id)
        
        # Check reciprocal neighbors
        for neighbor_id in neighbors:
            var reverse_neighbors = grid.get_neighbors(neighbor_id)
            if not reverse_neighbors.has(cell_id):
                push_error("Non-reciprocal neighbor: %d -> %d" % [cell_id, neighbor_id])
                return false
    
    return true
```

### Common Bugs
1. **Negative Modulo**: GDScript's `%` can return negative—always add the modulo back
2. **Off-by-One**: Check array bounds carefully (0-indexed vs. 1-indexed confusion)
3. **Floating Point**: Use integer coordinates until final pixel conversion
4. **Hex Odd Width**: Always validate even width in hex mode

---

## ⚡ Performance Notes

### Pre-Calculate Everything Possible
Don't calculate neighbors on-the-fly during gameplay:

```gdscript
# SLOW (recalculates every time)
func get_neighbors_slow(cell_id: int) -> Array:
    var pos = id_to_pos(cell_id)
    # ... complex math ...
    return neighbors

# FAST (pre-calculated once)
var neighbor_cache: Array[PackedInt32Array] = []

func get_neighbors_fast(cell_id: int) -> PackedInt32Array:
    return neighbor_cache[cell_id]
```

### Memory vs. Speed Trade-Off
For 10,000 cells:
- Storing 8 neighbors per cell = 80,000 integers = 320KB
- This is trivial on modern devices
- **Always pre-calculate and cache**

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Status**: Reference Material for Godot Port
