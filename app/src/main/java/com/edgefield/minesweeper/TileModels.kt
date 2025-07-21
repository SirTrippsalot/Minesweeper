// ───────────────── TileModels.kt ─────────────────
package com.edgefield.minesweeper

enum class Mark { NONE, QUESTION, FLAG }

enum class GameState { PLAYING, WON, LOST }

enum class GridType {
    SQUARE, TRIANGLE, HEXAGON, OCTASQUARE, CAIRO, RHOMBILLE, SNUB_SQUARE, PENROSE
}

enum class TouchAction {
    REVEAL, FLAG, QUESTION, MARK_CYCLE, NONE
}

data class TouchConfig(
    val singleTap: TouchAction = TouchAction.REVEAL,
    val doubleTap: TouchAction = TouchAction.FLAG,
    val tripleTap: TouchAction = TouchAction.QUESTION,
    val longPress: TouchAction = TouchAction.MARK_CYCLE
)

data class GameConfig(
    val rows: Int = 10,
    val cols: Int = 10,
    val mineCount: Int = 15,
    val gridType: GridType = GridType.SQUARE,
    val edgeMode: Boolean = true,
    val touchConfig: TouchConfig = TouchConfig()
)

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
