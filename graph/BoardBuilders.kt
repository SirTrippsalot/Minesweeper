package graph

fun buildSquareBoard(cols: Int, rows: Int): GameBoard {
    val board = GameBoard()
    for (y in 0 until rows) {
        for (x in 0 until cols) {
            val id = "${x}_${y}"
            board.addCell(Cell(id))
        }
    }
    val offsets = listOf(
        -1 to 0, 1 to 0, 0 to -1, 0 to 1,
        -1 to -1, -1 to 1, 1 to -1, 1 to 1
    )
    for (y in 0 until rows) {
        for (x in 0 until cols) {
            val id = "${x}_${y}"
            offsets.forEach { (dx, dy) ->
                val nx = x + dx
                val ny = y + dy
                if (nx in 0 until cols && ny in 0 until rows) {
                    board.connect(id, "${nx}_${ny}")
                }
            }
        }
    }
    return board
}

fun buildTriangleBoard(cols: Int, rows: Int): GameBoard {
    val board = GameBoard()
    for (y in 0 until rows) {
        for (x in 0 until cols) {
            val id = "${x}_${y}"
            board.addCell(Cell(id))
        }
    }
    for (y in 0 until rows) {
        for (x in 0 until cols) {
            val id = "${x}_${y}"
            val up = (x + y) % 2 == 0
            val neighbors = if (up) {
                listOf(-1 to 0, 1 to 0, 0 to 1)
            } else {
                listOf(-1 to 0, 1 to 0, 0 to -1)
            }
            neighbors.forEach { (dx, dy) ->
                val nx = x + dx
                val ny = y + dy
                if (nx in 0 until cols && ny in 0 until rows) {
                    board.connect(id, "${nx}_${ny}")
                }
            }
        }
    }
    return board
}

fun buildMixedDemoBoard(): GameBoard {
    val board = buildSquareBoard(2, 2)
    val offsetX = 2
    val triangles = buildTriangleBoard(2, 1)
    triangles.cells.forEach { cell ->
        val (x, y) = cell.id.split('_').map { it.toInt() }
        val newId = "${x + offsetX}_${y}"
        board.addCell(Cell(newId))
    }
    triangles.cells.forEach { cell ->
        val (x, y) = cell.id.split('_').map { it.toInt() }
        val id = "${x + offsetX}_${y}"
        cell.neighbors.forEach { n ->
            val (nx, ny) = n.id.split('_').map { it.toInt() }
            board.connect(id, "${nx + offsetX}_${ny}")
        }
    }
    board.connect("1_0", "2_0")
    return board
}
