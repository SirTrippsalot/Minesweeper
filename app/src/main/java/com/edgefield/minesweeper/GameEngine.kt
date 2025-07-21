// ───────────────── GameEngine.kt ─────────────────
package com.edgefield.minesweeper

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
        initializeTileToFaceMapping()
        seedMinesAndNumbers() 
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
    
    fun reveal(tile: Tile): GameState {
        if (gameState != GameState.PLAYING || tile.revealed || tile.mark == Mark.FLAG) return gameState
        
        // First click should always be safe
        if (firstClick) {
            firstClick = false
            ensureSafeFirstClick(tile)
        }
        
        tile.revealed = true
        stats.totalMoves++
        
        return if (tile.hasMine) {
            gameState = GameState.LOST
            stats.endTime = System.currentTimeMillis()
            gameState
        } else {
            if (tile.adjMines == 0) {
                neighbors(tile).forEach { reveal(it) }
            }
            checkWinCondition()
        }
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
        stats.totalMoves++
        
        // Update mine tracking
        when {
            oldMark != Mark.FLAG && mark == Mark.FLAG -> stats.minesFound++
            oldMark == Mark.FLAG && mark != Mark.FLAG -> stats.minesFound--
        }
    }
    
    fun processMarkedTiles(): Int {
        var processed = 0
        board.flatten().forEach { tile ->
            if (tile.revealed && tile.adjMines > 0) {
                val flaggedNeighbors = neighbors(tile).count { it.mark == Mark.FLAG }
                if (flaggedNeighbors == tile.adjMines) {
                    // Auto-reveal unflagged neighbors
                    neighbors(tile).filter { !it.revealed && it.mark != Mark.FLAG }.forEach {
                        reveal(it)
                        processed++
                    }
                }
            }
        }
        if (processed > 0) {
            stats.processCount++
        }
        return processed
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
        // Use GridSystem topology for all neighbor lookups
        val face = tileToFace[tile] ?: return emptyList()
        return tiling.neighbours(face).mapNotNull { neighborFace ->
            faceToTile[neighborFace]
        }
    }
}
