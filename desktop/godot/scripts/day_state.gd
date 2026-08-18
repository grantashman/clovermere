extends RefCounted
class_name ClovermereDayState

const START_DAY := 1
const START_MINUTE := 8 * 60
const MAX_ENERGY := 100

const WORK_PROFILES := {
    "tree": {"minutes": 30, "energy": 18, "amount": 3},
    "stone": {"minutes": 30, "energy": 16, "amount": 2},
    "ore": {"minutes": 45, "energy": 24, "amount": 1},
    "herb": {"minutes": 15, "energy": 8, "amount": 2},
    "fish": {"minutes": 30, "energy": 12, "amount": 2}
}
const REGROWTH_PROFILES := {
    "tree": {"days": 3, "initial_stage": "felled"},
    "stone": {"days": 2, "initial_stage": "depleted"},
    "ore": {"days": 2, "initial_stage": "depleted"},
    "herb": {"days": 1, "initial_stage": "harvested"},
    "fish": {"days": 1, "initial_stage": "harvested"}
}
const RESOURCE_KEYS := ["timber", "stone", "ore", "herbs", "fish"]
const RECIPE_CATALOG := {
    "tinkers-kit": {"name": "Tinker’s Kit", "cost": {"timber": 3, "stone": 2, "ore": 1}, "summary": "Reduce work energy costs by 20%.", "category": "tool"},
    "wayfarers-satchel": {"name": "Wayfarer’s Satchel", "cost": {"timber": 5, "herbs": 2}, "summary": "Finish field work in less time.", "category": "travel"},
    "hearthward-charm": {"name": "Hearthward Charm", "cost": {"stone": 2, "herbs": 2, "ore": 3}, "summary": "Raise the day’s energy reserve to 115.", "category": "ward"}
}
const UPGRADE_RECIPES := RECIPE_CATALOG
const COOKING_RECIPES := {
    "hearth-tea": {"name": "Hearth Tea", "cost": {"timber": 1, "herbs": 2}, "summary": "Steep a warm tonic and restore 25 energy.", "energy": 25, "minutes": 10},
    "riverside-stew": {"name": "Riverside Stew", "cost": {"fish": 1, "timber": 1}, "summary": "A filling meal that makes the next work action cost less energy.", "energy": 30, "minutes": 15, "meal_id": "riverside-stew", "effects": {"energy_discount": 0.15}},
    "garden-chowder": {"name": "Garden Chowder", "cost": {"fish": 1, "herbs": 1}, "summary": "A bright meal that makes the next work action take less time.", "energy": 20, "minutes": 12, "meal_id": "garden-chowder", "effects": {"minutes_discount": 0.2}}
}

var day := START_DAY
var minute_of_day := START_MINUTE
var energy := MAX_ENERGY
var inventory: Dictionary = {
    "timber": 0,
    "stone": 0,
    "ore": 0,
    "herbs": 0,
    "fish": 0
}
var upgrades: Dictionary = {}
var meals: Dictionary = {
    "riverside-stew": 0,
    "garden-chowder": 0
}
var next_work_effects: Dictionary = {
    "energy_discount": 0.0,
    "minutes_discount": 0.0,
    "uses": 0
}
var storage: Dictionary = {
    "timber": 0,
    "stone": 0,
    "ore": 0,
    "herbs": 0,
    "fish": 0
}

func max_energy() -> int:
    return 115 if has_upgrade("hearthward-charm") else MAX_ENERGY

func has_upgrade(upgrade_id: String) -> bool:
    return bool(upgrades.get(upgrade_id, false))

func recipe_ids() -> Array[String]:
    return ["tinkers-kit", "wayfarers-satchel", "hearthward-charm"]

func cooking_ids() -> Array[String]:
    return ["hearth-tea", "riverside-stew", "garden-chowder"]

func meal_ids() -> Array[String]:
    return ["riverside-stew", "garden-chowder"]

