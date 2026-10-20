#!/usr/bin/env python3
"""Gather the game's player-facing English strings into godot/locale/cs.po.

The game is written in English; Czech comes from the catalogue (gettext .po, the English
text is the msgid). scripts/lang.gd reads the catalogue at run time and answers every
lookup: Controls and Label3D translate their own text, drawn text goes through tr().
The lookup also takes an UPPER-CASE copy of a msgid and a formatted one ("3 CAMPS" from
"%d CAMPS"), so code that upper-cases or formats a string needs no change.

  python tools/i18n/extract.py            # merge new strings in, keep every translation
  python tools/i18n/extract.py --stats    # how much is translated, by file
  python tools/i18n/extract.py --todo [N] [--file PART]   # untranslated msgids, most used first

What counts as player-facing is a guess (see keep()): a literal with a space, a capital
or a sentence's punctuation, outside print/push_*/get_node/load/... and not a dictionary
key. A msgid nobody translates costs nothing; a string the guess missed shows in English
until it is added by hand to the catalogue (a "#. manual" entry is never dropped).
"""
import json
import os
import re
import sys
from collections import OrderedDict, defaultdict

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GODOT = os.path.join(ROOT, "godot")
PO = os.path.join(GODOT, "locale", "cs.po")

SKIP_DIRS = {"tools", ".godot", "addons", "locale"}
# Calls whose string arguments are never shown to the player.
SKIP_CALLS = re.compile(
    r"(print|printerr|print_debug|prints|printt|push_warning|push_error|assert|get_node|get_node_or_null|"
    r"has_node|find_child|find_children|load|preload|ResourceLoader\.exists|exists|has_method|call|call_deferred|"
    r"callv|connect|disconnect|is_connected|emit_signal|emit|add_to_group|remove_from_group|is_in_group|"
    r"get_nodes_in_group|get_first_node_in_group|call_group|has|get|erase|set_meta|get_meta|has_meta|"
    r"remove_meta|is_action_pressed|is_action_just_pressed|is_action_released|is_action|get_action_strength|"
    r"set_shader_parameter|get_shader_parameter|set_instance_shader_parameter|play|travel|has_animation|"
    r"get_setting|set_setting|has_setting|get_value|set_value|has_section_key|has_section|file_exists|"
    r"dir_exists|open|ends_with|begins_with|contains|find|replace|split|get_slice|trim_prefix|trim_suffix|"
    r"property_list_changed|set|_sfx|sfx|_play|play_sfx|_sound|sound|tween_property|tween_method|"
    r"get_theme_color|add_theme_color_override|add_theme_font_override|add_theme_font_size_override|"
    r"add_theme_stylebox_override|add_theme_constant_override|get_theme_font|get_theme_stylebox|"
    r"get_theme_constant|has_theme_color|RegEx\.create_from_string|compile|Expression|parse|"
    r"send_request|send_sync|send_play|send_place|send_kitchen|send_taproom|_coop_send|rpc|rpc_id|"
    r"get_parameter|set_parameter|tex|_tex|texture|_texture|_load|_img|img|icon|_icon|sprite|_sprite)\s*\(\s*$"
)
STRING = re.compile(r'(?P<prefix>[&^r]?)(?P<q>"""|"|\')')
PATHLIKE = re.compile(r"^(res|user|uid|http|https|bazaar|mailto)://|\.(png|jpg|webp|ogg|mp3|wav|tscn|tres|gd|json|glb|fnt|ttf|otf|gdshader|svg|txt|cfg)$", re.I)
WORD = re.compile(r"[A-Za-zÀ-ž]")


def keep(s: str) -> bool:
    t = s.strip()
    if len(t) < 2 or not WORD.search(t):
        return False
    if PATHLIKE.search(t) or t.startswith("#") and re.fullmatch(r"#[0-9a-fA-F]{3,8}", t):
        return False
    if "/" in t and " " not in t:
        return False
    # ids: snake_case, kebab, dotted, CONSTANT_CASE, node names with no space
    if " " not in t:
        if re.fullmatch(r"[a-z0-9_\-.:]+", t):
            return False
        if re.fullmatch(r"[A-Z0-9_]+", t) and "_" in t:
            return False
        if re.fullmatch(r"[A-Za-z]+[0-9]+D|[A-Z][a-z]+[A-Z][A-Za-z0-9]*", t) and t not in KEEP_CAMEL:
            return False
        if re.fullmatch(r"%[-+0-9.]*[dsfxX]", t):
            return False
    if re.fullmatch(r"[%0-9.\-+dsfx:/ ,()\[\]]+", t):
        return False
    return True


# CamelCase words that are shown (program names stay as they are; listed so they are seen).
KEEP_CAMEL = set()


