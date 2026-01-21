# Architecture Implementation Guide
## Godot-Specific Patterns for Topology Sweeper

This document provides concrete implementation patterns for the graph-based architecture in Godot 4.

---

## 🏛️ Core Architecture Pattern

### The Three-Layer Separation

```
┌─────────────────────────────────────────┐
│         INPUT LAYER (Control)           │
│   Gestures → Signals → No State         │
└────────────────┬────────────────────────┘
                 │ Emits: cell_clicked(id)
                 ▼
┌─────────────────────────────────────────┐
│       LOGIC LAYER (Node/Resource)       │
│  Pure Data → Graph → Game Rules         │
└────────────────┬────────────────────────┘
                 │ Emits: cell_revealed(id)
                 ▼
┌─────────────────────────────────────────┐
│      VISUAL LAYER (Node2D/MultiMesh)    │
│   Rendering → Shaders → No Logic        │
└─────────────────────────────────────────┘
```

**Rule**: Data flows DOWN via signals. No upward dependencies.

---

## 📦 Data Structures

### 1. GridData Resource (Core Game State)

```gdscript
## GridData.gd
## The heart of the game - stores all cell information using Struct-of-Arrays pattern.

class_name GridData
extends Resource

## Total number of cells in the grid
@export var cell_count: int = 0

## Grid dimensions (for reference/UI, not used for logic)
@export var grid_size: Vector2i = Vector2i.ZERO

## Grid type identifier
@export var grid_type: GridType = GridType.SQUARE

## Wrapping configuration
@export var wrap_horizontal: bool = true
@export var wrap_vertical: bool = true

# ===== STRUCT OF ARRAYS (SoA) PATTERN =====
# Each array is indexed by cell_id

## Which cells contain mines (1 = mine, 0 = safe)
var cell_is_mine: PackedByteArray

## Cell reveal state (0 = hidden, 1 = revealed, 2 = flagged, 3 = questioned)
var cell_state: PackedByteArray

## Number of neighboring mines (calculated once, cached)
var cell_danger_count: PackedByteArray

## Adjacency lists - each cell's array contains IDs of neighboring cells
var cell_neighbors: Array[PackedInt32Array]

# ===== INITIALIZATION =====

func initialize(count: int) -> void:
    cell_count = count
    
    # Allocate arrays
    cell_is_mine.resize(count)
    cell_state.resize(count)
    cell_danger_count.resize(count)
    cell_neighbors.resize(count)
    
    # Fill with defaults
    cell_is_mine.fill(0)
    cell_state.fill(0)
    cell_danger_count.fill(0)

# ===== CELL QUERIES =====

func is_mine(cell_id: int) -> bool:
    return cell_is_mine[cell_id] == 1

func is_revealed(cell_id: int) -> bool:
    return cell_state[cell_id] == 1

func is_flagged(cell_id: int) -> bool:
    return cell_state[cell_id] == 2

func is_questioned(cell_id: int) -> bool:
    return cell_state[cell_id] == 3

func get_neighbors(cell_id: int) -> PackedInt32Array:
    return cell_neighbors[cell_id]

func get_danger_count(cell_id: int) -> int:
    return cell_danger_count[cell_id]

# ===== CELL MODIFICATIONS =====

func set_mine(cell_id: int, is_mine_val: bool) -> void:
    cell_is_mine[cell_id] = 1 if is_mine_val else 0

func reveal_cell(cell_id: int) -> void:
    cell_state[cell_id] = 1

func flag_cell(cell_id: int) -> void:
    cell_state[cell_id] = 2

func question_cell(cell_id: int) -> void:
    cell_state[cell_id] = 3

func clear_marking(cell_id: int) -> void:
    cell_state[cell_id] = 0

# ===== NEIGHBOR MANAGEMENT =====

func set_neighbors(cell_id: int, neighbor_ids: PackedInt32Array) -> void:
    cell_neighbors[cell_id] = neighbor_ids

func calculate_danger_counts() -> void:
    """Call this once after mines are placed"""
    for cell_id in range(cell_count):
        if is_mine(cell_id):
            cell_danger_count[cell_id] = 0  # Mines don't show numbers
            continue
        
        var count = 0
        for neighbor_id in get_neighbors(cell_id):
            if is_mine(neighbor_id):
                count += 1
        
        cell_danger_count[cell_id] = count
```

### 2. GridType Enum

