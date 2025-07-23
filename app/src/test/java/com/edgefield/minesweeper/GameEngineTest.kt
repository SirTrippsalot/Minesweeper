package com.edgefield.minesweeper

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GameEngineTest {

    private fun engineFor(type: GridType, cols: Int, rows: Int): GameEngine {
        val config = GameConfig(
            rows = rows,
            cols = cols,
            difficulty = Difficulty.CUSTOM,
            customMines = 1,
            useMinePercent = false,
            gridType = type
        )
        return GameEngine(config)
    }

    private fun lineSetup(engine: GameEngine, mineIndex: Int) {
        engine.board.cells.values.forEach { it.isMine = false }
        val id = "${mineIndex}_0"
        engine.board.getCell(id)?.isMine = true
    }

    private fun assertWinAfterReveal(type: GridType) {
        val engine = engineFor(type, cols = 2, rows = 1)
        lineSetup(engine, 0)
        assertEquals(1, engine.board.countNeighborMines("1_0"))
        val state = engine.revealCell("1_0")
        assertEquals(GameState.WON, state)
        assertTrue(engine.board.getCell("1_0")!!.isRevealed)
    }

    @Test fun revealSafeWinsSquare() = assertWinAfterReveal(GridType.SQUARE)
    @Test fun revealSafeWinsTriangle() = assertWinAfterReveal(GridType.TRIANGLE)
    @Test fun revealSafeWinsHex() = assertWinAfterReveal(GridType.HEXAGON)

    private fun assertLoseAfterSecondReveal(type: GridType) {
        val engine = engineFor(type, cols = 3, rows = 1)
        lineSetup(engine, 1)
        engine.revealCell("0_0")
        assertEquals(GameState.PLAYING, engine.gameState)
        val state = engine.revealCell("1_0")
        assertEquals(GameState.LOST, state)
        assertTrue(engine.board.getCell("1_0")!!.isRevealed)
    }

    @Test fun revealMineLosesSquare() = assertLoseAfterSecondReveal(GridType.SQUARE)
    @Test fun revealMineLosesTriangle() = assertLoseAfterSecondReveal(GridType.TRIANGLE)
    @Test fun revealMineLosesHex() = assertLoseAfterSecondReveal(GridType.HEXAGON)

    @Test
    fun countMinesAcrossShapes() {
        listOf(GridType.SQUARE, GridType.TRIANGLE, GridType.HEXAGON).forEach { t ->
            val engine = engineFor(t, cols = 2, rows = 1)
            lineSetup(engine, 0)
            assertEquals(1, engine.board.countNeighborMines("1_0"), "count for $t")
        }
    }
}
