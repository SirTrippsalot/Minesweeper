// ───────────────── GameComponents.kt ─────────────────
package com.edgefield.minesweeper

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun GridTypeSelector(
    selectedType: GridType,
    onTypeSelected: (GridType) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text("Grid Type", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        
        val gridTypes = listOf(
            GridType.SQUARE to "Square (Classic)",
            GridType.TRIANGLE to "Triangle",
            GridType.HEXAGON to "Hexagon",
            GridType.OCTASQUARE to "Octasquare",
            GridType.CAIRO to "Cairo Pentagon",
            GridType.RHOMBILLE to "Rhombille",
            GridType.SNUB_SQUARE to "Snub Square",
            GridType.PENROSE to "Penrose"
        )
        
        gridTypes.forEach { (type, name) ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .selectable(
                        selected = selectedType == type,
                        onClick = { onTypeSelected(type) }
                    )
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                RadioButton(
                    selected = selectedType == type,
                    onClick = { onTypeSelected(type) }
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(name)
            }
        }
    }
}

@Composable
fun DifficultyPresets(
    onPresetSelected: (GameConfig) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text("Difficulty Presets", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        
        val presets = listOf(
            "Beginner" to GameConfig(rows = 9, cols = 9, mineCount = 10),
            "Intermediate" to GameConfig(rows = 16, cols = 16, mineCount = 40),
            "Expert" to GameConfig(rows = 16, cols = 30, mineCount = 99)
        )
        
        presets.forEach { (name, config) ->
            Button(
                onClick = { onPresetSelected(config) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 2.dp)
            ) {
                Text("$name (${config.rows}x${config.cols}, ${config.mineCount} mines)")
            }
        }
    }
}

@Composable
fun TouchControlsConfig(
    config: TouchConfig,
    onConfigChange: (TouchConfig) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        TouchActionRow("Single Tap", config.singleTap) { action ->
            onConfigChange(config.copy(singleTap = action))
        }
        
        TouchActionRow("Double Tap", config.doubleTap) { action ->
            onConfigChange(config.copy(doubleTap = action))
        }
        
        TouchActionRow("Triple Tap", config.tripleTap) { action ->
            onConfigChange(config.copy(tripleTap = action))
        }
        
        TouchActionRow("Long Press", config.longPress) { action ->
            onConfigChange(config.copy(longPress = action))
        }
    }
}

@Composable
private fun TouchActionRow(
    label: String,
    currentAction: TouchAction,
    onActionChange: (TouchAction) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            modifier = Modifier.weight(1f)
        )
        
        Box {
            OutlinedButton(
                onClick = { expanded = true }
            ) {
                Text(currentAction.displayName())
            }
            
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                listOf(TouchAction.REVEAL, TouchAction.FLAG, TouchAction.QUESTION, TouchAction.MARK_CYCLE, TouchAction.NONE).forEach { action ->
                    DropdownMenuItem(
                        text = { Text(action.displayName()) },
                        onClick = {
                            onActionChange(action)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

internal fun TouchAction.displayName(): String = when (this) {
    TouchAction.REVEAL -> "Reveal"
    TouchAction.FLAG -> "Flag"
    TouchAction.QUESTION -> "Question"
    TouchAction.MARK_CYCLE -> "Cycle Marks"
    TouchAction.NONE -> "None"
}