```gdscript
## GridType.gd
## Defines all supported grid tessellations

class_name GridType

enum Type {
    SQUARE,
    HEXAGON,
    TRIANGLE,
    CAIRO,
    RHOMBILLE,
    SNUB_SQUARE,
    OCTASQUARE,
    PENROSE
}

## Human-readable names
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

## Check if grid type supports wrapping
static func supports_wrapping(type: Type) -> bool:
    return type != Type.PENROSE
```

---

## 🎮 Game Logic Layer

### GameLogic Node (Orchestrator)

```gdscript
## GameLogic.gd
## Main game controller - manages state, win/lose, interactions

class_name GameLogic
extends Node

## Signals for UI to listen to
signal cell_revealed(cell_id: int, danger_count: int, is_mine: bool)
signal cell_marked(cell_id: int, mark_type: int)  # 0=clear, 2=flag, 3=question
signal game_won()
signal game_lost(mine_cell_id: int)
signal mine_count_changed(flagged: int, total: int)

## The core data
var grid_data: GridData

## Game state
var game_active: bool = false
var start_time: float = 0.0
var revealed_count: int = 0
var flagged_count: int = 0

# ===== INITIALIZATION =====

func start_new_game(grid: GridData) -> void:
    grid_data = grid
    game_active = true
    start_time = Time.get_ticks_msec() / 1000.0
    revealed_count = 0
    flagged_count = 0
    
    # Calculate mine counts for all cells
    grid_data.calculate_danger_counts()

# ===== PLAYER ACTIONS =====

func reveal_cell(cell_id: int) -> void:
    if !game_active:
        return
    
    if grid_data.is_revealed(cell_id) or grid_data.is_flagged(cell_id):
        return  # Already revealed or flagged
    
    grid_data.reveal_cell(cell_id)
    revealed_count += 1
    
    var is_mine = grid_data.is_mine(cell_id)
    var danger_count = grid_data.get_danger_count(cell_id)
    
    cell_revealed.emit(cell_id, danger_count, is_mine)
    
    if is_mine:
        _trigger_game_over(cell_id)
    elif danger_count == 0:
        _flood_reveal(cell_id)  # Auto-reveal safe neighbors
    else:
        _check_win_condition()

func toggle_flag(cell_id: int) -> void:
    if !game_active or grid_data.is_revealed(cell_id):
        return
    
    if grid_data.is_flagged(cell_id):
        grid_data.clear_marking(cell_id)
        flagged_count -= 1
        cell_marked.emit(cell_id, 0)
    else:
        grid_data.flag_cell(cell_id)
        flagged_count += 1
        cell_marked.emit(cell_id, 2)
    
    mine_count_changed.emit(flagged_count, _count_total_mines())

func toggle_question(cell_id: int) -> void:
    if !game_active or grid_data.is_revealed(cell_id):
        return
    
    if grid_data.is_questioned(cell_id):
        grid_data.clear_marking(cell_id)
        cell_marked.emit(cell_id, 0)
    else:
        grid_data.question_cell(cell_id)
        cell_marked.emit(cell_id, 3)

# ===== AUTO-REVEAL (FLOOD FILL) =====

func _flood_reveal(start_cell_id: int) -> void:
    """Recursively reveal all connected safe cells"""
    var to_reveal: Array[int] = [start_cell_id]
    var visited: Dictionary = {}  # Set of visited cell IDs
    
    while to_reveal.size() > 0:
        var cell_id = to_reveal.pop_back()
        
        if cell_id in visited:
            continue
        
        visited[cell_id] = true
        
        # Reveal neighbors if this cell is a zero
        if grid_data.get_danger_count(cell_id) == 0:
            for neighbor_id in grid_data.get_neighbors(cell_id):
                if !grid_data.is_revealed(neighbor_id) and !grid_data.is_flagged(neighbor_id):
                    grid_data.reveal_cell(neighbor_id)
                    revealed_count += 1
                    
                    var danger = grid_data.get_danger_count(neighbor_id)
                    cell_revealed.emit(neighbor_id, danger, false)
                    
                    if danger == 0:
                        to_reveal.append(neighbor_id)
    
    _check_win_condition()

# ===== WIN/LOSE CONDITIONS =====

func _check_win_condition() -> void:
    var total_safe_cells = grid_data.cell_count - _count_total_mines()
    
    if revealed_count >= total_safe_cells:
        game_active = false
        game_won.emit()

func _trigger_game_over(mine_cell_id: int) -> void:
    game_active = false
    game_lost.emit(mine_cell_id)
    
    # Optional: Reveal all mines
    for cell_id in range(grid_data.cell_count):
        if grid_data.is_mine(cell_id):
            grid_data.reveal_cell(cell_id)
            cell_revealed.emit(cell_id, 0, true)

func _count_total_mines() -> int:
    var count = 0
    for i in range(grid_data.cell_count):
        if grid_data.is_mine(i):
            count += 1
    return count
```

