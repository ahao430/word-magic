class_name TextNormalizer
extends RefCounted
## Step 1 of the casting pipeline (AGENTS.md §7.1): turn raw player
## input into a canonical lookup key — trimmed, lowercased, full-width
## folded to half-width, punctuation and whitespace stripped. CJK is
## kept; anything else non-alphanumeric is dropped.


static func normalize(raw: String) -> String:
	var out := ""
	var s := raw.strip_edges().to_lower()
	for i in s.length():
		var c := s[i]
		var cp := c.unicode_at(0)
		# Full-width forms (！：｜…) fold to their half-width twins.
		if cp >= 0xFF01 and cp <= 0xFF5E:
			c = String.chr(cp - 0xFEE0)
			cp = c.unicode_at(0)
		# Full-width space.
		if cp == 0x3000:
			continue
		var is_digit := cp >= 0x30 and cp <= 0x39
		var is_ascii := cp >= 0x61 and cp <= 0x7A
		var is_cjk := cp >= 0x4E00 and cp <= 0x9FFF
		if is_digit or is_ascii or is_cjk:
			out += c
	return out
