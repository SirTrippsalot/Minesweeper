package com.edgefield.minesweeper

import android.content.Context

object PrefsManager {
    private const val PREFS_NAME = "minesweeper_prefs"

    private const val KEY_BOARD = "board"
    private const val KEY_STATE = "state"
    private const val KEY_FIRST_CLICK = "first_click"
    private const val KEY_START_TIME = "start_time"
    private const val KEY_END_TIME = "end_time"
    private const val KEY_PROCESS_COUNT = "process_count"
    private const val KEY_TOTAL_MOVES = "total_moves"
    private const val KEY_MINES_FOUND = "mines_found"

    fun loadGameConfig(context: Context): GameConfig {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rows = prefs.getInt("rows", 10)
        val cols = prefs.getInt("cols", 10)
        val difficultyName = prefs.getString("difficulty", Difficulty.MEDIUM.name) ?: Difficulty.MEDIUM.name
        val difficulty = Difficulty.valueOf(difficultyName)
        val customMines = prefs.getInt("customMines", 15)
        val usePercent = prefs.getBoolean("useMinePercent", false)
        val gridTypeName = prefs.getString("gridType", GridType.SQUARE.name) ?: GridType.SQUARE.name
        val gridType = GridType.valueOf(gridTypeName)
        val edgeMode = prefs.getBoolean("edgeMode", true)
        val singleTap = prefs.getString("singleTap", TouchAction.QUESTION.name) ?: TouchAction.QUESTION.name
        val doubleTap = prefs.getString("doubleTap", TouchAction.FLAG.name) ?: TouchAction.FLAG.name
        val tripleTap = prefs.getString("tripleTap", TouchAction.REVEAL.name) ?: TouchAction.REVEAL.name
        val longPress = prefs.getString("longPress", TouchAction.NONE.name) ?: TouchAction.NONE.name
        val touchConfig = TouchConfig(
            singleTap = TouchAction.valueOf(singleTap),
            doubleTap = TouchAction.valueOf(doubleTap),
            tripleTap = TouchAction.valueOf(tripleTap),
            longPress = TouchAction.valueOf(longPress)
        )
        return GameConfig(
            rows = rows,
            cols = cols,
            difficulty = difficulty,
            customMines = customMines,
            useMinePercent = usePercent,
            gridType = gridType,
            edgeMode = edgeMode,
            touchConfig = touchConfig
        )
    }

    fun saveGameConfig(context: Context, config: GameConfig) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt("rows", config.rows)
            .putInt("cols", config.cols)
            .putString("difficulty", config.difficulty.name)
            .putInt("customMines", config.customMines)
            .putBoolean("useMinePercent", config.useMinePercent)
            .putString("gridType", config.gridType.name)
            .putBoolean("edgeMode", config.edgeMode)
            .putString("singleTap", config.touchConfig.singleTap.name)
            .putString("doubleTap", config.touchConfig.doubleTap.name)
            .putString("tripleTap", config.touchConfig.tripleTap.name)
            .putString("longPress", config.touchConfig.longPress.name)
            .apply()
    }

    fun saveGameState(context: Context, state: EngineState) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_BOARD, serializeCells(state.cells))
            .putString(KEY_STATE, state.gameState.name)
            .putBoolean(KEY_FIRST_CLICK, state.firstClick)
            .putLong(KEY_START_TIME, state.stats.startTime)
            .putLong(KEY_END_TIME, state.stats.endTime ?: -1L)
            .putInt(KEY_PROCESS_COUNT, state.stats.processCount)
            .putInt(KEY_TOTAL_MOVES, state.stats.totalMoves)
            .putInt(KEY_MINES_FOUND, state.stats.minesFound)
            .apply()
    }

    fun loadGameState(context: Context, config: GameConfig): EngineState? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val boardData = prefs.getString(KEY_BOARD, null) ?: return null
        val cells = deserializeCells(boardData)
        if (cells.size != config.rows * config.cols) return null
        val stats = GameStats(
            startTime = prefs.getLong(KEY_START_TIME, System.currentTimeMillis()),
            endTime = prefs.getLong(KEY_END_TIME, -1L).let { if (it == -1L) null else it },
            processCount = prefs.getInt(KEY_PROCESS_COUNT, 0),
            totalMoves = prefs.getInt(KEY_TOTAL_MOVES, 0),
            minesFound = prefs.getInt(KEY_MINES_FOUND, 0)
        )
        val gameState = GameState.valueOf(prefs.getString(KEY_STATE, GameState.PLAYING.name)!!)
        val firstClick = prefs.getBoolean(KEY_FIRST_CLICK, true)
        return EngineState(cells, gameState, firstClick, stats)
    }

    fun clearGameState(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .remove(KEY_BOARD)
            .remove(KEY_STATE)
            .remove(KEY_FIRST_CLICK)
            .remove(KEY_START_TIME)
            .remove(KEY_END_TIME)
            .remove(KEY_PROCESS_COUNT)
            .remove(KEY_TOTAL_MOVES)
            .remove(KEY_MINES_FOUND)
            .apply()
    }

    private fun serializeCells(cells: List<CellState>): String {
        return cells.joinToString("|") { cell ->
            listOf(
                cell.id,
                if (cell.isMine) "1" else "0",
                if (cell.isRevealed) "1" else "0",
                if (cell.isFlagged) "1" else "0"
            ).joinToString(",")
        }
    }

    private fun deserializeCells(data: String): List<CellState> {
        if (data.isBlank()) return emptyList()
        return data.split('|').map { entry ->
            val parts = entry.split(',')
            CellState(
                id = parts[0],
                isMine = parts.getOrNull(1) == "1",
                isRevealed = parts.getOrNull(2) == "1",
                isFlagged = parts.getOrNull(3) == "1"
            )
        }
    }
}