---

## 🎨 Visual Layer

### GridRenderer (MultiMesh-Based)

```gdscript
## GridRenderer.gd
## Renders the grid using MultiMeshInstance2D for performance

class_name GridRenderer
extends Node2D

@export var cell_texture: Texture2D
@export var cell_size: float = 64.0

var multimesh_instance: MultiMeshInstance2D
var grid_data: GridData
var grid_generator: GridGenerator  # Converts cell_id → pixel position

# ===== SETUP =====

func _ready() -> void:
    multimesh_instance = MultiMeshInstance2D.new()
    add_child(multimesh_instance)

func initialize(data: GridData, generator: GridGenerator) -> void:
    grid_data = data
    grid_generator = generator
    
    _create_multimesh()
    _update_all_visuals()

func _create_multimesh() -> void:
    var multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_2D
    multimesh.instance_count = grid_data.cell_count
    multimesh.mesh = _create_cell_mesh()
    
    # Set initial transforms
    for cell_id in range(grid_data.cell_count):
        var pixel_pos = grid_generator.get_pixel_position(cell_id)
        var transform = Transform2D()
        transform.origin = pixel_pos
        multimesh.set_instance_transform_2d(cell_id, transform)
    
    multimesh_instance.multimesh = multimesh

func _create_cell_mesh() -> Mesh:
    # Simple quad for now - can be replaced with actual grid shape
    var quad = QuadMesh.new()
    quad.size = Vector2(cell_size, cell_size)
    return quad

# ===== VISUAL UPDATES =====

func update_cell_visual(cell_id: int) -> void:
    # Change color based on state
    var color = _get_cell_color(cell_id)
    multimesh_instance.multimesh.set_instance_color(cell_id, color)

func _update_all_visuals() -> void:
    for cell_id in range(grid_data.cell_count):
        update_cell_visual(cell_id)

func _get_cell_color(cell_id: int) -> Color:
    if grid_data.is_revealed(cell_id):
        if grid_data.is_mine(cell_id):
            return Color.RED  # Mine
        else:
            var danger = grid_data.get_danger_count(cell_id)
            return _get_danger_color(danger)
    elif grid_data.is_flagged(cell_id):
        return Color.ORANGE
    elif grid_data.is_questioned(cell_id):
        return Color.YELLOW
    else:
        return Color.GRAY  # Hidden

func _get_danger_color(count: int) -> Color:
    # Ocean theme: darker blue = more danger
    match count:
        0: return Color(0.36, 0.54, 0.24)  # Green vegetation
        1: return Color(0.91, 0.83, 0.63)  # Light sand
        2: return Color(0.85, 0.75, 0.55)
        3: return Color(0.78, 0.67, 0.47)
        _: return Color(0.29, 0.62, 0.84)  # Water
```

---

## 🖱️ Input Layer

### InputManager (Gesture Detection)

