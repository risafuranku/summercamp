extends RefCounted

## One warden's game in this program (TODO.md SPLITSCREEN): its main and everything main
## makes for a warden, as one machine's game is in the co-op. A split screen runs two in one
## program, the host's and a local client's, each main the root of its own instance, each
## with its own co-op side (the client's is its own Coop node under a branch with its own
## MultiplayerAPI, joined to the host's over the loopback line).
##   var main := INSTANCE.main_of(self)   (never get_tree().current_scene: that is one)
##   INSTANCE.coop(self).is_host()        (never the Coop autoload by its name: that is the host's)

## Every instance's main is in this group (main.gd puts itself in it).
const GROUP := "game_main"
## Where a node keeps the main it found (it never moves from one instance to another).
const CACHE := &"_instance_main"

## How many mains are in the tree (main.gd counts itself in and out). One: every lookup is
## the scene's main and the Coop autoload, at no cost.
static var count := 0


## The main of the instance `node` belongs to: the nearest main over it; for a node outside
## every instance (an autoload, a node not in the tree) the scene's (the host's) main.
static func main_of(node: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if count > 1 and node != null:
		if node.has_meta(CACHE):
			var cached = node.get_meta(CACHE)
			if cached != null and is_instance_valid(cached):
				return cached
		var at := node
		while at != null:
			if at.is_in_group(GROUP):
				node.set_meta(CACHE, at)
				return at
			at = at.get_parent()
	return tree.current_scene if tree != null else null


## The co-op side of the instance `node` belongs to: a local client's main has its own
## (main.coop); the host's, and everything outside the instances, is the Coop autoload.
static func coop(node: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if count > 1 and node != null:
		var m := main_of(node)
		var own = m.get("coop") if m != null else null
		if own != null:
			return own
	return tree.root.get_node("Coop") if tree != null else null
