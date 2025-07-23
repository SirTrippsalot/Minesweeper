package com.edgefield.minesweeper.graph

/**
 * Basic representation of a board cell.
 */
data class Cell(
    val id: String,
    val vertices: Set<String>,
    var isMine: Boolean = false,
    var isRevealed: Boolean = false,
    var isFlagged: Boolean = false,
    var isMarked: Boolean = false,
    val neighbors: MutableSet<String> = mutableSetOf()
)