```gdscript
## InputManager.gd
## Handles all touch/mouse input and converts to game actions

class_name InputManager
extends Control

## Signals emitted to GameLogic
signal cell_tapped(cell_id: int)
signal cell_double_tapped(cell_id: int)
signal cell_long_pressed(cell_id: int)
signal camera_panned(delta: Vector2)
signal camera_zoomed(factor: float)

## Configuration
@export var double_tap_window: float = 0.3  # seconds
@export var long_press_duration: float = 0.5  # seconds

var grid_renderer: GridRenderer
var camera: Camera2D

# Tap detection state
var last_tap_time: float = 0.0
var press_start_time: float = 0.0
var press_position: Vector2
var is_pressing: bool = false

# ===== INPUT PROCESSING =====

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)
    elif event is InputEventMagnifyGesture:
        _handle_pinch(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        # Touch down
        is_pressing = true
        press_start_time = Time.get_ticks_msec() / 1000.0
        press_position = event.position
    else:
        # Touch up
        is_pressing = false
        var press_duration = Time.get_ticks_msec() / 1000.0 - press_start_time
        
        # Check for long press
        if press_duration >= long_press_duration:
            _on_long_press(event.position)
            return
        
        # Check for double tap
        var current_time = Time.get_ticks_msec() / 1000.0
        if current_time - last_tap_time < double_tap_window:
            _on_double_tap(event.position)
            last_tap_time = 0.0  # Reset to prevent triple-tap
        else:
            _on_single_tap(event.position)
            last_tap_time = current_time

func _handle_drag(event: InputEventScreenDrag) -> void:
    if event.index == 0:  # Single finger = pan
        camera_panned.emit(event.relative)

func _handle_pinch(event: InputEventMagnifyGesture) -> void:
    camera_zoomed.emit(event.factor)

# ===== TAP HANDLERS =====

func _on_single_tap(screen_pos: Vector2) -> void:
    var cell_id = _get_cell_at_position(screen_pos)
    if cell_id >= 0:
        cell_tapped.emit(cell_id)

func _on_double_tap(screen_pos: Vector2) -> void:
    var cell_id = _get_cell_at_position(screen_pos)
    if cell_id >= 0:
        cell_double_tapped.emit(cell_id)

func _on_long_press(screen_pos: Vector2) -> void:
    var cell_id = _get_cell_at_position(screen_pos)
    if cell_id >= 0:
        cell_long_pressed.emit(cell_id)

# ===== POSITION TO CELL CONVERSION =====

func _get_cell_at_position(screen_pos: Vector2) -> int:
    # Convert screen position to world position (account for camera)
    var world_pos = camera.get_global_mouse_position()
    
    # Ask grid generator to find nearest cell
    return grid_renderer.grid_generator.get_cell_at_position(world_pos)
```

---

## 🌍 Grid Generation

### GridGenerator Base Class

```gdscript
## GridGenerator.gd
## Abstract base for grid generation strategies

class_name GridGenerator
extends RefCounted

## Generate a complete grid with neighbor relationships
func generate(width: int, height: int, mine_count: int) -> GridData:
    push_error("GridGenerator.generate() must be overridden")
    return null

## Convert cell_id to pixel position
func get_pixel_position(cell_id: int) -> Vector2:
    push_error("GridGenerator.get_pixel_position() must be overridden")
    return Vector2.ZERO

## Find cell_id at given world position (for clicks)
func get_cell_at_position(world_pos: Vector2) -> int:
    push_error("GridGenerator.get_cell_at_position() must be overridden")
    return -1
```

### Example: SquareGridGenerator

```gdscript
## SquareGridGenerator.gd

class_name SquareGridGenerator
extends GridGenerator

const CELL_SIZE = 64.0

var grid_width: int
var grid_height: int
var wrap_horizontal: bool
var wrap_vertical: bool

func _init(width: int, height: int, wrap_h: bool = true, wrap_v: bool = true):
    grid_width = width
    grid_height = height
    wrap_horizontal = wrap_h
    wrap_vertical = wrap_v

func generate(width: int, height: int, mine_count: int) -> GridData:
    var grid = GridData.new()
    grid.cell_count = width * height
    grid.grid_size = Vector2i(width, height)
    grid.grid_type = GridType.Type.SQUARE
    grid.wrap_horizontal = wrap_horizontal
    grid.wrap_vertical = wrap_vertical
    
    grid.initialize(grid.cell_count)
    
    # Generate neighbors
    for y in range(height):
        for x in range(width):
            var cell_id = _pos_to_id(Vector2i(x, y))
            var neighbors = _calculate_neighbors(Vector2i(x, y))
            grid.set_neighbors(cell_id, neighbors)
    
    # Place mines randomly
    _place_mines(grid, mine_count)
    
    return grid

func _calculate_neighbors(pos: Vector2i) -> PackedInt32Array:
    var neighbors = PackedInt32Array()
    
    const OFFSETS = [
        Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
        Vector2i(-1,  0),                  Vector2i(1,  0),
        Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
    ]
    
    for offset in OFFSETS:
        var neighbor_pos = pos + offset
        
        if wrap_horizontal or wrap_vertical:
            neighbor_pos = _wrap_position(neighbor_pos)
        elif !_is_in_bounds(neighbor_pos):
            continue
        
        neighbors.append(_pos_to_id(neighbor_pos))
    
    return neighbors

func _wrap_position(pos: Vector2i) -> Vector2i:
    var wrapped = pos
    
    if wrap_horizontal:
        wrapped.x = wrapped.x % grid_width
        if wrapped.x < 0: wrapped.x += grid_width
    
    if wrap_vertical:
        wrapped.y = wrapped.y % grid_height
        if wrapped.y < 0: wrapped.y += grid_height
    
    return wrapped

func _is_in_bounds(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func _pos_to_id(pos: Vector2i) -> int:
    return pos.y * grid_width + pos.x

func _id_to_pos(id: int) -> Vector2i:
    return Vector2i(id % grid_width, id / grid_width)

func _place_mines(grid: GridData, count: int) -> void:
    var available_cells = range(grid.cell_count)
    available_cells.shuffle()
    
    for i in range(count):
        grid.set_mine(available_cells[i], true)

func get_pixel_position(cell_id: int) -> Vector2:
    var pos = _id_to_pos(cell_id)
    return Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)

func get_cell_at_position(world_pos: Vector2) -> int:
    var grid_pos = Vector2i(
        int(world_pos.x / CELL_SIZE),
        int(world_pos.y / CELL_SIZE)
    )
    
    if wrap_horizontal or wrap_vertical:
        grid_pos = _wrap_position(grid_pos)
    elif !_is_in_bounds(grid_pos):
        return -1
    
    return _pos_to_id(grid_pos)
```

