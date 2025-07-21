// ───────────────── GameViewModel.kt ─────────────────
package com.edgefield.minesweeper

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
    
    private var engine = GameEngine(gameConfig)
    
    var board by mutableStateOf(engine.board)
        private set
    var gameState by mutableStateOf(engine.gameState)
        private set
    var stats by mutableStateOf(engine.stats)
        private set
    
    init {
        startTimer()
    }

    fun handleTouch(tile: Tile, action: TouchAction) {
        when (action) {
            TouchAction.REVEAL -> reveal(tile)
            TouchAction.FLAG -> toggleFlag(tile)
            TouchAction.QUESTION -> toggleQuestion(tile)
            TouchAction.MARK_CYCLE -> cycleMark(tile)
            TouchAction.NONE -> { /* Do nothing */ }
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
    }
    
    fun getRemainingMines(): Int = engine.getRemainingMines()
    
    fun getElapsedTimeSeconds(): Long = stats.elapsedTime / 1000
    
    private fun startTimer() {
        viewModelScope.launch {
            while (isActive) {
                delay(1000) // Update every second
                if (gameState == GameState.PLAYING) {
                    // Force recomposition by creating completely new stats object
                    val currentTime = System.currentTimeMillis()
                    stats = GameStats(
                        startTime = engine.stats.startTime,
                        endTime = null, // Keep null while playing
                        processCount = engine.stats.processCount,
                        totalMoves = engine.stats.totalMoves,
                        minesFound = engine.stats.minesFound
                    )
                }
            }
        }
    }
}
