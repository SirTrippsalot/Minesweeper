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
import kotlin.math.*

//──────────────────────────────────────────────────────────────────────────────
//  1 ▍ Core numeric model – a single global integer lattice ("micropixels")
//──────────────────────────────────────────────────────────────────────────────

private const val SCALE = 1_000_000     // 1 model‑unit = 1e‑6 in our key space

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

//──────────────────────────────────────────────────────────────────────────────
//  4 ▍ Concrete generators
//──────────────────────────────────────────────────────────────────────────────

/** Square grid (classic). neighbourMode = 4 or 8 directions (logic‑side). */
class SquareGridBuilder(
    private val cols: Int,
    private val rows: Int
) : GridBuilder() {
    override fun build(): Tiling {
        // Each cell [i,j] with unit edge length 1
        for (j in 0 until rows) {
            for (i in 0 until cols) {
                val v0 = tiling.getVertex(i.toDouble(), j.toDouble())
                val v1 = tiling.getVertex(i+1.0, j.toDouble())
                val v2 = tiling.getVertex(i+1.0, j+1.0)
                val v3 = tiling.getVertex(i.toDouble(), j+1.0)

                val e0 = he(v0); val e1 = he(v1); val e2 = he(v2); val e3 = he(v3)
                connectTwin(v0,v1,e0); connectTwin(v1,v2,e1); connectTwin(v2,v3,e2); connectTwin(v3,v0,e3)
                registerFace(arrayOf(e0,e1,e2,e3))
            }
        }
        finalizeTwins()
        return tiling
    }
}
/*
* Regular hex grid using axial q,r indices. Creates a parallelogram [w×h]. */
class HexGridBuilder(
    private val w: Int,
    private val h: Int
) : GridBuilder() {
    private val SQRT3 = sqrt(3.0)

    override fun build(): Tiling {
        for (r in 0 until h) {
            for (q in 0 until w) {
                val cx = 1.5 * q
                val cy = SQRT3 * (r + q/2.0)

                // 6 corners, 0° first → counter‑clockwise
                val corners = (0 until 6).map { k ->
                    val angle = Math.toRadians(60.0*k - 30.0) // flat‑topped
                    tiling.getVertex(cx + cos(angle), cy + sin(angle))
                }.toTypedArray()

                val edges = Array(6) { he(corners[it]) }
                for (k in 0 until 6) {
                    connectTwin(corners[k], corners[(k+1)%6], edges[k])
                }
                registerFace(edges)
            }
        }
        finalizeTwins()
        return tiling
    }
}

/** Equilateral triangle grid – upright / inverted pattern. */
class TriangleGridBuilder(
    private val cols: Int,
    private val rows: Int
) : GridBuilder() {
    private val SQRT3 = sqrt(3.0)

    override fun build(): Tiling {
        for (j in 0 until rows) {
            for (i in 0 until cols) {
                val up = (i + j) % 2 == 0
                if (up) {
                    // upright Δ - use consistent vertical spacing
                    val baseY = j*SQRT3/2
                    val v0 = tiling.getVertex(i*0.5, baseY)
                    val v1 = tiling.getVertex((i+1)*0.5, baseY)
                    val v2 = tiling.getVertex(i*0.5 + 0.25, (j+1)*SQRT3/2)

                    val e0 = he(v0); val e1 = he(v1); val e2 = he(v2)
                    connectTwin(v0,v1,e0); connectTwin(v1,v2,e1); connectTwin(v2,v0,e2)
                    registerFace(arrayOf(e0,e1,e2))
                } else {
                    // inverted ∇ – shift half height, same vertical scaling
                    val baseY = j*SQRT3/2
                    val v0 = tiling.getVertex(i*0.5 + 0.25, (j+1)*SQRT3/2)
                    val v1 = tiling.getVertex((i+1)*0.5 + 0.25, (j+1)*SQRT3/2)
                    val v2 = tiling.getVertex((i+1)*0.5, baseY)

                    val e0 = he(v0); val e1 = he(v1); val e2 = he(v2)
                    connectTwin(v0,v1,e0); connectTwin(v1,v2,e1); connectTwin(v2,v0,e2)
                    registerFace(arrayOf(e0,e1,e2))
                }
            }
        }
        finalizeTwins()
        return tiling
    }
}

//──────────────────────────────────────────────────────────────────────────────
//  5 ▍ Place‑holders for the more exotic tilings (Octasquare, Cairo, etc.)
//      – provide boilerplate so you can fill in later without changing callers.
//──────────────────────────────────────────────────────────────────────────────

abstract class ExoticBuilder : GridBuilder() {
    companion object {
        fun octaSquare(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                // TODO: implement 4.8² Archimedean tiling
                // For now, fall back to square grid
                return SquareGridBuilder(w, h).build()
            }
        }

        fun cairo(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                // TODO: implement Cairo pentagonal tiling
                // For now, fall back to square grid
                return SquareGridBuilder(w, h).build()
            }
        }

        fun rhombille(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                // TODO: implement Rhombille (diamonds)
                // For now, fall back to square grid
                return SquareGridBuilder(w, h).build()
            }
        }

        fun snubSquare(w:Int, h:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                // TODO: implement snub‑square 5‑tiling
                // For now, fall back to square grid
                return SquareGridBuilder(w, h).build()
            }
        }

        fun penrose(radius:Int) : GridBuilder = object: ExoticBuilder() {
            override fun build(): Tiling {
                // TODO: implement Penrose (kite & dart) – non‑periodic generator
                // For now, fall back to square grid
                return SquareGridBuilder(radius, radius).build()
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
}

//──────────────────────────────────────────────────────────────────────────────
//  7 ▍ Convenience factory so the caller never sees builder classes directly
//──────────────────────────────────────────────────────────────────────────────

enum class GridKind { SQUARE, TRIANGLE, HEXAGON, OCTASQUARE, CAIRO, RHOMBILLE, SNUB_SQUARE, PENROSE }

object GridFactory {
    fun build(kind: GridKind, w:Int, h:Int = w): Tiling = when(kind) {
        GridKind.SQUARE      -> SquareGridBuilder(w,h).build()
        GridKind.TRIANGLE    -> TriangleGridBuilder(w,h).build()
        GridKind.HEXAGON     -> HexGridBuilder(w,h).build()
        GridKind.OCTASQUARE  -> ExoticBuilder.octaSquare(w,h).build()
        GridKind.CAIRO       -> ExoticBuilder.cairo(w,h).build()
        GridKind.RHOMBILLE   -> ExoticBuilder.rhombille(w,h).build()
        GridKind.SNUB_SQUARE -> ExoticBuilder.snubSquare(w,h).build()
        GridKind.PENROSE     -> ExoticBuilder.penrose(w).build()
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