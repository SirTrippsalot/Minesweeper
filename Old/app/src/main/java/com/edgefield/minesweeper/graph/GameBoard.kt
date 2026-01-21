package com.edgefield.minesweeper.graph

/**
 * Simple graph-based board representation.
 */
class GameBoard {
    val cells: MutableMap<String, Cell> = mutableMapOf()
    val vertexMap: MutableMap<String, MutableSet<String>> = mutableMapOf()

    /**
     * Adds a new cell to the board. Any existing cells sharing at least one
     * vertex are automatically connected as neighbours.
     */
    fun addCell(cell: Cell) {
        if (cells.containsKey(cell.id)) return
        cells[cell.id] = cell
        cell.vertices.forEach { vertex ->
            val ids = vertexMap.getOrPut(vertex) { mutableSetOf() }
            ids.forEach { other -> connect(cell.id, other) }
            ids.add(cell.id)
        }
    }

    /** Connects two cells bidirectionally. */
    fun connect(a: String, b: String) {
        if (a == b) return
        val first = cells[a] ?: return
        val second = cells[b] ?: return
        first.neighbors.add(b)
        second.neighbors.add(a)
    }

    fun getCell(id: String): Cell? = cells[id]

    fun getNeighbors(id: String): Set<Cell> =
        cells[id]?.neighbors?.mapNotNull { cells[it] }?.toSet() ?: emptySet()

    fun countNeighborMines(id: String): Int =
        getNeighbors(id).count { it.isMine }
}

