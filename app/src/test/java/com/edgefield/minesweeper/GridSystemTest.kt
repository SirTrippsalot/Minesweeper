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

    private fun invokeNeighbors(engine: GameEngine, tile: Tile): List<Tile> {
        val m = GameEngine::class.java.getDeclaredMethod("neighbors", Tile::class.java)
        m.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        return m.invoke(engine, tile) as List<Tile>
    }

    @Test
    fun neighborCountAcrossGrids() {
        listOf(GridType.SQUARE, GridType.HEXAGON, GridType.TRIANGLE).forEach { type ->
            val engine = GameEngine(GameConfig(rows = 3, cols = 3, mineCount = 0, gridType = type))
            val center = engine.board[1][1]
            val count = invokeNeighbors(engine, center).size
            assertEquals(type.kind.neighborCount, count, "${type.name} neighbor count")
        }
    }
}