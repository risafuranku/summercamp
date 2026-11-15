extends RefCounted

## The wardens at this machine (TODO.md SPLITSCREEN). A seat is one warden here: its input,
## its screen (a SubViewport everything this warden sees is drawn into, the world's view
## and the UI; its input goes only into it, and `get_viewport()` inside it is the seat's
## part of the window, so layouts follow by themselves), its view of the one world, its body
## and its player-facing layer. Seat 1's screen is main's (scenes/main.tscn Seat1/Screen):
## one player, the whole window.
##
## What draws for a warden goes on its seat's screen, never on the window's root:
##   SEATS.screen_of(self).add_child(layer)

## Every seat's screen is in this group.
const GROUP := "seat_screen"


## The screen of the seat `node` is drawn for: the nearest seat screen over it; for a node
## outside every seat (an autoload, a node not in the tree yet) seat 1's.
static func screen_of(node: Node) -> Node:
	var at := node
	while at != null:
		if at.is_in_group(GROUP):
			return at
		at = at.get_parent()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var first := tree.get_first_node_in_group(GROUP)
	return first if first != null else tree.root
