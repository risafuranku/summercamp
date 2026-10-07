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

signal day_advanced(day_index: int, income: int)
signal day_tick(day_index: int)
signal time_tick(hour: int, minute: int)
signal night_tick(night_index: int)

signal email_received(email: Dictionary)
signal customer_booking_confirmed(email: Dictionary)
signal customer_booking_rejected(email: Dictionary)
signal guest_created(guest: Dictionary)
signal guest_state_changed(guest_id: int, old_state: String, new_state: String)
signal accommodation_state_changed(accommodation_key: String, status: String, guest_count: int)
signal guest_review_posted(review: Dictionary)
signal guest_payment_received(amount: int, guest_id: int)

# Upkeep (FailureSystem / GameActions.service_building)
signal building_failed(coord: Vector2i, building_type: String)
signal building_serviced(coord: Vector2i, building_type: String, was_broken: bool, cost: int)

# Beeternet / install system
signal file_downloaded(filename: String)   # Beeternet -> desktop: file landed in Downloads
signal program_installed(app_id: String)   # Wizard -> desktop: program installed, unlock icons
@warning_ignore_restore("unused_signal")

# Allow global access to ease refactoring
# Usage: EventBus.state_changed.connect(func(chg): ...)
