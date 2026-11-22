extends RefCounted

## One warden's game in this program (TODO.md SPLITSCREEN), as one machine's game is in the
## co-op: its main and everything main makes, and its own copy of what the game has one of
## (the co-op side, the camp's state, the events, the guests, the mail). A split screen runs
## two in one program, the host's and a local client's: a co-op client like any other, joined
## to the host over the loopback line.
##
## The host's instance is the program's root: its services are the autoloads (/root/Coop,
## /root/CoreRoot...) and its main is the scene. A local client's is a branch (a node in the
## group "game_instance", with a MultiplayerAPI of its own) holding its own Coop, CoreRoot,
## EventBus, GuestManager, EmailManager and its Main.
##
##   var main := INSTANCE.main_of(self)    (never get_tree().current_scene)
##   INSTANCE.coop(self).is_host()         (never the autoload by its name: that is the host's)

## Every local client's branch is in this group.
const GROUP := "game_instance"
## Every instance's main is in this group (main.gd puts itself in it).
const MAIN_GROUP := "game_main"
## Where a node keeps the instance it found (a node never moves from one to another).
const CACHE := &"_instance_root"

## How many instances run (a local client's branch counts itself in and out): one, and every
## lookup is the program's root at no cost.
static var count := 1


## A player the split screen's second game has silenced (its camp's sound: the host's game
## plays it, scripts/instance/local_client.gd): leave its bus be.
const SILENT_BUS := "LocalClient"


static func silenced(player: Node) -> bool:
	return player != null and str(player.get("bus")) == SILENT_BUS


## The root of the instance `node` belongs to: a local client's branch over it, else the
## program's root (the host's, a lone machine's, an autoload, a node not in the tree yet).
static func root_of(node: Node) -> Node:
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
	return tree.root if tree != null else null


## The instance's main: the scene's for the host, the branch's `main` for a local client.
static func main_of(node: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var r := root_of(node)
	if r != null and tree != null and r != tree.root:
		return r.get("main")
	return tree.current_scene if tree != null else null


## Where what is drawn for this instance's warden goes (main's screen: the whole window for
## one, half of it in a split screen); never the window's root.
##   INSTANCE.screen_of(self).add_child(layer)
static func screen_of(node: Node) -> Node:
	var m := main_of(node)
	var s = m.get("_screen") if m != null else null
	if s != null:
		return s
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


## One of the instance's own (the autoloads' names): "Coop", "CoreRoot", "EventBus",
## "GuestManager", "EmailManager".
static func service(node: Node, name: String) -> Node:
	var r := root_of(node)
	return r.get_node_or_null(name) if r != null else null


static func coop(node: Node) -> Node:
	return service(node, "Coop")


static func core(node: Node) -> Node:
	return service(node, "CoreRoot")


static func bus(node: Node) -> Node:
	return service(node, "EventBus")


static func guests(node: Node) -> Node:
	return service(node, "GuestManager")


static func mail(node: Node) -> Node:
	return service(node, "EmailManager")


## The instance's input: the window's (Godot's Input) for the host, a local client's own
## (scripts/instance/instance_input.gd: its pad's events), with the same calls.
##   INSTANCE.input(self).is_action_pressed("interact")
static func input(node: Node) -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	var r := root_of(node)
	if r != null and tree != null and r != tree.root:
		var own = r.get("input")
		if own != null:
			return own
	return Input
