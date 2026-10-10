class_name RadioBag extends RefCounted

#A shuffle bag (docs/RADIO.md): every item comes out once before any repeats, and a fresh shuffle
#never starts with the item that just played, so a song can't play twice in a row across a cycle.

var items: Array = []
var pending: Array = []
var last = null
var rng: RandomNumberGenerator

func _init(source: Array = [], generator: RandomNumberGenerator = null):
	items = source.duplicate()
	rng = generator if generator else RandomNumberGenerator.new()

func isEmpty() -> bool:
	return items.is_empty()

func next():
	if items.is_empty(): return null
	if pending.is_empty(): refill()
	last = pending.pop_back()
	return last

#what the bag still has to play this cycle, to carry the shuffle over to the next launch
func state() -> Dictionary:
	return {"items":items.duplicate(), "pending":pending.duplicate(), "last":last}

#picks up a saved cycle: items that are gone are dropped, items added since are shuffled into what is
#left, so a new song still comes up this cycle; a save that doesn't fit is ignored
func restore(saved: Dictionary) -> void:
	var known = saved.get("items")
	var left = saved.get("pending")
	if not known is Array || not left is Array: return
	pending = []
	for item in left:
		if items.has(item) && not pending.has(item): pending.push_back(item)
	for item in items:
		if not known.has(item): pending.insert(rng.randi_range(0, pending.size()), item)
	last = saved.get("last") if items.has(saved.get("last")) else null

#Fisher-Yates with the bag's own RNG (tests seed it); the item drawn next sits at the back
func refill() -> void:
	pending = items.duplicate()
	for i in range(pending.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var swap = pending[i]
		pending[i] = pending[j]
		pending[j] = swap
	if pending.size() > 1 && pending.back() == last:
		var swap = pending[0]
		pending[0] = pending.back()
		pending[pending.size() - 1] = swap
