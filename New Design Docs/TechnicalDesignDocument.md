# Technical Design Document: Topology Sweeper
## Working Title: "Dead Reckoning" / "Ariska: Dead Reckoning"

> *"Minesweeper meets infinite oceans and non-Euclidean geometry"*

---

## 🎯 Project Vision

A premium, high-fidelity logic puzzle game targeting the "Thinky Puzzle" demographic. This is not a casual mobile game—it's a topological simulation wrapped in a minimalist nautical aesthetic for players who found Hexcells "too easy" and own copies of Tametsi.

### Target Audience
- **Size**: 50,000–100,000 players globally
- **Profile**: Logic puzzle enthusiasts who play every game in their sub-genre
- **Reference Games**: Tametsi, Hexcells Infinite, 14 Minesweeper Variants
- **Expectation**: Overwhelming Positive reviews from 2,000 dedicated players rather than millions of casual downloads

---

## 🏗️ Technical Foundation

### Engine: Godot 4.x
**Rationale for Switch from Kotlin/Gradle:**
- Cross-platform export (Android, iOS, PC, Web) with single codebase
- Efficient token usage with Claude (GDScript vs. Java/Kotlin boilerplate)
- Native support for infinite canvas via Camera2D
- Built-in gesture handling for mobile
- MultiMeshInstance2D for performant rendering of 10,000+ tiles

### Core Architecture Philosophy: Graph-Based Logic

**CRITICAL: We do NOT use 2D arrays `grid[x][y]` for game logic.**

This is non-negotiable because exotic grids (Penrose, Cairo, Snub Square) defy traditional coordinate systems.

#### The Graph Standard
Every cell in the game is a **Node** in a graph with:
- `id: int` - Unique identifier
- `is_mine: bool` - Mine status
- `neighbors: Array[int]` - List of adjacent cell IDs
- `state: int` - Hidden/Revealed/Flagged
- `danger_count: int` - Number of neighboring mines

**Benefits:**
1. Shape-agnostic logic (works for any tessellation)
2. Wrapping is just edge connections in the graph
3. Minesweeper logic becomes pure neighbor traversal
4. Can support future 3D or hyperbolic grids without rewriting core systems

---

## 🌊 Visual Theme: Ocean & Islands

### Metaphor System
- **Ocean (Water)**: Danger zones (mines)
- **Islands (Land)**: Safe zones
- **Sand**: Cells with danger_count > 0 (touching water)
- **Vegetation**: Cells with danger_count = 0 (deep safety)

### Biome Progression

#### 1. The Open Sea (Standard Mode)
- **Grids**: Square, Hexagon
- **Topology**: Wrapping Torus (infinite ocean)
- **Aesthetic**: Clean blue water, white sand beaches, green vegetation
- **Vibe**: Peaceful exploration, mathematical clarity

#### 2. The Sunken Ruins (Advanced Mode)
- **Grids**: Cairo Pentagonal, Rhombille
- **Topology**: Optional wrapping
- **Aesthetic**: Ancient stone pavement, weathered geometry
- **Special Mechanics**: 
  - Wall tiles (block adjacency, create logic shadows)
  - Pressure plates (locked tiles requiring neighbor clearance)
- **Vibe**: Archaeological puzzle-solving

#### 3. The Continental Shelf (Chaos Mode)
- **Grids**: Snub Square, Penrose
- **Topology**: NO wrapping (Penrose is mathematically incompatible with torus)
- **Aesthetic**: Jagged edges, purple/grey sand, void boundaries
- **Special Feature**: Non-local logic (adjacency variance)
- **Vibe**: Lovecraftian geometry, reality breakdown

---

## 🔶 Grid Types & Mathematics

### Complexity Ladder (Implementation Order)

#### Phase 1: Foundation Grids
1. **Square** (Tutorial)
   - Neighbors: 8 (Moore neighborhood)
   - Wrapping: Full torus support
   - Coordinate: Simple x,y

2. **Hexagon** (Intermediate)
   - Neighbors: 6
   - Wrapping: Full torus (requires EVEN width)
   - Coordinate: Offset or Axial system

#### Phase 2: Exotic Regular Grids
3. **Triangular**
   - Neighbors: 3 or 12 (edge vs. vertex)
   - Wrapping: Supported
   - Implementation: Dual of hexagonal grid

