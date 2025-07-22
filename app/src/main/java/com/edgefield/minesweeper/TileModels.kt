// ───────────────── TileModels.kt ─────────────────
package com.edgefield.minesweeper

enum class Mark { NONE, QUESTION, FLAG }

enum class GameState { PLAYING, WON, LOST }

enum class GridType {
    SQUARE, TRIANGLE, HEXAGON, OCTASQUARE, CAIRO, RHOMBILLE, SNUB_SQUARE, PENROSE
}

enum class Difficulty(val percent: Int) {
    VERY_EASY(5),
    EASY(10),
    MEDIUM(15),
    HARD(20),
    VERY_HARD(25),
    HARDEST(30),
    CUSTOM(15)
}

val GridType.kind: GridKind
    get() = GridKind.valueOf(name)

enum class TouchAction {
    REVEAL, FLAG, QUESTION, MARK_CYCLE, NONE
}

data class TouchConfig(
    val singleTap: TouchAction = TouchAction.MARK_CYCLE,
    val doubleTap: TouchAction = TouchAction.FLAG,
    val tripleTap: TouchAction = TouchAction.REVEAL,
    val longPress: TouchAction = TouchAction.NONE
)

data class GameConfig(
    val rows: Int = 10,
    val cols: Int = 10,
    val difficulty: Difficulty = Difficulty.MEDIUM,
    val customMines: Int = 15,
    val useMinePercent: Boolean = false,
    val gridType: GridType = GridType.SQUARE,
    val edgeMode: Boolean = true,
    val touchConfig: TouchConfig = TouchConfig()
) {
    val mineCount: Int
        get() {
            val cells = rows * cols
            return when (difficulty) {
                Difficulty.CUSTOM -> {
                    if (useMinePercent) {
                        (cells * customMines / 100.0).toInt().coerceIn(1, cells - 1)
                    } else {
                        customMines.coerceIn(1, cells - 1)
                    }
                }
                else -> (cells * difficulty.percent / 100).coerceIn(1, cells - 1)
            }
        }
}

data class GameStats(
    val startTime: Long = System.currentTimeMillis(),
    var endTime: Long? = null,
    var processCount: Int = 0,
    var totalMoves: Int = 0,
    var minesFound: Int = 0
) {
    val elapsedTime: Long get() = (endTime ?: System.currentTimeMillis()) - startTime
    val efficiency: Double get() = if (totalMoves > 0) (minesFound.toDouble() / totalMoves) * 100.0 else 0.0
}

data class Tile(
    val x: Int,
    val y: Int,
    var hasMine: Boolean = false,
    var revealed: Boolean = false,
    var mark: Mark = Mark.NONE,
    var adjMines: Int = 0
)
