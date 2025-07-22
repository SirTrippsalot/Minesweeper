package com.edgefield.minesweeper

/** Holds the serializable state of the game engine. */
data class EngineState(
    val board: Array<Array<Tile>>,
    val gameState: GameState,
    val firstClick: Boolean,
    val stats: GameStats
)
