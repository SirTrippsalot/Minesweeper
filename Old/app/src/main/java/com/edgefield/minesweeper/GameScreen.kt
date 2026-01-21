package com.edgefield.minesweeper

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalViewConfiguration
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Done
import androidx.compose.material3.*
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.rememberCoroutineScope
import android.view.ViewConfiguration
import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.zIndex
import com.edgefield.minesweeper.graph.Cell
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

private const val GHOST_ALPHA = 0.4f

// In infinite mode, all tiles are fully opaque (no ghosting)
private fun Color.ghostly(isGhost: Boolean) = this

private fun Offset.isZeroish(epsilon: Float = 0.5f): Boolean {
    return kotlin.math.abs(x) < epsilon && kotlin.math.abs(y) < epsilon
}

private fun Cell.cx(): Int = id.substringBefore('_').toInt()
private fun Cell.cy(): Int = id.substringAfter('_').toInt()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameScreen(vm: GameViewModel) {
    var showSettings by remember { mutableStateOf(false) }
    val tileSize = 40.dp
    
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top menu with stats and controls
        val sandColor = Color(0xFFF5EBDD)
        val textColor = Color(0xFF2C3E50)
        SmallTopAppBar(
            modifier = Modifier
                .fillMaxWidth()
                .zIndex(1f),
            colors = TopAppBarDefaults.smallTopAppBarColors(
                containerColor = sandColor
            ),
            title = {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            painter = painterResource(id = R.drawable.ic_mine),
                            contentDescription = stringResource(R.string.mines),
                            tint = textColor,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            "${vm.getRemainingMines()}/${vm.gameConfig.mineCount}",
                            modifier = Modifier.padding(start = 6.dp),
                            color = textColor,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Row(
                        modifier = Modifier.weight(1f),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            painter = painterResource(id = R.drawable.ic_timer),
                            contentDescription = stringResource(R.string.time),
                            tint = textColor,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            vm.getElapsedTimeFormatted(),
                            modifier = Modifier.padding(start = 6.dp),
                            color = textColor,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Row(
                        modifier = Modifier.weight(1f),
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            painter = painterResource(id = R.drawable.ic_moves),
                            contentDescription = stringResource(R.string.moves),
                            tint = textColor,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            vm.stats.totalMoves.toString(),
                            modifier = Modifier.padding(start = 6.dp),
                            color = textColor,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            },
            actions = {
                IconButton(onClick = { showSettings = true }) {
                    Icon(Icons.Default.Settings, contentDescription = "Options")
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
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Game board
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            GameBoard(vm, tileSize)
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Bottom controls area
        Surface(
            color = Color(0xFFFFF9C4),
            tonalElevation = 2.dp,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                GameControls(vm)
                GameStatus(vm.gameState)
            }
        }
    }
    
    if (showSettings) {
        SettingsDialog(
            config = vm.gameConfig,
            onConfigChange = vm::updateConfig,
            onDismiss = { showSettings = false }
        )
    }
}

private fun computeDirectionOffsets(
    board: Array<Array<Cell>>,
    tiling: Tiling,
    cellToFace: Map<Cell, Face>,
    faceToCell: Map<Face, Cell>,
    kind: GridKind
): List<Pair<Int, Int>> {
    val expected = kind.neighborCount
    board.flatten().forEach { cell ->
        val face = cellToFace[cell] ?: return@forEach
        val neighbors = tiling.neighbours(face).mapNotNull { nf -> faceToCell[nf] }
        if (neighbors.size == expected) {
            val cx = cell.cx()
            val cy = cell.cy()
            return neighbors.map { it.cx() - cx to it.cy() - cy }
        }
    }
    return when (kind) {
        GridKind.SQUARE -> listOf(
            -1 to 0, 1 to 0, 0 to -1, 0 to 1,
            -1 to -1, -1 to 1, 1 to -1, 1 to 1
        )
        GridKind.TRIANGLE -> listOf(-1 to 0, 1 to 0, 0 to 1, 0 to -1)
        else -> {
            val first = board[0][0]
            val face = cellToFace[first] ?: return emptyList()
            tiling.neighbours(face).mapNotNull { nf -> faceToCell[nf] }
                .map { it.cx() - first.cx() to it.cy() - first.cy() }
        }
    }
}

private fun computeRenderOffsets(
    board: Array<Array<Cell>>,
    renderer: TilingRenderer,
    cellToFace: Map<Cell, Face>,
    offsets: List<Pair<Int, Int>>,
    kind: GridKind
): Map<Pair<Int, Int>, Pair<Offset, Offset>> {
    val out = mutableMapOf<Pair<Int, Int>, Pair<Offset, Offset>>()
    offsets.forEach { delta ->
        val (dx, dy) = delta
        var even: Offset? = null
        var odd: Offset? = null
        outer@ for (y in board.indices) {
            for (x in board[y].indices) {
                val nx = x + dx
                val ny = y + dy
                if (nx in board[y].indices && ny in board.indices) {
                    val a = board[y][x]
                    val b = board[ny][nx]
                    val fa = cellToFace[a] ?: continue
                    val fb = cellToFace[b] ?: continue
                    val ca = renderer.faceCentroid(fa)
                    val cb = renderer.faceCentroid(fb)
                    val diff = Offset(cb.x - ca.x, cb.y - ca.y)
                    if (even == null) even = diff
                    if (x % 2 == 1 && odd == null) odd = diff
                    if (even != null && odd != null) break@outer
                }
            }
        }
        val fallback = even ?: odd ?: Offset.Zero
        even = even ?: fallback
        odd = odd ?: fallback
        out[delta] = even to if (kind == GridKind.HEXAGON) odd else even
    }
    return out
}

private val sqrt3 = sqrt(3f)

private val squareOffsets = listOf(
    -1 to 0, 1 to 0, 0 to -1, 0 to 1,
    -1 to -1, -1 to 1, 1 to -1, 1 to 1
)

private fun triangleOffsetsFor(x: Int, y: Int): List<Pair<Int, Int>> =
    if ((x + y) % 2 == 0) listOf(-1 to 0, 1 to 0, 0 to 1)
    else listOf(-1 to 0, 1 to 0, 0 to -1)

private fun triangleStep(delta: Pair<Int, Int>, up: Boolean, size: Float): Offset {
    val half = 0.5f * size
    val sixth = sqrt3 / 6f * size
    val third = sqrt3 / 3f * size
    val twoThird = 2f * sqrt3 / 3f * size
    return when (delta) {
        -1 to 0 -> Offset(-half, if (up) sixth else -sixth)
        1 to 0 -> Offset(half, if (up) sixth else -sixth)
        0 to 1 -> Offset(0f, if (up) twoThird else third)
        0 to -1 -> Offset(0f, if (up) -third else -twoThird)
        else -> Offset.Zero
    }
}

private fun squareStep(delta: Pair<Int, Int>, size: Float): Offset =
    Offset(delta.first * size, delta.second * size)

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
        else -> 1f
    }
    val renderer = remember(tileSizePx, bounds, scaleMultiplier) {
        TilingRenderer(tileSizePx * scaleMultiplier, bounds)
    }
    
    // Build a row-major matrix of cells for consistent ordering
    // Use vm.boardVersion to trigger recomposition when board state changes
    val cellMatrix = remember(vm.boardVersion, config.rows, config.cols) {
        Array(config.rows) { y ->
            Array(config.cols) { x ->
                vm.board.getCell("${x}_${y}")!!
            }
        }
    }

    // Map cells to faces (same order as GameEngine)
    val (cellToFace, faceToCell) = remember(tiling, cellMatrix) {
        mapCellsToFaces(cellMatrix.flatten(), tiling.faces)
    }

    // Offsets for neighbour directions and their screen translations
    val directionOffsets = remember(tiling, cellMatrix) {
        computeDirectionOffsets(cellMatrix, tiling, cellToFace, faceToCell, config.gridType.kind)
    }
    val renderOffsets = remember(renderer, directionOffsets) {
        computeRenderOffsets(cellMatrix, renderer, cellToFace, directionOffsets, config.gridType.kind)
    }
    
    var scale by remember { mutableStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }

    val coroutineScope = rememberCoroutineScope()
    var waitingForTriple by remember { mutableStateOf(false) }
    var doubleTapOffset by remember { mutableStateOf(Offset.Zero) }
    val tripleTimeout = ViewConfiguration.getDoubleTapTimeout().toLong()
    val viewConfig = LocalViewConfiguration.current

    // Helper function to find cell at any position
    fun findCellAtOffset(screenOffset: Offset, containerWidth: Float, containerHeight: Float): Cell? {
        // Get the center of the container
        val containerCenterX = containerWidth / 2f
        val containerCenterY = containerHeight / 2f

        // Transform screen coordinates to board coordinates
        // Account for: container center, pan offset, and scale
        val boardX = (screenOffset.x - containerCenterX - pan.x) / scale
        val boardY = (screenOffset.y - containerCenterY - pan.y) / scale

        // Offset by half the renderer size to get back to board origin
        val rendererCenterX = renderer.width / 2f
        val rendererCenterY = renderer.height / 2f
        val relativeX = boardX + rendererCenterX
        val relativeY = boardY + rendererCenterY

        // Wrap the offset to the main grid
        val gridWidth = renderer.width
        val gridHeight = renderer.height
        val wrappedX = ((relativeX % gridWidth) + gridWidth) % gridWidth
        val wrappedY = ((relativeY % gridHeight) + gridHeight) % gridHeight
        val wrappedOffset = Offset(wrappedX, wrappedY)

        val face = renderer.hitTest(wrappedOffset, tiling)
        return face?.let { faceToCell[it] }
    }

    // Outer box that fills available space
    Box(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput("tap", config.touchConfig, vm.boardVersion) {
                detectTapGestures(
                    onTap = { offset ->
                        val cell = findCellAtOffset(offset, size.width.toFloat(), size.height.toFloat())
                        if (waitingForTriple) {
                            waitingForTriple = false
                            cell?.let { vm.handleTouch(it, config.touchConfig.tripleTap) }
                        } else {
                            cell?.let { vm.handleTouch(it, config.touchConfig.singleTap) }
                        }
                    },
                    onDoubleTap = { offset ->
                        waitingForTriple = true
                        doubleTapOffset = offset
                        coroutineScope.launch {
                            delay(tripleTimeout)
                            if (waitingForTriple) {
                                waitingForTriple = false
                                val cell = findCellAtOffset(doubleTapOffset, size.width.toFloat(), size.height.toFloat())
                                cell?.let { vm.handleTouch(it, config.touchConfig.doubleTap) }
                            }
                        }
                    },
                    onLongPress = { offset ->
                        val cell = findCellAtOffset(offset, size.width.toFloat(), size.height.toFloat())
                        cell?.let { vm.handleTouch(it, config.touchConfig.longPress) }
                    }
                )
            }
            .pointerInput("transform") {
                detectTransformGestures { _, panChange, zoom, _ ->
                    scale = (scale * zoom).coerceIn(0.5f, 5f)
                    pan += panChange
                }
            },
        contentAlignment = Alignment.Center
    ) {
        // Inner box with the actual board content
        Box(
            modifier = Modifier
                .size(
                    width = (renderer.width / density).dp,
                    height = (renderer.height / density).dp
                )
                .graphicsLayer {
                    translationX = pan.x
                    translationY = pan.y
                    scaleX = scale
                    scaleY = scale
                    clip = false
                }
        ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
        ) {
            fun drawFace(
                cell: Cell,
                face: Face,
                offset: Offset = Offset.Zero,
                ghost: Boolean = false
            ) {
                val adj = vm.board.countNeighborMines(cell.id)
                val color = getCellColor(cell, adj, vm.gameState).ghostly(ghost)

                val path = Path()
                var e = face.any
                var first = true
                do {
                    val pt = renderer.modelToOffset(e.origin)
                    val shifted = Offset(pt.x + offset.x, pt.y + offset.y)
                    if (first) {
                        path.moveTo(shifted.x, shifted.y)
                        first = false
                    } else {
                        path.lineTo(shifted.x, shifted.y)
                    }
                    e = e.next
                } while (e !== face.any)
                path.close()

                val center = renderer.faceCentroid(face) + offset
                if (!cell.isRevealed) {
                    // Create a 3D-like raised effect for unrevealed cells
                    val highlightColor = when (cell.mark) {
                        Mark.FLAG -> Color(0xFF2196F3) // Lighter blue highlight
                        Mark.QUESTION -> Color(0xFFFFCA28) // Lighter amber highlight
                        else -> Color(0xFF78909C) // Lighter slate highlight
                    }.ghostly(ghost)

                    val brush = Brush.radialGradient(
                        colors = listOf(highlightColor, color),
                        center = center,
                        radius = renderer.size * 0.8f
                    )
                    drawPath(path = path, brush = brush)

                    // Add subtle shadow for depth
                    val shadowBrush = Brush.linearGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.15f).ghostly(ghost)),
                        start = Offset(center.x - renderer.size * 0.3f, center.y - renderer.size * 0.3f),
                        end = Offset(center.x + renderer.size * 0.3f, center.y + renderer.size * 0.3f)
                    )
                    drawPath(path = path, brush = shadowBrush)
                } else {
                    // Revealed cells with gradient backgrounds
                    if (cell.isMine) {
                        drawPath(path, color)
                    } else if (adj == 0) {
                        // Sand with subtle gradient
                        val sandBrush = Brush.radialGradient(
                            colors = listOf(Color(0xFFFFF3E0).ghostly(ghost), color),
                            center = center,
                            radius = renderer.size * 1.2f
                        )
                        drawPath(path = path, brush = sandBrush)
                        drawSandEffect(path, ghost)
                    } else {
                        // Water with gradient
                        val waterBrush = Brush.linearGradient(
                            colors = listOf(Color(0xFFB3E5FC).ghostly(ghost), color),
                            start = Offset(center.x - renderer.size, center.y - renderer.size),
                            end = Offset(center.x + renderer.size, center.y + renderer.size)
                        )
                        drawPath(path = path, brush = waterBrush)
                        drawWaterEffect(path, ghost)
                    }
                }
                // Draw borders with depth - lighter on top, darker on bottom
                if (!cell.isRevealed) {
                    drawPath(
                        path,
                        Color(0xFF37474F).ghostly(ghost),
                        style = Stroke(width = 2.dp.toPx())
                    )
                } else {
                    drawPath(
                        path,
                        Color(0xFF455A64).copy(alpha = 0.5f).ghostly(ghost),
                        style = Stroke(width = 1.dp.toPx())
                    )
                }

                drawTileOverlays(
                    cell,
                    center,
                    renderer.size,
                    vm.gameState,
                    ghost
                )
            }

            // Draw each cell once - infinite scrolling is handled by viewport wrapping
            cellMatrix.flatten().forEach { cell ->
                val face = cellToFace[cell]
                if (face != null) {
                    drawFace(cell, face)
                }
            }
        }
        
        // Overlay text numbers on top
        @Composable
        fun drawNumber(
            cell: Cell,
            face: Face,
            offset: Offset = Offset.Zero,
            ghost: Boolean = false
        ) {
            val count = vm.board.countNeighborMines(cell.id)
            if (cell.isRevealed && !cell.isMine && count > 0) {
                val center = renderer.faceCentroid(face) + offset

                Box(
                    modifier = Modifier
                        .offset(
                            x = (center.x / density - tileSize.value * 0.5f).dp,
                            y = (center.y / density - tileSize.value * 0.5f).dp
                        )
                        .size(tileSize)
                        .wrapContentSize(Alignment.Center)
                ) {
                    // Shadow layer for depth
                    Text(
                        text = count.toString(),
                        color = Color.Black.copy(alpha = 0.3f).ghostly(ghost),
                        fontSize = (tileSize.value * 0.5f).sp,
                        fontWeight = FontWeight.ExtraBold,
                        modifier = Modifier.offset(x = 1.dp, y = 1.dp)
                    )
                    // Main number with modern colors
                    Text(
                        text = count.toString(),
                        color = when (count) {
                            1 -> Color(0xFF1565C0) // Deep blue
                            2 -> Color(0xFF2E7D32) // Forest green
                            3 -> Color(0xFFC62828) // Crimson
                            4 -> Color(0xFF6A1B9A) // Deep purple
                            5 -> Color(0xFFD84315) // Deep orange
                            6 -> Color(0xFF00838F) // Teal
                            7 -> Color(0xFF263238) // Almost black
                            8 -> Color(0xFF424242) // Dark gray
                            else -> Color.Black
                        }.ghostly(ghost),
                        fontSize = (tileSize.value * 0.5f).sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }
        }

        // Draw numbers once - infinite scrolling is handled by viewport wrapping
        cellMatrix.flatten().forEach { cell ->
            val face = cellToFace[cell]
            if (face != null) {
                drawNumber(cell, face)
            }
        }
        } // End inner Box (board content)
    } // End outer Box (fill size + transformable)
}

