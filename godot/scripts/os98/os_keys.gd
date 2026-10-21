extends RefCounted

## With the second monitor the keyboard is the program's on the screen the warden looks
## at (os_shell.keys_for): both programs are on screen and running, but Builder's arrows
## must not pan the map on the other monitor while you type a mail on this one.


static func here(node: Node) -> bool:
	var n := node.get_parent() if node != null else null
	while n != null:
		if n.has_method("keys_for"):
			return bool(n.keys_for(node))
		n = n.get_parent()
	return true
