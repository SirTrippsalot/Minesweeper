# Implementation Plan: Topology Sweeper (Godot Port)
## Generated Plan of Attack - January 2026

---

## 🎯 Project Summary

**"Ariska: Dead Reckoning"** - A premium topological minesweeper game targeting the "Thinky Puzzle" demographic (50K-100K players globally). Pivoting from Kotlin/Android to Godot 4 for:
- Cross-platform support (Android/iOS/PC/Web)
- Token efficiency with AI assistance
- Built-in infinite canvas and performance features

### Key Architecture Requirements:
1. **Graph-based logic** (NO 2D arrays) - uses adjacency lists for all tessellations
2. **MultiMesh rendering** - one node for 10,000+ tiles
3. **Struct-of-Arrays data** - PackedArrays for memory efficiency
4. **Ocean/Island metaphor** - Water = mines, Land = safe zones
5. **Progressive unlocks** - Scanner modes, tools earned through skill challenges

---

## 📋 Development Phases

### **PHASE 1: Project Foundation** (Do First)

#### 1.1 Godot Project Structure
```
res://
├── scenes/
│   ├── main.tscn              # Main game scene
│   └── ui/
│       ├── hud.tscn           # Timer, mine counter
│       └── settings.tscn       # Configuration menu
├── scripts/
│   ├── core/                   # Pure game logic
│   │   ├── GridData.gd         # Struct-of-Arrays data
│   │   ├── GridType.gd         # Enum for grid types
│   │   └── GameLogic.gd        # Win/lose, reveal, flag logic
│   ├── rendering/
│   │   └── GridRenderer.gd     # MultiMesh visualization
│   ├── input/
│   │   └── InputManager.gd     # Gesture detection
│   └── generators/
│       ├── GridGenerator.gd    # Base class
│       ├── SquareGenerator.gd  # Square grid
│       └── HexGenerator.gd     # Hexagon grid
├── resources/
│   └── grid_configs/
└── assets/
    ├── textures/
    └── shaders/
        └── ocean_background.gdshader
```

#### 1.2 Core Data Structure (GridData.gd)
Implement the Struct-of-Arrays pattern:
```gdscript
class_name GridData
extends Resource

@export var cell_count: int = 0
@export var grid_size: Vector2i = Vector2i.ZERO
@export var grid_type: GridType.Type = GridType.Type.SQUARE
@export var wrap_horizontal: bool = true
@export var wrap_vertical: bool = true

# SoA Pattern - Memory efficient
var cell_is_mine: PackedByteArray
var cell_state: PackedByteArray  # 0=hidden, 1=revealed, 2=flagged, 3=questioned
var cell_danger_count: PackedByteArray
var cell_neighbors: Array[PackedInt32Array]
```

#### 1.3 Initial Tasks
- [ ] Create new Godot 4.3+ project
- [ ] Set up directory structure
- [ ] Create GridData.gd resource
- [ ] Create GridType.gd enum
- [ ] Set up .gitignore for Godot

---

### **PHASE 2: Square Grid MVP** (Critical Path)

#### 2.1 Square Grid Generator
- Simple coordinate system: `(x, y)` → `cell_id = y * width + x`
- 8-way Moore neighborhood neighbors
- **Torus wrapping**: Left edge connects to right, top to bottom
- Pre-calculate all neighbors once during generation

#### 2.2 Mine Placement
- Random distribution with configurable density (15-25%)
- Calculate danger counts after placement
- Support for "safe start" (first click always safe)

#### 2.3 Camera System
- Use Godot's built-in `Camera2D` with:
  - Pan via drag
  - Pinch-to-zoom
  - Smooth teleport at boundaries (infinite wrapping illusion)

#### 2.4 Tasks
- [ ] Implement GridGenerator.gd base class
- [ ] Implement SquareGridGenerator.gd
- [ ] Write neighbor calculation (8-way with wrapping)
- [ ] Implement mine placement logic
- [ ] Test: Generate 20×20 grid, verify neighbors
- [ ] Set up Camera2D with basic controls

