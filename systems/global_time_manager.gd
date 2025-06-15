# GlobalTimeManager.gd

# Manages the canonical game time for the entire simulation.
# As an Autoload (singleton), it provides a single source of truth for time,
# tracking minutes, hours, days, and seasons. It allows for time scaling and
# emits signals on time changes, enabling other systems to synchronize their updates.
class_name GlobalTimeManager
extends Node

# Signals to broadcast time changes across the simulation.
# Other systems can connect to these to trigger time-dependent logic.
signal hour_changed(new_hour: int)
signal day_changed(new_day: int)
signal season_changed(new_season: String)

# --- Configuration ---
# The number of in-game minutes that pass for every one real-world second.
# This allows for easy control over the simulation's speed.
@export var minutes_per_real_second: float = 1.0

# --- Time State ---
# Private variables to store the current time.
# Using a float for total minutes allows for smooth, delta-based progression.
var _total_minutes_elapsed: float = 420.0 # Start at 7:00 AM
var _current_game_minute: int = 0
var _current_game_hour: int = 7
var _current_game_day: int = 1
var _current_season: String = "Spring" # NOTE: This could be an enum in a final version.

# --- Private Constants ---
const MINUTES_IN_HOUR: int = 60
const HOURS_IN_DAY: int = 24
const DAYS_IN_SEASON: int = 30 # Simplified for now
const DAYS_IN_YEAR: int = DAYS_IN_SEASON * 4

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# It's good practice to ensure the time scale is valid on startup.
	if minutes_per_real_second <= 0:
		push_warning("GlobalTimeManager: minutes_per_real_second is set to zero or negative. Time will not advance.")
		minutes_per_real_second = 1.0 # Set a safe default to prevent division by zero
	
	# Set initial time components based on the starting total minutes.
	_update_time_components()


## Called every frame. 'delta' is the elapsed time since the previous frame.
## This is the core logic for advancing game time.
func _process(delta: float) -> void:
	# Calculate how many in-game minutes have passed this frame.
	var minutes_to_add: float = delta * minutes_per_real_second
	if minutes_to_add <= 0.0:
		return

	# Advance total time.
	_total_minutes_elapsed += minutes_to_add

	# Update the integer-based time components (minute, hour, day, season).
	_update_time_components()


## Updates the discrete time units (minute, hour, day, season) based on the
## total elapsed minutes. This function centralizes the time calculation logic
## and emits signals when units change.
func _update_time_components() -> void:
	# Store old values to detect changes.
	var old_hour: int = _current_game_hour
	var old_day: int = _current_game_day
	var old_season: String = _current_season

	# Calculate total days and the remaining minutes within the current day.
	var total_days_elapsed: int = floori(_total_minutes_elapsed / (MINUTES_IN_HOUR * HOURS_IN_DAY))
	var minutes_into_day: float = fmod(_total_minutes_elapsed, float(MINUTES_IN_HOUR * HOURS_IN_DAY))

	# Calculate total hours and the remaining minutes within the current hour.
	var hours_into_day: int = floori(minutes_into_day / MINUTES_IN_HOUR)
	var minutes_into_hour: int = floori(fmod(minutes_into_day, float(MINUTES_IN_HOUR)))

	# Update the public-facing time properties.
	_current_game_minute = minutes_into_hour
	_current_game_hour = hours_into_day
	_current_game_day = total_days_elapsed + 1 # Use 1-based indexing for players.

	# Update season based on the current day of the year.
	var day_in_year: int = total_days_elapsed % DAYS_IN_YEAR
	if day_in_year < DAYS_IN_SEASON:
		_current_season = "Spring"
	elif day_in_year < DAYS_IN_SEASON * 2:
		_current_season = "Summer"
	elif day_in_year < DAYS_IN_SEASON * 3:
		_current_season = "Autumn"
	else:
		_current_season = "Winter"

	# Emit signals if day, hour, or season have changed.
	if _current_game_hour != old_hour:
		hour_changed.emit(_current_game_hour)
	
	if _current_game_day != old_day:
		day_changed.emit(_current_game_day)

	if _current_season != old_season:
		season_changed.emit(_current_season)


# --- Public API ---
# Provides safe, read-only access to the current time components.

## Returns the current minute of the hour (0-59).
func get_current_minute() -> int:
	return _current_game_minute


## Returns the current hour of the day (0-23).
func get_current_hour() -> int:
	return _current_game_hour


## Returns the current day number.
func get_current_day() -> int:
	return _current_game_day


## Returns the name of the current season.
func get_current_season() -> String:
	return _current_season


## Returns a formatted string for display purposes (e.g., "Day 1, 07:05").
func get_time_string() -> String:
	return "Day %d, %02d:%02d" % [_current_game_day, _current_game_hour, _current_game_minute]