4. **Cairo Pentagonal**
   - Neighbors: 5 (uniform)
   - Wrapping: Supported
   - Implementation: Overlay two offset hex grids

5. **Rhombille**
   - Neighbors: 4 edge + 2 vertex
   - Wrapping: Supported
   - Visual Note: Creates optical illusion (Q*bert cubes)
   - Implementation: Each hex split into 3 rhombi

#### Phase 3: Irregular/Advanced Grids
6. **Octasquare** (Octa-Quad, 4.8.8 tessellation)
   - Neighbors: 3-8 (varies by shape)
   - Wrapping: Supported (complex)
   - Fairness Issue: Requires danger ratio visualization

7. **Snub Square**
   - Neighbors: 3-5 (varies by shape)
   - Wrapping: Supported
   - Fairness Issue: "3" on triangle = 100% danger, "3" on square = 60%

8. **Penrose** (Aperiodic)
   - Neighbors: Varies (5-7 typically)
   - Wrapping: **IMPOSSIBLE** (non-periodic tiling)
   - Implementation: Use "Periodic Approximant" or visible seam
   - Status: Special non-wrapping mode

---

## 🎮 Core Gameplay Mechanics

### Input System (Mobile-First)

#### Gesture Mapping (Fully Configurable)
| Gesture | Default Action | Alternative Options |
|---------|---------------|---------------------|
| Single Tap | Question Mark | Reveal, Flag, None |
| Double Tap | Flag | Reveal, Question, Cycle |
| Triple Tap | Reveal | Flag, Question |
| Long Press | Custom | Any action or None |
| Pinch | Zoom | - |
| Drag (1-finger) | Pan Camera | - |

**Critical UX Rule**: First tap on blank tile always clears marking ("instant off")

#### Process Button
Auto-clears cells where flagged neighbor count matches the number displayed

### Wrapping System (Toggleable)
- Wrap Left–Right
- Wrap Top–Bottom  
- Fully Wrapped (Torus)
- No Wrapping (Bounded)

**Note**: Penrose mode locks wrapping to OFF

### Win/Lose Conditions
- **Lose**: Reveal a mine
- **Win**: All non-mine cells revealed
- **Optional Strict Mode**: Must flag all mines (not just avoid them)

---

## 🏆 Scoring & Progression

### Metrics
1. **Time**: Primary metric (lower is better)
2. **Process Count**: Number of successful auto-clears
3. **Efficiency**: (mines_found / total_moves) × 100
4. **Grid Complexity Bonus**: Modifier based on grid type + wrapping

### Leaderboards
- Separate boards for each grid type
- Separate boards for wrapping configurations
- Cryptographic seed verification to prevent cheating
- Custom configurations excluded from competitive boards

---

## 💰 Monetization Strategy

### Premium-First Model
- **Base Price**: Free with ethical ads
- **Ad Placement**:
  - Small persistent banner (during gameplay, non-intrusive)
  - Full-screen ad between games
  - Optional ad for hints/undo
- **Ad Removal**: $10-15 one-time purchase
  - Targets the premium puzzle audience
  - No feature paywalls
  - Clean UX for paying customers

### Market Positioning
- **Not competing with**: Candy Crush, casual mobile games
- **Competing with**: Tametsi ($4.99), Hexcells ($2.99), Understand ($5.99)
- **Unique Selling Point**: Topological wrapping + exotic tessellations

---

## 🔧 Technical Implementation

### Scene Structure
```
Main (Node2D)
├── GameLogic (Node)               # Pure data, no visuals
│   └── GridData (Resource)        # Graph structure
├── Camera2D                       # Player viewport
├── InputManager (Control)         # Full-screen gesture detection
└── Visuals (Node2D)
    ├── GridRenderer_Main (MultiMeshInstance2D)
    ├── GridRenderer_Ghost_Left (MultiMeshInstance2D)
    ├── GridRenderer_Ghost_Right (MultiMeshInstance2D)
    ├── GridRenderer_Ghost_Top (MultiMeshInstance2D)
    ├── GridRenderer_Ghost_Bottom (MultiMeshInstance2D)
    └── Ocean_Background (ColorRect w/ shader)
```

### Data Storage Pattern: Struct-of-Arrays (SoA)