func cooking_preview(recipe_id: String) -> Dictionary:
    var recipe: Dictionary = COOKING_RECIPES.get(recipe_id, {})
    if recipe.is_empty():
        return {"ok": false, "craftable": false, "reason": "unknown-recipe"}
    var cost: Dictionary = recipe.get("cost", {})
    var missing: Dictionary = {}
    for material_variant in cost.keys():
        var material := str(material_variant)
        var available := int(inventory.get(material, 0))
        var required := int(cost[material_variant])
        if available < required:
            missing[material] = required - available
    return {
        "ok": true,
        "craftable": missing.is_empty(),
        "id": recipe_id,
        "name": str(recipe.get("name", recipe_id)),
        "summary": str(recipe.get("summary", "")),
        "cost": cost.duplicate(true),
        "missing": missing,
        "energy": int(recipe.get("energy", 0)),
        "minutes": int(recipe.get("minutes", 0)),
        "meal_id": str(recipe.get("meal_id", "")),
        "meal_count": int(meals.get(str(recipe.get("meal_id", "")), 0)),
        "effects": recipe.get("effects", {}).duplicate(true)
    }

func cook_recipe(recipe_id: String) -> Dictionary:
    var preview := cooking_preview(recipe_id)
    if not bool(preview.get("ok", false)):
        return {"ok": false, "reason": str(preview.get("reason", "unknown-recipe")), "recipe": recipe_id}
    if not bool(preview.get("craftable", false)):
        return {"ok": false, "reason": "missing-materials", "recipe": recipe_id, "missing": preview.get("missing", {})}
    var recipe: Dictionary = COOKING_RECIPES[recipe_id]
    _consume_materials(recipe.get("cost", {}))
    var minutes := int(recipe.get("minutes", 0))
    minute_of_day = mini(23 * 60 + 59, minute_of_day + minutes)
    var meal_id := str(recipe.get("meal_id", ""))
    if not meal_id.is_empty():
        meals[meal_id] = int(meals.get(meal_id, 0)) + 1
        return {
            "ok": true,
            "recipe": recipe_id,
            "name": str(recipe.get("name", recipe_id)),
            "minutes": minutes,
            "meal_id": meal_id,
            "meal_count": int(meals.get(meal_id, 0)),
            "cost": recipe.get("cost", {}).duplicate(true),
            "effects": recipe.get("effects", {}).duplicate(true)
        }
    var energy_restored := int(recipe.get("energy", 0))
    energy = mini(max_energy(), energy + energy_restored)
    return {
        "ok": true,
        "recipe": recipe_id,
        "name": str(recipe.get("name", recipe_id)),
        "minutes": minutes,
        "energy": energy_restored,
        "cost": recipe.get("cost", {}).duplicate(true)
    }

func eat_meal(meal_id: String) -> Dictionary:
    if not meal_ids().has(meal_id):
        return {"ok": false, "reason": "unknown-meal", "meal_id": meal_id}
    var count := int(meals.get(meal_id, 0))
    if count <= 0:
        return {"ok": false, "reason": "missing-meal", "meal_id": meal_id}
    var recipe: Dictionary = COOKING_RECIPES.get(meal_id, {})
    if recipe.is_empty():
        return {"ok": false, "reason": "unknown-meal", "meal_id": meal_id}
    meals[meal_id] = count - 1
    energy = mini(max_energy(), energy + int(recipe.get("energy", 0)))
    minute_of_day = mini(23 * 60 + 59, minute_of_day + 5)
    var effects: Dictionary = recipe.get("effects", {})
    next_work_effects = {
        "energy_discount": float(effects.get("energy_discount", 0.0)),
        "minutes_discount": float(effects.get("minutes_discount", 0.0)),
        "uses": 1
    }
    return {
        "ok": true,
        "meal_id": meal_id,
        "name": str(recipe.get("name", meal_id)),
        "energy": int(recipe.get("energy", 0)),
        "minutes": 5,
        "effects": next_work_effects.duplicate(true),
        "remaining": meals[meal_id]
    }

