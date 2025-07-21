// ───────────────── GameEngine.kt ─────────────────
package com.edgefield.minesweeper

import android.util.Log
import kotlin.random.Random

class GameEngine(private val config: GameConfig) {
    
    val board: Array<Array<Tile>> = Array(config.rows) { r ->
        Array(config.cols) { c -> Tile(c, r) }
    }
    
    // Grid topology using GridSystem
    private val tiling = GridFactory.build(
        kind = when (config.gridType) {
            GridType.SQUARE -> GridKind.SQUARE
            GridType.TRIANGLE -> GridKind.TRIANGLE
            GridType.HEXAGON -> GridKind.HEXAGON
            GridType.OCTASQUARE -> GridKind.OCTASQUARE
            GridType.CAIRO -> GridKind.CAIRO
            GridType.RHOMBILLE -> GridKind.RHOMBILLE
            GridType.SNUB_SQUARE -> GridKind.SNUB_SQUARE
            GridType.PENROSE -> GridKind.PENROSE
        },
        w = config.cols,
        h = config.rows
    )
    
    // Map between tiles and faces - using a more robust approach
    private val tileToFace = mutableMapOf<Tile, Face>()
    private val faceToTile = mutableMapOf<Face, Tile>()
    
    var gameState: GameState = GameState.PLAYING
        private set
    
    val stats = GameStats()
    
    init {
        Log.d("GameEngine", "Initializing GameEngine with config: rows=${config.rows}, cols=${config.cols}, mines=${config.mineCount}, gridType=${config.gridType}")
        try {
            Log.d("GameEngine", "Creating tiling...")
            // Tiling is already created above
            Log.d("GameEngine", "Tiling created with ${tiling.faces.size} faces")
            
            Log.d("GameEngine", "Initializing tile-to-face mapping...")
            initializeTileToFaceMapping()
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
        // Create a deterministic mapping between board positions and faces
        // Faces are generated in row-major order by the grid builders
        val tiles = board.flatten()
        
        if (tiling.faces.size != tiles.size) {
            throw IllegalStateException("Tiling face count (${tiling.faces.size}) doesn't match tile count (${tiles.size})")
        }
        
        tiles.forEachIndexed { index, tile ->
            val face = tiling.faces[index]
            tileToFace[tile] = face
            faceToTile[face] = tile
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
        board.flatten().forEach { tile ->
            tile.adjMines = neighbors(tile).count { it.hasMine }
        }
    }

    private var firstClick = true
    val isFirstClick: Boolean
        get() = firstClick
    
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
            board.flatten().forEach { tile ->
                tile.adjMines = neighbors(tile).count { it.hasMine }
            }
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
        return if (config.gridType == GridType.SQUARE) {
            val out = mutableListOf<Tile>()
            for (dy in -1..1) {
                for (dx in -1..1) {
                    if (dx == 0 && dy == 0) continue
                    val nx = tile.x + dx
                    val ny = tile.y + dy
                    if (nx in 0 until config.cols && ny in 0 until config.rows) {
                        out += board[ny][nx]
                    }
                }
            }
            out
        } else {
            val face = tileToFace[tile] ?: return emptyList()
            tiling.neighbours(face).mapNotNull { neighborFace ->
                faceToTile[neighborFace]
            }
        }
    }
}