**Success Criteria**: 20×20 square grid that wraps seamlessly, you can pan/zoom, and neighbors are correctly calculated.

---

### **PHASE 3: Visual Layer** (Make It Look Good)

#### 3.1 MultiMesh Rendering
```gdscript
class_name GridRenderer
extends Node2D

var multimesh_instance: MultiMeshInstance2D
var grid_data: GridData

func initialize(data: GridData, generator: GridGenerator):
    var multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_2D
    multimesh.instance_count = data.cell_count
    # Set transforms once from generator.get_pixel_position()
```

#### 3.2 Ocean Theme Colors
- Deep Water (mines): `#1a4d6d`
- Sand (danger > 0): `#e8d4a0`
- Vegetation (danger == 0): `#5c8a3d`
- Hidden cells: Gray overlay

#### 3.3 Ghost Chunk System
Render edge cells at offset positions for seamless wrapping:
```
┌──────────┬──────────┬──────────┐
│  Ghost   │   Real   │  Ghost   │
│   (L)    │  Grid    │   (R)    │
└──────────┴──────────┴──────────┘
```
Only render 1-tile-wide strips at boundaries, forward clicks to real cells.

#### 3.4 Tasks
- [ ] Create GridRenderer.gd with MultiMesh
- [ ] Implement cell color mapping (ocean theme)
- [ ] Create ocean background shader
- [ ] Implement ghost chunk rendering for edges
- [ ] Add cell state visual updates (hidden/revealed/flagged)
- [ ] Test: 10,000 cells at 60 FPS

---

### **PHASE 4: Input System** (Mobile-First)

#### 4.1 Gesture Detection
```gdscript
class_name InputManager
extends Control

signal cell_tapped(cell_id: int)
signal cell_double_tapped(cell_id: int)
signal cell_long_pressed(cell_id: int)
signal camera_panned(delta: Vector2)
signal camera_zoomed(factor: float)
```

#### 4.2 Configurable Actions
Default mapping:
- **Single Tap** → Question mark
- **Double Tap** → Flag
- **Triple Tap** → Reveal
- **Long Press** → Custom action

#### 4.3 Hit Detection
Use centroid-based nearest cell:
```gdscript
func get_cell_at_position(world_pos: Vector2) -> int:
    var closest = -1
    var min_dist = INF
    for cell_id in visible_cells:
        var centroid = generator.get_pixel_position(cell_id)
        var dist = world_pos.distance_squared_to(centroid)
        if dist < min_dist:
            min_dist = dist
            closest = cell_id
    return closest
```

#### 4.4 Tasks
- [ ] Create InputManager.gd Control node
- [ ] Implement tap detection (single/double/long)
- [ ] Implement drag for camera pan
- [ ] Implement pinch-to-zoom
- [ ] Add centroid-based hit testing
- [ ] Connect input signals to game logic
- [ ] Test on mobile device (if available)

---

### **PHASE 5: Hexagon Grid** (Architecture Validation)

#### 5.1 Axial Coordinate System
- Use `(q, r)` axial coordinates (not offset)
- 6-way neighbors
- **Critical**: Force map width to EVEN numbers (prevent zigzag seam)

#### 5.2 Wrapping Math
More complex than square - refer to Red Blob Games guide

#### 5.3 Tasks
- [ ] Implement HexGridGenerator.gd
- [ ] Add axial coordinate conversion
- [ ] Calculate 6-way hex neighbors
- [ ] Implement hex wrapping (even width validation)
- [ ] Calculate hex pixel positions (flat-top or pointy-top)
- [ ] Test: 20×20 hex grid with wrapping
- [ ] Verify neighbor correctness visually

**Success Criteria**: If hex wrapping works, the graph architecture is proven sound.

---

### **PHASE 6: Game Logic** (Make It Playable)

#### 6.1 GameLogic.gd
```gdscript
class_name GameLogic
extends Node

signal cell_revealed(cell_id: int, danger_count: int, is_mine: bool)
signal cell_marked(cell_id: int, mark_type: int)
signal game_won()
signal game_lost(mine_cell_id: int)

func reveal_cell(cell_id: int) -> void:
    # Check for mine
    # If danger_count == 0, trigger flood reveal
    # Check win condition
```

