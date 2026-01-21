package com.edgefield.minesweeper.graph

import com.edgefield.minesweeper.Mark

/**
 * Basic representation of a board cell.
 */
data class Cell(
    val id: String,
    val vertices: Set<String>,
    var isMine: Boolean = false,
    var isRevealed: Boolean = false,
    var mark: Mark = Mark.NONE,
    val neighbors: MutableSet<String> = mutableSetOf()
)

