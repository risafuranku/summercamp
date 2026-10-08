class_name BalanceConfig
extends Resource

## Global configuration for game balance constants.
## This resource should be loaded by CoreRoot or Systems.

# --- Economy ---
const STARTING_MONEY: int = 850
const BASE_INCOME_PER_GUEST: int = 15
const REFUND_RATIO: float = 0.5 

# --- Time ---
## In-game minutes per real second. 1.5 makes a day 16 real minutes and the night
## (20:00-06:30) about 7. Everything that counts game time from real seconds (weather,
## breakdowns) multiplies by this.
const GAME_MINUTES_PER_SECOND: float = 1.5
## Real seconds per in-game minute (the time system's view of the same number).
const TIME_SCALE: float = 1.0 / GAME_MINUTES_PER_SECOND
## Hour when day starts (light)
const DAY_START_HOUR: float = 6.5
## Hour when night starts (dark, flashlight needed)
const NIGHT_START_HOUR: int = 20

# --- Karma ---
const MAX_KARMA: float = 100.0
const MIN_KARMA: float = -100.0
const KARMA_PENALTY_NO_POWER: float = -5.0
const KARMA_PENALTY_NO_HYGIENE: float = -2.0

# --- Needs ---
## Distance in meters for service coverage
const SERVICE_RADIUS: float = 25.0
