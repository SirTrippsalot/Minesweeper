/** GridSystem.kt – generic topology + rendering layer for 2‑D Minesweeper boards.
 * 
 * A single pipeline does everything in three stages:
 *   1.  Integer‑exact MODEL coordinates (scaled so every vertex is the *same* object)
 *   2.  DCEL topology shared by all tilings
 *   3.  Runtime mapping to Android Path for drawing
 *
 * Add new tilings by implementing one small builder class that emits faces out
 *   of reusable getVertex(x,y) calls.  The infrastructure takes care of twins,
 *   neighbour lookup, hit‑testing, zoom, etc.
 *
 * 2025 – public domain / CC0
 */
package com.edgefield.minesweeper

import android.graphics.Canvas
import android.graphics.Path
import android.graphics.Paint
import android.graphics.PointF
import androidx.compose.ui.geometry.Offset
import kotlin.math.*

//──────────────────────────────────────────────────────────────────────────────
//  1 ▍ Core numeric model – a single global integer lattice ("micropixels")
//──────────────────────────────────────────────────────────────────────────────

private const val SCALE = 1_000_000     // 1 model‑unit = 1e‑6 in our key space
private val SQRT3 = sqrt(3.0)

internal data class VKey(val x: Long, val y: Long)

class Vertex internal constructor(internal val key: VKey) {
    val modelX : Double = key.x.toDouble() / SCALE
    val modelY : Double = key.y.toDouble() / SCALE
}

data class Bounds(val minX: Double, val minY: Double, val maxX: Double, val maxY: Double)

//──────────────────────────────────────────────────────────────────────────────
//  2 ▍ DCEL – minimal half‑edge structure (kept package‑internal)
//──────────────────────────────────────────────────────────────────────────────

class HalfEdge internal constructor(var origin: Vertex) {
    lateinit var twin : HalfEdge
    lateinit var next : HalfEdge
    lateinit var prev : HalfEdge
    lateinit var face : Face
}

class Face internal constructor(val sides: Int) {
    lateinit var any : HalfEdge          // entry edge for this polygon
}

class Tiling internal constructor(
    internal val faces   : MutableList<Face>,
    private  val vTable  : MutableMap<VKey,Vertex>
) {
    /** Returns the other cells that share an edge with f in O(#edges). */
    fun neighbours(f: Face): List<Face> {
        val out = mutableListOf<Face>()
        var e = f.any
        do {
            try {
                val twinFace = e.twin.face
                // Only add if it's not the boundary face (has sides > 0)
                if (twinFace.sides > 0) {
                    out += twinFace
                }
            } catch (ex: UninitializedPropertyAccessException) {
                // Skip boundary edges that don't have twins
            }
            e = e.next
        } while(e !== f.any)
        return out
    }

    /** Lazy vertex creation shared by all builders. */
    internal fun getVertex(x: Double, y: Double): Vertex {
        val key = VKey((x*SCALE).roundToLong(), (y*SCALE).roundToLong())
        return vTable.getOrPut(key) { Vertex(key) }
    }

    /** Axis-aligned bounding box in model coordinates. */
    fun modelBounds(): Bounds {
        var minX = Double.POSITIVE_INFINITY
        var minY = Double.POSITIVE_INFINITY
        var maxX = Double.NEGATIVE_INFINITY
        var maxY = Double.NEGATIVE_INFINITY
        vTable.values.forEach { v ->
            if (v.modelX < minX) minX = v.modelX
            if (v.modelX > maxX) maxX = v.modelX
            if (v.modelY < minY) minY = v.modelY
            if (v.modelY > maxY) maxY = v.modelY
        }
        return Bounds(minX, minY, maxX, maxY)
    }
}

data class PolygonDefinition(
    val vertices: List<Pair<Double, Double>>,
    val placement: (col: Int, row: Int, base: Pair<Double, Double>, index: Int) -> Pair<Double, Double>
)

//──────────────────────────────────────────────────────────────────────────────
//  3 ▍ Abstract builder base – takes care of twin wiring & bookkeeping
//──────────────────────────────────────────────────────────────────────────────

