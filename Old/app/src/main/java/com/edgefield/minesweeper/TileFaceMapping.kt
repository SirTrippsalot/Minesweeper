package com.edgefield.minesweeper

import com.edgefield.minesweeper.graph.Cell

/** Helper to create bidirectional mappings between board cells and tiling faces. */
internal fun mapCellsToFaces(
    cells: List<Cell>,
    faces: List<Face>
): Pair<Map<Cell, Face>, Map<Face, Cell>> {
    require(cells.size == faces.size) {
        "Cell count (${cells.size}) must match face count (${faces.size})"
    }
    val cellToFace = mutableMapOf<Cell, Face>()
    val faceToCell = mutableMapOf<Face, Cell>()
    cells.forEachIndexed { idx, cell ->
        val face = faces[idx]
        cellToFace[cell] = face
        faceToCell[face] = cell
    }
    return cellToFace to faceToCell
}
