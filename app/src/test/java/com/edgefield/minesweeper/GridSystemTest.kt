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
        // Basic grids
        val squareTiling = GridFactory.build(GridKind.SQUARE, 5, 5)
        assertTrue(squareTiling.faces.isNotEmpty(), "Square grid should have faces")

        val hexTiling = GridFactory.build(GridKind.HEXAGON, 5, 5)
        assertTrue(hexTiling.faces.isNotEmpty(), "Hex grid should have faces")

        val triangleTiling = GridFactory.build(GridKind.TRIANGLE, 5, 5)
        assertTrue(triangleTiling.faces.isNotEmpty(), "Triangle grid should have faces")

        // Exotic grids
        val octaTiling = GridFactory.build(GridKind.OCTASQUARE, 4, 4)
        assertTrue(octaTiling.faces.isNotEmpty(), "Octasquare grid should have faces")

        val cairoTiling = GridFactory.build(GridKind.CAIRO, 4, 4)
        assertTrue(cairoTiling.faces.isNotEmpty(), "Cairo grid should have faces")

        val rhombilleTiling = GridFactory.build(GridKind.RHOMBILLE, 4, 4)
        assertTrue(rhombilleTiling.faces.isNotEmpty(), "Rhombille grid should have faces")

        val snubTiling = GridFactory.build(GridKind.SNUB_SQUARE, 4, 4)
        assertTrue(snubTiling.faces.isNotEmpty(), "Snub Square grid should have faces")

        val penroseTiling = GridFactory.build(GridKind.PENROSE, 4, 4)
        assertTrue(penroseTiling.faces.isNotEmpty(), "Penrose grid should have faces")

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
        GridType.values().forEach { type ->
            val engine = GameEngine(GameConfig(rows = 3, cols = 3, mineCount = 0, gridType = type))
            val center = engine.board[1][1]
            val count = invokeNeighbors(engine, center).size
            assertEquals(type.kind.neighborCount, count, "${type.name} neighbor count")
        }
    }
}