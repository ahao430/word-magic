extends Node
## Weather runtime (AGENTS.md §10.1): walks the four weather states on
## a timer, drifts the wind vector, and drives two camera-following
## particle fields (rain streaks slanted by the wind, drifting leaves
## carried by it). The ONLY writer of the Weather statics; save/restore
## round-trips through capture/apply so weather survives F5/F9.

const SEED := 20261113
const TRANSIT_MIN := 22.0
const TRANSIT_VAR := 20.0

## Wind strength bands per state (px/s at the projectile offset factor).
const WIND_RANGE := {
	"clear": Vector2(0.0, 0.0),
	"windy": Vector2(70.0, 150.0),
	"rain": Vector2(25.0, 70.0),
	"storm": Vector2(130.0, 230.0),
}

var _state := "clear"
var _timer := 16.0
var _target_wind := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

## Region weather bias ("forest" uniform; "wetland" doubles the wet
## states — 迷雾湿地 lives up to its name). Owned by the world's
## region poll; pure weights exposed for tests.
var region_bias := "forest"

var _rain: CPUParticles2D
var _leaves: CPUParticles2D


func _ready() -> void:
	_rng.seed = SEED
	_build_particles()
	force_state("clear")


## Deterministic switch used by tests and session restore.
func force_state(next: String) -> void:
	_state = next
	Weather.state_name = next
	_pick_wind()
	_apply_particles()
	_timer = TRANSIT_MIN + _rng.randf() * TRANSIT_VAR


func _physics_process(delta: float) -> void:
	# Wind eases toward its target so gust changes stay readable.
	Weather.wind = Weather.wind.lerp(_target_wind, 1.0 - exp(-1.2 * delta))
	if _rain != null:
		_rain.gravity = Vector2(Weather.wind.x * 1.5, 120.0)
	if _leaves != null:
		_leaves.direction = Weather.wind.normalized() if Weather.wind.length() > 1.0 else Vector2.RIGHT
	_timer -= delta
	if _timer <= 0.0:
		force_state(_pick_state())


## Weighted state choice: uniform in the forest, rain/storm doubled in
## the wetland (the region's identity is its weather).
func _pick_state() -> String:
	var weights: Dictionary = state_weights(region_bias)
	var total := 0
	for w in weights.values():
		total += int(w)
	var roll := _rng.randi() % maxi(total, 1)
	for state in weights:
		roll -= int(weights[state])
		if roll < 0:
			return state
	return Weather.STATES[0]


## Pure weights per region (test seam).
static func state_weights(bias: String) -> Dictionary:
	if bias == "wetland":
		return {"clear": 1.0, "windy": 1.0, "rain": 2.0, "storm": 2.0}
	return {"clear": 1.0, "windy": 1.0, "rain": 1.0, "storm": 1.0}


func _pick_wind() -> void:
	var band: Vector2 = WIND_RANGE[_state]
	if band.y <= 0.0:
		_target_wind = Vector2.ZERO
		return
	var strength := _rng.randf_range(band.x, band.y)
	_target_wind = Vector2.from_angle(_rng.randf() * TAU) * strength
	Weather.wind = Weather.wind.lerp(_target_wind, 0.5)


func _build_particles() -> void:
	var tex: Texture2D = load("res://assets/sprites/effects/particle_dot_4.png")
	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.texture = tex
	_rain.emitting = false
	_rain.amount = 260
	_rain.lifetime = 1.1
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(760, 6)
	_rain.direction = Vector2(0, 1)
	_rain.spread = 10.0
	_rain.initial_velocity_min = 520.0
	_rain.initial_velocity_max = 660.0
	_rain.gravity = Vector2(0, 120)
	_rain.scale_amount_min = 0.35
	_rain.scale_amount_max = 0.7
	_rain.color = Color(0.55, 0.7, 0.95, 0.55)
	add_child(_rain)
	_leaves = CPUParticles2D.new()
	_leaves.name = "Leaves"
	_leaves.texture = tex
	_leaves.emitting = false
	_leaves.amount = 50
	_leaves.lifetime = 3.2
	_leaves.local_coords = false
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(700, 380)
	_leaves.direction = Vector2.RIGHT
	_leaves.spread = 18.0
	_leaves.initial_velocity_min = 60.0
	_leaves.initial_velocity_max = 140.0
	_leaves.gravity = Vector2(0, 25)
	_leaves.angular_velocity_min = -220.0
	_leaves.angular_velocity_max = 220.0
	_leaves.scale_amount_min = 1.2
	_leaves.scale_amount_max = 2.0
	_leaves.color = Color(0.55, 0.75, 0.35, 0.7)
	add_child(_leaves)


func _apply_particles() -> void:
	if _rain != null:
		_rain.emitting = _state in ["rain", "storm"]
		_rain.amount = 400 if _state == "storm" else 260
	if _leaves != null:
		_leaves.emitting = _state in ["windy", "storm"]


## Particles ride the camera: keep the field centered on the view.
func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center: Vector2 = cam.get_screen_center_position()
	_rain.position = center + Vector2(0, -380)
	_leaves.position = center


## --- Session save tier ---

func capture_state() -> Dictionary:
	var data := Weather.capture()
	data["timer"] = _timer
	return data


func apply_state(data: Dictionary) -> void:
	Weather.apply(data)
	_state = Weather.state_name
	_target_wind = Weather.wind
	_timer = float(data.get("timer", 16.0))
	_apply_particles()
