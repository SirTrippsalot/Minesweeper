// ───────────────── GameEngine.kt ─────────────────
package com.edgefield.minesweeper

import android.util.Log
import kotlin.random.Random
import kotlin.math.sqrt

// Mapping helper
import com.edgefield.minesweeper.mapTilesToFaces

class GameEngine(private val config: GameConfig) {

    private val squareOffsets = listOf(
        -1 to 0, 1 to 0, 0 to -1, 0 to 1,
        -1 to -1, -1 to 1, 1 to -1, 1 to 1
    )

    private val triangleOffsets = listOf(
        -1 to 0, 1 to 0, 0 to 1, 0 to -1
    )
    
    val board: Array<Array<Tile>> = Array(config.rows) { r ->
        Array(config.cols) { c -> Tile(c, r) }
    }
    
    // Grid topology using GridSystem
    private val tiling = GridFactory.build(
        kind = config.gridType.kind,
        w = config.cols,
        h = config.rows
    )
    
    // Map between tiles and faces - using a more robust approach
    private val tileToFace = mutableMapOf<Tile, Face>()
    private val faceToTile = mutableMapOf<Face, Tile>()
    
    var gameState: GameState = GameState.PLAYING
        private set
    
    val stats = GameStats()

    private lateinit var directionOffsets: List<Pair<Int, Int>>
    
    init {
        Log.d("GameEngine", "Initializing GameEngine with config: rows=${config.rows}, cols=${config.cols}, mines=${config.mineCount}, gridType=${config.gridType}")
        try {
            Log.d("GameEngine", "Creating tiling...")
            // Tiling is already created above
            Log.d("GameEngine", "Tiling created with ${tiling.faces.size} faces")
            
            Log.d("GameEngine", "Initializing tile-to-face mapping...")
            initializeTileToFaceMapping()
            directionOffsets = computeDirectionOffsets()
            Log.d("GameEngine", "Tile-to-face mapping complete")
            
            Log.d("GameEngine", "Seeding mines and numbers...")
            seedMinesAndNumbers()
            Log.d("GameEngine", "GameEngine initialization complete")
        } catch (e: Exception) {
            Log.e("GameEngine", "Error initializing GameEngine", e)
            throw e
        }
    }
    
    private fun initializeTileToFaceMapping() {
        val (tToF, fToT) = mapTilesToFaces(board.flatten(), tiling.faces)
        tileToFace.putAll(tToF)
        faceToTile.putAll(fToT)
    }

    private fun recalculateAdjacents() {
        board.flatten().forEach { tile ->
            tile.adjMines = neighbors(tile).count { it.hasMine }
        }
    }

    private fun seedMinesAndNumbers() {
        var placed = 0
        while (placed < config.mineCount) {
            val r = Random.nextInt(config.rows)
            val c = Random.nextInt(config.cols)
            val t = board[r][c]
            if (!t.hasMine) {
                t.hasMine = true
                placed++
            }
        }
        recalculateAdjacents()
    }