func recipe_preview(recipe_id: String) -> Dictionary:
    var recipe: Dictionary = RECIPE_CATALOG.get(recipe_id, {})
    if recipe.is_empty():
        return {"ok": false, "craftable": false, "reason": "unknown-recipe"}
    var cost: Dictionary = recipe.get("cost", {})
    var missing: Dictionary = {}
    for material_variant in cost.keys():
        var material := str(material_variant)
        var available := int(inventory.get(material, 0))
        var required := int(cost[material_variant])
        if available < required:
            missing[material] = required - available
    return {
        "ok": true,
        "craftable": not has_upgrade(recipe_id) and missing.is_empty(),
        "owned": has_upgrade(recipe_id),
        "id": recipe_id,
        "name": str(recipe.get("name", recipe_id)),
        "summary": str(recipe.get("summary", "")),
        "category": str(recipe.get("category", "tool")),
        "cost": cost.duplicate(true),
        "missing": missing
    }

func _consume_materials(cost: Dictionary) -> void:
    for material_variant in cost.keys():
        var material := str(material_variant)
        inventory[material] = int(inventory.get(material, 0)) - int(cost[material_variant])

func craft_recipe(recipe_id: String) -> Dictionary:
    var preview := recipe_preview(recipe_id)
    if not bool(preview.get("ok", false)) or bool(preview.get("owned", false)):
        return {"ok": false, "reason": str(preview.get("reason", "already-owned")), "recipe": recipe_id}
    if not bool(preview.get("craftable", false)):
        return {"ok": false, "reason": "missing-materials", "recipe": recipe_id, "missing": preview.get("missing", {})}
    var recipe: Dictionary = RECIPE_CATALOG[recipe_id]
    _consume_materials(recipe.get("cost", {}))
    upgrades[recipe_id] = true
    return {"ok": true, "recipe": recipe_id, "name": str(recipe.get("name", recipe_id)), "cost": recipe.get("cost", {}).duplicate(true)}

func purchase_upgrade(upgrade_id: String) -> Dictionary:
    return craft_recipe(upgrade_id)

func can_afford(cost: Dictionary) -> bool:
    for material_variant in cost.keys():
        var material := str(material_variant)
        if not RESOURCE_KEYS.has(material):
            return false
        if int(inventory.get(material, 0)) < int(cost[material_variant]):
            return false
    return true

func spend_materials(cost: Dictionary) -> bool:
    if not can_afford(cost):
        return false
    _consume_materials(cost)
    return true

func apply_reward(reward: Dictionary) -> void:
    if reward.has("energy"):
        energy = clampi(energy + int(reward.get("energy", 0)), 0, max_energy())
    var reward_inventory = reward.get("inventory", {})
    if reward_inventory is Dictionary:
        for material_variant in reward_inventory.keys():
            var material := str(material_variant)
            if RESOURCE_KEYS.has(material):
                inventory[material] = int(inventory.get(material, 0)) + maxi(0, int(reward_inventory[material_variant]))
    var reward_storage = reward.get("storage", {})
    if reward_storage is Dictionary:
        for material_variant in reward_storage.keys():
            var material := str(material_variant)
            if RESOURCE_KEYS.has(material):
                storage[material] = int(storage.get(material, 0)) + maxi(0, int(reward_storage[material_variant]))

func deposit_inventory() -> Dictionary:
    var deposited: Dictionary = {}
    for material in RESOURCE_KEYS:
        var amount := int(inventory.get(material, 0))
        if amount <= 0:
            continue
        deposited[material] = amount
        storage[material] = int(storage.get(material, 0)) + amount
        inventory[material] = 0
    return deposited

func withdraw_storage(requested: Dictionary = {}) -> Dictionary:
    var moved: Dictionary = {}
    for material_variant in requested.keys():
        var material := str(material_variant)
        if not RESOURCE_KEYS.has(material):
            continue
        var amount := mini(int(requested[material_variant]), int(storage.get(material, 0)))
        if amount <= 0:
            continue
        storage[material] = int(storage.get(material, 0)) - amount
        inventory[material] = int(inventory.get(material, 0)) + amount
        moved[material] = amount
    return moved

