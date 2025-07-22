package com.edgefield.minesweeper

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Done
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.rememberCoroutineScope
import android.view.ViewConfiguration
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

@Composable
fun GameScreen(vm: GameViewModel) {
    var showSettings by remember { mutableStateOf(false) }
    val tileSize = 40.dp
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(8.dp)
    ) {
        // Header with title and controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Minesweeper Edgelord",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Row {
                IconButton(onClick = { showSettings = true }) {
                    Icon(Icons.Default.Settings, contentDescription = "Settings")
                }
                IconButton(onClick = vm::reset) {
                    Icon(Icons.Default.Refresh, contentDescription = "Restart")
                }
                IconButton(
                    onClick = { vm.processMarkedTiles() },
                    enabled = vm.gameState == GameState.PLAYING
                ) {
                    Icon(Icons.Default.Done, contentDescription = "Reveal Marked")
                }
            }
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        // Game stats row
        GameStatsRow(vm)
        
        Spacer(modifier = Modifier.height(8.dp))
        
        // Game board
        GameBoard(vm, tileSize)
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Game controls
        GameControls(vm)
        
        // Game status
        GameStatus(vm.gameState)
    }
    
    if (showSettings) {
        SettingsDialog(
            config = vm.gameConfig,
            onConfigChange = vm::updateConfig,
            onDismiss = { showSettings = false }
        )
    }
}

@Composable
private fun GameStatsRow(vm: GameViewModel) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        StatCard("Mines", "${vm.getRemainingMines()}/${vm.gameConfig.mineCount}")
        StatCard("Time", vm.getElapsedTimeFormatted())
        StatCard("Moves", vm.stats.totalMoves.toString())
        StatCard("Efficiency", "${vm.stats.efficiency.toInt()}%")
    }
}

