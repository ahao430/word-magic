extends SceneTree
## One-shot: synthesize the SFX set as AudioStreamWAV resources (16-bit
## mono 22050 Hz) — no external audio assets, fully procedural and
## reproducible. Sounds are intentionally deterministic (no random).
##
##   godot --headless --path . -s res://tools/dev/build_sfx.gd
##
## Output: assets/audio/sfx/<name>.tres
##   sfx_cast_fire / ice / lightning / wind
##   sfx_hit / sfx_explosion / sfx_hurt / sfx_puzzle

const OUT_DIR := "res://assets/audio/sfx"
const RATE := 22050


func _init() -> void:
	_save("sfx_cast_fire", 0.45, _cast_fire)
	_save("sfx_cast_ice", 0.35, _cast_ice)
	_save("sfx_cast_lightning", 0.25, _cast_lightning)
	_save("sfx_cast_wind", 0.40, _cast_wind)
	_save("sfx_hit", 0.18, _hit)
	_save("sfx_explosion", 0.50, _explosion)
	_save("sfx_hurt", 0.20, _hurt)
	_save("sfx_puzzle", 0.60, _puzzle)
	print("[sfx] 8 streams saved to " + OUT_DIR)
	quit()


func _save(name: String, duration: float, synth: Callable) -> void:
	var wav := _make(duration, synth)
	wav.resource_name = name
	var err := ResourceSaver.save(wav, "%s/%s.tres" % [OUT_DIR, name])
	if err != OK:
		push_error("[sfx] save failed: " + name)
		quit(1)


## Render a synth lambda (t_seconds, i_sample) -> [-1, 1] into 16-bit PCM.
func _make(duration: float, synth: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := clampf(float(synth.call(t, i)), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


# --- deterministic building blocks ---

func _noise(i: int, seed: int) -> float:
	var v := (i * 374761393 + seed * 668265263) % 2000003
	return float(v) / 1000001.5 - 1.0


func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) * decay)


# --- sound designs (PLAN.md §9: element-shaped casts + impacts) ---

func _cast_fire(t: float, i: int) -> float:
	var brown := 0.0
	for k in 4:
		brown += _noise(i + k * 977, 11 + k) / 4.0
	var sweep := sin(TAU * (220.0 - 130.0 * t / 0.45) * t)
	return clampf(brown * 1.4 * _env(t, 0.03, 5.0) + sweep * 0.35 * _env(t, 0.02, 7.0), -1.0, 1.0)


func _cast_ice(t: float, _i: int) -> float:
	var wob := 1.0 + 0.01 * sin(TAU * 23.0 * t)
	var tone := sin(TAU * 1318.0 * wob * t) * 0.5 + sin(TAU * 1976.0 * wob * t) * 0.35
	var sparkle := sin(TAU * 2637.0 * t) * 0.25 * clampf(t * 12.0, 0.0, 1.0)
	return tone * _env(t, 0.01, 9.0) + sparkle * _env(t, 0.06, 7.0)


func _cast_lightning(t: float, i: int) -> float:
	var f := 800.0 * exp(-t * 9.0) + 120.0
	var square := 1.0 if fmod(t * f, 1.0 / f) < 0.5 / f else -1.0
	var crackle := _noise(i, 29) * 0.4 * (1.0 if fmod(t, 0.02) < 0.01 else 0.3)
	return clampf((square * 0.4 + crackle) * _env(t, 0.005, 10.0), -1.0, 1.0)


func _cast_wind(t: float, i: int) -> float:
	var band := _noise(i, 7) * (0.5 + 0.5 * sin(TAU * 3.5 * t))
	return clampf(band * _env(t, 0.10, 4.0) * 1.6, -1.0, 1.0)


func _hit(t: float, _i: int) -> float:
	var thump := sin(TAU * (170.0 - 110.0 * t / 0.18) * t)
	return clampf(thump * _env(t, 0.002, 18.0), -1.0, 1.0)


func _explosion(t: float, i: int) -> float:
	var boom := sin(TAU * (95.0 - 55.0 * t / 0.5) * t)
	var rumble := _noise(i, 13) * 0.7
	return clampf(tanh((boom * 1.2 + rumble) * 2.2) * _env(t, 0.004, 6.0), -1.0, 1.0)


func _hurt(t: float, _i: int) -> float:
	var f := 300.0 - 180.0 * t / 0.2
	var phase := TAU * (300.0 * t - 900.0 * t * t)  # integral of the sweep
	var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
	return clampf(saw * _env(t, 0.004, 14.0) * 0.7, -1.0, 1.0)


func _puzzle(t: float, _i: int) -> float:
	# Rising fifth: C5 pluck, then G5 pluck.
	var a := sin(TAU * 523.25 * t) * _env(t, 0.01, 7.0)
	var b := sin(TAU * 784.0 * (t - 0.18)) * _env(t - 0.18, 0.01, 6.0) if t > 0.18 else 0.0
	var shimmer := sin(TAU * 1568.0 * t) * 0.15 * _env(t, 0.2, 3.0)
	return clampf((a + b) * 0.6 + shimmer, -1.0, 1.0)
