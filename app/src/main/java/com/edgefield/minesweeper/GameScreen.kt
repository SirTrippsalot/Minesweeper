package com.edgefield.minesweeper

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.zIndex
import com.edgefield.minesweeper.graph.Cell
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

private const val GHOST_ALPHA = 0.4f

private fun Color.ghostly(isGhost: Boolean) = if (isGhost) copy(alpha = GHOST_ALPHA) else this

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
    val cellMatrix = remember(vm.board) {
        Array(config.rows) { y ->
            Array(config.cols) { x ->
                vm.board.getCell("${x}_${y}")!!
            }
        }
    }

    // Map cells to faces (same order as GameEngine)
    val (cellToFace, faceToCell) = remember(tiling, vm.board) {
        mapCellsToFaces(cellMatrix.flatten(), tiling.faces)
    }

    // Offsets for neighbour directions and their screen translations
    val directionOffsets = remember(tiling, vm.board) {
        computeDirectionOffsets(cellMatrix, tiling, cellToFace, faceToCell, config.gridType.kind)
    }
    val renderOffsets = remember(renderer, directionOffsets) {
        computeRenderOffsets(cellMatrix, renderer, cellToFace, directionOffsets, config.gridType.kind)
    }
    
    var scale by remember { mutableStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }

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
            .pointerInput(Unit) {
                detectTransformGestures { centroid, panChange, zoom, _ ->
                    val oldScale = scale
                    scale = (scale * zoom).coerceIn(0.5f, 5f)
                    val scaleDiff = scale / oldScale
                    pan += panChange + (centroid - pan) * (1 - scaleDiff)
                }
            }
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
                            val face = renderer.hitTest(offset, tiling)
                            val cell = face?.let { faceToCell[it] }
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
                                    val face = renderer.hitTest(doubleTapOffset, tiling)
                                    val cell = face?.let { faceToCell[it] }
                                    cell?.let { vm.handleTouch(it, config.touchConfig.doubleTap) }
                                }
                            }
                        },
                        onLongPress = { offset ->
                            val face = renderer.hitTest(offset, tiling)
                            val cell = face?.let { faceToCell[it] }
                            cell?.let { vm.handleTouch(it, config.touchConfig.longPress) }
                        }
                    )
                }
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
                    val brush = Brush.radialGradient(
                        colors = listOf(Color(0x80CCCCCC).ghostly(ghost), color),
                        center = center,
                        radius = renderer.size
                    )
                    drawPath(path = path, brush = brush)
                } else {
                    drawPath(path, color)
                    if (!cell.isMine) {
                        if (adj == 0) {
                            drawSandEffect(path, ghost)
                        } else {
                            drawWaterEffect(path, ghost)
                        }
                    }
                }
                drawPath(
                    path,
                    Color.Black.ghostly(ghost),
                    style = Stroke(width = 1.dp.toPx())
                )

                drawTileOverlays(
                    cell,
                    center,
                    renderer.size,
                    vm.gameState,
                    ghost
                )
            }

            // Draw each cell using GridSystem geometry
            cellMatrix.flatten().forEach { cell ->
                val face = cellToFace[cell]
                if (face != null) {
                    drawFace(cell, face)
                }
            }

            if (config.edgeMode) {
                cellMatrix.flatten().forEach { base ->
                    val baseFace = cellToFace[base] ?: return@forEach
                    val baseCenter = renderer.faceCentroid(baseFace)
                    val offsets = when (config.gridType.kind) {
                        GridKind.TRIANGLE -> triangleOffsetsFor(base.cx(), base.cy())
                        GridKind.SQUARE -> squareOffsets
                        else -> directionOffsets
                    }
                    offsets.forEach { delta ->
                        var nx = base.cx() + delta.first
                        var ny = base.cy() + delta.second
                        if (config.gridType.kind == GridKind.TRIANGLE && config.rows % 2 == 1) {
                            if (ny < 0 && delta.second == -1) nx -= 1
                            else if (ny >= config.rows && delta.second == 1) nx += 1
                        }
                        if (nx !in 0 until config.cols || ny !in 0 until config.rows) {
                            val wx = ((nx % config.cols) + config.cols) % config.cols
                            val wy = ((ny % config.rows) + config.rows) % config.rows
                            val wrappedCell = cellMatrix[wy][wx]
                            val wrappedFace = cellToFace[wrappedCell] ?: return@forEach
                            val step = when (config.gridType.kind) {
                                GridKind.TRIANGLE -> triangleStep(delta, (base.cx() + base.cy()) % 2 == 0, renderer.size)
                                GridKind.SQUARE -> squareStep(delta, renderer.size)
                                GridKind.HEXAGON -> {
                                    val pair = renderOffsets[delta] ?: (Offset.Zero to Offset.Zero)
                                    if (base.cx() % 2 == 1) pair.second else pair.first
                                }
                                else -> {
                                    val pair = renderOffsets[delta] ?: (Offset.Zero to Offset.Zero)
                                    pair.first
                                }
                            }
                            val wrappedCenter = renderer.faceCentroid(wrappedFace)
                            val offset = Offset(
                                baseCenter.x + step.x - wrappedCenter.x,
                                baseCenter.y + step.y - wrappedCenter.y
                            )
                            if (!offset.isZeroish()) {
                                drawFace(wrappedCell, wrappedFace, offset, true)
                            }
                        }
                    }
                }
            }

            // Draw a bold purple outline around the grid
            tiling.faces.forEach { face ->
                var edge = face.any
                do {
                    if (edge.twin.face.sides == 0) {
                        val start = renderer.modelToOffset(edge.origin)
                        val end = renderer.modelToOffset(edge.next.origin)
                        drawLine(
                            color = Color(0xFF800080),
                            start = start,
                            end = end,
                            strokeWidth = 4.dp.toPx()
                        )
                    }
                    edge = edge.next
                } while (edge !== face.any)
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

                    Text(
                        text = count.toString(),
                        color = when (count) {
                            1 -> Color.Blue
                            2 -> Color.Green
                            3 -> Color.Red
                            4 -> Color(0xFF800080) // Purple
                            5 -> Color(0xFF800000) // Maroon
                            6 -> Color.Cyan
                            7 -> Color.Black
                            8 -> Color.Gray
                            else -> Color.Black
                        }.ghostly(ghost),
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

        cellMatrix.flatten().forEach { cell ->
            val face = cellToFace[cell]
            if (face != null) {
                drawNumber(cell, face)
            }
        }

        if (config.edgeMode) {
            cellMatrix.flatten().forEach { base ->
                val baseFace = cellToFace[base] ?: return@forEach
                val baseCenter = renderer.faceCentroid(baseFace)
                val offsets = when (config.gridType.kind) {
                    GridKind.TRIANGLE -> triangleOffsetsFor(base.cx(), base.cy())
                    GridKind.SQUARE -> squareOffsets
                    else -> directionOffsets
                }
                offsets.forEach { delta ->
                    var nx = base.cx() + delta.first
                    var ny = base.cy() + delta.second
                    if (config.gridType.kind == GridKind.TRIANGLE && config.rows % 2 == 1) {
                        if (ny < 0 && delta.second == -1) nx -= 1
                        else if (ny >= config.rows && delta.second == 1) nx += 1
                    }
                    if (nx !in 0 until config.cols || ny !in 0 until config.rows) {
                        val wx = ((nx % config.cols) + config.cols) % config.cols
                        val wy = ((ny % config.rows) + config.rows) % config.rows
                        val wrappedCell = cellMatrix[wy][wx]
                        val wrappedFace = cellToFace[wrappedCell] ?: return@forEach
                        val step = when (config.gridType.kind) {
                            GridKind.TRIANGLE -> triangleStep(delta, (base.cx() + base.cy()) % 2 == 0, renderer.size)
                            GridKind.SQUARE -> squareStep(delta, renderer.size)
                            GridKind.HEXAGON -> {
                                val pair = renderOffsets[delta] ?: (Offset.Zero to Offset.Zero)
                                if (base.cx() % 2 == 1) pair.second else pair.first
                            }
                            else -> {
                                val pair = renderOffsets[delta] ?: (Offset.Zero to Offset.Zero)
                                pair.first
                            }
                        }
                        val wrappedCenter = renderer.faceCentroid(wrappedFace)
                        val offset = Offset(
                            baseCenter.x + step.x - wrappedCenter.x,
                            baseCenter.y + step.y - wrappedCenter.y
                        )
                        if (!offset.isZeroish()) {
                            drawNumber(wrappedCell, wrappedFace, offset, true)
                        }
                    }
                }
            }
        }
    }
}

