# AGENTS Instructions for Topology Sweeper (Godot Port)

## Engine & Language
- **Engine**: Godot 4.x (4.3+)
- **Primary Language**: GDScript
- **Target Platforms**: Android, iOS, PC (Windows/Linux/Mac), Web

---

## Coding Guidelines

### GDScript Style
- Use **snake_case** for variables, functions, and file names
- Use **PascalCase** for class names
- Indent using **tabs** (Godot default)
- Keep line length under **100 characters** when possible
- Use type hints for all variables and function signatures

#### Good Examples
```gdscript
class_name GridData
extends Resource

var cell_count: int = 0
var neighbors: Array[PackedInt32Array]

func get_neighbor_ids(cell_id: int) -> PackedInt32Array:
    return neighbors[cell_id]
```

### File Organization
```
res://
├── scenes/
│   ├── main.tscn
│   └── ui/
├── scripts/
│   ├── core/           # Game logic (graph, data structures)
│   ├── rendering/      # Visual systems (MultiMesh, shaders)
│   └── input/          # Gesture detection, input management
├── resources/
│   └── grid_configs/   # Grid generation parameters
└── assets/
    ├── textures/
    └── shaders/
```

### Resource Management
- Create `.tres` or `.res` files for data that should persist
- Use `@export` for inspector-editable properties
- Prefer `Resource` classes over JSON for complex data
- Use `@tool` for editor scripts that need to run in-editor

### Performance Requirements
- **Target**: 10,000+ cells on mobile devices
- **Memory Budget**: < 100MB for core game data
- **Rendering**: Must use MultiMeshInstance2D (NO individual Sprite2D nodes)
- **Data Storage**: Use PackedArrays (PackedByteArray, PackedInt32Array) for bulk data

---

## Architectural Constraints

### CRITICAL: Graph-Based Logic (Non-Negotiable)

**DO NOT use 2D arrays for game logic** (e.g., `var grid: Array[Array]`)

All cell logic must use the graph/adjacency list approach:

```gdscript
# CORRECT
class_name CellGraph
var cell_is_mine: PackedByteArray
var cell_neighbors: Array[PackedInt32Array]

func get_neighbors(cell_id: int) -> PackedInt32Array:
    return cell_neighbors[cell_id]

# WRONG - Do not use this pattern
var grid: Array[Array] = []
func get_neighbors(x: int, y: int) -> Array:
    # Calculating neighbors from coordinates
```

**Rationale**: Exotic grids (Penrose, Cairo, Snub Square) cannot be represented with x,y coordinates. The graph approach works for ALL tessellations.

### Separation of Concerns

1. **Data Layer** (Pure logic, no visuals)
   - Cell states, mine placement, neighbor relationships
   - Lives in `scripts/core/`
   - No dependencies on Node2D or visual classes

2. **Visual Layer** (Rendering only)
   - MultiMeshInstance2D for tile rendering
   - Shaders for effects
   - Lives in `scripts/rendering/`
   - Listens to signals from Data Layer

3. **Input Layer** (Gesture detection)
   - Control node for touch events
   - Emits signals for game actions
   - Lives in `scripts/input/`
   - No direct cell manipulation

---

## Git & Version Control

### Commit Messages
- Use imperative mood: "Add hexagon grid support" (not "Added" or "Adds")
- Keep headline under 50 characters
- Add body for complex changes (explain WHY, not WHAT)

### Example Commit
```
Add ghost chunk rendering system

Implements the infinite wrapping illusion by rendering edge cells
at offset positions. This avoids the performance cost of rendering
the entire grid multiple times while maintaining visual continuity.
```

### .gitignore Requirements
```
# Godot
.import/
.godot/
export_presets.cfg

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
```

---

## Testing & Validation

### No Automated Tests Required (Initially)
Due to the visual nature of the game and rapid prototyping phase, programmatic tests are not required.

### Manual Validation Checklist
- [ ] Grid renders at correct scale
- [ ] Camera pan/zoom works smoothly
- [ ] Ghost chunks appear seamlessly at edges
- [ ] Clicks on ghost cells trigger correct real cell
- [ ] Wrapping logic works (left edge connects to right edge)
- [ ] Mines generate with correct neighbor counts
- [ ] Win/lose conditions trigger properly

### Performance Benchmarks
- **Mobile**: 60 FPS with 10,000 visible cells
- **Desktop**: 60 FPS with 50,000+ cells
- **Memory**: < 150MB total RAM usage

---

## Godot-Specific Conventions

### Signal Naming
Use past tense for signals representing completed actions:
```gdscript
signal cell_revealed(cell_id: int)
signal mine_exploded(cell_id: int)
signal game_won()
```

