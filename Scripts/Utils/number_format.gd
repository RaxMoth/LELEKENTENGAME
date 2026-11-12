## Number and time formatting for UI (idle-game friendly short numbers).
##
##   NumberFormat.compact(1530)        -> "1.53K"
##   NumberFormat.with_separators(1234567) -> "1,234,567"
##   NumberFormat.duration(125)        -> "2:05"
##
## Dependencies: none
class_name NumberFormat
extends RefCounted

const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func compact(value: float, decimals: int = 2) -> String:
	var absolute_value: float = absf(value)
	if absolute_value < 1000.0:
		return str(int(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)
	var suffix_index: int = mini(int(floor(log(absolute_value) / log(1000.0))), SUFFIXES.size() - 1)
	var scaled_value: float = value / pow(1000.0, suffix_index)
	# Fewer decimals for larger leading numbers keeps the width stable: 1.23K, 12.3K, 123K.
	var leading_digits: int = str(int(absf(scaled_value))).length()
	var shown_decimals: int = clampi(decimals + 1 - leading_digits, 0, decimals)
	return String.num(scaled_value, shown_decimals) + SUFFIXES[suffix_index]


static func with_separators(value: int, separator: String = ",") -> String:
	var digits: String = str(absi(value))
	var grouped: String = ""
	var digit_count: int = digits.length()
	for digit_index: int in digit_count:
		if digit_index > 0 and (digit_count - digit_index) % 3 == 0:
			grouped += separator
		grouped += digits[digit_index]
	return ("-" if value < 0 else "") + grouped


## "m:ss" below an hour, "h:mm:ss" above.
static func duration(total_seconds: float) -> String:
	var whole_seconds: int = maxi(0, int(total_seconds))
	var hours: int = floori(whole_seconds / 3600.0)
	var minutes: int = floori((whole_seconds % 3600) / 60.0)
	var seconds: int = whole_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%d:%02d" % [minutes, seconds]


## Human friendly "2h 5m" / "45s" style durations for timers like energy refills.
static func duration_short(total_seconds: float) -> String:
	var whole_seconds: int = maxi(0, int(total_seconds))
	if whole_seconds >= 3600:
		return "%dh %dm" % [floori(whole_seconds / 3600.0), floori((whole_seconds % 3600) / 60.0)]
	if whole_seconds >= 60:
		return "%dm %ds" % [floori(whole_seconds / 60.0), whole_seconds % 60]
	return "%ds" % whole_seconds
