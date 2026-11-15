extends RefCounted

## The web page the game runs in (web/shell.src.html). The engine has one thread there: while
## it downloads, boots and has the browser translate its shaders it can draw nothing, so the
## page plays the studio splash (a recording) and the title card with the boot's bar over the
## canvas, moving all the while. The game tells it how far the boot is and when its own
## picture is up. Off the web nothing happens.
##   PAGE.step(text, progress)    a boot step (0..1), printed as "[boot] <ms> <text>" for tools/web/qa.mjs
##   PAGE.ready()                 the title is up: the page's card goes

static var _shell: JavaScriptObject


static func _page() -> JavaScriptObject:
	if _shell == null and OS.has_feature("web"):
		_shell = JavaScriptBridge.get_interface("__ccShell")
	return _shell


static func step(text: String, progress: float) -> void:
	if not OS.has_feature("web"):
		return
	print("[boot] %d %s" % [Time.get_ticks_msec(), text])
	var shell := _page()
	if shell != null:
		shell.status(progress)


static func ready() -> void:
	if not OS.has_feature("web"):
		return
	print("[boot] %d ready" % Time.get_ticks_msec())
	var shell := _page()
	if shell != null:
		shell.ready()
