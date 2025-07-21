// ───────────────── MainActivity.kt ─────────────────
package com.edgefield.minesweeper

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d("MainActivity", "onCreate started")
        super.onCreate(savedInstanceState)
        
        try {
            Log.d("MainActivity", "Setting content")
            setContent {
                Log.d("MainActivity", "Inside setContent")
                MaterialTheme {
                    Surface {
                        Log.d("MainActivity", "Creating ViewModel")
                        val vm: GameViewModel = viewModel()
                        Log.d("MainActivity", "ViewModel created, showing GameScreen")
                        GameScreen(vm)
                    }
                }
            }
            Log.d("MainActivity", "onCreate completed successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error in onCreate", e)
            throw e
        }
    }
}
