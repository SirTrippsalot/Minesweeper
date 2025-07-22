package com.edgefield.minesweeper

// Simple test to verify GridSystem integration
fun testGridSystemIntegration() {
    // Test square grid
    val squareTiling = GridFactory.build(GridKind.SQUARE, 5, 5)
    println("Square grid: ${squareTiling.faces.size} faces")
    
    // Test hex grid
    val hexTiling = GridFactory.build(GridKind.HEXAGON, 5, 5)
    println("Hex grid: ${hexTiling.faces.size} faces")
    
    // Test triangle grid
    val triangleTiling = GridFactory.build(GridKind.TRIANGLE, 5, 5)
    println("Triangle grid: ${triangleTiling.faces.size} faces")
    
    // Test neighbor lookup
    if (squareTiling.faces.isNotEmpty()) {
        val firstFace = squareTiling.faces[0]
        val neighbors = squareTiling.neighbours(firstFace)
        println("First square face has ${neighbors.size} neighbors")
    }
}

// Verify neighbour counts via GameEngine
fun testNeighborCounts() {
    val types = listOf(GridType.SQUARE, GridType.TRIANGLE, GridType.HEXAGON)
    types.forEach { type ->
        val config = GameConfig(rows = 3, cols = 3, mineCount = 0, gridType = type)
        val engine = GameEngine(config)
        val tile = engine.board[1][1]
        val method = GameEngine::class.java.getDeclaredMethod("neighbors", Tile::class.java).apply {
            isAccessible = true
        }
        val neighbors = method.invoke(engine, tile) as List<*>
        val expected = when (type) {
            GridType.SQUARE -> GridKind.SQUARE.neighborCount
            GridType.TRIANGLE -> GridKind.TRIANGLE.neighborCount
            GridType.HEXAGON -> GridKind.HEXAGON.neighborCount
            else -> 0
        }
        println("${type.name} center has ${neighbors.size} neighbors")
        check(neighbors.size == expected) {
            "${type.name} expected $expected neighbors, got ${neighbors.size}"
        }
    }
}
