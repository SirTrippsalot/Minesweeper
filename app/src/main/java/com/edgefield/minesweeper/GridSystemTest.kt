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