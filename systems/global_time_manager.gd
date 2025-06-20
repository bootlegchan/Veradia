## global_time_manager.gd
## Manages the canonical game time (minutes, hours, days, seasons).
## This is an an Autoload (singleton) responsible for advancing and synchronizing time.
class_name GlobalTimeManager extends Node

## Signal emitted when the game time has ticked, providing the current total minutes.
signal time_ticked(current_total_minutes: int)

# Properties
var _current_total_minutes: int = 0
var _current_game_hour: int = 0
var _current_game_day: int = 1
var _current_season: String = "Spring" # e.g., "Spring", "Summer", "Autumn", "Winter"

@export var _minutes_per_real_second: float = 1.0 # How many game minutes pass per real-world second

## Accumulator to handle fractional minutes between frames.
var _time_accumulator: float = 0.0

var _last_emitted_total_minutes: int = -1 # Initialize to -1 to guarantee the first tick is processed

## Called when the node enters the scene tree for the first time.
func _ready():
	print("GlobalTimeManager initialized.")
	# Immediately emit the initial time state
	_last_emitted_total_minutes = _current_total_minutes
	time_ticked.emit(_current_total_minutes)

## Called every frame to advance game time.
func _process(delta: float):
	# Add the fraction of game minutes that passed this frame to the accumulator.
	_time_accumulator += _minutes_per_real_second * delta

	# If the accumulator has reached at least one full minute, update the total minutes.
	if _time_accumulator >= 1.0:
		var minutes_to_add = floori(_time_accumulator)
		_current_total_minutes += minutes_to_add
		_time_accumulator -= minutes_to_add # Keep the remainder for the next frame

		# Update derived time values (hour, day, season) based on the new total minutes.
		_current_game_hour = (_current_total_minutes / 60) % 24
		_current_game_day = (_current_total_minutes / (60 * 24)) + 1

		# Basic season logic (can be expanded later)
		var days_in_season = 90 # Assuming 90 days per season
		var current_day_in_year = (_current_game_day - 1) % (days_in_season * 4)
		if current_day_in_year < days_in_season:
			_current_season = "Spring"
		elif current_day_in_year < days_in_season * 2:
			_current_season = "Summer"
		elif current_day_in_year < days_in_season * 3:
			_current_season = "Autumn"
		else:
			_current_season = "Winter"

		# Emit time_ticked signal only when minutes change to avoid excessive signals
		if _current_total_minutes != _last_emitted_total_minutes:
			time_ticked.emit(_current_total_minutes)
			_last_emitted_total_minutes = _current_total_minutes

## Public API for getting current time values.
func get_current_total_minutes() -> int:
	return _current_total_minutes

func get_current_game_hour() -> int:
	return _current_game_hour

func get_current_game_day() -> int:
	return _current_game_day

func get_current_season() -> String:
	return _current_season

func get_minutes_per_real_second() -> float:
	return _minutes_per_real_second
