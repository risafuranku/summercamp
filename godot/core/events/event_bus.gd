extends Node

## Central signal hub for the game.
## Should be registered as an Autoload (Singleton).

# Signals
@warning_ignore_start("unused_signal")
signal state_changed(changes: Dictionary)
# Payload example: { "time": { "day": 1, "hour": 9.5 }, "weather": "rain", "money": 500 }

signal money_changed(new_amount: int)
signal building_placed(building_id: String, origin: Vector2i, footprint: Vector2i, rotation: int)
signal building_removed(origin: Vector2i)

# Builder contract (request -> authority -> confirmation)
signal RequestBuild(building_type: String, pos: Vector2i, rot: int)
signal RequestDemolish(area: Rect2i)
signal RequestRotate(dir: int)

signal BuildConfirmed(building_type: String, pos: Vector2i, rot: int)
signal BuildRejected(building_type: String, pos: Vector2i, rot: int, reason: String)
signal DemolishConfirmed(area: Rect2i, removed_count: int, fee_paid: int, refund_total: int)
signal DemolishRejected(area: Rect2i, reason: String)

signal open_builder_requested
signal open_guestrack_requested

signal day_advanced(day_index: int, income: int)
signal day_tick(day_index: int)
signal time_tick(hour: int, minute: int)
signal night_tick(night_index: int)
signal event_tick

signal email_received(email: Dictionary)
signal customer_booking_confirmed(email: Dictionary)
signal customer_booking_rejected(email: Dictionary)
signal guest_created(guest: Dictionary)
signal guest_state_changed(guest_id: int, old_state: String, new_state: String)
signal accommodation_state_changed(accommodation_key: String, status: String, guest_count: int)
signal guest_review_posted(review: Dictionary)
signal guest_payment_received(amount: int, guest_id: int)

# Beeternet / install system
signal file_downloaded(filename: String)   # Beeternet → desktop: soubor stažen do Downloads
signal program_installed(app_id: String)   # Wizard → desktop: program nainstalován, odemkni ikony

signal spatnej1
signal spatnej2
signal spatnej3

signal dobrej1
signal dobrej2
signal dobrej3
@warning_ignore_restore("unused_signal")

# Allow global access to ease refactoring
# Usage: EventBus.state_changed.connect(func(chg): ...)
