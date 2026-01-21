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

        // Apply edge wrapping if enabled
        if (config.edgeMode) {
            applyEdgeWrapping()
        }
    }

    private fun applyEdgeWrapping() {
        // Add wrapped neighbor connections for cells at grid boundaries
        var wrappedConnections = 0
        for (y in 0 until config.rows) {
            for (x in 0 until config.cols) {
                val cellId = "${x}_${y}"

                // Define the offsets to check based on grid type
                val offsets = when (config.gridType) {
                    GridType.SQUARE -> listOf(
                        -1 to -1, 0 to -1, 1 to -1,  // Top row
                        -1 to 0,           1 to 0,   // Middle row (skip 0,0 - self)
                        -1 to 1,  0 to 1,  1 to 1    // Bottom row
                    )
                    GridType.HEXAGON -> listOf(
                        -1 to -1, 0 to -1,
                        -1 to 0,          1 to 0,
                                  0 to 1, 1 to 1
                    )
                    GridType.TRIANGLE -> {
                        // Triangles have different neighbor patterns
                        // For now, use similar to square
                        listOf(
                            -1 to -1, 0 to -1, 1 to -1,
                            -1 to 0,           1 to 0,
                            -1 to 1,  0 to 1,  1 to 1
                        )
                    }
                    else -> listOf(
                        -1 to -1, 0 to -1, 1 to -1,
                        -1 to 0,           1 to 0,
                        -1 to 1,  0 to 1,  1 to 1
                    )
                }

                // Check each potential neighbor
                for ((dx, dy) in offsets) {
                    val nx = x + dx
                    val ny = y + dy

                    // Skip if neighbor is already in bounds (already connected by normal logic)
                    if (nx in 0 until config.cols && ny in 0 until config.rows) {
                        continue
                    }

                    // Calculate wrapped coordinates
                    val wx = ((nx % config.cols) + config.cols) % config.cols
                    val wy = ((ny % config.rows) + config.rows) % config.rows
                    val wrappedId = "${wx}_${wy}"

                    // Connect the cells if the wrapped neighbor exists
                    board.connect(cellId, wrappedId)
                    wrappedConnections++
                }
            }
        }
        Log.d("GameEngine", "Applied edge wrapping: $wrappedConnections wrapped connections created")
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
        if (gameState != GameState.PLAYING || cell.isRevealed || cell.mark == Mark.FLAG) return gameState

        // Handle first click based on configuration
        if (firstClick) {
            firstClick = false
            if (config.safeFirstClick || config.zeroFirstClick) {
                ensureSafeFirstClick(cell, guaranteeZero = config.zeroFirstClick)
            }
        }

        // Breadth-first flood fill starting from the clicked tile
        val queue = ArrayDeque<Cell>()
        queue += cell
        var counted = false

        while (queue.isNotEmpty()) {
            val current = queue.removeFirst()
            if (current.isRevealed || current.mark == Mark.FLAG) continue

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
                    if (!neighbor.isRevealed && neighbor.mark != Mark.FLAG) {
                        queue += neighbor
                    }
                }
            }
        }

        return checkWinCondition()
    }
    
    private fun ensureSafeFirstClick(firstCell: Cell, guaranteeZero: Boolean = false) {
        // Remove mine from first click cell if present
        if (firstCell.isMine) {
            firstCell.isMine = false
            val candidates = board.cells.values.filter { it.id != firstCell.id && !it.isMine }
            if (candidates.isNotEmpty()) {
                candidates.random().isMine = true
            }
        }

        // If guaranteeZero, also clear mines from all neighbors
        if (guaranteeZero) {
            val neighborsToCheck = neighbors(firstCell).toMutableList()
            neighborsToCheck.forEach { neighbor ->
                if (neighbor.isMine) {
                    neighbor.isMine = false
                    // Find a cell to relocate the mine to (not first click, not its neighbors)
                    val excludedIds = (neighborsToCheck.map { it.id } + firstCell.id).toSet()
                    val candidates = board.cells.values.filter {
                        it.id !in excludedIds && !it.isMine
                    }
                    if (candidates.isNotEmpty()) {
                        candidates.random().isMine = true
                    }
                }
            }
        }
    }

    fun toggleFlag(cell: Cell) {
        if (gameState != GameState.PLAYING || cell.isRevealed) return

        if (cell.mark == Mark.FLAG) {
            cell.mark = Mark.NONE
            stats.minesFound--
        } else {
            cell.mark = Mark.FLAG
            stats.minesFound++
        }
    }

    fun toggleMark(cell: Cell) {
        if (gameState != GameState.PLAYING || cell.isRevealed) return

        cell.mark = if (cell.mark == Mark.QUESTION) Mark.NONE else Mark.QUESTION
    }

    fun cycleMark(cell: Cell) {
        if (gameState != GameState.PLAYING || cell.isRevealed) return

        when (cell.mark) {
            Mark.NONE -> cell.mark = Mark.QUESTION
            Mark.QUESTION -> {
                cell.mark = Mark.FLAG
                stats.minesFound++
            }
            Mark.FLAG -> {
                cell.mark = Mark.NONE
                stats.minesFound--
            }
        }
    }

    fun processMarkedTiles(): Int {
        val toReveal = board.cells.values.filter { it.mark == Mark.QUESTION && !it.isRevealed }
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

    fun getFlagCount(): Int = board.cells.values.count { it.mark == Mark.FLAG }
    
    fun getRemainingMines(): Int = config.mineCount - getFlagCount()

    private fun neighbors(cell: Cell): List<Cell> = board.getNeighbors(cell.id).toList()

    fun exportState(): EngineState {
        val cells = board.cells.values.map { cell ->
            CellState(
                id = cell.id,
                isMine = cell.isMine,
                isRevealed = cell.isRevealed,
                mark = cell.mark
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
                cell.mark = cs.mark
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