abstract class GridBuilder {
    protected val tiling = Tiling(mutableListOf(), mutableMapOf())
    private val edgeMap  = mutableMapOf<Pair<VKey,VKey>, HalfEdge>()

    protected fun he(origin: Vertex): HalfEdge = HalfEdge(origin)

    /** Connects e to its opposite edge if it already exists, otherwise stores it. */
    protected fun connectTwin(u: Vertex, v: Vertex, e: HalfEdge) {
        val key = Pair(v.key, u.key) // opposite direction
        edgeMap[key]?.let { twin ->
            e.twin  = twin
            twin.twin = e
            edgeMap.remove(key)
        } ?: run {
            edgeMap[Pair(u.key,v.key)] = e
        }
    }
    
    /** Call this after all faces are registered to create boundary twins */
    protected fun finalizeTwins() {
        // Create a single boundary face for all boundary edges
        val boundaryFace = Face(0) // 0 sides for boundary
        
        // Create boundary twins for any unmatched edges
        edgeMap.values.forEach { edge ->
            try {
                edge.twin // Try to access twin
            } catch (e: UninitializedPropertyAccessException) {
                // Create a boundary twin that points back to itself
                val boundaryTwin = HalfEdge(edge.next.origin)
                edge.twin = boundaryTwin
                boundaryTwin.twin = edge
                boundaryTwin.face = boundaryFace
                boundaryTwin.next = boundaryTwin
                boundaryTwin.prev = boundaryTwin
            }
        }
        edgeMap.clear()
    }

    /** Call this from your subclass once per finished polygon. */
    protected fun registerFace(edges: Array<HalfEdge>) {
        val face = Face(edges.size)
        for (i in edges.indices) {
            val e = edges[i]
            e.next = edges[(i+1)%edges.size]
            e.prev = edges[(i+edges.size-1)%edges.size]
            e.face = face
        }
        face.any = edges[0]
        tiling.faces += face
    }

    /** Build your grid here and return a ready‑to‑use tiling. */
    abstract fun build(): Tiling
}

open class GenericGridBuilder(
    private val definition: PolygonDefinition,
    private val cols: Int,
    private val rows: Int
) : GridBuilder() {
    override fun build(): Tiling {
        for (j in 0 until rows) {
            for (i in 0 until cols) {
                val verts = definition.vertices.mapIndexed { idx, base ->
                    val coord = definition.placement(i, j, base, idx)
                    tiling.getVertex(coord.first, coord.second)
                }
                val edges = Array(verts.size) { he(verts[it]) }
                for (k in edges.indices) {
                    connectTwin(verts[k], verts[(k + 1) % edges.size], edges[k])
                }
                registerFace(edges)
            }
        }
        finalizeTwins()
        return tiling
    }
}

private val SQUARE_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.0 to 0.0,
        1.0 to 0.0,
        1.0 to 1.0,
        0.0 to 1.0
    )
) { c, r, v, _ ->
    c + v.first to r + v.second
}

private val HEX_DEFINITION = PolygonDefinition(
    vertices = (0 until 6).map { k ->
        val angle = Math.toRadians(60.0 * k)
        cos(angle) to sin(angle)
    }
) { q, r, v, _ ->
    val cx = 1.5 * q
    val cy = SQRT3 * r + (SQRT3 / 2) * (q % 2)
    cx + v.first to cy + v.second
}

private val TRIANGLE_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.0 to 0.0,
        1.0 to 0.0,
        0.5 to SQRT3 / 2
    )
) { c, r, _, idx ->
    val p = r % 2
    val q = 1 - p
    val up = (c + r) % 2 == 0
    if (up) {
        when (idx) {
            0 -> c + 1.5 * p to r * SQRT3 / 2
            1 -> c + 1 + 1.5 * p to r * SQRT3 / 2
            else -> c + 1.5 * q to (r + 1) * SQRT3 / 2
        }
    } else {
        when (idx) {
            0 -> c + 1.5 * q to (r + 1) * SQRT3 / 2
            1 -> c + 1 + 1.5 * p to r * SQRT3 / 2
            else -> c + 1 + 1.5 * q to (r + 1) * SQRT3 / 2
        }
    }
}

