package com.edgefield.minesweeper

import android.content.Context

object PrefsManager {
    private const val PREFS_NAME = "minesweeper_prefs"

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
        val singleTap = prefs.getString("singleTap", TouchAction.MARK_CYCLE.name) ?: TouchAction.MARK_CYCLE.name
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
}
