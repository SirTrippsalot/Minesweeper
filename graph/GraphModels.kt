package graph

data class Cell(val id: String) {
    val neighbors: MutableSet<Cell> = mutableSetOf()
}

class GameBoard {
    private val cellMap = mutableMapOf<String, Cell>()

    fun addCell(cell: Cell) {
        cellMap[cell.id] = cell
    }

    fun getCell(id: String): Cell? = cellMap[id]

    fun connect(aId: String, bId: String) {
        val a = cellMap.getOrPut(aId) { Cell(aId).also { addCell(it) } }
        val b = cellMap.getOrPut(bId) { Cell(bId).also { addCell(it) } }
        a.neighbors.add(b)
        b.neighbors.add(a)
    }

    val cells: Collection<Cell>
        get() = cellMap.values
}