---

## 🎬 Scene Setup Example

### Main.tscn Structure

```gdscript
## Main.gd

extends Node2D

@onready var game_logic: GameLogic = $GameLogic
@onready var grid_renderer: GridRenderer = $Visuals/GridRenderer
@onready var input_manager: InputManager = $InputManager
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
    # Generate grid
    var generator = SquareGridGenerator.new(20, 20, true, true)
    var grid_data = generator.generate(20, 20, 40)  # 20x20 with 40 mines
    
    # Initialize systems
    game_logic.start_new_game(grid_data)
    grid_renderer.initialize(grid_data, generator)
    input_manager.grid_renderer = grid_renderer
    input_manager.camera = camera
    
    # Connect signals
    input_manager.cell_tapped.connect(_on_cell_tapped)
    input_manager.cell_double_tapped.connect(_on_cell_double_tapped)
    input_manager.camera_panned.connect(_on_camera_panned)
    
    game_logic.cell_revealed.connect(_on_cell_revealed)
    game_logic.game_won.connect(_on_game_won)
    game_logic.game_lost.connect(_on_game_lost)

func _on_cell_tapped(cell_id: int) -> void:
    game_logic.toggle_question(cell_id)

func _on_cell_double_tapped(cell_id: int) -> void:
    game_logic.toggle_flag(cell_id)

func _on_camera_panned(delta: Vector2) -> void:
    camera.position -= delta / camera.zoom

func _on_cell_revealed(cell_id: int, danger_count: int, is_mine: bool) -> void:
    grid_renderer.update_cell_visual(cell_id)

func _on_game_won() -> void:
    print("You won!")

func _on_game_lost(mine_cell_id: int) -> void:
    print("Game over - hit mine at cell %d" % mine_cell_id)
```

---

## 🚀 Performance Optimizations

### 1. Dirty Flag Pattern
Only update visuals that changed:

```gdscript
var dirty_cells: Array[int] = []

func mark_dirty(cell_id: int) -> void:
    if cell_id not in dirty_cells:
        dirty_cells.append(cell_id)

func _process(_delta: float) -> void:
    for cell_id in dirty_cells:
        grid_renderer.update_cell_visual(cell_id)
    dirty_cells.clear()
```

### 2. Spatial Culling
Only render visible cells:

```gdscript
func get_visible_cells(camera_rect: Rect2) -> Array[int]:
    var visible = []
    for cell_id in range(grid_data.cell_count):
        var pos = grid_generator.get_pixel_position(cell_id)
        if camera_rect.has_point(pos):
            visible.append(cell_id)
    return visible
```

### 3. Batch Updates
Group visual changes together:

```gdscript
# Instead of updating one-by-one
for cell_id in cells_to_update:
    update_cell_visual(cell_id)

# Batch the multimesh update
multimesh_instance.multimesh.set_instance_transform_2d_array(transforms)
```

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Status**: Implementation Guide for Godot Port
