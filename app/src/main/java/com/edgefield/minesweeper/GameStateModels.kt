package com.edgefield.minesweeper

/** Holds the serializable state of the game engine. */
data class CellState(
    val id: String,
    val isMine: Boolean,
    val isRevealed: Boolean,
    val isFlagged: Boolean
)

data class EngineState(
    val cells: List<CellState>,
    val gameState: GameState,
    val firstClick: Boolean,
    val stats: GameStats
)
