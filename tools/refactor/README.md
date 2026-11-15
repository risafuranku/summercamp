# tools/refactor: making the game instanceable (TODO.md SPLITSCREEN, 15. 11.)

Split screen = a co-op host and a local co-op client inside one Godot program. Everything the
game has one of goes per instance (scripts/instance/instance.gd). These scripts did the
mechanical part; run from anywhere (they chdir into godot/):

- `route_coop.py [--dry]`: I2, every `Coop.member` to `INSTANCE.coop(x)` (done 15. 11.).
- `route_services.py [--dry] [CoreRoot EventBus GuestManager EmailManager Coop]`: I2b, the same
  for the other autoloads; prints what it leaves for a hand (static funcs, inner classes,
  RefCounted helpers without an owner in its OWNER map).
- `dedupe_instance.py`: drops `const INSTANCE` from a script whose parent script has it.
- `fix_infer.py LOG`: `var x := <untyped>` to `var x = ...` for the "Cannot infer the type"
  errors in a Godot log (a routed call returns a plain Node).
- `load_all.gd.txt`: compiles every script with the autoloads loaded: copy it to
  `godot/tools/_tmp_load_all.gd` as `extends Node` (`_ready`, `get_tree().quit()`), run it as
  a scene, delete it. "LOADED n scripts, 0 bad".
- `instance_v3.gd.txt`: the next instance.gd (I2b): an instance's root is a local client's
  branch (group "game_instance") or the program's root, its services the root's children by
  the autoloads' names.
- `rep.py FILE < pairs.txt`: exact replacements (a Python list of (old, new)), keeping the
  file's line ends; refuses unless each old text is there once.
- `pad_instance_reps.txt`, `local_client_reps.txt`: I5, the pad translator per instance and
  the local client's pad, input and silent bus (apply with rep.py, then every other
  `Input.parse_input_event(` in pad.gd to `_send(`).
- `main_screen.py`: I4, main draws into its instance's screen (done 15. 11.).
