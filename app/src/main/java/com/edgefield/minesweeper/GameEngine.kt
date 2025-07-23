// ───────────────── GameEngine.kt ─────────────────
package com.edgefield.minesweeper

import android.util.Log
import kotlin.random.Random
import com.edgefield.minesweeper.graph.Cell
import com.edgefield.minesweeper.graph.GameBoard

class GameEngine(private val config: GameConfig) {
    
    val board = GameBoard()
    
    // Grid topology using GridSystem
    private val tiling = GridFactory.build(
        kind = config.gridType.kind,
        w = config.cols,
        h = config.rows
    )
    
    
    var gameState: GameState = GameState.PLAYING
        private set
    
    val stats = GameStats()

    private fun buildBoard() {
        var index = 0
        for (y in 0 until config.rows) {
            for (x in 0 until config.cols) {
                val face = tiling.faces[index++]
                board.addCell(face.toCell("${x}_${y}"))
            }
        }
    }

    private fun seedMines() {
        val cells = board.cells.values.toList()
        var placed = 0
        while (placed < config.mineCount) {
            val cell = cells.random()
            if (!cell.isMine) {
                cell.isMine = true
                placed++
            }
        }
    }

    
    init {
        Log.d("GameEngine", "Initializing GameEngine with config: rows=${config.rows}, cols=${config.cols}, mines=${config.mineCount}, gridType=${config.gridType}")
        try {
            Log.d("GameEngine", "Creating tiling...")
            // Tiling is already created above
            Log.d("GameEngine", "Tiling created with ${tiling.faces.size} faces")
            
            Log.d("GameEngine", "Building board graph...")
            buildBoard()
            Log.d("GameEngine", "Board built")

            Log.d("GameEngine", "Seeding mines...")
            seedMines()
            Log.d("GameEngine", "GameEngine initialization complete")
        } catch (e: Exception) {
            Log.e("GameEngine", "Error initializing GameEngine", e)
            throw e
        }
    }
    


    private var firstClick = true
    val isFirstClick: Boolean
        get() = firstClick

    /**
     * Reveal the tile at the given board coordinates. If the tile has zero
     * adjacent mines, adjacent tiles are automatically revealed in a
     * breadth-first manner.
     */
    fun revealCell(id: String, countMove: Boolean = true): GameState {
        val cell = board.getCell(id) ?: return gameState
        return reveal(cell, countMove)
    }

    fun reveal(cell: Cell, countMove: Boolean = true): GameState {
        if (gameState != GameState.PLAYING || cell.isRevealed || cell.isFlagged) return gameState

        // First click should always be safe
        if (firstClick) {
            firstClick = false
            ensureSafeFirstClick(cell)
        }

        // Breadth-first flood fill starting from the clicked tile
        val queue = ArrayDeque<Cell>()
        queue += cell
        var counted = false

        while (queue.isNotEmpty()) {
            val current = queue.removeFirst()
            if (current.isRevealed || current.isFlagged) continue

            current.isRevealed = true
            if (countMove && !counted) {
                stats.totalMoves++
                counted = true
            }

            if (current.isMine) {
                gameState = GameState.LOST
                stats.endTime = System.currentTimeMillis()
                return gameState
            }

            if (board.countNeighborMines(current.id) == 0) {
                neighbors(current).forEach { neighbor ->
                    if (!neighbor.isRevealed && !neighbor.isFlagged) {
                        queue += neighbor
                    }
                }
            }
        }

        return checkWinCondition()
    }
    
    private fun ensureSafeFirstClick(firstCell: Cell) {
        if (firstCell.isMine) {
            firstCell.isMine = false
            val candidates = board.cells.values.filter { it.id != firstCell.id && !it.isMine }
            if (candidates.isNotEmpty()) {
                candidates.random().isMine = true
            }
        }
    }

    fun toggleFlag(cell: Cell) {
        if (gameState != GameState.PLAYING || cell.isRevealed) return

        val wasFlagged = cell.isFlagged
        cell.isFlagged = !wasFlagged

        if (wasFlagged) stats.minesFound-- else stats.minesFound++
    }

    fun toggleMark(cell: Cell) {
        if (gameState != GameState.PLAYING || cell.isRevealed) return
        cell.isMarked = !cell.isMarked
    }

    fun cycleMark(cell: Cell) {
        if (gameState != GameState.PLAYING || cell.isRevealed) return
        when {
            cell.isMarked -> {
                cell.isMarked = false
                cell.isFlagged = true
                stats.minesFound++
            }
            cell.isFlagged -> {
                cell.isFlagged = false
                stats.minesFound--
            }
            else -> cell.isMarked = true
        }
    }

    fun processMarkedTiles(): Int {
        val toReveal = board.cells.values.filter { it.isMarked && !it.isRevealed }
        toReveal.forEach { reveal(it, countMove = false) }
        if (toReveal.isNotEmpty()) {
            stats.processCount++
            stats.totalMoves++
        }
        return toReveal.size
    }

    private fun checkWinCondition(): GameState {
        val allSafeCellsRevealed = board.cells.values.all { cell ->
            cell.isMine || cell.isRevealed
        }
        
        if (allSafeCellsRevealed) {
            gameState = GameState.WON
            stats.endTime = System.currentTimeMillis()
        }
        
        return gameState
    }

    fun getFlagCount(): Int = board.cells.values.count { it.isFlagged }
    
    fun getRemainingMines(): Int = config.mineCount - getFlagCount()

    private fun neighbors(cell: Cell): List<Cell> = board.getNeighbors(cell.id).toList()

    fun exportState(): EngineState {
        val cells = board.cells.values.map { cell ->
            CellState(
                id = cell.id,
                isMine = cell.isMine,
                isRevealed = cell.isRevealed,
                isFlagged = cell.isFlagged,
                isMarked = cell.isMarked
            )
        }
        return EngineState(
            cells = cells,
            gameState = gameState,
            firstClick = firstClick,
            stats = stats.copy()
        )
    }

    fun loadState(state: EngineState) {
        state.cells.forEach { cs ->
            board.getCell(cs.id)?.let { cell ->
                cell.isMine = cs.isMine
                cell.isRevealed = cs.isRevealed
                cell.isFlagged = cs.isFlagged
                cell.isMarked = cs.isMarked
            }
        }
        firstClick = state.firstClick
        gameState = state.gameState
        stats.startTime = state.stats.startTime
        stats.endTime = state.stats.endTime
        stats.processCount = state.stats.processCount
        stats.totalMoves = state.stats.totalMoves
        stats.minesFound = state.stats.minesFound
    }
}
