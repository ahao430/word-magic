class_name WavUtil
extends RefCounted
## WAV container helpers for voice capture: silence trimming and a
## minimal 16-bit PCM mono RIFF writer that any /audio/transcriptions
## endpoint accepts.

const SILENCE_THRESHOLD := 0.02
const KEEP_PADDING := 0.15  # seconds of hushed audio kept around speech


## Trim leading/trailing near-silence so short holds don't upload dead
## air (faster + cheaper ASR). Returns an empty array when nothing but
## silence was captured.
static func trim_silence(frames: PackedVector2Array, mix_rate: int) -> PackedVector2Array:
	if frames.is_empty():
		return frames
	var pad := maxi(int(KEEP_PADDING * mix_rate), 1)
	var first := -1
	var last := -1
	for i in frames.size():
		if absf(frames[i].x) > SILENCE_THRESHOLD or absf(frames[i].y) > SILENCE_THRESHOLD:
			if first == -1:
				first = i
			last = i
	if first == -1:
		return PackedVector2Array()
	first = maxi(first - pad, 0)
	last = mini(last + pad, frames.size() - 1)
	return frames.slice(first, last + 1)


## frames -> WAV bytes (16-bit PCM, mono, source mix rate).
static func build_wav(frames: PackedVector2Array, mix_rate: int) -> PackedByteArray:
	var samples := frames.size()
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var v := int(clampf(frames[i].x, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	out.append_array(_u32(36 + data.size()))
	out.append_array("WAVE".to_ascii_buffer())
	out.append_array("fmt ".to_ascii_buffer())
	out.append_array(_u32(16))          # fmt chunk size
	out.append_array(_u16(1))           # PCM
	out.append_array(_u16(1))           # mono
	out.append_array(_u32(mix_rate))
	out.append_array(_u32(mix_rate * 2))  # byte rate
	out.append_array(_u16(2))           # block align
	out.append_array(_u16(16))          # bits per sample
	out.append_array("data".to_ascii_buffer())
	out.append_array(_u32(data.size()))
	out.append_array(data)
	return out


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


static func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_u16(0, v)
	return b