// TouchAction.displayName() is defined in GameComponents.kt



private fun getCellColor(cell: Cell, adj: Int, gameState: GameState): Color {
    return when {
        !cell.isRevealed && cell.mark == Mark.FLAG -> Color(0xFF1976D2) // Deep ocean blue for flagged cells
        !cell.isRevealed && cell.mark == Mark.QUESTION -> Color(0xFFFFB300) // Bright amber for question marked cells
        !cell.isRevealed -> Color(0xFF546E7A) // Slate blue-gray for unrevealed
        cell.isMine && gameState == GameState.LOST -> Color(0xFFD32F2F) // Vibrant red for mines
        cell.isRevealed && adj == 0 -> Color(0xFFFFECB3) // Warm sand for empty island
        cell.isRevealed -> Color(0xFF81D4FA) // Bright tropical water
        else -> Color(0xFFCFD8DC) // Light gray fallback
    }
}

private fun DrawScope.drawTileOverlays(
    cell: Cell,
    center: Offset,
    tileSizePx: Float,
    gameState: GameState,
    ghost: Boolean = false
) {
    // Draw mines, flags, and question marks as overlays
    if (cell.isMine && gameState == GameState.LOST) {
        // Draw mine with 3D effect
        // Shadow
        drawCircle(
            color = Color.Black.copy(alpha = 0.4f).ghostly(ghost),
            radius = tileSizePx * 0.18f,
            center = Offset(center.x + 2f, center.y + 2f)
        )
        // Main mine body with gradient
        val mineBrush = Brush.radialGradient(
            colors = listOf(Color(0xFF616161).ghostly(ghost), Color(0xFF212121).ghostly(ghost)),
            center = center,
            radius = tileSizePx * 0.18f
        )
        drawCircle(
            brush = mineBrush,
            radius = tileSizePx * 0.18f,
            center = center
        )
        // Highlight for metallic shine
        drawCircle(
            color = Color.White.copy(alpha = 0.3f).ghostly(ghost),
            radius = tileSizePx * 0.08f,
            center = Offset(center.x - tileSizePx * 0.06f, center.y - tileSizePx * 0.06f)
        )
        // Mine spikes
        val spikeLength = tileSizePx * 0.12f
        for (i in 0 until 8) {
            val angle = i * Math.PI / 4
            val endX = center.x + cos(angle).toFloat() * spikeLength
            val endY = center.y + sin(angle).toFloat() * spikeLength
            drawLine(
                color = Color(0xFF212121).ghostly(ghost),
                start = center,
                end = Offset(endX, endY),
                strokeWidth = 2.dp.toPx()
            )
        }
    } else if (!cell.isRevealed && cell.mark == Mark.FLAG) {
        val stroke = 3.dp.toPx()
        val size = tileSizePx * 0.45f
        if (gameState == GameState.LOST && !cell.isMine) {
            // Draw red X for incorrect flag with shadow
            val half = size / 2f
            val topLeft = Offset(center.x - half, center.y - half)
            val topRight = Offset(center.x + half, center.y - half)
            val bottomLeft = Offset(center.x - half, center.y + half)
            val bottomRight = Offset(center.x + half, center.y + half)

            // Shadow
            drawLine(Color.Black.copy(alpha = 0.3f).ghostly(ghost),
                Offset(topLeft.x + 2f, topLeft.y + 2f),
                Offset(bottomRight.x + 2f, bottomRight.y + 2f),
                strokeWidth = stroke)
            drawLine(Color.Black.copy(alpha = 0.3f).ghostly(ghost),
                Offset(topRight.x + 2f, topRight.y + 2f),
                Offset(bottomLeft.x + 2f, bottomLeft.y + 2f),
                strokeWidth = stroke)

            // Main X
            drawLine(Color(0xFFD32F2F).ghostly(ghost), topLeft, bottomRight, strokeWidth = stroke)
            drawLine(Color(0xFFD32F2F).ghostly(ghost), topRight, bottomLeft, strokeWidth = stroke)
        } else {
            // Draw modern checkmark with shadow
            val start = Offset(center.x - size / 2f, center.y)
            val mid = Offset(center.x - size / 8f, center.y + size / 2f)
            val end = Offset(center.x + size / 2f, center.y - size / 2f)

            // Shadow
            drawLine(
                Color.Black.copy(alpha = 0.3f).ghostly(ghost),
                Offset(start.x + 2f, start.y + 2f),
                Offset(mid.x + 2f, mid.y + 2f),
                strokeWidth = stroke
            )
            drawLine(
                Color.Black.copy(alpha = 0.3f).ghostly(ghost),
                Offset(mid.x + 2f, mid.y + 2f),
                Offset(end.x + 2f, end.y + 2f),
                strokeWidth = stroke
            )

            // Main checkmark
            drawLine(Color(0xFF2E7D32).ghostly(ghost), start, mid, strokeWidth = stroke)
            drawLine(Color(0xFF2E7D32).ghostly(ghost), mid, end, strokeWidth = stroke)
        }
    } else if (!cell.isRevealed && cell.mark == Mark.QUESTION) {
        drawIntoCanvas { canvas ->
            // Shadow
            val shadowPaint = Paint().apply {
                color = Color.Black.copy(alpha = 0.3f).toArgb()
                textAlign = Paint.Align.CENTER
                textSize = tileSizePx * 0.6f
                typeface = Typeface.DEFAULT_BOLD
            }
            canvas.nativeCanvas.drawText("?", center.x + 2f, center.y + shadowPaint.textSize / 3f + 2f, shadowPaint)

            // Main question mark
            val paint = Paint().apply {
                color = Color(0xFFFF6F00).toArgb() // Vibrant orange
                textAlign = Paint.Align.CENTER
                textSize = tileSizePx * 0.6f
                typeface = Typeface.DEFAULT_BOLD
            }
            canvas.nativeCanvas.drawText("?", center.x, center.y + paint.textSize / 3f, paint)
        }
    }
}

