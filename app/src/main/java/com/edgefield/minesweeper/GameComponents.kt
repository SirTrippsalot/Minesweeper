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
fun ConfigNumberField(
    label: String,
    value: Int,
    onValueChange: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value.toString(),
        onValueChange = { it.toIntOrNull()?.let(onValueChange) },
        label = { Text(label) },
        modifier = modifier
    )
}

@Composable
fun GridTypeSelector(
    selectedType: GridType,
    onTypeSelected: (GridType) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        var expanded by remember { mutableStateOf(false) }

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

        val currentName = gridTypes.firstOrNull { it.first == selectedType }?.second ?: ""

        Box {
            OutlinedButton(onClick = { expanded = true }) {
                Text(currentName)
            }

            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                gridTypes.forEach { (type, name) ->
                    DropdownMenuItem(
                        text = { Text(name) },
                        onClick = {
                            onTypeSelected(type)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun DifficultySelector(
    selected: Difficulty,
    onSelected: (Difficulty) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        var expanded by remember { mutableStateOf(false) }

        Text("Difficulty", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))

        val currentName = selected.name
            .replace('_', ' ')
            .lowercase()
            .replaceFirstChar { it.titlecase() }

        Box {
            OutlinedButton(onClick = { expanded = true }) {
                Text(currentName)
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                Difficulty.values().forEach { diff ->
                    val name = diff.name
                        .replace('_', ' ')
                        .lowercase()
                        .replaceFirstChar { it.titlecase() }

                    DropdownMenuItem(
                        text = { Text(name) },
                        onClick = {
                            onSelected(diff)
                            expanded = false
                        }
                    )
                }
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
            "Very Easy" to GameConfig(difficulty = Difficulty.VERY_EASY),
            "Easy" to GameConfig(difficulty = Difficulty.EASY),
            "Medium" to GameConfig(difficulty = Difficulty.MEDIUM),
            "Hard" to GameConfig(difficulty = Difficulty.HARD),
            "Very Hard" to GameConfig(difficulty = Difficulty.VERY_HARD),
            "Hardest" to GameConfig(difficulty = Difficulty.HARDEST),
            "Custom" to GameConfig(difficulty = Difficulty.CUSTOM)
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