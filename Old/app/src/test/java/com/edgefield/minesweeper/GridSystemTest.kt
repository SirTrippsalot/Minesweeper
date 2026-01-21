package com.edgefield.minesweeper

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Basic integration test for [GridSystem].
 */
class GridSystemTest {


    @Test
    fun neighborCountAcrossGrids() {
        GridKind.values().forEach { kind ->
            val tiling = GridFactory.build(kind, 3, 3)
            val centerFace = tiling.faces[4]
            val count = tiling.neighbours(centerFace).size
            assertEquals(kind.neighborCount, count, "${kind.name} neighbor count")
        }
    }

    @Test
    fun faceCountAcrossGrids() {
        GridKind.values().forEach { kind ->
            val tiling = GridFactory.build(kind, 3, 3)
            assertEquals(9, tiling.faces.size, "${kind.name} face count")
        }
    }

    @Test
    fun neighboursAreUnique() {
        val tiling = GridFactory.build(GridKind.SQUARE, 3, 3)
        val centerFace = tiling.faces[4]
        val neighbors = tiling.neighbours(centerFace)
        assertEquals(neighbors.toSet().size, neighbors.size, "Neighbors should be unique")
    }
}