private fun DrawScope.drawWaterEffect(path: Path, ghost: Boolean) {
    val bounds = path.getBounds()
    val step = bounds.height / 3f
    clipPath(path) {
        // Draw just 2 subtle wave lines
        for (i in 1..2) {
            val y = bounds.top + i * step
            val color = Color(0xFF0D47A1).copy(alpha = 0.15f).ghostly(ghost)
            drawLine(
                color = color,
                start = Offset(bounds.left, y),
                end = Offset(bounds.right, y),
                strokeWidth = 0.5.dp.toPx()
            )
        }
        // Single shimmer line
        val shimmer = Color(0xFFE1F5FE).copy(alpha = 0.15f).ghostly(ghost)
        drawLine(
            color = shimmer,
            start = Offset(bounds.left, bounds.top),
            end = Offset(bounds.right, bounds.bottom),
            strokeWidth = 1.dp.toPx()
        )
    }
}

private fun DrawScope.drawSandEffect(path: Path, ghost: Boolean) {
    val bounds = path.getBounds()
    val step = bounds.width / 4f
    clipPath(path) {
        // Draw simplified sand texture (4x4 grid instead of 6x6)
        val baseColor = Color(0xFFD7CCC8).copy(alpha = 0.25f).ghostly(ghost)
        for (x in 0 until 4) {
            for (y in 0 until 4) {
                val cx = bounds.left + (x + 0.5f) * step
                val cy = bounds.top + (y + 0.5f) * step
                drawCircle(baseColor, radius = step / 12f, center = Offset(cx, cy))
            }
        }

        // Add subtle highlight for sun-bleached sand effect
        val highlight = Color(0xFFFFFBF0).copy(alpha = 0.12f).ghostly(ghost)
        drawCircle(
            color = highlight,
            radius = bounds.width / 3f,
            center = Offset(bounds.centerLeft.x + bounds.width * 0.4f, bounds.centerLeft.y - bounds.height * 0.2f)
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
                    ConfigNumberField(
                        label = "Rows",
                        value = tempConfig.rows,
                        onValueChange = { tempConfig = tempConfig.copy(rows = it) },
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    ConfigNumberField(
                        label = "Cols",
                        value = tempConfig.cols,
                        onValueChange = { tempConfig = tempConfig.copy(cols = it) },
                        modifier = Modifier.weight(1f)
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))

                DifficultySelector(
                    selected = tempConfig.difficulty,
                    onSelected = { tempConfig = tempConfig.copy(difficulty = it) }
                )

                if (tempConfig.difficulty == Difficulty.CUSTOM) {
                    Spacer(modifier = Modifier.height(8.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Use Percentage")
                        Spacer(Modifier.width(8.dp))
                        Switch(
                            checked = tempConfig.useMinePercent,
                            onCheckedChange = { tempConfig = tempConfig.copy(useMinePercent = it) }
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    ConfigNumberField(
                        label = if (tempConfig.useMinePercent) "Mine %" else "Mine Count",
                        value = tempConfig.customMines,
                        onValueChange = { value ->
                            val max = tempConfig.rows * tempConfig.cols - 1
                            tempConfig = tempConfig.copy(customMines = value.coerceIn(1, max))
                        }
                    )
                }
                
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
                    val clamped = tempConfig.copy(
                        rows = tempConfig.rows.coerceIn(5, 100),
                        cols = tempConfig.cols.coerceIn(5, 100)
                    )
                    onConfigChange(clamped)
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