def unescape(body: str) -> str:
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}.get(n, "\\" + n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def gd_strings(path: str):
    """(line, text) of each literal in a .gd file whose context may show it."""
    with open(path, encoding="utf-8") as f:
        src = f.read()
    i = 0
    line = 1
    n = len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c == "#":
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        m = STRING.match(src, i)
        if m and (m.group("prefix") == "" or not src[i - 1 : i].isalnum() if i else True):
            # a prefix letter only counts when it starts a token (r"..." / &"..." / ^"...")
            prefix = m.group("prefix")
            if prefix == "r" and i > 0 and (src[i - 1].isalnum() or src[i - 1] == "_"):
                i += 1
                continue
            q = m.group("q")
            start = m.end()
            j = start
            while j < n:
                if src[j] == "\\" and q != '"""':
                    j += 2
                    continue
                if src.startswith(q, j):
                    break
                j += 1
            body = src[start:j]
            end = j + len(q)
            text = body if prefix == "r" else unescape(body)
            before = src[src.rfind("\n", 0, i) + 1 : i]
            after = src[end : src.find("\n", end) if src.find("\n", end) >= 0 else n]
            if prefix in ("&", "^"):
                pass
            elif re.match(r"\s*:(?!=)", after) and not re.search(r"\?\s*$|\bif\b.*$", before):
                pass  # a dictionary key or a match branch
            elif re.search(r"(==|!=|\bin|\bmatch)\s*$", before) or re.match(r"\s*(==|!=|\bin\b)", after):
                pass
            elif re.search(r"\.name\s*=\s*$|\bname\s*=\s*$|\bid\s*=\s*$|\bkey\s*=\s*$|[\w\])]\[\s*$", before) and not re.search(r"\b(text|title|label)\b", before):
                pass
            elif SKIP_CALLS.search(before) or re.search(r"(print|printerr|push_warning|push_error|assert)\(.*$", before):
                pass
            elif re.search(r"\b(signal|extends|class_name|@export_enum|@export_file|@export_dir|const\s+(?:[A-Z0-9]+_)*(?:PATHS?|DIRS?|FILES?|TEX|TEXTURES?|SFX|SND|SOUNDS?|ICONS?|IMG|IMAGES?)(?:_[A-Z0-9]+)*\s*(?::=|=|:).*)\s*", before):
                pass
            elif keep(text):
                yield line, text
            line += body.count("\n")
            i = end
            continue
        i += 1


def tscn_strings(path: str):
    with open(path, encoding="utf-8") as f:
        for ln, row in enumerate(f, 1):
            m = re.match(r'(text|tooltip_text|placeholder_text|title|display_name|description|label)\s*=\s*"((?:[^"\\]|\\.)*)"', row)
            if m and keep(unescape(m.group(2))):
                yield ln, unescape(m.group(2))


TEXT_KEYS = {"subject", "body", "text", "from", "sender", "sender_name", "title", "name", "line", "lines",
             "label", "description", "summary", "reply", "replies", "message", "preview", "signature", "options"}


def json_strings(path: str):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    def walk(v, key=""):
        if isinstance(v, dict):
            for k, x in v.items():
                yield from walk(x, k)
        elif isinstance(v, list):
            for x in v:
                yield from walk(x, key)
        elif isinstance(v, str) and key in TEXT_KEYS and keep(v):
            yield 0, v

    yield from walk(data)


def collect():
    found = OrderedDict()  # msgid -> [refs]
    for base, dirs, files in os.walk(GODOT):
        rel_base = os.path.relpath(base, GODOT).replace("\\", "/")
        if rel_base.split("/")[0] in SKIP_DIRS:
            dirs[:] = []
            continue
        dirs.sort()
        for name in sorted(files):
            p = os.path.join(base, name)
            rel = os.path.relpath(p, GODOT).replace("\\", "/")
            if name.endswith(".gd"):
                gen = gd_strings(p)
            elif name.endswith((".tscn", ".tres")):
                gen = tscn_strings(p)
            elif name.endswith(".json") and rel.startswith("data/pools"):
                gen = json_strings(p)
            else:
                continue
            try:
                for ln, text in gen:
                    found.setdefault(text, []).append("%s:%d" % (rel, ln) if ln else rel)
            except (UnicodeDecodeError, json.JSONDecodeError) as e:
                print("skip", rel, e, file=sys.stderr)
    return found


# ── the .po file ───────────────────────────────────────────────────────────────

def po_quote(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t").replace("\r", "\\r")
    if "\n" not in s:
        return '"%s"' % s.replace("\n", "\\n")
    parts = s.split("\n")
    lines = ['""']
    for k, p in enumerate(parts):
        lines.append('"%s%s"' % (p, "\\n" if k < len(parts) - 1 else ""))
    if lines[-1] == '""':
        lines.pop()
    return "\n".join(lines)


def po_unquote(chunks) -> str:
    return unescape("".join(c[1:-1] for c in chunks))


def read_po(path: str):
    """OrderedDict msgid -> {"str": msgstr or list for plurals, "plural": msgid_plural, "comments": [..]}"""
    entries = OrderedDict()
    header = None
    if not os.path.exists(path):
        return header, entries
    with open(path, encoding="utf-8") as f:
        blocks = f.read().split("\n\n")
    for b in blocks:
        lines = [l for l in b.strip("\n").split("\n") if l.strip()]
        if not lines:
            continue
        comments = [l for l in lines if l.startswith("#")]
        cur = None
        fields = defaultdict(list)
        for l in lines:
            if l.startswith("#"):
                continue
            m = re.match(r'(msgid_plural|msgid|msgstr\[\d\]|msgstr|msgctxt)\s+(".*")$', l)
            if m:
                cur = m.group(1)
                fields[cur].append(m.group(2))
            elif l.startswith('"') and cur:
                fields[cur].append(l)
        if "msgid" not in fields:
            continue
        mid = po_unquote(fields["msgid"])
        if mid == "":
            header = b.strip("\n")
            continue
        e = {"comments": comments}
        if "msgid_plural" in fields:
            e["plural"] = po_unquote(fields["msgid_plural"])
            e["str"] = [po_unquote(fields["msgstr[%d]" % k]) for k in range(3) if "msgstr[%d]" % k in fields]
        else:
            e["str"] = po_unquote(fields.get("msgstr", ['""']))
        entries[mid] = e
    return header, entries


HEADER = '''msgid ""
msgstr ""
"Project-Id-Version: Cursed Camp Manager Simulator\\n"
"Language: cs\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: nplurals=3; plural=(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2;\\n"'''


def write_po(path: str, header, entries):
    out = [header or HEADER]
    for mid, e in entries.items():
        block = list(e.get("comments", []))
        block.append("msgid " + po_quote(mid))
        if "plural" in e:
            block.append("msgid_plural " + po_quote(e["plural"]))
            strs = e["str"] if isinstance(e["str"], list) else [e["str"]]
            for k in range(3):
                block.append("msgstr[%d] %s" % (k, po_quote(strs[k] if k < len(strs) else "")))
        else:
            block.append("msgstr " + po_quote(e["str"] if isinstance(e["str"], str) else ""))
        out.append("\n".join(block))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n\n".join(out) + "\n")


def translated(e) -> bool:
    s = e.get("str")
    return any(s) if isinstance(s, list) else bool(s)


def main(argv):
    header, old = read_po(PO)
    found = collect()
    entries = OrderedDict()
    for mid, refs in found.items():
        e = old.get(mid, {"str": ""})
        keepc = [c for c in e.get("comments", []) if not c.startswith("#:") and not c.startswith("#. uses")]
        refs_line = ["#: " + " ".join(refs[:4]) + (" (+%d)" % (len(refs) - 4) if len(refs) > 4 else "")]
        entries[mid] = dict(e, comments=keepc + refs_line + (["#. uses %d" % len(refs)] if len(refs) > 1 else []))
    # Kept: manual entries, and translations of strings the code no longer has (marked).
    for mid, e in old.items():
        if mid in entries:
            continue
        if any(c.startswith("#. manual") for c in e.get("comments", [])):
            entries[mid] = e
        elif translated(e):
            entries[mid] = dict(e, comments=[c for c in e.get("comments", []) if not c.startswith("#:")] + (["#. gone"] if "#. gone" not in e.get("comments", []) else []))
    if "--stats" in argv or "--todo" in argv:
        report(entries, argv)
        return
    write_po(PO, header, entries)
    done = sum(1 for e in entries.values() if translated(e))
    print("%s: %d msgids, %d translated, %d to do" % (os.path.relpath(PO, ROOT), len(entries), done, len(entries) - done))


def report(entries, argv):
    by_file = defaultdict(lambda: [0, 0])
    for mid, e in entries.items():
        ref = next((c for c in e.get("comments", []) if c.startswith("#:")), "#: ?")
        f = ref[3:].split(" ")[0].split(":")[0]
        by_file[f][0] += 1
        by_file[f][1] += 1 if translated(e) else 0
    if "--todo" in argv:
        k = argv.index("--todo")
        limit = int(argv[k + 1]) if k + 1 < len(argv) and argv[k + 1].isdigit() else 200
        part = argv[argv.index("--file") + 1] if "--file" in argv else ""
        rows = []
        for mid, e in entries.items():
            if translated(e):
                continue
            ref = next((c for c in e.get("comments", []) if c.startswith("#:")), "")
            if part and part not in ref:
                continue
            uses = next((int(c.split()[-1]) for c in e.get("comments", []) if c.startswith("#. uses")), 1)
            rows.append((uses, mid, ref))
        rows.sort(key=lambda r: -r[0])
        for uses, mid, ref in rows[:limit]:
            print(json.dumps(mid, ensure_ascii=False), "  ", ref[3:60])
        print("--", len(rows), "untranslated")
        return
    for f, (n, d) in sorted(by_file.items(), key=lambda kv: -kv[1][0]):
        print("%5d %5d  %s" % (n, d, f))
    tot = sum(v[0] for v in by_file.values())
    done = sum(v[1] for v in by_file.values())
    print("%5d %5d  total (%.0f%%)" % (tot, done, 100.0 * done / max(1, tot)))


if __name__ == "__main__":
    main(sys.argv[1:])
