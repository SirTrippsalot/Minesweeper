package com.edgefield.minesweeper

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Basic integration test for [GridSystem].
 */
class GridSystemTest {

    @Test
    fun gridSystemIntegration() {
        // Test square grid
        val squareTiling = GridFactory.build(GridKind.SQUARE, 5, 5)
        assertTrue(squareTiling.faces.isNotEmpty(), "Square grid should have faces")

        // Test hex grid
        val hexTiling = GridFactory.build(GridKind.HEXAGON, 5, 5)
        assertTrue(hexTiling.faces.isNotEmpty(), "Hex grid should have faces")

        // Test triangle grid
        val triangleTiling = GridFactory.build(GridKind.TRIANGLE, 5, 5)
        assertTrue(triangleTiling.faces.isNotEmpty(), "Triangle grid should have faces")

        // Test neighbor lookup
        val firstFace = squareTiling.faces[0]
        val neighbors = squareTiling.neighbours(firstFace)
        assertTrue(neighbors.isNotEmpty(), "First square face should have neighbors")
    }

    @Test
    fun neighborCountAcrossGrids() {
        listOf(GridKind.SQUARE, GridKind.HEXAGON, GridKind.TRIANGLE).forEach { kind ->
            val tiling = GridFactory.build(kind, 3, 3)
            val centerFace = tiling.faces[4]
            val count = tiling.neighbours(centerFace).size
            assertEquals(kind.neighborCount, count, "${kind.name} neighbor count")
        }
    }
}