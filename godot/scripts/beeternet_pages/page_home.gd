static func render(ctx: Dictionary) -> Dictionary:
	var downloads: Array = ctx.get("downloads_items", [])
	var unlocked: Dictionary = ctx.get("unlock_registry", {})
	var installers: Dictionary = ctx.get("installer_files", {})
	var catalog: Array = ctx.get("app_catalog", [])
	var guest_reviews: Array = ctx.get("guest_reviews", [])

	var b := ""
	b += "[color=#4466cc][b]BEETERNET[/b]  -  The Internet[/color]\n"
	b += "[color=#888899]v3.2  |  Camp Software Repository[/color]\n\n"
	b += "[color=#334455]================================================[/color]\n"
	b += "[color=#cc9922][b] AVAILABLE MODULES[/b][/color]\n"
	b += "[color=#334455]================================================[/color]\n\n"

	for app_data in catalog:
		var app_id := str(app_data.get("id", ""))
		var title := str(app_data.get("title", app_id))
		var summary := str(app_data.get("summary", ""))
		var size_label := str(app_data.get("size", "unknown"))
		var installer_file := str(installers.get(app_id, ""))
		var is_installed: bool = bool(unlocked.get(app_id, false))
		var is_downloaded: bool = not installer_file.is_empty() and installer_file in downloads

		b += "[b]■  %s[/b]\n" % title
		b += "%s\n" % summary
		b += "[color=#555555]Size: %s  |  Freeware  |  Camp-Certified[/color]\n" % size_label
		if is_installed:
			b += "[color=#44aa44]  ✓ Installed on this system.[/color]\n"
		elif is_downloaded:
			b += "[color=#ddaa33]  Downloaded - run installer from [b]Downloads[/b].[/color]\n"
		else:
			b += "  [url=download://%s][color=#226622][b][ DOWNLOAD ][/b][/color][/url]\n" % app_id
		b += "\n"

	if not guest_reviews.is_empty():
		b += "[color=#334455]================================================[/color]\n"
		b += "[color=#cc8844][b] LATEST CAMP REVIEWS[/b][/color]\n"
		b += "[color=#334455]================================================[/color]\n\n"
		for review_any in guest_reviews:
			if not (review_any is Dictionary):
				continue
			var review: Dictionary = review_any
			var guest_name := str(review.get("name", "Guest"))
			var day := int(review.get("day", 0))
			var rating := clampi(int(review.get("rating", 3)), 1, 5)
			var stars := ""
			for _i in range(rating):
				stars += "*"
			b += "[b]%s[/b]  [color=#886622]%s[/color]  [color=#666666](day %d)[/color]\n" % [guest_name, stars, day]
			b += "%s\n\n" % str(review.get("text", ""))

	b += "[color=#334455]================================================[/color]\n"
	b += "[color=#888888][i]New titles are periodically mirrored to Beeternet.[/i][/color]\n"
	b += "[color=#555566]Use is subject to licence CC-EULA-7b.[/color]\n"

	return {
		"title": "Beeternet Home",
		"body": b,
	}