private val OCTASQUARE_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.25 to 0.0,
        0.75 to 0.0,
        1.0 to 0.25,
        1.0 to 0.75,
        0.75 to 1.0,
        0.25 to 1.0,
        0.0 to 0.75,
        0.0 to 0.25
    )
) { c, r, v, _ ->
    c + v.first to r + v.second
}

private val CAIRO_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.5 to 0.0,
        1.0 to 0.4,
        0.8 to 1.0,
        0.2 to 1.0,
        0.0 to 0.4
    )
) { c, r, v, _ ->
    c + v.first to r + v.second
}

private val RHOMBILLE_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.25 to 0.0,
        0.75 to 0.0,
        1.0 to 0.5,
        0.75 to 1.0,
        0.25 to 1.0,
        0.0 to 0.5
    )
) { c, r, v, _ ->
    c + v.first to r + v.second
}

private val SNUB_SQUARE_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.0 to 0.2,
        0.4 to 0.0,
        1.0 to 0.5,
        0.6 to 1.0,
        0.0 to 0.8
    )
) { c, r, v, _ ->
    c + v.first to r + v.second
}

private val PENROSE_DEFINITION = PolygonDefinition(
    vertices = listOf(
        0.5 to 0.0,
        1.0 to 0.4,
        1.0 to 0.6,
        0.5 to 1.0,
        0.0 to 0.6,
        0.0 to 0.4
    )
) { c, r, v, _ ->
    c + v.first to r + v.second
}

//──────────────────────────────────────────────────────────────────────────────
//  4 ▍ Concrete generators
//──────────────────────────────────────────────────────────────────────────────

/** Square grid (classic). neighbourMode = 4 or 8 directions (logic‑side). */
class SquareGridBuilder(cols: Int, rows: Int) :
    GenericGridBuilder(SQUARE_DEFINITION, cols, rows)
/*
* Regular hex grid using axial q,r indices. Creates a parallelogram [w×h]. */
class HexGridBuilder(w: Int, h: Int) :
    GenericGridBuilder(HEX_DEFINITION, w, h)

/** Equilateral triangle grid – upright / inverted pattern. */
class TriangleGridBuilder(cols: Int, rows: Int) :
    GenericGridBuilder(TRIANGLE_DEFINITION, cols, rows)

//──────────────────────────────────────────────────────────────────────────────
//  5 ▍ Place‑holders for the more exotic tilings (Octasquare, Cairo, etc.)
//      – provide boilerplate so you can fill in later without changing callers.
//──────────────────────────────────────────────────────────────────────────────

abstract class ExoticBuilder : GridBuilder() {
    companion object {
        fun octaSquare(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                return GenericGridBuilder(OCTASQUARE_DEFINITION, w, h).build()
            }
        }

        fun cairo(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                return GenericGridBuilder(CAIRO_DEFINITION, w, h).build()
            }
        }

        fun rhombille(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                return GenericGridBuilder(RHOMBILLE_DEFINITION, w, h).build()
            }
        }

        fun snubSquare(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                return GenericGridBuilder(SNUB_SQUARE_DEFINITION, w, h).build()
            }
        }

        fun penrose(radius:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                return GenericGridBuilder(PENROSE_DEFINITION, radius, radius).build()
            }
        }
    }
}

//──────────────────────────────────────────────────────────────────────────────
//  6 ▍ Rendering helpers (Android Canvas)
//──────────────────────────────────────────────────────────────────────────────

class TilingRenderer(val size: Float, bounds: Bounds) {
    private val offsetX = -bounds.minX
    private val offsetY = -bounds.minY
    val width: Float = ((bounds.maxX - bounds.minX)*size).toFloat()
    val height: Float = ((bounds.maxY - bounds.minY)*size).toFloat()

