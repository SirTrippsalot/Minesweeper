package com.edgefield.minesweeper

import graph.buildSquareBoard
import graph.buildTriangleBoard
import graph.buildMixedDemoBoard
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class BoardBuildersTest {
    @Test
    fun squareBoardNeighborCount() {
        val board = buildSquareBoard(3, 3)
        val center = board.getCell("1_1")!!
        assertEquals(8, center.neighbors.size)
    }

    @Test
    fun triangleBoardNeighborCount() {
        val board = buildTriangleBoard(3, 3)
        val center = board.getCell("1_1")!!
        assertEquals(3, center.neighbors.size)
    }

    @Test
    fun mixedBoardIsNotEmpty() {
        val board = buildMixedDemoBoard()
        assertTrue(board.cells.isNotEmpty())
    }
}
