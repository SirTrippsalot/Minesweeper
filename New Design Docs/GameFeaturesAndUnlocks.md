# Game Features & Tech Unlocks
## The "Ariska Protocol" - Progressive Mastery System

This document defines the progression system, unlockable technologies, and advanced features that transform Topology Sweeper from a puzzle game into a mastery journey.

---

## 🎯 Design Philosophy: Earned, Never Bought

**Core Principle**: Every unlock must be earned through demonstrated skill, never purchased.

**Why**: In a logic game, knowledge is the only currency. Buying power-ups would cheapen the experience and betray the "Thinky Puzzle" audience.

**Implementation**: Unlocks are gated behind specific challenge completions that prove the player understands the systems they're about to gain access to.

---

## 📡 The Scanner Tech Tree

### Base State: Mk.I Contact Sensor (Default)

**Adjacency Mode**: Edge/Contact Only (Von Neumann for squares, standard for other grids)

**Lore**: "Detects vibrational anomalies through direct physical contact with the substrate."

**Gameplay**: 
- Square: 4 neighbors
- Hexagon: 6 neighbors
- Triangle: 3 neighbors
- Clean, orthogonal logic chains

---

### Unlock 1: Mk.II Field Sensor (Vertex/Moore Mode)

#### The Technology
**Adjacency Mode**: Vertex/Corner detection enabled

**Lore**: "Detects subspace radiation bleeding through geometric singularities (corners). Experimental technology - use with caution."

**Gameplay Impact by Grid**:

| Grid Type | Contact Mode | Field Mode | Difficulty Change |
|-----------|--------------|------------|-------------------|
| Square | 4 neighbors | 8 neighbors | **EASIER** (standard Minesweeper) |
| Hexagon | 6 neighbors | 6 neighbors | **NO CHANGE** (vertices = edges) |
| Triangle | 3 neighbors | 12 neighbors | **MUCH HARDER** (information overload) |
| Cairo | 5 neighbors | 8-10 neighbors | **HARDER** (variable counts) |
| Penrose | 3-5 neighbors | 7-14 neighbors | **NIGHTMARE** (chaotic variance) |

#### The Unlock Challenge: "Chaos Theory"

**Location**: Found in the Ruins biome (Cairo grid)

**Discovery**: Black Monolith tile surrounded by Logic Gates

**Challenge Requirements**:
- Grid: 15×15 Triangle grid
- Density: 20% mines
- Mode: Field Scanner ACTIVE (you test the tech before earning it)
- Constraint: Must complete with < 5% error rate

**Lesson Taught**: High information density requires careful parsing. The player must learn to read "7" on a triangle and understand what that means before they get permanent access.

**Reward**: Toggle appears in UI - "Scanner Mode: [Contact] / [Field]"

#### Visual/Audio Feedback

**Toggle Sound**: Heavy analog "CLUNK-HISS" (like night vision goggles)

**Visual Changes (Field Mode Active)**:
- Grid lines gain subtle glow (bloom shader)
- Faint connection lines appear at corners
- Numbers change instantly (2 → 5)
- Color shift: Blue-tinted overlay

**UI Indicator**: Scanner icon in corner shows current mode

---

### Unlock 2: Seismic Actuator (Auto-Chord)

#### The Technology
**Mechanic**: Classic Minesweeper "chording" - click a satisfied number to auto-reveal remaining neighbors

**Example**:
```
[3] surrounded by [F][F][F] and 5 unrevealed
Click the [3] → Auto-reveals all 5 unrevealed neighbors
```

**Lore**: "Hydraulic pistons that automatically collapse unstable rock formations once structural supports (flags) are verified."

**Gameplay**: Enables speed-solving and chain reactions

#### The Unlock Challenge: "The Cascade Protocol"

**Challenge Requirements**:
- Grid: 30×30 Hexagon
- Density: 10% mines (LOW - encourages chording)
- Time Limit: 60 seconds
- Goal: Clear 500 tiles

**Why This Is Hard**: It's physically impossible to click 500 tiles individually in 60 seconds. You MUST use pattern recognition and plan chord chains.