@Composable
private fun StatCard(label: String, value: String) {
    Card(
        modifier = Modifier.padding(4.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun GameBoard(vm: GameViewModel, tileSize: androidx.compose.ui.unit.Dp) {
    val config = vm.gameConfig
    val density = LocalDensity.current.density
    val tileSizePx = tileSize.value * density

    // Create tiling using GridSystem
    val tiling = remember(config.gridType, config.cols, config.rows) {
        GridFactory.build(
            kind = config.gridType.kind,
            w = config.cols,
            h = config.rows
        )
    }
    val bounds = remember(tiling) { tiling.modelBounds() }
    val scaleMultiplier = when (config.gridType) {
        GridType.HEXAGON -> 2f / 3f
        GridType.TRIANGLE -> 0.75f
        else -> 1f
    }
    val renderer = remember(tileSizePx, bounds, scaleMultiplier) {
        TilingRenderer(tileSizePx * scaleMultiplier, bounds)
    }
    
    // Map tiles to faces (same order as GameEngine)
    val tileToFace = remember(tiling, vm.board) {
        val map = mutableMapOf<Tile, Face>()
        vm.board.flatten().forEachIndexed { index, tile ->
            if (index < tiling.faces.size) {
                map[tile] = tiling.faces[index]
            }
        }
        map
    }
    
    Box(
        modifier = Modifier
            .size(
                width = (renderer.width / density).dp,
                height = (renderer.height / density).dp
            )
    ) {
        val coroutineScope = rememberCoroutineScope()
        var waitingForTriple by remember { mutableStateOf(false) }
        var doubleTapOffset by remember { mutableStateOf(Offset.Zero) }
        val tripleTimeout = ViewConfiguration.getDoubleTapTimeout().toLong()

        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(config.touchConfig, waitingForTriple, vm.board) {
                    detectTapGestures(
                        onTap = { offset ->
                            val tile = getTileFromGridSystem(offset, tiling, tileToFace, renderer)
                            if (waitingForTriple) {
                                waitingForTriple = false
                                tile?.let { vm.handleTouch(it, config.touchConfig.tripleTap) }
                            } else {
                                tile?.let { vm.handleTouch(it, config.touchConfig.singleTap) }
                            }
                        },
                        onDoubleTap = { offset ->
                            waitingForTriple = true
                            doubleTapOffset = offset
                            coroutineScope.launch {
                                delay(tripleTimeout)
                                if (waitingForTriple) {
                                    waitingForTriple = false
                                    val tile = getTileFromGridSystem(doubleTapOffset, tiling, tileToFace, renderer)
                                    tile?.let { vm.handleTouch(it, config.touchConfig.doubleTap) }
                                }
                            }
                        },
                        onLongPress = { offset ->
                            val tile = getTileFromGridSystem(offset, tiling, tileToFace, renderer)
                            tile?.let { vm.handleTouch(it, config.touchConfig.longPress) }
                        }
                    )
                }
        ) {
            drawGameBoardWithGridSystem(vm.board, vm.gameState, tiling, tileToFace, renderer)
        }
        
        // Overlay text numbers on top
        vm.board.flatten().forEach { tile ->
            if (tile.revealed && !tile.hasMine && tile.adjMines > 0) {
                val face = tileToFace[tile]
                if (face != null) {
                    val center = getFaceCentroid(face, renderer)
                    
                    Text(
                        text = tile.adjMines.toString(),
                        color = when (tile.adjMines) {
                            1 -> Color.Blue
                            2 -> Color.Green  
                            3 -> Color.Red
                            4 -> Color(0xFF800080) // Purple
                            5 -> Color(0xFF800000) // Maroon
                            6 -> Color.Cyan
                            7 -> Color.Black
                            8 -> Color.Gray
                            else -> Color.Black
                        },
                        fontSize = (tileSize.value * 0.4f).sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .offset(
                                x = (center.x / density - tileSize.value * 0.5f).dp,
                                y = (center.y / density - tileSize.value * 0.5f).dp
                            )
                            .size(tileSize)
                            .wrapContentSize(Alignment.Center)
                    )
                }
            }
        }
    }
}

// GridSystem-based functions
private fun getTileFromGridSystem(
    offset: Offset, 
    tiling: Tiling, 
    tileToFace: Map<Tile, Face>, 
    renderer: TilingRenderer
): Tile? {
    // Find the closest tile by checking distance to face centroids
    var closestTile: Tile? = null
    var minDistance = Float.MAX_VALUE
    
    tileToFace.forEach { (tile, face) ->
        val center = getFaceCentroid(face, renderer)
        val distance = kotlin.math.sqrt(
            (offset.x - center.x) * (offset.x - center.x) + 
            (offset.y - center.y) * (offset.y - center.y)
        )
        if (distance < minDistance) {
            minDistance = distance
            closestTile = tile
        }
    }
    
    return closestTile
}

private fun getFaceCentroid(face: Face, renderer: TilingRenderer): Offset {
    // Calculate centroid of the face vertices
    var sumX = 0f
    var sumY = 0f
    var count = 0
    
    var e = face.any
    do {
        val pt = renderer.modelToOffset(e.origin)
        sumX += pt.x
        sumY += pt.y
        count++
        e = e.next
    } while (e !== face.any)
    
    return Offset(sumX / count, sumY / count)
}


private fun getTileFromOffset(
    offset: Offset, 
    tiling: Tiling, 
    faceToTile: Map<Face, Tile>, 
    renderer: TilingRenderer
): Tile? {
    // Simple hit testing - find the face whose center is closest to the click point
    var closestTile: Tile? = null
    var minDistance = Float.MAX_VALUE
    
    tiling.faces.forEach { face ->
        val tile = faceToTile[face]
        if (tile != null) {
            val center = getFaceCentroid(face, renderer)
            val distance = kotlin.math.sqrt(
                (offset.x - center.x) * (offset.x - center.x) + 
                (offset.y - center.y) * (offset.y - center.y)
            )
            if (distance < minDistance) {
                minDistance = distance
                closestTile = tile
            }
        }
    }
    
    return closestTile
}

// Removed duplicate function - using getFaceCentroid instead

private fun DrawScope.drawGameBoardWithGridSystem(
    board: Array<Array<Tile>>, 
    gameState: GameState, 
    tiling: Tiling, 
    tileToFace: Map<Tile, Face>, 
    renderer: TilingRenderer
) {
    // Draw each tile using GridSystem topology
    board.flatten().forEach { tile ->
        val face = tileToFace[tile]
        if (face != null) {
            val color = getTileColor(tile, gameState)
            
            // Create Compose path from face vertices
            val path = androidx.compose.ui.graphics.Path()
            var e = face.any
            var first = true
            
            do {
                val pt = renderer.modelToOffset(e.origin)

                if (first) {
                    path.moveTo(pt.x, pt.y)
                    first = false
                } else {
                    path.lineTo(pt.x, pt.y)
                }
                e = e.next
            } while (e !== face.any)
            
            path.close()
            
            // Draw filled shape
            drawPath(path, color)
            
            // Draw outline
            drawPath(path, Color.Black, style = Stroke(width = 1.dp.toPx()))
            
            // Draw overlays (mines, flags, etc.)
            val center = getFaceCentroid(face, renderer)
            drawTileOverlays(tile, center, renderer.size, gameState)
        }
    }
}

// TouchAction.displayName() is defined in GameComponents.kt



private fun getTileColor(tile: Tile, gameState: GameState): Color {
    return when {
        !tile.revealed && tile.mark == Mark.FLAG -> Color(0xFF9E9E9E) // Same gray as unrevealed
        !tile.revealed && tile.mark == Mark.QUESTION -> Color(0xFFFF9800) // Orange for questions
        !tile.revealed -> Color(0xFF9E9E9E) // Gray for unrevealed
        tile.hasMine && gameState == GameState.LOST -> Color(0xFFF44336) // Red for mines
        tile.revealed -> Color(0xFFE0E0E0) // Light gray for revealed
        else -> Color(0xFFE0E0E0) // Default fallback
    }
}

private fun DrawScope.drawTileOverlays(tile: Tile, center: Offset, tileSizePx: Float, gameState: GameState) {
    // Draw mines, flags, and question marks as overlays
    if (tile.hasMine && gameState == GameState.LOST) {
        // Draw mine
        drawCircle(
            color = Color.Black,
            radius = tileSizePx * 0.15f,
            center = center
        )
    } else if (!tile.revealed && tile.mark == Mark.FLAG) {
        // Draw green checkmark
        val stroke = 2.dp.toPx()
        val size = tileSizePx * 0.4f
        val start = Offset(center.x - size / 2f, center.y)
        val mid = Offset(center.x - size / 8f, center.y + size / 2f)
        val end = Offset(center.x + size / 2f, center.y - size / 2f)
        drawLine(Color(0xFF4CAF50), start, mid, strokeWidth = stroke)
        drawLine(Color(0xFF4CAF50), mid, end, strokeWidth = stroke)
    } else if (!tile.revealed && tile.mark == Mark.QUESTION) {
        // Draw question mark
        drawCircle(
            color = Color.Blue,
            radius = tileSizePx * 0.08f,
            center = center,
            style = Stroke(width = 2.dp.toPx())
        )
    }
}

@Composable
private fun GameControls(vm: GameViewModel) {
    Spacer(modifier = Modifier.height(8.dp))
    
    Text(
        "Controls: Single Tap = ${vm.gameConfig.touchConfig.singleTap.displayName()}, " +
        "Double Tap = ${vm.gameConfig.touchConfig.doubleTap.displayName()}, " +
        "Triple Tap = ${vm.gameConfig.touchConfig.tripleTap.displayName()}, " +
        "Long Press = ${vm.gameConfig.touchConfig.longPress.displayName()}",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun GameStatus(gameState: GameState) {
    when (gameState) {
        GameState.WON -> {
            Text(
                "🎉 You Won! 🎉",
                style = MaterialTheme.typography.headlineMedium,
                color = Color(0xFF4CAF50),
                fontWeight = FontWeight.Bold
            )
        }
        GameState.LOST -> {
            Text(
                "💥 Game Over 💥",
                style = MaterialTheme.typography.headlineMedium,
                color = Color(0xFFF44336),
                fontWeight = FontWeight.Bold
            )
        }
        GameState.PLAYING -> {
            // No status message during play
        }
    }
}

@Composable
private fun SettingsDialog(
    config: GameConfig,
    onConfigChange: (GameConfig) -> Unit,
    onDismiss: () -> Unit
) {
    var tempConfig by remember { mutableStateOf(config) }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Game Settings") },
        text = {
            Column {
                Text("Grid Size")
                Row {
                    OutlinedTextField(
                        value = tempConfig.rows.toString(),
                        onValueChange = { 
                            it.toIntOrNull()?.let { rows ->
                                tempConfig = tempConfig.copy(rows = rows.coerceIn(5, 20))
                            }
                        },
                        label = { Text("Rows") },
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    OutlinedTextField(
                        value = tempConfig.cols.toString(),
                        onValueChange = { 
                            it.toIntOrNull()?.let { cols ->
                                tempConfig = tempConfig.copy(cols = cols.coerceIn(5, 20))
                            }
                        },
                        label = { Text("Cols") },
                        modifier = Modifier.weight(1f)
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                OutlinedTextField(
                    value = tempConfig.mineCount.toString(),
                    onValueChange = { 
                        it.toIntOrNull()?.let { mines ->
                            val maxMines = (tempConfig.rows * tempConfig.cols * 0.3).toInt()
                            tempConfig = tempConfig.copy(mineCount = mines.coerceIn(1, maxMines))
                        }
                    },
                    label = { Text("Mine Count") }
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text("Grid Type")
                GridTypeSelector(
                    selectedType = tempConfig.gridType,
                    onTypeSelected = { tempConfig = tempConfig.copy(gridType = it) }
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Row {
                    Checkbox(
                        checked = tempConfig.edgeMode,
                        onCheckedChange = { tempConfig = tempConfig.copy(edgeMode = it) }
                    )
                    Text("Edge Mode")
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text("Touch Controls")
                TouchControlsConfig(
                    config = tempConfig.touchConfig,
                    onConfigChange = { tempConfig = tempConfig.copy(touchConfig = it) }
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    onConfigChange(tempConfig)
                    onDismiss()
                }
            ) {
                Text("Apply")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}