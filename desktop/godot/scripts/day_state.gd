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
const REGROWTH_PROFILES := {
    "tree": {"days": 3, "initial_stage": "felled"},
    "stone": {"days": 2, "initial_stage": "depleted"},
    "ore": {"days": 2, "initial_stage": "depleted"},
    "herb": {"days": 1, "initial_stage": "harvested"}
}
const UPGRADE_RECIPES := {
    "tinkers-kit": {"name": "Tinker’s Kit", "cost": {"timber": 3, "stone": 2, "ore": 1}}
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
var upgrades: Dictionary = {}

func has_upgrade(upgrade_id: String) -> bool:
    return bool(upgrades.get(upgrade_id, false))

func purchase_upgrade(upgrade_id: String) -> Dictionary:
    var recipe: Dictionary = UPGRADE_RECIPES.get(upgrade_id, {})
    if recipe.is_empty():
        return {"ok": false, "reason": "unknown-upgrade"}
    if has_upgrade(upgrade_id):
        return {"ok": false, "reason": "already-owned"}
    var cost: Dictionary = recipe.get("cost", {})
    for material_variant in cost.keys():
        var material := str(material_variant)
        if int(inventory.get(material, 0)) < int(cost[material_variant]):
            return {"ok": false, "reason": "missing-materials", "material": material}
    for material_variant in cost.keys():
        var material := str(material_variant)
        inventory[material] = int(inventory.get(material, 0)) - int(cost[material_variant])
    upgrades[upgrade_id] = true
    return {"ok": true, "upgrade": upgrade_id, "name": str(recipe.get("name", upgrade_id)), "cost": cost.duplicate(true)}

func preview_work(resource: Dictionary) -> Dictionary:
    var kind := str(resource.get("kind", ""))
    var profile: Dictionary = WORK_PROFILES.get(kind, {})
    if profile.is_empty():
        return {"ok": false, "reason": "unknown-resource"}
    var energy_cost := int(profile.get("energy", 0))
    var adjusted_energy := energy_cost
    if has_upgrade("tinkers-kit"):
        adjusted_energy = maxi(1, roundi(float(energy_cost) * 0.8))
    if energy < adjusted_energy:
        return {"ok": false, "reason": "too-tired", "required_energy": adjusted_energy}
    return {
        "ok": true,
        "minutes": int(profile.get("minutes", 0)),
        "energy": adjusted_energy,
        "amount": int(profile.get("amount", 0)),
        "yield": str(resource.get("yield", "materials"))
    }

func work_resource(resource: Dictionary) -> Dictionary:
    var preview := preview_work(resource)
    if not bool(preview.get("ok", false)):
        return preview
    var energy_cost := int(preview.get("energy", 0))
    var minutes := int(preview.get("minutes", 0))
    var amount := int(preview.get("amount", 0))
    var yield_key := str(preview.get("yield", resource.get("yield", "materials")))
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

func regrowth_profile(kind: String) -> Dictionary:
    return REGROWTH_PROFILES.get(kind, {})

func mark_resource_cleared(resource: Dictionary, changes: Dictionary, states: Dictionary, changed_day: int) -> void:
    var resource_id := str(resource.get("id", ""))
    var kind := str(resource.get("kind", ""))
    var profile := regrowth_profile(kind)
    if resource_id.is_empty() or profile.is_empty():
        return
    changes[resource_id] = true
    states[resource_id] = {
        "kind": kind,
        "stage": str(profile.get("initial_stage", "cleared")),
        "days_remaining": int(profile.get("days", 1)),
        "changed_day": changed_day
    }

func _stage_for(kind: String, days_remaining: int) -> String:
    if kind == "tree":
        return "felled" if days_remaining >= 3 else "sprout" if days_remaining == 2 else "young"
    if kind == "stone":
        return "depleted" if days_remaining >= 2 else "fractures"
    if kind == "ore":
        return "depleted" if days_remaining >= 2 else "crystals"
    return "harvested"

func advance_regrowth(changes: Dictionary, states: Dictionary, resources: Array, new_day: int) -> Array[String]:
    var restored: Array[String] = []
    var resource_by_id: Dictionary = {}
    for resource_variant in resources:
        if resource_variant is Dictionary:
            var resource: Dictionary = resource_variant
            resource_by_id[str(resource.get("id", ""))] = resource
    for resource_id_variant in states.keys().duplicate():
        var resource_id := str(resource_id_variant)
        if not resource_by_id.has(resource_id):
            states.erase(resource_id)
            continue
        var resource: Dictionary = resource_by_id[resource_id]
        var kind := str(resource.get("kind", ""))
        var state: Dictionary = states[resource_id] if states[resource_id] is Dictionary else {}
        if kind == "herb":
            changes[resource_id] = false
            states.erase(resource_id)
            restored.append(resource_id)
            continue
        var remaining := int(state.get("days_remaining", int(regrowth_profile(kind).get("days", 1)))) - 1
        if remaining <= 0:
            changes[resource_id] = false
            states.erase(resource_id)
            restored.append(resource_id)
            continue
        state["days_remaining"] = remaining
        state["stage"] = _stage_for(kind, remaining)
        state["last_advanced_day"] = new_day
        states[resource_id] = state
    return restored

func normalize_resource_states(changes: Dictionary, states: Dictionary, resources: Array, current_day: int) -> void:
    for resource_variant in resources:
        if not resource_variant is Dictionary:
            continue
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        if not bool(changes.get(resource_id, false)) or states.has(resource_id):
            continue
        var profile := regrowth_profile(str(resource.get("kind", "")))
        if profile.is_empty():
            continue
        states[resource_id] = {
            "kind": str(resource.get("kind", "")),
            "stage": str(profile.get("initial_stage", "cleared")),
            "days_remaining": int(profile.get("days", 1)),
            "changed_day": current_day
        }

func sleep_next_day(changes: Dictionary, resources: Array, states: Dictionary = {}) -> Array[String]:
    day += 1
    var restored := advance_regrowth(changes, states, resources, day)
    # Preserve the original herb contract even for legacy callers that do not
    # provide the optional resource-state map.
    if states.is_empty():
        for resource_variant in resources:
            if not resource_variant is Dictionary:
                continue
            var resource: Dictionary = resource_variant
            if str(resource.get("kind", "")) == "herb":
                changes[str(resource.get("id", ""))] = false
    minute_of_day = START_MINUTE
    energy = MAX_ENERGY
    return restored

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
        "inventory": inventory.duplicate(true),
        "upgrades": upgrades.duplicate(true)
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
    upgrades = {}
    var source_upgrades = source.get("upgrades", {})
    if source_upgrades is Dictionary:
        for upgrade_id in UPGRADE_RECIPES.keys():
            if bool(source_upgrades.get(upgrade_id, false)):
                upgrades[upgrade_id] = true
