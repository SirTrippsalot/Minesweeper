# Minesweeper Edgelord

A Jetpack Compose implementation of Minesweeper with multiple grid types and optional edge wrapping.

## Prerequisites

- Android Studio Hedgehog or newer, **or** a command-line setup with the Android SDK.
- JDK 8+ (the project targets Java 8) and Kotlin 1.9.23.
- No separate Gradle installation is required; the project ships with the Gradle wrapper.

## Build and Run

Use the Gradle wrapper to build the debug APK:

```bash
./gradlew assembleDebug
```

Install it on a connected device or emulator:

```bash
./gradlew installDebug
```

You can also open the project in Android Studio and run it directly from the IDE.

## Features

- Classic reveal/flag/question gameplay.
- Several board layouts: Square, Triangle, Hexagon, Octasquare, Cairo, Rhombille, Snub Square and Penrose.
- Configurable edge wrapping (left/right, top/bottom or full torus).
- Gesture-based controls with zoom and pan support.
- Settings are saved between sessions.
- Flags appear as darker water and return to gray when removed.
- Revealed tiles show water or sand textures.

### Selecting a Grid Type

Open the Settings screen and pick one of the available tilings. Wrapping options can be toggled per edge. Penrose grids do not support wrapping.
