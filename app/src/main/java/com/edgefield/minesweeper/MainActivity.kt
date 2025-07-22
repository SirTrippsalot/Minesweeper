// ───────────────── MainActivity.kt ─────────────────
package com.edgefield.minesweeper

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.activity.viewModels

class MainActivity : ComponentActivity() {
    private val vm: GameViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d("MainActivity", "onCreate started")
        super.onCreate(savedInstanceState)
        
        try {
            Log.d("MainActivity", "Setting content")
            setContent {
                Log.d("MainActivity", "Inside setContent")
                MaterialTheme {
                    Surface {
                        Log.d("MainActivity", "Showing GameScreen")
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

    override fun onPause() {
        super.onPause()
        vm.saveState()
    }

    override fun onResume() {
        super.onResume()
        vm.loadState()
    }
}