### Node Naming
- Use descriptive PascalCase for scene tree nodes
- Prefix type for clarity: `GridRenderer_Main`, `InputManager_Touch`

### Scene Tree Structure (Required)
```
Main (Node2D)
├── GameLogic (Node)
├── Camera2D
├── InputManager (Control)
└── Visuals (Node2D)
    ├── GridRenderer_Main (MultiMeshInstance2D)
    ├── GridRenderer_Ghost_* (MultiMeshInstance2D)
    └── OceanBackground (ColorRect)
```

### Shader Convention
All shaders should:
- Have clear variable names (no single letters except common ones like `UV`)
- Include comments explaining the visual effect
- Use `TIME` for animations, not `_process(delta)`

Example:
```glsl
shader_type canvas_item;

// Creates gentle water ripple effect
void fragment() {
    vec2 distorted_uv = UV + vec2(
        sin(TIME + UV.y * 10.0) * 0.01,
        cos(TIME + UV.x * 8.0) * 0.01
    );
    COLOR = texture(TEXTURE, distorted_uv);
}
```

---

## Code Review Priorities

When reviewing changes, prioritize in this order:

1. **Architecture Compliance**: Does it use the graph approach?
2. **Performance**: Does it avoid creating thousands of nodes?
3. **Readability**: Can another developer understand this in 6 months?
4. **Godot Best Practices**: Does it use built-in features correctly?
5. **Style**: Does it match the formatting guidelines?

---

## Common Pitfalls to Avoid

### ❌ Creating Individual Sprite Nodes
```gdscript
# WRONG - This creates 10,000 nodes
for cell in cells:
    var sprite = Sprite2D.new()
    add_child(sprite)
```

### ✅ Use MultiMesh Instead
```gdscript
# CORRECT - One node, many instances
var multimesh = MultiMesh.new()
multimesh.instance_count = 10000
# Set transforms...
```

### ❌ Using get_node() Everywhere
```gdscript
# WRONG - Fragile, breaks on renames
func _ready():
    get_node("../../GameLogic/CellData").connect(...)
```

### ✅ Use @onready and Direct References
```gdscript
# CORRECT - Type-safe, refactor-friendly
@onready var cell_data: CellData = $GameLogic/CellData

func _ready():
    cell_data.cell_revealed.connect(_on_cell_revealed)
```

### ❌ Hardcoding Values
```gdscript
# WRONG
var grid_size = Vector2i(20, 20)
```

### ✅ Use Constants or Configuration
```gdscript
# CORRECT
const DEFAULT_GRID_SIZE = Vector2i(20, 20)
# Or load from resource
@export var grid_config: GridConfig
```

---

## Documentation Standards

### Function Documentation
For complex functions, use brief docstrings:

```gdscript
## Converts grid coordinates to pixel position for the given grid type.
## Returns Vector2.ZERO if the grid type is invalid.
func grid_to_pixel(coord: Vector2i, grid_type: GridType) -> Vector2:
    match grid_type:
        GridType.SQUARE:
            return Vector2(coord.x * 64, coord.y * 64)
        GridType.HEX:
            return hex_to_pixel(coord)
        _:
            push_warning("Invalid grid type")
            return Vector2.ZERO
```

### File Headers (Optional but Recommended)
```gdscript
## GridData.gd
##
## Core data structure for the minesweeper graph.
## Uses Struct-of-Arrays pattern for memory efficiency.
## 
## Each cell is referenced by ID (array index).
## Neighbor relationships are stored as adjacency lists.

class_name GridData
extends Resource
```

---

## Platform-Specific Notes

### Android
- Test with `adb logcat` for performance profiling
- Use remote debugging for on-device testing
- Ensure all touch targets are ≥48dp

### iOS
- Export requires macOS with Xcode
- Test haptic feedback on actual devices (simulators don't support it)
- Respect safe areas for notched devices

### Web
- Limit to WebGL2 features (no Vulkan)
- Test in both Chrome and Firefox
- Asset streaming: keep initial download < 15MB

---

## Questions & Clarifications

If you encounter ambiguity:

1. **Refer to TechnicalDesignDocument.md first**
2. **Consult GridMathematicsReference.md for coordinate systems**
3. **Ask for clarification rather than guessing**
4. **Prefer the simplest solution that respects the graph architecture**

---

## Change Log

- **v1.0** (January 2026): Initial Godot port guidelines
- Switch from Kotlin/Gradle to GDScript
- Established graph-based architecture as mandatory
- Defined MultiMesh rendering requirement

---

**Remember**: The graph architecture is not a suggestion—it's the foundation that makes exotic grids possible. Protect it fiercely.
