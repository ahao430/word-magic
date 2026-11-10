extends SceneTree
## One-shot: synthesize the exploration BGM (24s loop, 16-bit mono
## 22050 Hz): soft two-chord-per-bar pad progression (Am F C G) with a
## fifth and detune layer, an A-minor-pentatonic plucked arpeggio and a
## sparse high sparkle. Deterministic — same build, same track.
##
##   godot --headless --path . -s res://tools/dev/build_bgm.gd
##
## Output: assets/audio/music/explore_loop.tres (LOOP_FORWARD)

const OUT := "res://assets/audio/music/explore_loop.tres"
const RATE := 22050
const DUR := 24.0

# A2, F2, C3, G2 — six seconds each (Am -> F -> C -> G).
const CHORDS := [110.0, 87.31, 130.81, 98.0]
const PENTA := [220.0, 261.63, 293.66, 329.63, 392.0, 440.0]  # A3..A4


func _init() -> void:
	var n := int(DUR * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := _mix(t)
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 29000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.resource_name = "explore_loop"
	var err := ResourceSaver.save(wav, OUT)
	if err != OK:
		push_error("[bgm] save failed")
		quit(1)
		return
	print("[bgm] saved " + OUT)
	quit()


func _hash(x: int, seed: int) -> float:
	var v := (x * 374761393 + seed * 668265263) % 1000003
	return float(v) / 1000003.0


func _mix(t: float) -> float:
	# Pad: chord root + octave + fifth, detuned second layer for width.
	var root: float = CHORDS[int(t / 6.0) % 4]
	var pad := sin(TAU * root * t) * 0.10
	pad += sin(TAU * root * 2.0 * t) * 0.055
	pad += sin(TAU * root * 1.5 * t) * 0.035
	pad += sin(TAU * root * 1.003 * t) * 0.05

	# Arpeggio: a plucked pentatonic note every 0.5s (120 bpm quarters),
	# walking deterministically with a per-step hash wobble.
	var step := int(t / 0.5)
	var note: float = PENTA[int(_hash(step, 3) * 3.0 + step * 2 + floori(t / 6.0)) % PENTA.size()]
	var lt := fmod(t, 0.5)
	var pluck := minf(lt * 60.0, 1.0) * exp(-lt * 6.5)
	var arp := (sin(TAU * note * t) + 0.4 * sin(TAU * note * 2.0 * t)) * 0.16 * pluck

	# Sparkle: a soft high ping once per chord, off the beat.
	var ping := 0.0
	if step % 16 == 12:
		var l2 := fmod(t, 6.0)
		ping = sin(TAU * 659.25 * t) * 0.07 * exp(-l2 * 2.0)

	return tanh((pad * 0.9 + arp + ping) * 1.5) * 0.9
