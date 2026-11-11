class_name SpellBalance
extends RefCounted
## Balance calculator (AGENTS.md §7.6): mana cost is ALWAYS computed by
## the game from validated parameters. Costs target PLAN.md §2.4 bands
## (simple 10-20, medium 25-40); the AI/parser side can never set it.
##
## Damage is priced by POTENTIAL: a channeled shape (beam/field/summon)
## lands its damage once per tick, so the cost scales with the number of
## ticks the duration allows — a pumped-up channel can never outprice
## the damage it can actually deal. The channeled coefficient 0.5 puts
## the damage-per-mana asymptote at exactly 2.0; the flats and the 0.4
## one-shot coefficient keep every legal (validator-clamped) spell under
## it. tests/balance_test.gd guards that bound for the whole registry
## and for max-clamped crafted spells.

## Channel tick cadence per shape — the SINGLE source the effect nodes
## read (beam.gd / field_zone.gd / summon.gd); balance and execution
## can never drift apart.
const CHANNEL_TICKS := {
	"beam": 0.4,
	"field": 0.5,
	"tornado": 0.4,
	"summon": 1.0,
}

## The tornado's own push clears its zone after ~1.2s, so its damage
## potential is capped well below the theoretical tick count (empirical).
const TORNADO_PRICED_TICKS := 3

## Damage pricing: one-shot shapes 0.4x, channeled shapes 0.5x per tick
## (the channel coefficient is what pins the mana-efficiency ceiling).
const ONE_SHOT_DMG_COEFF := 0.4
const CHANNEL_DMG_COEFF := 0.5


## How many damage applications a full channel of this spell lands
## (ticks fire at t = tick, 2*tick, ...; a one-shot lands once).
static func potential_ticks(spell: Dictionary) -> int:
	var shape: String = str(spell.get("shape", ""))
	if not CHANNEL_TICKS.has(shape):
		return 1
	if shape == "tornado":
		return TORNADO_PRICED_TICKS
	var duration: float = float(spell.get("parameters", {}).get("duration", 0.0))
	# +0.001 bridges fp noise (1.2 / 0.4 computes to 2.999...).
	return maxi(int(duration / float(CHANNEL_TICKS[shape]) + 0.001), 0)


static func compute_cost(spell: Dictionary) -> int:
	var p: Dictionary = spell["parameters"]
	var ticks: int = maxi(potential_ticks(spell), 1)
	var coeff := CHANNEL_DMG_COEFF if CHANNEL_TICKS.has(str(spell.get("shape", ""))) \
			else ONE_SHOT_DMG_COEFF
	var cost := 8.0
	cost += p.get("damage", 0.0) * coeff * ticks
	if p.get("radius", 0.0) > 16.0:
		cost += p.get("radius", 0.0) * 0.05
	cost += p.get("duration", 0.0) * 2.0
	if p.get("speed", 0.0) > 300.0:
		cost += 4.0
	return int(round(cost))
