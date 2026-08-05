extends CanvasLayer

const BOOT_LINES := [
	"NEC-CAMP SYSTEM BIOS v2.7",
	"Copyright (C) 1993 Cursed Camp Industries",
	"640 KB Base Memory OK",
	"Sound Blaster 16 ... DETECTED",
	"Floppy Drive A: ... READY",
	"Mounting C:\\CAMP_OS ...",
	"Loading services: INPUT, LOGBOOK, WATCHER",
	"Warning: 1 anomaly preserved in memory",
	"Boot complete. Welcome counselor."
]

@onready var root: Control = $Root
@onready var desktop: Control = $Root/Desktop
@onready var boot_overlay: Control = $Root/BootOverlay
@onready var boot_text: RichTextLabel = $Root/BootOverlay/PanelContainer/MarginContainer/BootText
@onready var clock_label: Label = $Root/Desktop/TopBar/MarginContainer/HBoxContainer/ClockLabel
@onready var terminal_window: PanelContainer = $Root/Desktop/TerminalWindow
@onready var terminal_output: TextEdit = $Root/Desktop/TerminalWindow/MarginContainer/VBoxContainer/TerminalOutput
@onready var terminal_input: LineEdit = $Root/Desktop/TerminalWindow/MarginContainer/VBoxContainer/TerminalInput
@onready var logbook_window: PanelContainer = $Root/Desktop/LogbookWindow
@onready var logbook_text: RichTextLabel = $Root/Desktop/LogbookWindow/MarginContainer/VBoxContainer/LogbookText
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _is_powered := false
var _has_booted := false
var _boot_session_id := 0
var _clock_tick := 0.0
var _audio_playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	randomize()
	_ensure_input_action()
	_setup_audio()
	_connect_ui()
	_set_visible_state(false)
	_prepare_logbook()
	set_process(true)


func _process(delta: float) -> void:
	if not _is_powered or not _has_booted:
		return

	_clock_tick -= delta
	if _clock_tick <= 0.0:
		clock_label.text = Time.get_datetime_string_from_system(false, true)
		_clock_tick = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_crt_os"):
		get_viewport().set_input_as_handled()
		if _is_powered:
			_power_off()
		else:
			_power_on()


func _connect_ui() -> void:
	$Root/Desktop/TopBar/MarginContainer/HBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$Root/Desktop/IconArea/TerminalIcon.pressed.connect(_on_terminal_icon_pressed)
	$Root/Desktop/IconArea/LogbookIcon.pressed.connect(_on_logbook_icon_pressed)
	$Root/Desktop/IconArea/BuilderIcon.pressed.connect(_on_builder_icon_pressed)
	$Root/Desktop/IconArea/GuestRackIcon.pressed.connect(_on_guest_rack_icon_pressed)
	$Root/Desktop/TerminalWindow/MarginContainer/VBoxContainer/Header/CloseTerminalButton.pressed.connect(_on_close_terminal_pressed)
	$Root/Desktop/TerminalWindow/MarginContainer/VBoxContainer/TerminalInput.text_submitted.connect(_on_terminal_submitted)
	$Root/Desktop/LogbookWindow/MarginContainer/VBoxContainer/Header/CloseLogbookButton.pressed.connect(_on_close_logbook_pressed)


func _prepare_logbook() -> void:
	logbook_text.clear()
	logbook_text.append_text("Camp Office Memo #044\n")
	logbook_text.append_text("----------------------\n")
	logbook_text.append_text("- Keep generator online after midnight.\n")
	logbook_text.append_text("- If the hallway phone rings twice, do not answer.\n")
	logbook_text.append_text("- CRT terminal logs are not to be deleted.\n")
	logbook_text.append_text("- In case of static voices: stay at desk, lights on.\n")


func _ensure_input_action() -> void:
	if not InputMap.has_action("toggle_crt_os"):
		InputMap.add_action("toggle_crt_os")

	for existing_event in InputMap.action_get_events("toggle_crt_os"):
		if existing_event is InputEventKey and existing_event.physical_keycode == KEY_F1:
			return

	var toggle_event := InputEventKey.new()
	toggle_event.physical_keycode = KEY_F1
	InputMap.action_add_event("toggle_crt_os", toggle_event)


func _setup_audio() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.4
	sfx_player.stream = generator
	sfx_player.volume_db = -9.0
	sfx_player.play()
	_audio_playback = sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _set_visible_state(visible: bool) -> void:
	root.visible = visible
	desktop.visible = false
	boot_overlay.visible = false
	terminal_window.visible = false
	logbook_window.visible = false


func _power_on() -> void:
	_is_powered = true
	_set_visible_state(true)
	_play_tone(110.0, 0.12, 0.15)
	_start_boot_sequence()


