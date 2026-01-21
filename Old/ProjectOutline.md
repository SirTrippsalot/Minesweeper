## 🎮 Game Title: **"Minesweeper Edgelord"**

> *"Minesweeper meets geometry nightmares."*

---

## 🧩 Core Features

### ✅ Classic Minesweeper Foundations
- Tap: reveal cell
- Flag: mark mine candidate
- Question: uncertain mark
- Mine count + flag count displayed
- Lose on mine, win when all safe cells revealed

---

## 🔶 Grid Types (Tiling Modes)

Each tiling has unique neighbor logic and geometry:

| Grid Type     | Shape Description                      | Neighbors |
|---------------|----------------------------------------|-----------|
| **Square**     | Classic 2D Minesweeper                 | 4 or 8    |
| **Triangle**   | Alternating upright/inverted triangles | 3 or 6    |
| **Hexagon**    | Uniform hex grid                       | 6         |
| **Octasquare** | Alternating squares and octagons       | 8 (varies)|
| **Cairo**      | Flat-tessellating pentagons            | 5         |
| **Rhombille**  | Diamond grid, triangle adjacency       | 6         |
| **Snub Square**| Twisted mix of squares + triangles     | 5 or more |
| **Penrose**    | Quasiperiodic non-repeating tiling     | Varies, not wrap-able |

🎯 Additional tilings may unlock progressively. Penrose is reserved for chaos mode and cannot be wrapped due to its non-periodic nature.

---

## 🧠 Edge Logic (Wrapping Options)
Toggleable per edge:
- **Wrap Left–Right**
- **Wrap Top–Bottom**
- **Fully Wrapped (Torus)**
- **No Wrapping (Standard Bounded)**

Each wrap config alters neighbor logic dynamically.

Note: **Penrose tiling cannot be wrapped**, due to its mathematical quasiperiodicity — it lacks translational symmetry.

---

## ⏱️ Scoring System

| Metric           | Description                                                   |
|------------------|---------------------------------------------------------------|
| **Time**          | Base metric; lower is better                                  |
| **Process Count** | # of “flag-to-clear” operations — a correct flagged cell revealed |
| **Efficiency**    | (mines found / total moves) x 100                             |
| **Grid Bonus**    | Based on complexity of grid shape or wrap options             |

🏅 **Leaderboards** exist for each grid type and configuration (excluding custom). Design encourages participation while reducing incentive to cheat — likely through cryptographic seed verification and anonymized score logs.

---

## 💰 Monetization Model

- **No feature paywalls** — all gameplay is fully available
- **Small persistent banner** during gameplay (non-intrusive)
- **Full-screen ad** shown **between games**
- **Full-screen ad** on **optional hint or undo** requests
- **"Ad-Free Upgrade"** for **$2.99**:
  - Removes all ads
  - Honors clean UX for paying users

This approach maintains ethical monetization while covering costs and allowing light rewards.

---

## 🤏 Touch Interaction System (Configurable)

### 🧑‍💻 Default Controls

| Gesture       | Action                     | Behavior |
|---------------|----------------------------|----------|
| **Single Tap**   | Question mark               | Light mark, unsure guess |
| **Double Tap**   | Flag mark (mine)            | Confident mine mark |
| **Triple Tap**   | Clear / Reveal              | Full click, triggers tile |
| **Long Press**   | Alternate function (e.g., cancel mark or inspect mode) | Reserved for customization |
| **Pinch Zoom**   | Zoom in/out                 | Dynamic grid scaling |
| **Drag (1-finger)** | Pan/move grid               | For larger or zoomed boards |
| **Process Button** | Confirm marked tiles        | Auto-clear if numbers match flags |

First tap on blank tile always acts as instant "off" (no need to cycle).

### 🔧 Configurable Gesture Mapping
Users can assign any of the following to each gesture:
- **Reveal (Clear)**
- **Flag**
- **Question Mark**
- **Mark Cycle (Flag → ? → Off)**
- **None / Disabled**
- **Process Tile** *(optional gesture trigger, if not using button)*

Mapping UI example:

| Gesture      | Assigned Action    |
|--------------|--------------------|
| Single Tap   | Question Mark      |
| Double Tap   | Flag               |
| Triple Tap   | Reveal             |
| Long Press   | Custom (None by default) |

---

## 📱 Touch UX Defaults

| Feature        | Default Behavior    |
|----------------|---------------------|
| Zoom           | Pinch               |
| Pan            | One-finger drag     |
| Tap Target     | ≥ 48dp              |
| Haptics        | On mark/reveal      |
| First Action   | Always disables tile marking ("instant off") |

---

## 📐 Interface & UX

- Dynamic grid scaling
- On-screen toggles:
  - Restart
  - Settings
  - Toggle flag mode
  - Mine counter
  - Timer
  - Process count
  - Grid type + wrap status overlay

### Grid Preview Mode
- Preview shown during grid selection and difficulty setup (in settings)
- Available for all preset grid types and difficulties
- **Custom mode** excluded from leaderboards

### Play Mode
- Active gameplay state with all interactive functionality

