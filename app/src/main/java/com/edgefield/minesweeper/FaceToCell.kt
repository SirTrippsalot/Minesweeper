package com.edgefield.minesweeper

import com.edgefield.minesweeper.graph.Cell

/** Converts a DCEL face into a board cell using vertex keys as IDs. */
internal fun Face.toCell(id: String): Cell {
    val vertices = mutableSetOf<String>()
    var edge = any
    do {
        val key = edge.origin.key
        vertices.add("${key.x}_${key.y}")
        edge = edge.next
    } while (edge !== any)
    return Cell(id = id, vertices = vertices)
}
