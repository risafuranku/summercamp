# beeternet_pages/page_404.gd
# 404 fallback page

static func render(ctx: Dictionary) -> Dictionary:
	var url: String = ctx.get("url", "")

	var b := ""
	b += "[color=#cc3333][b]  Error 404 — Page Not Found[/b][/color]\n\n"
	b += "The address you requested could not be located:\n"
	b += "[color=#888899]  %s[/color]\n\n" % url
	b += "The server may be offline, the address may have changed,\n"
	b += "or this page does not exist on Beeternet.\n\n"
	b += "[url=home://start][color=#4466cc]← Return to Home[/color][/url]\n"

	return { "title": "404 Not Found", "body": b }
