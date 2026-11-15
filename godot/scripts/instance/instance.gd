extends RefCounted

## One warden's game in this program (TODO.md SPLITSCREEN): its main and everything main
## makes for a warden, as one machine's game is in the co-op. A split screen runs two in one
## program, the host's and a local client's, each main the root of its own instance.
##   var main := INSTANCE.main_of(self)   (never get_tree().current_scene: that is one)

## Every instance's main is in this group (main.gd puts itself in it).
const GROUP := "game_main"


## The main of the instance `node` belongs to: the nearest main over it; for a node outside
## every instance (an autoload, a node not in the tree) the scene's (the host's) main.
static func main_of(node: Node) -> Node:
	var at := node
	while at != null:
		if at.is_in_group(GROUP):
			return at
		at = at.get_parent()
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null