func preview_work(resource: Dictionary) -> Dictionary:
    var kind := str(resource.get("kind", ""))
    var profile: Dictionary = WORK_PROFILES.get(kind, {})
    if profile.is_empty():
        return {"ok": false, "reason": "unknown-resource"}
    var energy_cost := int(profile.get("energy", 0))
    var adjusted_energy := energy_cost
    var adjusted_minutes := int(profile.get("minutes", 0))
    if has_upgrade("tinkers-kit"):
        adjusted_energy = maxi(1, roundi(float(energy_cost) * 0.8))
    if has_upgrade("wayfarers-satchel"):
        adjusted_minutes = maxi(5, roundi(float(adjusted_minutes) * 0.8))
    var effect_uses := int(next_work_effects.get("uses", 0))
    if effect_uses > 0:
        var energy_discount := clampf(float(next_work_effects.get("energy_discount", 0.0)), 0.0, 0.8)
        var minutes_discount := clampf(float(next_work_effects.get("minutes_discount", 0.0)), 0.0, 0.8)
        adjusted_energy = maxi(1, roundi(float(adjusted_energy) * (1.0 - energy_discount)))
        adjusted_minutes = maxi(5, roundi(float(adjusted_minutes) * (1.0 - minutes_discount)))
    if energy < adjusted_energy:
        return {"ok": false, "reason": "too-tired", "required_energy": adjusted_energy}
    return {
        "ok": true,
        "minutes": adjusted_minutes,
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
    if int(next_work_effects.get("uses", 0)) > 0:
        next_work_effects["uses"] = 0
        next_work_effects["energy_discount"] = 0.0
        next_work_effects["minutes_discount"] = 0.0
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
    energy = max_energy()
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
        "storage": storage.duplicate(true),
        "upgrades": upgrades.duplicate(true),
        "meals": meals.duplicate(true),
        "next_work_effects": next_work_effects.duplicate(true)
    }

func from_dict(source: Dictionary) -> void:
    day = maxi(START_DAY, int(source.get("day", START_DAY)))
    minute_of_day = clampi(int(source.get("minute_of_day", START_MINUTE)), 0, 23 * 60 + 59)
    inventory = {
        "timber": 0,
        "stone": 0,
        "ore": 0,
        "herbs": 0,
        "fish": 0
    }
    var source_inventory = source.get("inventory", {})
    if source_inventory is Dictionary:
        for key in inventory.keys():
            inventory[key] = maxi(0, int(source_inventory.get(key, 0)))
    storage = {}
    for key in RESOURCE_KEYS:
        storage[key] = 0
    var source_storage = source.get("storage", {})
    if source_storage is Dictionary:
        for key in RESOURCE_KEYS:
            storage[key] = maxi(0, int(source_storage.get(key, 0)))
    upgrades = {}
    var source_upgrades = source.get("upgrades", {})
    if source_upgrades is Dictionary:
        for upgrade_id in RECIPE_CATALOG.keys():
            if bool(source_upgrades.get(upgrade_id, false)):
                upgrades[upgrade_id] = true
    energy = clampi(int(source.get("energy", max_energy())), 0, max_energy())
    meals = {"riverside-stew": 0, "garden-chowder": 0}
    var source_meals = source.get("meals", {})
    if source_meals is Dictionary:
        for meal_id in meals.keys():
            meals[meal_id] = maxi(0, int(source_meals.get(meal_id, 0)))
    next_work_effects = {"energy_discount": 0.0, "minutes_discount": 0.0, "uses": 0}
    var source_effects = source.get("next_work_effects", {})
    if source_effects is Dictionary:
        next_work_effects["energy_discount"] = clampf(float(source_effects.get("energy_discount", 0.0)), 0.0, 0.8)
        next_work_effects["minutes_discount"] = clampf(float(source_effects.get("minutes_discount", 0.0)), 0.0, 0.8)
        next_work_effects["uses"] = mini(1, maxi(0, int(source_effects.get("uses", 0))))