**Lesson Taught**: Speed comes from logic optimization, not clicking speed. Forces players to think several moves ahead.

**Reward**: Chord action becomes available (default: Ctrl+Click or configurable gesture)

---

### Unlock 3: Ablative Hull Plating (Second Chance)

#### The Technology
**Mechanic**: Absorbs ONE mine detonation per run

**What Happens**:
1. Player clicks mine
2. Screen shakes violently
3. Armor icon shatters
4. Mine tile becomes "SLAG" (dead, inert, reveals nothing)
5. Game continues

**Lore**: "Sacrificial ceramic plates designed to direct blast force outward. Single-use expendable armor."

**Strategic Depth**: Do you use it aggressively (risky clicks) or save it as insurance (conservative play)?

#### The Unlock Challenge: "The Minefield"

**Challenge Requirements**:
- Grid: 8×8 Snub Square
- Density: 35% mines (EXTREMELY HIGH)
- Constraint: NO ARMOR (you don't get to use it in the test)
- Goal: Complete without hitting any mine

**Why This Is Brutal**: Snub Square has neighbor variance (triangles vs. squares) AND the density is punishing. Every click is a calculation.

**Lesson Taught**: To earn the right to make a mistake, you must first prove you can survive without making one.

**Reward**: Hull Plating icon appears in UI (recharges each new game)

---

### Unlock 4: Resonance Buoy (Area Density Scan)

#### The Technology
**Mechanic**: Consumable item (carry max 3 per run)

**Effect**: Reveals total mine count in 5×5 area (not locations)

**Use Case**: In infinite mode, helps decide if an island is worth exploring

**Example**:
```
Deploy buoy at center of unexplored 5×5 region
Returns: "12 mines detected"
You now know: This area is 48% mines (dangerous)
```

**Lore**: "Low-frequency sonar ping. Returns aggregate density data of the substrate."

#### The Unlock Challenge: "The Dark Room"

**Challenge Requirements**:
- Grid: 20×20 Square
- Mechanic: **FOG OF WAR** - All numbers hidden as "?"
- Only reveals: Cells with 0 adjacent mines show actual "0"
- Buoys: You get 5 buoys to use during challenge
- Goal: Clear the grid using only density intuition

**Why This Teaches Density Thinking**: Without seeing individual numbers, you must reason probabilistically about regions.

**Lesson Taught**: Area density scanning is about strategic reconnaissance, not brute force information gathering.

**Reward**: Buoys become available as consumable (max 3, recharge on new game)

---

## 🎮 Advanced Game Modes

### 1. Edge Wrapping Variants

**Current Implementation**: Binary toggle (wrap ON/OFF)

**Proposed Enhancement**: Granular control

#### Wrapping Options
- **None**: Standard bounded grid
- **Horizontal Only**: Left edge connects to right
- **Vertical Only**: Top connects to bottom
- **Full Torus**: Both axes wrap
- **Klein Bottle**: Horizontal wraps normally, vertical wraps with flip

**UI Design**: Visual preview showing how edges connect

**Strategic Impact**: Different wrapping changes safe/danger zones

---

### 2. The "Simulation Chamber" (Challenge Hub)

**Purpose**: Dedicated area for tech unlock challenges and skill tests

**Narrative Frame**: You're not in the "real" ocean - this is a controlled environment for testing

**Structure**:
```
Main Hub (Infinite Ocean)
    └── Simulation Chamber Access Point
        ├── "Chaos Theory" (Field Scanner)
        ├── "Cascade Protocol" (Actuator)
        ├── "The Minefield" (Hull Plating)
        ├── "Dark Room" (Resonance Buoy)
        └── [Future challenges]
```

**Visual Design**: 
- Sterile, geometric architecture (contrast to organic ocean)
- Glowing wireframe grids
- Holographic UI elements

---

### 3. Infinite Ocean Mode (Post-Tutorial)

#### Core Loop
1. Start on small safe island (guaranteed 0-neighbors)
2. Expand outward into procedurally generated infinite grid
3. Discover "landmarks" (Monoliths, Simulation Chambers, etc.)
4. Accumulate score based on safe tiles revealed

#### Landmarks System

**Monolith** (Tech unlock location)
- Appears every ~500 revealed tiles
- Surrounded by Logic Gate puzzle
- Grants new tech on completion

**Supply Cache**
- Appears every ~200 tiles
- Restores consumables (Buoys, future items)
- Requires clearing surrounding area first

**Density Anomaly**
- Random high-density pockets (35%+ mines)
- Marked with visual distortion
- High risk, high reward (bonus points)

#### Infinite Grid Generation
- Uses seeded procedural generation
- Chunks generate on-demand as camera moves
- Previous chunks can be revisited (stored in save)
- Wrapping works via ghost chunks as designed

---

## 🎯 Difficulty Modifiers (Post-Launch Ideas)

### 1. "Pressure" Mode
- Timer counts DOWN instead of up
- Must clear X tiles before time expires
- Unlocks: Earn time extensions by chording

### 2. "Fragile" Mode
- Hull Plating removed
- One mistake = game over
- Pure skill test

### 3. "Blind" Mode
- All numbers hidden until cell is clicked
- Ultimate memory/logic test
- Unlocks: After beating each grid type on Hard

### 4. "Corrupted" Mode
- Random cells have incorrect numbers (5% error rate)
- Must use redundancy checking to detect lies
- Advanced logical reasoning

---

## 📊 Scoring & Leaderboards (Expanded)

### Per-Grid Leaderboards

**Tracked Metrics**:
1. Time (fastest clear)
2. Efficiency (mines found / total moves)
3. Process Count (successful chords)
4. Perfect Runs (zero mistakes with Hull Plating unused)

**Separate Boards For**:
- Grid Type (Square, Hex, Triangle, etc.)
- Scanner Mode (Contact vs. Field)
- Wrapping Configuration (None, H, V, Full)
- Difficulty Preset (Easy, Medium, Hard, etc.)

**Anti-Cheat**:
- Cryptographic seed verification
- Replay validation
- Anomaly detection (impossible solve speeds)

---

## 🎨 Visual/UX for Tech System

### Tech Unlocked Notification

```
[SCREEN FLASH]
┌─────────────────────────────────────────┐
│  FIRMWARE UPDATE ACQUIRED               │
│                                         │
│  [SCANNER ICON]                         │
│  Mk.II FIELD SENSOR                     │
│                                         │
│  "Reality bends at the corners"         │
│                                         │
│  Press [TAB] to toggle scanner modes    │
└─────────────────────────────────────────┘
[CODE SCROLLS IN BACKGROUND]
```

**Sound**: Deep bass note + digital chirps

### Active Tech Indicator (HUD)

```
┌────────────────────────────────┐
│ ⚡ Scanner: FIELD              │
│ 🛡️ Hull: ACTIVE                │
│ 📡 Buoys: [●●○] 2/3            │
└────────────────────────────────┘
```

**Placement**: Top-right corner, minimal

### Settings Integration

**Tech Tab**:
- Toggle acquired techs ON/OFF (for challenge runs)
- Rebind hotkeys
- View tech lore/descriptions

---

## 🔬 Future Tech Ideas (Post-Launch Expansion)

### 1. "Quantum Probe"
- Reveals mine/safe status without opening
- Consumable (1 per game)
- Challenge: "Schrödinger's Grid" (all cells quantum until observed)

### 2. "Temporal Echo"
- Undo last 3 moves
- One-time use per game
- Challenge: Timed speedrun with intentional traps

### 3. "Phase Shift"
- Temporarily ignore one mine (phase through it)
- Reveals number as if mine wasn't there
- Challenge: Grid where 50% of tiles are phased mines

### 4. "Neural Mesh"
- Auto-flags obvious mines (100% deduction only)
- QoL for late-game large grids
- Challenge: 50×50 grid with no other assists

---

## 🎓 Progression Curve Design

### Tutorial → Mastery Path

```
Chapter 1: The Shallows (Tutorial)
├─ Square grid basics (8-neighbor)
├─ Flag/question mechanics
└─ First win → Unlock Hex grid

Chapter 2: Deeper Waters
├─ Hex grid mastery
├─ Triangle grid introduction
└─ Complete Triangle → Unlock Field Scanner challenge

Chapter 3: The Ruins
├─ Cairo/Rhombille grids
├─ Wall/obstacle mechanics
└─ Complete Cairo puzzle → Unlock Actuator challenge

Chapter 4: The Shelf
├─ Snub Square variance training
├─ Octasquare introduction
└─ Survive Minefield → Unlock Hull Plating

Chapter 5: The Abyss
├─ Penrose chaos
├─ All systems online
└─ Infinite Ocean unlocked

Endgame: Mastery Challenges
├─ Speed runs
├─ Perfect clears
├─ Custom mutator combinations
```

---

## 🎯 Implementation Priority

### Phase 1 (MVP)
- [x] Basic scanner toggle (Contact/Field)
- [ ] Field Scanner unlock challenge
- [ ] Visual feedback for scanner mode
- [ ] Settings to enable/disable unlocked tech

### Phase 2 (Core Features)
- [ ] Simulation Chamber hub
- [ ] Actuator (Chording) unlock + challenge
- [ ] Hull Plating unlock + challenge
- [ ] Monolith landmark system

### Phase 3 (Depth)
- [ ] Resonance Buoy unlock + challenge
- [ ] Infinite Ocean mode
- [ ] Leaderboards integration
- [ ] Replay system

### Phase 4 (Polish)
- [ ] Advanced difficulty mutators
- [ ] Achievement system
- [ ] Daily challenges
- [ ] Community seed sharing

---

## 💡 Design Insights from Spitballing Session

### The "Scanner as Tech" Breakthrough

**Original Problem**: How to justify different neighbor modes (Edge vs. Vertex)?

**Solution**: Frame it as equipment upgrades rather than arbitrary settings

**Benefits**:
1. **Diegetic**: Feels like part of the world, not a menu option
2. **Progressive**: Unlocks complexity gradually
3. **Strategic**: Players can choose when to use advanced tools
4. **Rewarding**: Unlocks feel earned, not granted

### The "Certification Exam" Pattern

**Key Insight**: To unlock a tool, you must first prove you can handle its consequences

**Why This Works**:
- Prevents players from unlocking tools they're not ready for
- Creates "aha!" moments when the unlock suddenly makes sense
- Natural difficulty curve (harder challenges = better rewards)

### The "Monkey's Paw" Upgrades

**Philosophy**: Not all upgrades make things easier

**Examples**:
- Field Scanner on Squares → Easier (8 neighbors)
- Field Scanner on Triangles → Harder (12 neighbors)

**Design Lesson**: Tools that increase complexity are interesting if they're optional and earned

---

## 🎮 Player Journey Example

```
Day 1: Alice starts the game
├─ Completes tutorial (Square grid)
├─ Tries Hex (wow, this is different)
└─ Unlocks Triangle grid

Day 3: Alice is getting good
├─ Tries Triangle grid
├─ "Only 3 neighbors? This is hard!"
└─ Discovers Monolith in Cairo grid

Day 5: The Field Scanner challenge
├─ Enters "Chaos Theory" simulation
├─ "Oh no, 12 neighbors on triangles!"
├─ Fails 3 times
└─ Success! Scanner unlocked

Day 7: Experimentation
├─ Tries Field mode on Squares
├─ "Oh! This is normal Minesweeper!"
├─ Tries Field on Penrose
└─ "This is madness" (turns it back off)

Day 10: The Cascade
├─ Finds Actuator challenge
├─ "60 seconds? Impossible!"
├─ Learns to plan chord chains
└─ Unlocks chording, becomes speed demon

Day 14: The Minefield
├─ "35% density? That's suicide!"
├─ Spends hour learning Snub Square variance
├─ Clears it perfectly
└─ "I earned this armor"

Day 30: Master of the Ocean
├─ All tech unlocked
├─ Infinite mode mastered
├─ Helps new players on Discord
└─ Suggests new grid types to developer
```

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Status**: Feature Design - Ready for Implementation
**Dependencies**: Requires core graph architecture + MultiMesh rendering