#### 6.2 Flood Reveal (Zero Cascade)
When revealing a cell with `danger_count == 0`, recursively reveal all connected safe neighbors.

#### 6.3 Win/Lose Conditions
- **Lose**: Reveal a mine
- **Win**: All non-mine cells revealed
- Optional: Strict mode (must flag all mines)

#### 6.4 Tasks
- [ ] Create GameLogic.gd node
- [ ] Implement reveal_cell() with mine detection
- [ ] Implement toggle_flag() and toggle_question()
- [ ] Add flood reveal algorithm (BFS/DFS)
- [ ] Implement win condition checking
- [ ] Implement lose condition (reveal all mines)
- [ ] Add timer tracking
- [ ] Connect to GridRenderer for visual updates
- [ ] Test: Complete a full game (win and lose)

---

### **PHASE 7: Exotic Grids** (The Differentiator)

Priority order based on complexity:

#### 7.1 Cairo Pentagonal
- Use dual-hex trick - overlay two hex grids
- Each pentagon's neighbors from hex pair relationships

#### 7.2 Rhombille
- Split hexagons into 3 rhombi
- Creates Q*bert cube optical illusion

#### 7.3 Triangle
- Dual of hexagon
- Alternating upright/inverted triangles
- 3 or 12 neighbors (depending on scanner mode)

#### 7.4 Snub Square & Octasquare
- **Danger ratio visualization required** - display "3/5" not just "3"
- Use mega-tile approach for coordinate system

#### 7.5 Penrose (Final Boss)
- **NO wrapping** (mathematically impossible)
- Use bounded mode with void boundary
- Pure graph approach - no coordinate system
- Theme as "Continental Shelf" where reality breaks down

#### 7.6 Tasks
- [ ] Implement CairoGridGenerator.gd
- [ ] Implement RhombilleGridGenerator.gd
- [ ] Implement TriangleGridGenerator.gd
- [ ] Implement danger ratio visualization system
- [ ] Implement SnubSquareGridGenerator.gd
- [ ] Implement OctasquareGridGenerator.gd
- [ ] Implement PenroseGridGenerator.gd (inflation/deflation)
- [ ] Add bounded mode support for Penrose
- [ ] Test each grid type thoroughly

---

### **PHASE 8: Tech Unlock System** (Depth Layer)

#### 8.1 Scanner Toggle
- **Mk.I Contact Sensor** (default): Edge/contact neighbors only
- **Mk.II Field Sensor** (unlocked): Vertex/corner neighbors
  - Square: 4 → 8 neighbors (easier)
  - Triangle: 3 → 12 neighbors (harder!)

#### 8.2 Unlock Challenges
1. **"Chaos Theory"** → Field Scanner
   - 15×15 Triangle grid with Field Scanner active
   - Must complete with < 5% error rate

2. **"Cascade Protocol"** → Auto-Chord
   - 30×30 Hexagon, 10% density, 60 second limit
   - Must clear 500 tiles

3. **"The Minefield"** → Hull Plating (second chance)
   - 8×8 Snub Square, 35% density
   - Complete without hitting any mine

4. **"Dark Room"** → Resonance Buoy (area density scan)
   - 20×20 Square with fog of war
   - Numbers hidden as "?", only zeros show

#### 8.3 Simulation Chamber Hub
Dedicated scene for challenges with holographic aesthetic.

#### 8.4 Tasks
- [ ] Implement scanner mode system (contact vs. field)
- [ ] Create neighbor calculation variants by mode
- [ ] Design Simulation Chamber scene
- [ ] Implement "Chaos Theory" challenge
- [ ] Implement "Cascade Protocol" challenge
- [ ] Implement "The Minefield" challenge
- [ ] Implement "Dark Room" challenge
- [ ] Add unlock persistence system
- [ ] Create tech unlock UI notifications
- [ ] Add tech indicator HUD

---