    private fun computeDirectionOffsets(): List<Pair<Int, Int>> {
        val expected = config.gridType.kind.neighborCount
        board.flatten().forEach { tile ->
            val face = tileToFace[tile] ?: return@forEach
            val neighbors = tiling.neighbours(face).mapNotNull { nf ->
                faceToTile[nf]
            }
            if (neighbors.size == expected) {
                return neighbors.map { it.x - tile.x to it.y - tile.y }
            }
        }
        // Fallback to generic offsets based on grid type
        return when (config.gridType.kind) {
            GridKind.SQUARE -> squareOffsets
            GridKind.TRIANGLE -> triangleOffsets
            else -> {
                val first = board[0][0]
                val face = tileToFace[first] ?: return emptyList()
                tiling.neighbours(face).mapNotNull { nf -> faceToTile[nf] }
                    .map { it.x - first.x to it.y - first.y }
            }
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
    fun revealTile(x: Int, y: Int, countMove: Boolean = true): GameState {
        if (y !in board.indices) return gameState
        val row = board[y]
        if (x !in row.indices) return gameState
        return reveal(row[x], countMove)
    }
    
    fun reveal(tile: Tile, countMove: Boolean = true): GameState {
        if (gameState != GameState.PLAYING || tile.revealed || tile.mark == Mark.FLAG) return gameState

        // First click should always be safe
        if (firstClick) {
            firstClick = false
            ensureSafeFirstClick(tile)
        }

        // Breadth-first flood fill starting from the clicked tile
        val queue = ArrayDeque<Tile>()
        queue += tile
        var counted = false

        while (queue.isNotEmpty()) {
            val current = queue.removeFirst()
            if (current.revealed || current.mark == Mark.FLAG) continue

            current.revealed = true
            if (countMove && !counted) {
                stats.totalMoves++
                counted = true
            }

            if (current.hasMine) {
                gameState = GameState.LOST
                stats.endTime = System.currentTimeMillis()
                return gameState
            }

            if (current.adjMines == 0) {
                neighbors(current).forEach { neighbor ->
                    if (!neighbor.revealed && neighbor.mark != Mark.FLAG) {
                        queue += neighbor
                    }
                }
            }
        }

        return checkWinCondition()
    }
    
    private fun ensureSafeFirstClick(firstTile: Tile) {
        if (firstTile.hasMine) {
            // Move the mine to a different location
            firstTile.hasMine = false
            
            // Find a new location for the mine
            var placed = false
            while (!placed) {
                val r = Random.nextInt(config.rows)
                val c = Random.nextInt(config.cols)
                val candidate = board[r][c]
                if (!candidate.hasMine && candidate != firstTile) {
                    candidate.hasMine = true
                    placed = true
                }
            }
            
            // Recalculate adjacent mine counts
            recalculateAdjacents()
        }
    }

    fun toggleMark(tile: Tile, mark: Mark) {
        if (gameState != GameState.PLAYING || tile.revealed) return
        
        val oldMark = tile.mark
        tile.mark = mark
        
        // Update mine tracking
        when {
            oldMark != Mark.FLAG && mark == Mark.FLAG -> stats.minesFound++
            oldMark == Mark.FLAG && mark != Mark.FLAG -> stats.minesFound--
        }
    }
    
    fun processMarkedTiles(): Int {
        val toReveal = board.flatten().filter { it.mark == Mark.QUESTION && !it.revealed }
        toReveal.forEach { reveal(it, countMove = false) }
        if (toReveal.isNotEmpty()) {
            stats.processCount++
            stats.totalMoves++
        }
        return toReveal.size
    }

    private fun checkWinCondition(): GameState {
        val allSafeCellsRevealed = board.flatten().all { tile ->
            tile.hasMine || tile.revealed
        }
        
        if (allSafeCellsRevealed) {
            gameState = GameState.WON
            stats.endTime = System.currentTimeMillis()
        }
        
        return gameState
    }

    fun getFlagCount(): Int = board.flatten().count { it.mark == Mark.FLAG }
    
    fun getRemainingMines(): Int = config.mineCount - getFlagCount()

    private fun neighbors(tile: Tile): List<Tile> {
        // Base neighbours via GridSystem topology
        val face = tileToFace[tile] ?: return emptyList()
        val adjacent = tiling.neighbours(face).mapNotNull { neighborFace ->
            faceToTile[neighborFace]
        }.toMutableList()
        if (config.edgeMode && ::directionOffsets.isInitialized) {
            val seen = adjacent.toMutableSet()
            val offsets = when (config.gridType.kind) {
                GridKind.TRIANGLE -> {
                    if ((tile.x + tile.y) % 2 == 0) {
                        listOf(-1 to 0, 1 to 0, 0 to 1)
                    } else {
                        listOf(-1 to 0, 1 to 0, 0 to -1)
                    }
                }
                GridKind.SQUARE -> squareOffsets
                else -> directionOffsets
            }
            offsets.forEach { (dx, dy) ->
                val (nx, ny) = wrapCoord(tile.x + dx, tile.y + dy)
                val neighbor = board[ny][nx]
                if (neighbor !== tile && seen.add(neighbor)) {
                    adjacent += neighbor
                }
            }
        }
        return adjacent
    }

    private fun wrapCoord(x: Int, y: Int): Pair<Int, Int> {
        val wx = ((x % config.cols) + config.cols) % config.cols
        val wy = ((y % config.rows) + config.rows) % config.rows
        return wx to wy
    }

    fun exportState(): EngineState {
        val boardCopy = Array(board.size) { r ->
            Array(board[r].size) { c ->
                val t = board[r][c]
                Tile(t.x, t.y, t.hasMine, t.revealed, t.mark, t.adjMines)
            }
        }
        return EngineState(
            board = boardCopy,
            gameState = gameState,
            firstClick = firstClick,
            stats = stats.copy()
        )
    }

    fun loadState(state: EngineState) {
        require(state.board.size == config.rows &&
            state.board[0].size == config.cols) {
            "Board size mismatch"
        }
        for (y in board.indices) {
            for (x in board[y].indices) {
                val src = state.board[y][x]
                val dst = board[y][x]
                dst.hasMine = src.hasMine
                dst.revealed = src.revealed
                dst.mark = src.mark
                dst.adjMines = src.adjMines
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