**Why**: Memory efficiency for 10,000+ cells on mobile

```gdscript
class_name MinesweeperGraph

# Index = Cell ID
var cell_is_mine: PackedByteArray      # 1 byte per cell
var cell_state: PackedByteArray        # 0=hidden, 1=revealed, 2=flagged
var cell_danger_count: PackedByteArray # 0-8 (or more for exotic grids)
var cell_neighbors: Array[PackedInt32Array]  # Adjacency list
```

**Performance**: 100,000 cells = ~100KB RAM (vs. 100MB+ with Objects)

### Infinite Canvas: The "Ghost Chunk" System

**Principle**: Don't render infinite grids—fake it with visual wrapping

#### Implementation
1. **Data Layer**: Single fixed-size graph (e.g., 20×20)
2. **Visual Layer**: 
   - Render central grid at "real" positions
   - Render 8 "ghost" copies at the edges (only edge cells)
3. **Camera Logic**:
   - Camera moves freely
   - When camera moves far enough, teleport instantly (seamless)
4. **Click Forwarding**:
   - Raycasts detect clicks on ghost cells
   - Ghost cell ID maps to real cell ID
   - Update propagates to all visual instances

**Token-Saving Benefit**: Claude doesn't need to manage complex chunk systems—just simple position offsets

### Grid Rendering Strategy

**DO NOT use individual Sprite2D nodes** (10,000 nodes = death)

**USE MultiMeshInstance2D:**
- 1 draw call for 10,000 instances
- Transforms calculated once at generation
- Perfect for static grids

**Shader Enhancement** (Ocean background):
```glsl
// Simple UV distortion for water ripple effect
vec2 distorted_uv = UV + vec2(sin(TIME + UV.y * 10.0) * 0.01);
```

---

## 🎨 Visual Design Guidelines

### Color Palette (Ocean Theme)
- **Deep Water**: #1a4d6d (mines)
- **Shallow Water**: #4a9fd6
- **Sand**: #e8d4a0
- **Vegetation**: #5c8a3d
- **Stone (Ruins)**: #6b6560

### UI Principles
- Minimalist, no skeuomorphism
- Large touch targets (≥48dp)
- Haptic feedback on all interactions
- Discrete number display (not garish)

### Sound Design (Suggested)
- Stone grinding (tile reveal)
- Water splash (mine hit)
- Gentle waves (ambient, options)
- Satisfying "click" (flag placement)

---

## 📋 Development Roadmap

### Phase 1: Godot Port Foundation (MVP)
- [ ] Set up Godot 4 project structure
- [ ] Implement Graph-based data system
- [ ] Port Square grid with wrapping
- [ ] Implement basic camera pan/zoom
- [ ] Port gesture detection (tap, double-tap, drag, pinch)
- [ ] Implement MultiMesh rendering for square grid
- [ ] Ghost chunk system for infinite wrapping
- [ ] Basic mine generation & reveal logic

### Phase 2: Core Features
- [ ] Add Hexagon grid support
- [ ] Implement flag/question marking
- [ ] Add process button logic
- [ ] Create settings/config system
- [ ] Implement win/lose conditions
- [ ] Add timer & score tracking
- [ ] Ocean/island visual theme
- [ ] ShaderMaterial for water background

### Phase 3: Exotic Grids
- [ ] Cairo Pentagonal grid
- [ ] Rhombille grid
- [ ] Triangular grid
- [ ] Snub Square grid
- [ ] Danger ratio visualization for unfair grids
- [ ] Octasquare grid
- [ ] Penrose grid (non-wrapping)

### Phase 4: Polish & Release
- [ ] Leaderboard system
- [ ] Cryptographic seed verification
- [ ] Ad integration
- [ ] In-app purchase (ad removal)
- [ ] Tutorial/onboarding
- [ ] Settings persistence
- [ ] Platform-specific builds (Android, iOS, PC, Web)
- [ ] Marketing materials (focusing on premium puzzle audience)

---

## 🚨 Critical Edge Cases

### Ghost Chunk Click Forwarding
**Problem**: User clicks a visual ghost cell that represents a real cell
**Solution**:
```gdscript
func _on_ghost_clicked(ghost_id: int, ghost_offset: Vector2i) -> void:
    var real_id = ghost_id  # Ghost ID == Real ID
    var real_cell = get_cell(real_id)
    real_cell.reveal()
    # Update ALL visual instances (main + all ghosts)
    update_visual_for_cell(real_id)
```