// TouchAction.displayName() is defined in GameComponents.kt



private fun getCellColor(cell: Cell, adj: Int, gameState: GameState): Color {
    return when {
        !cell.isRevealed && cell.isFlagged -> Color(0xFF64B5F6) // Darker blue water for flagged cells
        !cell.isRevealed -> Color(0xFF9E9E9E) // Gray for unrevealed
        cell.isMine && gameState == GameState.LOST -> Color(0xFFF44336) // Red for mines
        cell.isRevealed && adj == 0 -> Color(0xFFFFF9C4) // Sand for empty island
        cell.isRevealed -> Color(0xFFB3E5FC) // Light blue for ocean
        else -> Color(0xFFE0E0E0) // Default fallback
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
        // Draw mine
        drawCircle(
            color = Color.Black.ghostly(ghost),
            radius = tileSizePx * 0.15f,
            center = center
        )
    } else if (!cell.isRevealed && cell.isFlagged) {
        val stroke = 2.dp.toPx()
        val size = tileSizePx * 0.4f
        if (gameState == GameState.LOST && !cell.isMine) {
            // Draw red X for incorrect flag
            val half = size / 2f
            val topLeft = Offset(center.x - half, center.y - half)
            val topRight = Offset(center.x + half, center.y - half)
            val bottomLeft = Offset(center.x - half, center.y + half)
            val bottomRight = Offset(center.x + half, center.y + half)
            drawLine(Color.Red.ghostly(ghost), topLeft, bottomRight, strokeWidth = stroke)
            drawLine(Color.Red.ghostly(ghost), topRight, bottomLeft, strokeWidth = stroke)
        } else {
            // Draw green checkmark
            val start = Offset(center.x - size / 2f, center.y)
            val mid = Offset(center.x - size / 8f, center.y + size / 2f)
            val end = Offset(center.x + size / 2f, center.y - size / 2f)
            drawLine(Color(0xFF4CAF50).ghostly(ghost), start, mid, strokeWidth = stroke)
            drawLine(Color(0xFF4CAF50).ghostly(ghost), mid, end, strokeWidth = stroke)
        }
    }
}

private fun DrawScope.drawWaterEffect(path: Path, ghost: Boolean) {
    val bounds = path.getBounds()
    val step = bounds.height / 4f
    val color = Color(0xFF2196F3).copy(alpha = 0.3f).ghostly(ghost)
    clipPath(path) {
        for (i in 1 until 4) {
            val y = bounds.top + i * step
            drawLine(
                color = color,
                start = Offset(bounds.left, y),
                end = Offset(bounds.right, y),
                strokeWidth = 1.dp.toPx()
            )
        }
    }
}

private fun DrawScope.drawSandEffect(path: Path, ghost: Boolean) {
    val bounds = path.getBounds()
    val step = bounds.width / 5f
    val color = Color(0xFFBCAAA4).copy(alpha = 0.5f).ghostly(ghost)
    clipPath(path) {
        for (x in 0 until 5) {
            for (y in 0 until 5) {
                val cx = bounds.left + (x + 0.5f) * step
                val cy = bounds.top + (y + 0.5f) * step
                drawCircle(color, radius = step / 10f, center = Offset(cx, cy))
            }
        }
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