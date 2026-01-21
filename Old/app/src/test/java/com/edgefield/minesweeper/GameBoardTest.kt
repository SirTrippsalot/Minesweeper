package com.edgefield.minesweeper

import com.edgefield.minesweeper.graph.Cell
import com.edgefield.minesweeper.graph.GameBoard
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GameBoardTest {

    @Test
    fun neighboursLinkedWhenVerticesShared() {
        val board = GameBoard()
        board.addCell(Cell(id = "A", vertices = setOf("v1", "v2", "v3")))
        board.addCell(Cell(id = "B", vertices = setOf("v3", "v4")))

        val aNeighbours = board.getNeighbors("A").map { it.id }
        val bNeighbours = board.getNeighbors("B").map { it.id }

        assertTrue("B" in aNeighbours, "A should link to B")
        assertTrue("A" in bNeighbours, "B should link back to A")
    }

    @Test
    fun countNeighborMinesWorks() {
        val board = GameBoard()
        board.addCell(Cell(id = "A", vertices = setOf("v1", "v2", "v3"), isMine = true))
        board.addCell(Cell(id = "B", vertices = setOf("v3", "v4", "v5")))
        board.addCell(Cell(id = "C", vertices = setOf("v5", "v6"), isMine = true))

        assertEquals(2, board.countNeighborMines("B"), "B should see two mines")
        assertEquals(0, board.countNeighborMines("A"), "A should see no mines")
    }
}