func _power_off() -> void:
	_is_powered = false
	_has_booted = false
	_boot_session_id += 1
	terminal_input.release_focus()
	_set_visible_state(false)
	_play_tone(90.0, 0.14, 0.14)


func _start_boot_sequence() -> void:
	_boot_session_id += 1
	var session_id := _boot_session_id
	_has_booted = false
	boot_overlay.visible = true
	desktop.visible = false
	boot_text.clear()

	for line in BOOT_LINES:
		if session_id != _boot_session_id or not _is_powered:
			return
		boot_text.append_text(line + "\n")
		_play_tone(randf_range(300.0, 520.0), 0.03, 0.06)
		await get_tree().create_timer(0.34).timeout

	if session_id != _boot_session_id or not _is_powered:
		return

	await get_tree().create_timer(0.45).timeout
	if session_id != _boot_session_id or not _is_powered:
		return

	boot_overlay.visible = false
	desktop.visible = true
	_has_booted = true
	_clock_tick = 0.0
	_terminal_reset()
	_play_tone(680.0, 0.08, 0.10)


func _on_start_pressed() -> void:
	if not _has_booted:
		return
	if terminal_window.visible:
		_on_close_terminal_pressed()
	else:
		_on_terminal_icon_pressed()


func _on_terminal_icon_pressed() -> void:
	if not _has_booted:
		return
	terminal_window.visible = true
	terminal_window.grab_focus()
	terminal_input.grab_focus()
	_play_tone(780.0, 0.05, 0.08)


func _on_logbook_icon_pressed() -> void:
	if not _has_booted:
		return
	logbook_window.visible = true
	logbook_window.grab_focus()
	_play_tone(560.0, 0.05, 0.08)


func _on_builder_icon_pressed() -> void:
	if not _has_booted:
		return
	_play_tone(620.0, 0.05, 0.08)
	EventBus.open_builder_requested.emit()


func _on_guest_rack_icon_pressed() -> void:
	if not _has_booted:
		return
	_play_tone(480.0, 0.05, 0.08)
	EventBus.open_guestrack_requested.emit()


func _on_close_terminal_pressed() -> void:
	terminal_window.visible = false
	terminal_input.release_focus()
	_play_tone(320.0, 0.04, 0.07)


func _on_close_logbook_pressed() -> void:
	logbook_window.visible = false
	_play_tone(280.0, 0.04, 0.07)


func _terminal_reset() -> void:
	terminal_output.text = ""
	terminal_input.clear()
	_terminal_print("CAMP_OS Terminal v0.1")
	_terminal_print("Type 'help' for command list.")


func _on_terminal_submitted(value: String) -> void:
	var command := value.strip_edges()
	terminal_input.clear()
	if command.is_empty():
		return

	_terminal_print("> " + command)
	_process_command(command)
	_play_tone(860.0, 0.025, 0.05)
	terminal_input.grab_focus()


func _process_command(command: String) -> void:
	var lower := command.to_lower()
	var parts := lower.split(" ", false)
	var base := parts[0]

	match base:
		"help":
			_terminal_print("help, dir, date, echo, clear, whoami, anomaly, reboot")
		"dir":
			_terminal_print("C:/")
			_terminal_print("  CAMP.EXE")
			_terminal_print("  LOGBOOK.TXT")
			_terminal_print("  WATCHER.DAT")
		"date":
			_terminal_print(Time.get_datetime_string_from_system(false, true))
		"echo":
			if command.length() > 5:
				_terminal_print(command.substr(5))
			else:
				_terminal_print("")
		"clear":
			terminal_output.text = ""
		"whoami":
			_terminal_print("camp_counselor")
		"anomaly":
			_terminal_print("Anomaly #1: STATIC WHISPER detected in Hallway-03")
		"reboot":
			_start_boot_sequence()
		_:
			_terminal_print("Bad command or file name")


func _terminal_print(text_line: String) -> void:
	terminal_output.text += text_line + "\n"
	terminal_output.scroll_vertical = terminal_output.get_line_count()


func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
	if _audio_playback == null:
		return

	var sample_rate := 44100.0
	var frame_count := int(max(duration, 0.01) * sample_rate)
	var writable_frames := _audio_playback.get_frames_available()
	if writable_frames <= 0:
		return
	frame_count = min(frame_count, writable_frames)

	var phase := 0.0
	var phase_increment := TAU * frequency / sample_rate
	for i in frame_count:
		var envelope := 1.0 - (float(i) / float(frame_count))
		var sample := sin(phase) * amplitude * envelope
		phase += phase_increment
		_audio_playback.push_frame(Vector2(sample, sample))