    private fun modelToPixel(v: Vertex): PointF =
        PointF(((v.modelX + offsetX)*size).toFloat(), ((v.modelY + offsetY)*size).toFloat())

    fun modelToOffset(v: Vertex): Offset =
        Offset(((v.modelX + offsetX)*size).toFloat(), ((v.modelY + offsetY)*size).toFloat())

    fun facePath(face: Face): Path {
        val p = Path()
        var e = face.any; var first = true
        do {
            val pt = modelToPixel(e.origin)
            if (first) { p.moveTo(pt.x, pt.y); first=false } else { p.lineTo(pt.x, pt.y) }
            e = e.next
        } while(e !== face.any)
        p.close()
        return p
    }

    fun draw(canvas: Canvas, tiling: Tiling, paint: Paint) {
        tiling.faces.forEach { f -> canvas.drawPath(facePath(f), paint) }
    }

    fun drawTiling(canvas: Canvas, tiling: Tiling) {
        val paint = Paint().apply {
            style = Paint.Style.STROKE
            strokeWidth = 1f
        }
        draw(canvas, tiling, paint)
    }

    fun faceCentroid(face: Face): Offset {
        var sumX = 0f
        var sumY = 0f
        var count = 0

        var e = face.any
        do {
            val pt = modelToOffset(e.origin)
            sumX += pt.x
            sumY += pt.y
            count++
            e = e.next
        } while (e !== face.any)

        return Offset(sumX / count, sumY / count)
    }

    fun hitTest(point: Offset, tiling: Tiling): Face? {
        var closest: Face? = null
        var minDistance = Float.MAX_VALUE

        tiling.faces.forEach { face ->
            val c = faceCentroid(face)
            val dx = point.x - c.x
            val dy = point.y - c.y
            val dist = dx * dx + dy * dy
            if (dist < minDistance) {
                minDistance = dist
                closest = face
            }
        }

        return closest
    }
}

//──────────────────────────────────────────────────────────────────────────────
//  7 ▍ Convenience factory so the caller never sees builder classes directly
//──────────────────────────────────────────────────────────────────────────────

enum class GridKind(val neighborCount: Int) {
    SQUARE(8),
    TRIANGLE(3),
    HEXAGON(6),
    OCTASQUARE(8),
    CAIRO(5),
    RHOMBILLE(6),
    SNUB_SQUARE(5),
    PENROSE(6)
}

object GridFactory {
    fun build(kind: GridKind, w:Int, h:Int = w): Tiling = when(kind) {
        GridKind.SQUARE      -> GenericGridBuilder(SQUARE_DEFINITION, w, h).build()
        GridKind.TRIANGLE    -> GenericGridBuilder(TRIANGLE_DEFINITION, w, h).build()
        GridKind.HEXAGON     -> GenericGridBuilder(HEX_DEFINITION, w, h).build()
        GridKind.OCTASQUARE  -> GenericGridBuilder(OCTASQUARE_DEFINITION, w, h).build()
        GridKind.CAIRO       -> GenericGridBuilder(CAIRO_DEFINITION, w, h).build()
        GridKind.RHOMBILLE   -> GenericGridBuilder(RHOMBILLE_DEFINITION, w, h).build()
        GridKind.SNUB_SQUARE -> GenericGridBuilder(SNUB_SQUARE_DEFINITION, w, h).build()
        GridKind.PENROSE     -> GenericGridBuilder(PENROSE_DEFINITION, w, h).build()
    }
}

//──────────────────────────────────────────────────────────────────────────────
//  8 ▍ Example usage (call from your custom View)
//──────────────────────────────────────────────────────────────────────────────

/*
class MineBoardView(context: Context, attrs: AttributeSet?) : View(context, attrs) {
    private val tiling = GridFactory.build(GridKind.HEXAGON, 10,10)
    private val renderer = TilingRenderer(size = 50f) // edge length
    private val paint = Paint().apply { style = Paint.Style.STROKE; strokeWidth = 3f }

    override fun onDraw(canvas: Canvas) {
        renderer.draw(canvas, tiling, paint)
    }
}
*/