class_name Weather
extends RefCounted
## Static weather state (the Sfx/Settings precedent): effects and the
## HUD read it; the ONLY writer is the world's WeatherSystem node (and
## tests). Wind is a world-space px/s vector that deflects everything
## that flies; rain rescales elemental damage at the point of impact —
## environment as a tactical layer (AGENTS.md §10.1).

const STATES := ["clear", "windy", "rain", "storm"]

## Element damage multipliers per weather state (1.0 = untouched).
const DAMAGE_MODS := {
	"rain": {"fire": 0.75, "lightning": 1.25},
	"storm": {"fire": 0.75, "lightning": 1.25},
}

## Ballistic wind sensitivity for projectiles (velocity offset factor).
const WIND_SENSITIVITY := 0.35

## Chain lightning: lightning hops per wet state, hop search radius and
## damage decay per hop (rain arcs once, a storm twice).
const CHAIN_HOPS := {"rain": 1, "storm": 2}
const CHAIN_RADIUS := 110.0
const CHAIN_DECAY := 0.6

## Clear-sky blessing: mana regeneration multiplier under the sun.
const MANA_BLESSING := 1.5

## Wet weather bogs the slimes down (enemy side of the cross table).
const ENEMY_WET_SLOW := 0.7

static var state_name := "clear"
static var wind := Vector2.ZERO


static func reset() -> void:
	state_name = "clear"
	wind = Vector2.ZERO


static func wind_vector() -> Vector2:
	return wind


## Wind speed band for the HUD (弱/中/强); "" when calm.
static func wind_band() -> String:
	var speed := wind.length()
	if state_name == "clear" or speed < 1.0:
		return ""
	if speed < 90.0:
		return "弱"
	if speed < 160.0:
		return "中"
	return "强"


static func damage_scale(element: String) -> float:
	var mods: Dictionary = DAMAGE_MODS.get(state_name, {})
	return float(mods.get(element, 1.0))


## How many chain hops a lightning hit earns in this weather (0 = dry).
static func chain_hops() -> int:
	return int(CHAIN_HOPS.get(state_name, 0))


## Mana regeneration multiplier: the sun feeds nature's casters.
static func mana_regen_scale() -> float:
	return MANA_BLESSING if state_name == "clear" else 1.0


## Wet weather slows ground enemies (rain and storm alike).
static func enemy_speed_scale() -> float:
	return ENEMY_WET_SLOW if state_name in ["rain", "storm"] else 1.0


## HUD suffix so players can read WHY the weather matters right now.
static func tactical_hint() -> String:
	if chain_hops() > 0:
		return "·链电"
	if state_name == "clear":
		return "·回蓝"
	return ""


static func scale_damage(damage: float, element: String) -> float:
	return damage * damage_scale(element)


static func describe() -> String:
	match state_name:
		"clear":
			return "晴朗"
		"windy":
			return "起风"
		"rain":
			return "细雨"
		"storm":
			return "风雨交加"
	return state_name


## 8-direction arrow glyph from the wind angle (right = east).
static func wind_arrow() -> String:
	if wind.length() < 1.0:
		return ""
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var octant := int(roundi(wind.angle() / (TAU / 8.0))) % 8
	if octant < 0:
		octant += 8
	return arrows[octant]


static func capture() -> Dictionary:
	return {"state": state_name, "wind_x": wind.x, "wind_y": wind.y}


static func apply(data: Dictionary) -> void:
	state_name = str(data.get("state", "clear")) if STATES.has(str(data.get("state", "clear"))) else "clear"
	wind = Vector2(float(data.get("wind_x", 0.0)), float(data.get("wind_y", 0.0)))