### **PHASE 9: Polish & Release** (Ship It)

#### 9.1 Settings System
- Gesture configuration
- Scanner mode toggle
- Grid size/density presets
- Sound/haptics options
- Wrapping configuration

#### 9.2 Tutorial/Onboarding
- Interactive tutorial for square grid
- Tooltips for exotic grids
- Challenge introduction sequences
- "Hostile marketing" description filters casual players

#### 9.3 Monetization
- Small banner ad (non-intrusive)
- $10-15 IAP for ad removal (premium pricing)
- **NO feature paywalls**

#### 9.4 Platform Builds
- Android (primary target)
- iOS (requires macOS for export)
- PC (Windows/Linux/Mac)
- Web (< 15MB initial load)

#### 9.5 Tasks
- [ ] Create settings scene with all options
- [ ] Implement settings persistence (ConfigFile)
- [ ] Create interactive tutorial levels
- [ ] Add sound effects (reveal, flag, mine, win/lose)
- [ ] Implement haptic feedback
- [ ] Integrate ad system (banner + interstitial)
- [ ] Implement IAP for ad removal
- [ ] Create HUD with timer and mine counter
- [ ] Design and implement main menu
- [ ] Create capsule art and marketing materials
- [ ] Set up export presets for all platforms
- [ ] Test builds on each platform
- [ ] Write store descriptions ("hostile marketing")
- [ ] Submit to app stores

---

## 🚨 Critical Gotchas to Avoid

1. **NEVER use 2D arrays for logic** - graph approach is LAW
2. **NEVER use individual Sprite2D nodes** - MultiMesh from day 1
3. **Force even width for hex grids** - prevent zigzag seam
4. **Pre-calculate neighbors once** - don't recalculate per frame
5. **Use PackedArrays** - not Dictionaries (100MB → 100KB)
6. **Penrose cannot wrap** - accept bounded mode with thematic void
7. **Test wrapping at boundaries** - click cells at exact edges
8. **Validate neighbor reciprocity** - if A neighbors B, then B neighbors A
9. **Mobile touch targets** - minimum 48dp (≥64 pixels)
10. **Profile early** - ensure 60 FPS with 10,000 cells

---

## 📊 Development Metrics

### Performance Targets
- **Mobile**: 60 FPS with 10,000 visible cells
- **Desktop**: 60 FPS with 50,000+ cells
- **Memory**: < 150MB total RAM usage
- **Initial Load (Web)**: < 15MB

### Success Milestones
1. ✅ Square grid wraps seamlessly
2. ✅ Camera pan/zoom works smoothly
3. ✅ Can click cells and reveal
4. ✅ Flood reveal cascades correctly
5. ✅ Hexagon grid validates architecture
6. ✅ At least 3 exotic grids working
7. ✅ One tech unlock challenge playable
8. ✅ Builds export to Android

---

## 🎯 Recommended First Steps

**Start here:**
1. Create new Godot 4.3+ project
2. Implement `GridData.gd` resource structure
3. Implement `SquareGridGenerator.gd` with wrapping
4. Create `Main.tscn` with basic scene structure
5. Test: Generate 20×20 grid, print neighbors, verify wrapping

**First working prototype goal:**
> "Click on a 20×20 square grid with wrapping. Cells reveal danger counts. Clicking a mine shows red. That's it."

Once that works, everything else builds on that foundation.

---

## 📚 Reference Documents

- **TechnicalDesignDocument.md** - Overall vision and architecture
- **ArchitectureImplementationGuide.md** - Godot-specific patterns
- **GridMathematicsReference.md** - Coordinate systems for all grids
- **GameFeaturesAndUnlocks.md** - Tech tree and progression
- **KeyInsightsAndGotchas.md** - Lessons learned
- **KotlinExtractionGuide.md** - Valuable patterns from old codebase
- **AGENTS.md** - Coding guidelines and standards

---

## 🔄 Current Status

**Phase**: Not started
**Next Action**: Create Godot project and implement Phase 1

---

**Document Version**: 1.0
**Created**: January 2026
**Status**: Ready to begin implementation
