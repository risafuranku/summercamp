extends RefCounted

const PAGE_ROOT := "res://data/beeternet/pages"
const HOME_URL := "home://start"

const URL_MAP := {
	"home://start": "home.html",
	"beeternet://home": "home.html",
	"camp://downloads": "downloads.html",
	"camp://programs": "downloads.html",
	"camp://software": "downloads.html",
}

const URL_ALIASES := {
	"": HOME_URL,
	"home": HOME_URL,
	"start": HOME_URL,
	"downloads": "camp://downloads",
	"programs": "camp://downloads",
	"software": "camp://downloads",
	"repo": "camp://downloads",
}

const TONE_COLORS := {
	"ok": "#2b6b2d",
	"warn": "#8c6219",
	"muted": "#5a5e63",
	"alert": "#8a2f2f",
}


func render(url: String, ctx: Dictionary) -> Dictionary:
	var resolved_url := _normalize_url(url)
	var page_path := _resolve_page_path(resolved_url)
	if page_path.is_empty():
		return _render_404(resolved_url, ctx)

	var html := _read_text(page_path)
	if html.is_empty():
		return _render_404(resolved_url, ctx)

	var title := _extract_tag_content(html, "title")
	if title.is_empty():
		title = "Beeternet"
	var body_html := _extract_tag_content(html, "body")
	if body_html.is_empty():
		body_html = html
	body_html = _apply_tokens(body_html, resolved_url, ctx)
	return {
		"title": title,
		"url": resolved_url,
		"body": _html_to_bbcode(body_html),
	}


func _normalize_url(url: String) -> String:
	var lowered := url.strip_edges().to_lower()
	if URL_ALIASES.has(lowered):
		return str(URL_ALIASES.get(lowered, HOME_URL))
	if lowered.is_empty():
		return HOME_URL
	return lowered


func _resolve_page_path(url: String) -> String:
	if URL_MAP.has(url):
		return "%s/%s" % [PAGE_ROOT, str(URL_MAP.get(url, ""))]
	var slug := _slug_from_url(url)
	if slug.is_empty():
		return ""
	return "%s/%s.html" % [PAGE_ROOT, slug]


func _slug_from_url(url: String) -> String:
	if not url.contains("://"):
		return _sanitize_slug(url)
	if url.begins_with("camp://"):
		return _sanitize_slug(url.substr(7))
	if url.begins_with("page://"):
		return _sanitize_slug(url.substr(7))
	return ""


func _sanitize_slug(value: String) -> String:
	var slug := value.strip_edges().to_lower().replace(" ", "-")
	if slug.is_empty() or slug.begins_with("/") or slug.contains(".."):
		return ""
	var matcher := RegEx.new()
	if matcher.compile("^[a-z0-9_\\-/]+$") != OK:
		return ""
	if matcher.search(slug) == null:
		return ""
	return slug


func _render_404(url: String, ctx: Dictionary) -> Dictionary:
	var page_path := "%s/404.html" % PAGE_ROOT
	var html := _read_text(page_path)
	if html.is_empty():
		html = "<title>404 Not Found</title><body><h1>Error 404</h1><p>Page missing: {{REQUESTED_URL}}</p><p><a href=\"home://start\">Return home</a></p></body>"
	var title := _extract_tag_content(html, "title")
	if title.is_empty():
		title = "404 Not Found"
	var body_html := _extract_tag_content(html, "body")
	if body_html.is_empty():
		body_html = html
	body_html = _apply_tokens(body_html, url, ctx)
	return {
		"title": title,
		"url": url,
		"body": _html_to_bbcode(body_html),
	}


func _apply_tokens(html: String, url: String, ctx: Dictionary) -> String:
	var out := html
	out = out.replace("{{URL}}", _escape_html(url))
	out = out.replace("{{REQUESTED_URL}}", _escape_html(url))
	out = out.replace("{{PROGRAM_LIST}}", _build_program_list_html(ctx))
	out = out.replace("{{GUEST_REVIEWS}}", _build_guest_reviews_html(ctx))
	out = out.replace("{{MIRROR_STATUS}}", _build_mirror_status_html(ctx))

	var download_count := 0
	var downloads_any: Variant = ctx.get("downloads_items", [])
	if downloads_any is Array:
		download_count = (downloads_any as Array).size()
	out = out.replace("{{DOWNLOAD_COUNT}}", str(download_count))
	return out


