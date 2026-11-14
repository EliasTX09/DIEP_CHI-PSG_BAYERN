class_name SimState
extends RefCounted
## Gemeinsamer Zustand eines Balls fuer Gadgets: wird sowohl vom echten Ball3D (pro Physik-Tick)
## als auch von der Flugbahn-Simulation ShotSim benutzt. So wirken Boost, Wind, Teleporter,
## Looping-Schiene usw. in Vorschau, Bot-KI und Spiel identisch.

var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var grounded: bool = false
## Bahn-Uhr in Sekunden (treibt bewegliche Hindernisse und Laser).
var time: float = 0.0
## Multiplikator fuer den Rollwiderstand in diesem Tick (Sand > 1).
var decel_mul: float = 1.0
## 0..1: Anteil des Windes, den der Ball ignoriert (Ball-Bonus).
var wind_resist: float = 0.0
## Aktive Schiene (Looping) oder null.
var rail: Gadget = null
var rail_s: float = 0.0
var rail_speed: float = 0.0
## Ball wird festgehalten (Kanone laedt).
var held: bool = false
var hold_left: float = 0.0
var holder: Gadget = null
## Wurde in diesem Tick teleportiert / per Gadget versetzt?
var teleported: bool = false
## "" = alles gut, sonst Grund fuer Out-of-Bounds ("water" | "lava" | "void" | "laser" | "ob" = Gelaende neben der Bahn).
var out_kind: String = ""
## Abklingzeiten je Gadget (instance_id -> Sekunden).
var cooldowns: Dictionary = {}
## Ereignisse dieses Ticks (fuer Sounds/Effekte), z.B. "boost", "teleport", "cannon", "rail_in".
var events: PackedStringArray = PackedStringArray()
## true in der Simulation (keine Sounds/Effekte ausloesen).
var is_sim: bool = false

func begin_tick(p: Vector3, v: Vector3, on_ground: bool, t: float, dt: float) -> void:
	pos = p
	vel = v
	grounded = on_ground
	time = t
	decel_mul = 1.0
	teleported = false
	out_kind = ""
	if events.size() > 0:
		events = PackedStringArray()
	if not cooldowns.is_empty():
		for k in cooldowns.keys():
			var left: float = float(cooldowns[k]) - dt
			if left <= 0.0:
				cooldowns.erase(k)
			else:
				cooldowns[k] = left

func on_cooldown(g: Object) -> bool:
	return cooldowns.has(g.get_instance_id())

func set_cooldown(g: Object, seconds: float) -> void:
	cooldowns[g.get_instance_id()] = seconds

func reset() -> void:
	rail = null
	rail_s = 0.0
	rail_speed = 0.0
	held = false
	hold_left = 0.0
	holder = null
	teleported = false
	out_kind = ""
	decel_mul = 1.0
	cooldowns.clear()
	events = PackedStringArray()
