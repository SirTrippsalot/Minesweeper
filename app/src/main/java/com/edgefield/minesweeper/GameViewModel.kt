// ───────────────── GameViewModel.kt ─────────────────
package com.edgefield.minesweeper

import android.app.Application
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.edgefield.minesweeper.PrefsManager
import com.edgefield.minesweeper.graph.Cell
import com.edgefield.minesweeper.graph.GameBoard
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive

class GameViewModel(application: Application) : AndroidViewModel(application) {

    var gameConfig by mutableStateOf(GameConfig())
        private set
    
    private var engine: GameEngine
    
    var board by mutableStateOf(GameBoard())
        private set

    val cells: List<Cell>
        get() {
            val list = mutableListOf<Cell>()
            for (y in 0 until gameConfig.rows) {
                for (x in 0 until gameConfig.cols) {
                    board.getCell("${x}_${y}")?.let { list += it }
                }
            }
            return list
        }
    var gameState by mutableStateOf(GameState.PLAYING)
        private set
    var stats by mutableStateOf(GameStats())
        private set

    var elapsedTimeMs by mutableStateOf(0L)
        private set
    
    init {
        Log.d("GameViewModel", "Initializing GameViewModel")
        try {
            gameConfig = PrefsManager.loadGameConfig(getApplication())
            Log.d("GameViewModel", "Creating GameEngine with config: $gameConfig")
            engine = GameEngine(gameConfig)
            Log.d("GameViewModel", "GameEngine created successfully")
            
            board = cloneBoard(engine.board)
            gameState = engine.gameState
            stats = engine.stats
            
            Log.d("GameViewModel", "Starting timer")
            startTimer()
            Log.d("GameViewModel", "GameViewModel initialization complete")
        } catch (e: Exception) {
            Log.e("GameViewModel", "Error initializing GameViewModel", e)
            throw e
        }
    }

    fun handleTouch(cell: Cell, action: TouchAction) {
        if (engine.isFirstClick) {
            reveal(cell)
        } else {
            when (action) {
                TouchAction.REVEAL -> reveal(cell)
                TouchAction.FLAG, TouchAction.QUESTION, TouchAction.MARK_CYCLE -> toggleFlag(cell)
                TouchAction.NONE -> { /* Do nothing */ }
            }
        }
        updateState()
    }

    private fun reveal(cell: Cell) {
        gameState = engine.reveal(cell)
    }

    private fun toggleFlag(cell: Cell) {
        val newFlag = !cell.isFlagged
        engine.toggleMark(cell, newFlag)
    }
    
    fun processMarkedTiles() {
        engine.processMarkedTiles()
        updateState()
    }

    fun updateConfig(newConfig: GameConfig) {
        gameConfig = newConfig
        PrefsManager.saveGameConfig(getApplication(), newConfig)
        reset()
    }

    fun reset() {
        engine = GameEngine(gameConfig)
        updateState()
        startTimer() // Restart timer for new game
    }
    
    private fun updateState() {
        board = cloneBoard(engine.board)
        gameState = engine.gameState
        stats = GameStats(
            startTime = engine.stats.startTime,
            endTime = engine.stats.endTime,
            processCount = engine.stats.processCount,
            totalMoves = engine.stats.totalMoves,
            minesFound = engine.stats.minesFound
        )
        elapsedTimeMs = stats.elapsedTime
    }
    
    fun getRemainingMines(): Int = engine.getRemainingMines()
    
    fun getElapsedTimeFormatted(): String {
        val totalSeconds = elapsedTimeMs / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return "%d:%02d".format(minutes, seconds)
    }
    
    private fun startTimer() {
        elapsedTimeMs = 0L
        viewModelScope.launch {
            while (isActive) {
                delay(1000)
                if (gameState == GameState.PLAYING) {
                    elapsedTimeMs = System.currentTimeMillis() - stats.startTime
                }
            }
        }
    }

    fun saveState() {
        PrefsManager.saveGameState(getApplication(), engine.exportState())
    }

    private fun cloneBoard(source: GameBoard): GameBoard {
        val copy = GameBoard()
        source.cells.values.forEach { cell ->
            val newCell = Cell(
                id = cell.id,
                vertices = cell.vertices.toSet(),
                isMine = cell.isMine,
                isRevealed = cell.isRevealed,
                isFlagged = cell.isFlagged
            )
            copy.addCell(newCell)
        }
        return copy
    }

    fun loadState() {
        PrefsManager.loadGameState(getApplication(), gameConfig)?.let { state ->
            engine = GameEngine(gameConfig)
            engine.loadState(state)
            updateState()
        }
    }
}
