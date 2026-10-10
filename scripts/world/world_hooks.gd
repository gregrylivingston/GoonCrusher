class_name WorldHooks extends RefCounted
## Small world rules the goons, their FX and the AI driver share (docs/WORLD.md, "Goon and FX hooks"). Static
## and pure: every query is a grid read through World (World.terrainAt and friends, O(1) array reads on the
## live WorldMap), never a physics query, so 250 goons and a planner can call them every tick. Without a map
## (the menu, tests without a stand-in) nothing is a wall or lethal, so every rule here is a no-op.
## With a real WorldMap the grid walks (slideStep, nearLethal, lethalAhead, lineClear, bounce) run in its
## native WorldGrid (World.grid); the GDScript below is the same rule, for stand-ins and the parity tests.

const FINE := 128.0               #a fine cell (WorldGen.FINE)
const DROWN_CREDIT_SECONDS := 3.0 #a goon that drowns this soon after the car touched it counts as a crush
const TETHER_SAFE_PX := 400.0     #harpoon and magnet tethers break with the car this close to deep water
const STUCK_SECONDS := 4.0        #a goon pressing a barrier on screen this long may be swept away
const LINE_STEP := 64.0           #samples along a blast's or shot's line
const BANK_RINGS := 6             #a drowned bandit's loot is dropped up to this many fine cells away

## Eight unit directions, for ring samples
const DIRS := [Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071),
	Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071)]

## A wall cell (rock, cliff, building): what stops shots, shells and blasts. Water doesn't: things fly over it.
static func wallAt(pos: Vector2) -> bool:
	if World.grid != null: return World.grid.wallAt(pos)
	return World.isWallTerrain(World.terrainAt(pos))

## One step of an off-screen goon, which moves without collision: the whole step if its cell is open, else
## along the one axis that is (sliding along the barrier), else it holds. Blocked means water or a wall, so
## off-screen goons never walk into a lake unseen. A goon already on blocked ground (spawned at a cliff's
## foot, shoved in) may step anywhere, so it can get out. Steps are a few px per tick, far below a 128 px
## cell, so nothing tunnels.
static func slideStep(pos: Vector2, step: Vector2) -> Vector2:
	if World.grid != null: return World.grid.slideStep(pos, step)
	var to := pos + step
	if not World.blockedAt(to) || World.blockedAt(pos): return to
	var alongX := pos + Vector2(step.x, 0.0)
	var alongY := pos + Vector2(0.0, step.y)
	var xFirst := absf(step.x) >= absf(step.y)
	var first := alongX if xFirst else alongY
	var second := alongY if xFirst else alongX
	if first != pos && not World.blockedAt(first): return first
	if second != pos && not World.blockedAt(second): return second
	return pos

## Did the car touch this goon recently enough for its drowning to count as a crush ("SPLASH")
static func drownCredited(now: float, lastTouch: float) -> bool:
	return now - lastTouch <= DROWN_CREDIT_SECONDS

## The nearest dry, open point to `pos` (a drowned goon's bank): rings of fine cells, eight directions each,
## past the wading band. `pos` itself when nothing is found.
static func bankNear(pos: Vector2) -> Vector2:
	for ring in range(1, BANK_RINGS + 1):
		for dir in DIRS:
			var p: Vector2 = pos + dir * FINE * ring
			var t := World.terrainAt(p)
			if not World.isBlocked(t) && not World.isLethal(t) && t != Root.terrain.WADE: return p
	return pos

#--- wading depth ------------------------------------------------------------------------------------

const WADE_SLOW := 0.6   #a solid goon in wading depth (WADE) moves at this share of its speed (the buff scale, like slime)...
const WADE_HOLD := 0.2   #...for this long after the last check that found it there
const WADE_EVERY := 4    #ticks between checks, staggered by goon (Walker.checkWade)

## A solid goon's speed share in wading depth this tick: WADE_SLOW there, 1 elsewhere
static func wadeScaleAt(pos: Vector2) -> float:
	return WADE_SLOW if World.terrainAt(pos) == Root.terrain.WADE else 1.0

## Is there deep water within `radius` of `pos`: the point, then eight directions at the radius and at half of
## it (17 reads). Coarser than a disc, but water bodies are hundreds of px across.
static func nearLethal(pos: Vector2, radius: float) -> bool:
	if World.grid != null: return World.grid.nearLethal(pos, radius)
	if World.lethalAt(pos): return true
	for dir in DIRS:
		if World.lethalAt(pos + dir * radius) || World.lethalAt(pos + dir * radius * 0.5): return true
	return false

## Deep water along a heading within `dist` px of `pos`, sampled every fine cell: the distance to it, or INF
static func lethalAhead(pos: Vector2, dir: Vector2, dist: float) -> float:
	if World.grid != null: return World.grid.lethalAhead(pos, dir, dist)
	var d := FINE
	while d <= dist:
		if World.lethalAt(pos + dir * d): return d
		d += FINE
	return INF

## A tether (harpoon, magnet) lets go when it could drag the car into deep water
static func tetherMustBreak(carPos: Vector2) -> bool:
	return nearLethal(carPos, TETHER_SAFE_PX)

## Where oil and slime may land: not on shallows, wading depth, deep water or a wall, and not within one fine
## cell of deep water (the slick would read as a swim, and a slid car would end up in it)
static func hazardAllowed(pos: Vector2) -> bool:
	var t := World.terrainAt(pos)
	if t == Root.terrain.SHALLOWS || t == Root.terrain.WADE || World.isLethal(t) || World.isWallTerrain(t): return false
	for dir in DIRS:
		if World.lethalAt(pos + dir * FINE): return false
	return true

## Is the straight line from a to b free of wall cells (a blast's reach, a shot's path)
static func lineClear(a: Vector2, b: Vector2) -> bool:
	if World.grid != null: return World.grid.lineClear(a, b)
	var length := a.distance_to(b)
	var steps := ceili(length / LINE_STEP)
	for i in range(1, steps + 1):
		if wallAt(a.lerp(b, float(i) / steps)): return false
	return true

## A sliding body's velocity after this tick's step meets a wall cell: the blocked axis is reflected (both
## in a corner), so a kicked shell rebounds like a pinball. Unchanged when the step is clear.
static func bounce(pos: Vector2, vel: Vector2, delta: float) -> Vector2:
	if World.grid != null: return World.grid.bounce(pos, vel, delta)
	var step := vel * delta
	if not wallAt(pos + step): return vel
	var out := vel
	if wallAt(pos + Vector2(step.x, 0.0)): out.x = -out.x
	if wallAt(pos + Vector2(0.0, step.y)): out.y = -out.y
	if out == vel: out = -vel
	return out

## The nearest node of a group within maxDist of pos (props tagged by BreakableProp.tag), or null.
## `skipMeta` excludes nodes carrying that metadata as true (a smashed crate).
static func nearestInGroup(tree: SceneTree, group: StringName, pos: Vector2, maxDist: float, skipMeta: StringName = &"") -> Node2D:
	if tree == null: return null
	var best: Node2D = null
	var bestD := maxDist * maxDist
	for node in tree.get_nodes_in_group(group):
		if not node is Node2D || not node.is_inside_tree(): continue
		if skipMeta != &"" && node.get_meta(skipMeta, false): continue
		var d: float = node.global_position.distance_squared_to(pos)
		if d < bestD:
			bestD = d
			best = node
	return best