### Penrose Neighbor Calculation with Seam
**Problem**: True Penrose tiling cannot wrap, but we want a large play area
**Solutions**:
1. **Periodic Approximant**: Use a rare periodic subset of Penrose tiles
2. **Visible Seam**: Accept broken geometry at edges, theme as "reality fracture"
3. **Bounded Mode**: Simply don't wrap, let edges dissolve into void

**Chosen Approach**: Option 3 (thematic void boundary)

### Hexagon Odd-Width Wrapping Bug
**Problem**: Hexagon rows offset by 0.5—odd widths create zigzag seam
**Solution**: Force map width to EVEN numbers in hex mode
```gdscript
func validate_hex_map_size(size: Vector2i) -> Vector2i:
    if size.x % 2 != 0:
        size.x += 1  # Force even
    return size
```

### Coordinate Normalization (Wrapping Math)
```gdscript
func get_normalized_coord(pos: Vector2i, map_size: Vector2i) -> Vector2i:
    var x = pos.x % map_size.x
    var y = pos.y % map_size.y
    
    # Fix negative modulo
    if x < 0: x += map_size.x
    if y < 0: y += map_size.y
    
    return Vector2i(x, y)
```

---

## 🎓 Design Philosophy Summary

### What This Game IS
- A mathematical simulation with emotional resonance
- A premium product for a small, dedicated audience
- A showcase of exotic geometry made playable
- A "cathedral" built with care, not a quick flip

### What This Game IS NOT
- A casual mobile time-waster
- A game for "gamers" who play AAA titles
- A freemium grind with paywalled features
- A generic Minesweeper clone

### Core Mantra
> "Minesweeper is the Mechanic. The Interface is the Game."

The challenge comes from understanding topological space, not memorizing patterns.

---

## 📚 Reference Materials

### Recommended Reading
- Red Blob Games: Hexagonal Grids (https://www.redblobgames.com/grids/hexagons/)
- Penrose Tiling on Wikipedia
- Godot Docs: MultiMeshInstance2D
- Godot Docs: Touch Input Events

### Inspirational Games
- Tametsi (precise logical deduction)
- Hexcells Infinite (clean minimalist design)
- Understand (premium puzzle pricing)
- The Witness (environmental storytelling through geometry)

---

## 🔐 SEO & Marketing Strategy

### Title Evolution
- **Working Title**: "Minesweeper Edgelord"
- **Proposed Title**: "Ariska: Dead Reckoning"
- **Alternative**: "Dead Reckoning: Infinite"

### Tag Strategy (Steam/App Stores)
Primary: Puzzle, Logic, Minimalist, Minesweeper
Secondary: Abstract, Geometry, Premium, Relaxing
Hidden: Thinky Puzzle, Hex Grid, Topology

### Capsule Art Requirements
- Logo: "ARISKA" in bold geometric font (stone texture)
- Subtitle: "Dead Reckoning" in elegant serif
- Background: Penrose grid dissolving into ocean
- Icon: Small red flag (recognizable Minesweeper callback)

### "Hostile Marketing" Philosophy
Explicitly filter out casual players in the description:
> "This is not your grandmother's Minesweeper. If you found Hexcells 'too easy' and you own a copy of Tametsi, welcome home."

---

## 📞 Notes for Claude Code Integration

When feeding this document to Claude Code, emphasize:

1. **Graph Architecture is LAW**: No 2D arrays for logic, ever
2. **MultiMesh for Rendering**: No individual sprite nodes
3. **SoA for Data**: PackedArrays for memory efficiency
4. **Wrapping = Graph Edges**: Not camera tricks
5. **Start with Square/Hex**: Don't jump to Penrose first

### Suggested First Prompt
```
I am building a Minesweeper game in Godot 4 using the graph-based 
architecture described in TechnicalDesignDocument.md.

Phase 1 Goal: Implement Square grid with torus wrapping.

DO NOT use TileMapLayer or 2D arrays.
DO use the Graph approach with PackedArrays.

Start by creating the GridData resource structure.
```

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Maintainer**: Primary Developer  
**Status**: Godot Port In Progress
