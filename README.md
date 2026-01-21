# Topology Sweeper (Godot Port)
## "Ariska: Dead Reckoning"

A premium topological minesweeper game with exotic tessellations, targeting the "Thinky Puzzle" demographic.

---

## 🎮 Project Status

**Current Phase**: Phase 1 Complete - Foundation Data Structures
**Next Phase**: Phase 2 - Visual Rendering with MultiMesh

### Completed
- ✅ Project structure setup
- ✅ Core data architecture (GridData with Struct-of-Arrays)
- ✅ Grid type system (enum for all tessellations)
- ✅ Base grid generator architecture
- ✅ Square grid generator with full torus wrapping
- ✅ Test scene validating all data structures

### Next Steps
- [ ] MultiMesh rendering system
- [ ] Ocean theme visual styling
- [ ] Ghost chunk system for infinite wrapping illusion
- [ ] Input/gesture detection
- [ ] Game logic (reveal, flag, win/lose)

---

## 🏗️ Architecture Overview

### Core Principles
1. **Graph-Based Logic** - Uses adjacency lists, NOT 2D arrays
2. **Struct-of-Arrays** - Memory-efficient data storage (100KB for 100K cells)
3. **MultiMesh Rendering** - One draw call for 10,000+ tiles
4. **Ocean Metaphor** - Water = mines, Land = safe zones

### Directory Structure
```
res://
├── scripts/
│   ├── core/           # GridData, GridType, GameLogic
│   ├── generators/     # Grid generation for each tessellation
│   ├── rendering/      # MultiMesh visualization (coming soon)
│   └── input/          # Gesture detection (coming soon)
├── scenes/
│   ├── test.tscn       # Current test scene
│   └── main.tscn       # Main game scene (coming soon)
├── assets/
│   ├── textures/
│   └── shaders/
└── resources/
    └── grid_configs/
```

---

## 🚀 Getting Started

### Prerequisites
- Godot 4.3 or later
- Basic understanding of GDScript

### Running the Test Scene
1. Open the project in Godot Editor
2. Press F5 to run the test scene
3. Check the console output for validation results

Expected output:
```
=== Testing Grid Data Structures ===

Test 1: Creating 10×10 square grid with wrapping...
✓ Grid created successfully
  - Type: Square
  - Size: 100 cells
  - Mines: 15
  - Wrapping: H=true V=true

Test 2: Validating neighbor relationships...
✓ All cells have exactly 8 neighbors (correct for wrapped square grid)

...
```

---

## 📚 Key Files

### Core Data Structures
- **[scripts/core/GridData.gd](scripts/core/GridData.gd)** - Main data storage using Struct-of-Arrays
- **[scripts/core/GridType.gd](scripts/core/GridType.gd)** - Enum for all grid types
- **[scripts/generators/GridGenerator.gd](scripts/generators/GridGenerator.gd)** - Base class for grid generation
- **[scripts/generators/SquareGridGenerator.gd](scripts/generators/SquareGridGenerator.gd)** - Square grid implementation

### Test & Documentation
- **[scripts/TestGrid.gd](scripts/TestGrid.gd)** - Validation tests for data structures
- **[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)** - Complete development roadmap

### Design Documents (in New Design Docs/)
- **TechnicalDesignDocument.md** - Overall vision and architecture
- **ArchitectureImplementationGuide.md** - Godot-specific patterns
- **GridMathematicsReference.md** - Coordinate systems for all grids
- **GameFeaturesAndUnlocks.md** - Tech tree and progression system

---

## 🎯 Design Goals

### Target Audience
- 50,000–100,000 players globally
- Logic puzzle enthusiasts who found "Hexcells too easy"
- Owners of Tametsi, Understand, 14 Minesweeper Variants

### Unique Selling Points
1. **Exotic Grids** - Square, Hex, Cairo, Penrose, and more
2. **Topological Wrapping** - True torus topology (infinite ocean)
3. **Progressive Unlocks** - Scanner modes earned through skill challenges
4. **Ocean Theme** - Minimalist nautical aesthetic
5. **Premium Quality** - $10-15 IAP, no feature paywalls

---

## 🔧 Technical Highlights

### Graph-Based Architecture
All game logic uses adjacency lists instead of 2D arrays:
```gdscript
# Each cell stores its neighbor IDs
var cell_neighbors: Array[PackedInt32Array]

# Get neighbors (works for ANY grid type)
func get_neighbors(cell_id: int) -> PackedInt32Array:
    return cell_neighbors[cell_id]
```

**Why?** This approach works for all tessellations, including exotic grids like Penrose that don't have regular coordinate systems.

### Memory Efficiency
Using PackedArrays for 100,000 cells:
- **With objects**: ~100MB RAM
- **With Struct-of-Arrays**: ~100KB RAM

### Performance Targets
- **Mobile**: 60 FPS with 10,000 cells
- **Desktop**: 60 FPS with 50,000+ cells
- **Memory**: < 150MB total

---

## 📖 Documentation

All design documents are in the [New Design Docs/](New Design Docs/) folder:

1. **TechnicalDesignDocument.md** - Start here for full vision
2. **ArchitectureImplementationGuide.md** - Code patterns and examples
3. **GridMathematicsReference.md** - Math for all grid types
4. **KeyInsightsAndGotchas.md** - Lessons learned and pitfalls
5. **GameFeaturesAndUnlocks.md** - Progression system design
6. **AGENTS.md** - Coding guidelines and conventions

---

## 🚨 Critical Rules

1. **NEVER use 2D arrays for logic** - Graph approach is LAW
2. **NEVER use individual Sprite2D nodes** - MultiMesh only
3. **Force even width for hex grids** - Prevents zigzag seam
4. **Pre-calculate neighbors once** - Don't recalculate per frame
5. **Use PackedArrays** - Not Dictionaries
6. **Penrose cannot wrap** - Accept bounded mode

---

## 🎨 Visual Theme

### Ocean Metaphor
- **Water (Blue)** = Danger zones (mines)
- **Sand (Tan)** = Cells touching water (danger > 0)
- **Vegetation (Green)** = Deep safety (danger = 0)

### Biome Progression
1. **Open Sea** (Square/Hex) - Calm, infinite, meditative
2. **Sunken Ruins** (Cairo/Rhombille) - Stone textures, walls
3. **Continental Shelf** (Penrose/Snub) - Reality-breaking geometry

---

## 📊 Development Roadmap

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for complete breakdown.

**Phase 1**: ✅ Foundation (Complete)
**Phase 2**: Visual Rendering
**Phase 3**: Input System
**Phase 4**: Hexagon Grid
**Phase 5**: Game Logic
**Phase 6**: Exotic Grids
**Phase 7**: Tech Unlocks
**Phase 8**: Polish & Release

---

## 🤝 Contributing

This is a solo project, but insights and suggestions are welcome! Please ensure:
- All code follows the patterns in ArchitectureImplementationGuide.md
- Graph-based architecture is preserved
- No 2D arrays for game logic
- Performance targets are maintained

---

## 📄 License

TBD - Likely commercial release with premium pricing ($10-15)

---

## 🎯 Quick Start Commands

```bash
# Open in Godot Editor
godot

# Run test scene
godot --path . scenes/test.tscn

# Run main scene (when available)
godot --path . scenes/main.tscn
```

---

**Status**: Phase 1 Complete - Foundation Solid ✅
**Next Action**: Implement MultiMesh rendering (Phase 2)
**Version**: 0.1.0-alpha
**Last Updated**: January 2026