func _build_program_list_html(ctx: Dictionary) -> String:
	var catalog_any: Variant = ctx.get("app_catalog", [])
	if not (catalog_any is Array):
		return "<p><span class=\"muted\">Program catalog unavailable.</span></p>"
	var catalog: Array = catalog_any
	if catalog.is_empty():
		return "<p><span class=\"muted\">No programs published yet.</span></p>"

	var installers: Dictionary = ctx.get("installer_files", {})
	var unlocked: Dictionary = ctx.get("unlock_registry", {})
	var downloads_any: Variant = ctx.get("downloads_items", [])
	var downloaded_files: Array = []
	if downloads_any is Array:
		downloaded_files = (downloads_any as Array).duplicate()

	var out := ""
	for idx in range(catalog.size()):
		var row_any: Variant = catalog[idx]
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var app_id := str(row.get("id", ""))
		var title := _escape_html(str(row.get("title", app_id)))
		var summary := _escape_html(str(row.get("summary", "")))
		var size_label := _escape_html(str(row.get("size", "unknown")))
		var installer_file := str(installers.get(app_id, ""))
		var is_installed := bool(unlocked.get(app_id, false))
		var is_downloaded := not installer_file.is_empty() and installer_file in downloaded_files

		out += "<div class=\"card\">"
		out += "<h3>%s</h3>" % title
		out += "<p>%s</p>" % summary
		out += "<p><span class=\"muted\">size: %s | package: %s</span></p>" % [size_label, _escape_html(installer_file)]
		if is_installed:
			out += "<p><span class=\"ok\">Installed on this workstation.</span></p>"
		elif is_downloaded:
			out += "<p><span class=\"warn\">Downloaded. Run installer from Downloads folder.</span></p>"
		else:
			out += "<p><a href=\"download://%s\">[ DOWNLOAD ]</a></p>" % _escape_html(app_id)
		out += "</div>"
		if idx < catalog.size() - 1:
			out += "<hr>"
	return out


func _build_guest_reviews_html(ctx: Dictionary) -> String:
	var reviews_any: Variant = ctx.get("guest_reviews", [])
	if not (reviews_any is Array):
		return "<p><span class=\"muted\">No review feed available.</span></p>"
	var reviews: Array = reviews_any
	if reviews.is_empty():
		return "<p><span class=\"muted\">No reviews posted this cycle.</span></p>"

	var out := ""
	for review_any in reviews:
		if not (review_any is Dictionary):
			continue
		var review: Dictionary = review_any
		var guest_name := _escape_html(str(review.get("name", "Guest")))
		var day := int(review.get("day", 0))
		var rating := clampi(int(review.get("rating", 3)), 1, 5)
		var stars := ""
		for _i in range(rating):
			stars += "*"
		out += "<div class=\"card\">"
		out += "<p><strong>%s</strong> <span class=\"warn\">%s</span> <span class=\"muted\">day %d</span></p>" % [guest_name, stars, day]
		out += "<p>%s</p>" % _escape_html(str(review.get("text", "")))
		out += "</div>"
	return out


func _build_mirror_status_html(ctx: Dictionary) -> String:
	var catalog_any: Variant = ctx.get("app_catalog", [])
	var total := 0
	if catalog_any is Array:
		total = (catalog_any as Array).size()
	var downloads_any: Variant = ctx.get("downloads_items", [])
	var downloaded := 0
	if downloads_any is Array:
		downloaded = (downloads_any as Array).size()
	return "primary mirror online | published packages: %d | local downloads: %d" % [total, downloaded]


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var body := file.get_as_text()
	file.close()
	return body


func _extract_tag_content(source: String, tag_name: String) -> String:
	var matcher := RegEx.new()
	var pattern := "(?is)<%s[^>]*>(.*?)</%s>" % [tag_name, tag_name]
	if matcher.compile(pattern) != OK:
		return ""
	var hit := matcher.search(source)
	if hit == null:
		return ""
	return str(hit.get_string(1)).strip_edges()


