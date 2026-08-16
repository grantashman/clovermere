extends RefCounted
class_name ClovermereDayState

const START_DAY := 1
const START_MINUTE := 8 * 60
const MAX_ENERGY := 100

const WORK_PROFILES := {
    "tree": {"minutes": 30, "energy": 18, "amount": 3},
    "stone": {"minutes": 30, "energy": 16, "amount": 2},
    "ore": {"minutes": 45, "energy": 24, "amount": 1},
    "herb": {"minutes": 15, "energy": 8, "amount": 2}
}

var day := START_DAY
var minute_of_day := START_MINUTE
var energy := MAX_ENERGY
var inventory: Dictionary = {
    "timber": 0,
    "stone": 0,
    "ore": 0,
    "herbs": 0
}

func work_resource(resource: Dictionary) -> Dictionary:
    var kind := str(resource.get("kind", ""))
    var profile: Dictionary = WORK_PROFILES.get(kind, {})
    if profile.is_empty():
        return {"ok": false, "reason": "unknown-resource"}
    var energy_cost := int(profile.get("energy", 0))
    if energy < energy_cost:
        return {"ok": false, "reason": "too-tired", "required_energy": energy_cost}
    var minutes := int(profile.get("minutes", 0))
    var amount := int(profile.get("amount", 0))
    var yield_key := str(resource.get("yield", "materials"))
    energy -= energy_cost
    minute_of_day = mini(23 * 60 + 59, minute_of_day + minutes)
    inventory[yield_key] = int(inventory.get(yield_key, 0)) + amount
    return {
        "ok": true,
        "minutes": minutes,
        "energy": energy_cost,
        "yield": yield_key,
        "amount": amount
    }

func sleep_next_day(changes: Dictionary, resources: Array) -> void:
    for resource_variant in resources:
        if not resource_variant is Dictionary:
            continue
        var resource: Dictionary = resource_variant
        if str(resource.get("kind", "")) == "herb":
            changes[str(resource.get("id", ""))] = false
    day += 1
    minute_of_day = START_MINUTE
    energy = MAX_ENERGY

func format_clock() -> String:
    var hour := int(minute_of_day / 60)
    var minute := minute_of_day % 60
    var suffix := "AM" if hour < 12 else "PM"
    var display_hour := hour % 12
    if display_hour == 0:
        display_hour = 12
    return "%02d:%02d %s" % [display_hour, minute, suffix]

func to_dict() -> Dictionary:
    return {
        "day": day,
        "minute_of_day": minute_of_day,
        "energy": energy,
        "inventory": inventory.duplicate(true)
    }

func from_dict(source: Dictionary) -> void:
    day = maxi(START_DAY, int(source.get("day", START_DAY)))
    minute_of_day = clampi(int(source.get("minute_of_day", START_MINUTE)), 0, 23 * 60 + 59)
    energy = clampi(int(source.get("energy", MAX_ENERGY)), 0, MAX_ENERGY)
    inventory = {
        "timber": 0,
        "stone": 0,
        "ore": 0,
        "herbs": 0
    }
    var source_inventory = source.get("inventory", {})
    if source_inventory is Dictionary:
        for key in inventory.keys():
            inventory[key] = maxi(0, int(source_inventory.get(key, 0)))
