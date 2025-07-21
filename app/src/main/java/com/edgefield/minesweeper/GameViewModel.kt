// ───────────────── GameViewModel.kt ─────────────────
package com.edgefield.minesweeper

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive

class GameViewModel : ViewModel() {

    var gameConfig by mutableStateOf(GameConfig())
        private set
    
    private var engine: GameEngine
    
    var board by mutableStateOf(arrayOf<Array<Tile>>())
        private set
    var gameState by mutableStateOf(GameState.PLAYING)
        private set
    var stats by mutableStateOf(GameStats())
        private set

    var elapsedTimeMs by mutableStateOf(0L)
        private set
    
    init {
        Log.d("GameViewModel", "Initializing GameViewModel")
        try {
            Log.d("GameViewModel", "Creating GameEngine with config: $gameConfig")
            engine = GameEngine(gameConfig)
            Log.d("GameViewModel", "GameEngine created successfully")
            
            board = engine.board
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

    fun handleTouch(tile: Tile, action: TouchAction) {
        if (engine.isFirstClick) {
            reveal(tile)
        } else {
            when (action) {
                TouchAction.REVEAL -> reveal(tile)
                TouchAction.FLAG -> toggleFlag(tile)
                TouchAction.QUESTION -> toggleQuestion(tile)
                TouchAction.MARK_CYCLE -> cycleMark(tile)
                TouchAction.NONE -> { /* Do nothing */ }
            }
        }
        updateState()
    }

    private fun reveal(tile: Tile) {
        gameState = engine.reveal(tile)
    }

    private fun toggleFlag(tile: Tile) {
        val newMark = if (tile.mark == Mark.FLAG) Mark.NONE else Mark.FLAG
        engine.toggleMark(tile, newMark)
    }
    
    private fun toggleQuestion(tile: Tile) {
        val newMark = if (tile.mark == Mark.QUESTION) Mark.NONE else Mark.QUESTION
        engine.toggleMark(tile, newMark)
    }

    private fun cycleMark(tile: Tile) {
        val next = when (tile.mark) {
            Mark.NONE -> Mark.QUESTION
            Mark.QUESTION -> Mark.FLAG
            Mark.FLAG -> Mark.NONE
        }
        engine.toggleMark(tile, next)
    }
    
    fun processMarkedTiles() {
        engine.processMarkedTiles()
        updateState()
    }

    fun updateConfig(newConfig: GameConfig) {
        gameConfig = newConfig
        reset()
    }

    fun reset() {
        engine = GameEngine(gameConfig)
        updateState()
        startTimer() // Restart timer for new game
    }
    
    private fun updateState() {
        // Force recomposition by creating new array references
        board = Array(engine.board.size) { row ->
            Array(engine.board[row].size) { col ->
                engine.board[row][col]
            }
        }
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
}