func _html_to_bbcode(source: String) -> String:
	var out := source.replace("\r\n", "\n").replace("\r", "\n")
	out = _regex_sub(out, "(?is)<!--.*?-->", "")
	out = _replace_anchor_tags(out)
	out = _replace_span_class_tags(out)

	out = _regex_sub(out, "(?is)<br\\s*/?>", "\n")
	out = _regex_sub(out, "(?is)<hr\\s*/?>", "\n[color=#5e6474]------------------------------------------------[/color]\n")
	out = _regex_sub(out, "(?is)<h1[^>]*>", "\n[color=#22344f][b]")
	out = _regex_sub(out, "(?is)</h1>", "[/b][/color]\n\n")
	out = _regex_sub(out, "(?is)<h2[^>]*>", "\n[color=#2a3f5d][b]")
	out = _regex_sub(out, "(?is)</h2>", "[/b][/color]\n\n")
	out = _regex_sub(out, "(?is)<h3[^>]*>", "\n[color=#304b70][b]")
	out = _regex_sub(out, "(?is)</h3>", "[/b][/color]\n")
	out = _regex_sub(out, "(?is)<p[^>]*>", "")
	out = _regex_sub(out, "(?is)</p>", "\n\n")
	out = _regex_sub(out, "(?is)<ul[^>]*>", "\n")
	out = _regex_sub(out, "(?is)</ul>", "\n")
	out = _regex_sub(out, "(?is)<li[^>]*>", "  * ")
	out = _regex_sub(out, "(?is)</li>", "\n")
	out = _regex_sub(out, "(?is)<(?:div|section|article|header|footer|body)[^>]*>", "\n")
	out = _regex_sub(out, "(?is)</(?:div|section|article|header|footer|body)>", "\n")
	out = _regex_sub(out, "(?is)<strong[^>]*>", "[b]")
	out = _regex_sub(out, "(?is)</strong>", "[/b]")
	out = _regex_sub(out, "(?is)<b[^>]*>", "[b]")
	out = _regex_sub(out, "(?is)</b>", "[/b]")
	out = _regex_sub(out, "(?is)<em[^>]*>", "[i]")
	out = _regex_sub(out, "(?is)</em>", "[/i]")
	out = _regex_sub(out, "(?is)<i[^>]*>", "[i]")
	out = _regex_sub(out, "(?is)</i>", "[/i]")
	out = _regex_sub(out, "(?is)<code[^>]*>", "[color=#5d3100][b]")
	out = _regex_sub(out, "(?is)</code>", "[/b][/color]")
	out = _regex_sub(out, "(?is)<[^>]+>", "")

	out = out.replace("&nbsp;", " ")
	out = out.replace("&quot;", "\"")
	out = out.replace("&#39;", "'")
	out = out.replace("&apos;", "'")
	out = out.replace("&amp;", "&")
	out = _regex_sub(out, "[ \\t]+\\n", "\n")
	out = _regex_sub(out, "\\n{3,}", "\n\n")
	return "%s\n" % out.strip_edges()


func _replace_anchor_tags(source: String) -> String:
	var matcher := RegEx.new()
	if matcher.compile("(?is)<a\\s+[^>]*href\\s*=\\s*\"([^\"]+)\"[^>]*>(.*?)</a>") != OK:
		return source
	var out := source
	var hits := matcher.search_all(out)
	for i in range(hits.size() - 1, -1, -1):
		var hit: RegExMatch = hits[i]
		var href := str(hit.get_string(1)).strip_edges()
		var label := _strip_tags(str(hit.get_string(2))).strip_edges()
		if label.is_empty():
			label = href
		var replacement := "[url=%s][color=#274072][u]%s[/u][/color][/url]" % [href, label]
		out = out.substr(0, hit.get_start()) + replacement + out.substr(hit.get_end())
	return out


func _replace_span_class_tags(source: String) -> String:
	var matcher := RegEx.new()
	if matcher.compile("(?is)<span\\s+[^>]*class\\s*=\\s*\"([^\"]+)\"[^>]*>(.*?)</span>") != OK:
		return source
	var out := source
	var hits := matcher.search_all(out)
	for i in range(hits.size() - 1, -1, -1):
		var hit: RegExMatch = hits[i]
		var class_raw := str(hit.get_string(1)).to_lower().strip_edges()
		var span_class_name := class_raw.split(" ")[0]
		var content := _strip_tags(str(hit.get_string(2))).strip_edges()
		var color_hex := str(TONE_COLORS.get(span_class_name, ""))
		var replacement := content
		if not color_hex.is_empty():
			replacement = "[color=%s]%s[/color]" % [color_hex, content]
		out = out.substr(0, hit.get_start()) + replacement + out.substr(hit.get_end())
	return out


func _strip_tags(source: String) -> String:
	return _regex_sub(source, "(?is)<[^>]+>", "")


func _regex_sub(source: String, pattern: String, replacement: String) -> String:
	var matcher := RegEx.new()
	if matcher.compile(pattern) != OK:
		return source
	return matcher.sub(source, replacement, true)


func _escape_html(source: String) -> String:
	var out := source
	out = out.replace("&", "&amp;")
	out = out.replace("<", "&lt;")
	out = out.replace(">", "&gt;")
	out = out.replace("\"", "&quot;")
	out = out.replace("'", "&#39;")
	return out
