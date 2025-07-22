package com.edgefield.minesweeper

/** Helper to create bidirectional mappings between board tiles and tiling faces. */
internal fun mapTilesToFaces(
    tiles: List<Tile>,
    faces: List<Face>
): Pair<Map<Tile, Face>, Map<Face, Tile>> {
    require(tiles.size == faces.size) {
        "Tile count (${tiles.size}) must match face count (${faces.size})"
    }
    val tileToFace = mutableMapOf<Tile, Face>()
    val faceToTile = mutableMapOf<Face, Tile>()
    tiles.forEachIndexed { idx, tile ->
        val face = faces[idx]
        tileToFace[tile] = face
        faceToTile[face] = tile
    }
    return tileToFace to faceToTile
}
