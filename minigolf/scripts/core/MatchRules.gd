class_name MatchRules
extends RefCounted
## Reine Regel-Logik (ohne Nodes) fuer Quick-Deathmatch, Wertung, Sudden-Death und Belohnungen.

const HOLES_PER_MATCH := 3
const HOLE_TIME := 45.0           # Sekunden pro Bahn
const DNF_PENALTY := 3            # nicht eingelocht: par + 3
const MAX_STROKES := 8
const SUDDEN_DEATH_TIME := 20.0
const PIN_TIE_EPSILON := 1.0      # px: darunter = Gleichstand

static func hole_score(strokes: int, finished: bool, par: int) -> int:
	return strokes if finished else par + DNF_PENALTY

## players: Array of {id, total, ...}. Liefert IDs mit minimaler Gesamt-Schlagzahl.
static func leaders(players: Array) -> Array:
	var best: int = 1 << 30
	for p in players:
		best = mini(best, int(p["total"]))
	var out: Array = []
	for p in players:
		if int(p["total"]) == best:
			out.append(p["id"])
	return out

static func needs_sudden_death(players: Array) -> bool:
	return players.size() > 1 and leaders(players).size() > 1

## dists: {player_id: distance_px (INF = kein Schuss)}. Liefert Sieger-ID oder "" bei Gleichstand.
static func pin_winner(dists: Dictionary) -> String:
	var best: float = INF
	var winner: String = ""
	var tie: bool = false
	for id in dists:
		var d: float = dists[id]
		if d < best - PIN_TIE_EPSILON:
			best = d; winner = id; tie = false
		elif absf(d - best) <= PIN_TIE_EPSILON and winner != "":
			tie = true
	if best == INF or tie:
		return ""
	return winner

## Ranking (1 = Sieger). Rueckgabe: Array of {id, rank, total} sortiert.
static func ranking(players: Array, sudden_death_winner: String = "") -> Array:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a, b):
		if a["id"] == sudden_death_winner: return b["id"] != sudden_death_winner
		if b["id"] == sudden_death_winner: return false
		return int(a["total"]) < int(b["total"]))
	var out: Array = []
	var rank := 1
	for i in sorted.size():
		out.append({"id": sorted[i]["id"], "rank": rank, "total": sorted[i]["total"]})
		rank += 1
	return out

static func coins_for_rank(rank: int, player_count: int) -> int:
	if player_count <= 1:
		return 20
	return [100, 60, 35, 20][mini(rank - 1, 3)]
