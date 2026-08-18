extends RefCounted
class_name ClovermereVillageProject

const PROJECT_ID := "village-commons"
const PROJECT_DEFINITION := {
    "id": PROJECT_ID,
    "name": "Village Commons",
    "summary": "A shared green where Clovermere can gather, trade, and plan the next season.",
    "stages": [
        {"id": "foundation", "name": "Mark the Commons", "summary": "Set the first stones and timber around a shared village green.", "cost": {"timber": 5, "stone": 3}, "support": 1},
        {"id": "shelter", "name": "Raise the Shelter", "summary": "Build a covered table for tools, food, and the evening meeting.", "cost": {"timber": 4, "ore": 2}, "support": 2},
        {"id": "planting", "name": "Plant the Commons", "summary": "Bring herbs and fish to seed the green and mark its first feast.", "cost": {"herbs": 3, "fish": 1}, "support": 3}
    ]
}

func project_id() -> String:
    return PROJECT_ID

func stage_count() -> int:
    return PROJECT_DEFINITION.stages.size()

func default_state() -> Dictionary:
    return {"project_id": PROJECT_ID, "stage": 0, "support_events": {}, "contributions": {}, "completed_day": 0}

func definition() -> Dictionary:
    return PROJECT_DEFINITION.duplicate(true)

func current_stage(state: Dictionary) -> Dictionary:
    var stage := int(state.get("stage", 0))
    if stage >= stage_count():
        return {"id": "complete", "name": "Village Commons Complete", "summary": "Clovermere has a shared place to gather.", "cost": {}, "support": 0}
    return PROJECT_DEFINITION.stages[stage].duplicate(true)

func support_points(state: Dictionary) -> int:
    var events: Dictionary = state.get("support_events", {}) if state.get("support_events", {}) is Dictionary else {}
    return events.size()

func record_support(state: Dictionary, source: String, source_id: String) -> bool:
    if source.is_empty() or source_id.is_empty():
        return false
    var events: Dictionary = state.get("support_events", {}) if state.get("support_events", {}) is Dictionary else {}
    var key := "%s:%s" % [source, source_id]
    if events.has(key):
        return false
    events[key] = true
    state["support_events"] = events
    return true

func can_contribute(state: Dictionary, inventory: Dictionary) -> bool:
    var stage := current_stage(state)
    return not is_complete(state) and support_points(state) >= int(stage.get("support", 0)) and _can_afford(inventory, stage.get("cost", {}))

func contribute(state: Dictionary, inventory: Dictionary, day: int) -> Dictionary:
    if is_complete(state):
        return {"ok": false, "reason": "complete"}
    var stage := current_stage(state)
    var required_support := int(stage.get("support", 0))
    if support_points(state) < required_support:
        return {"ok": false, "reason": "needs-support", "required": required_support, "current": support_points(state), "stage": stage.duplicate(true)}
    var cost: Dictionary = stage.get("cost", {})
    if not _can_afford(inventory, cost):
        return {"ok": false, "reason": "missing-materials", "missing": _missing(inventory, cost), "stage": stage.duplicate(true)}
    for material_variant in cost.keys():
        var material := str(material_variant)
        inventory[material] = int(inventory.get(material, 0)) - int(cost[material_variant])
    var stage_index := int(state.get("stage", 0))
    var contributions: Dictionary = state.get("contributions", {}) if state.get("contributions", {}) is Dictionary else {}
    contributions[str(stage.get("id", stage_index))] = maxi(1, day)
    state["contributions"] = contributions
    state["stage"] = stage_index + 1
    if is_complete(state):
        state["completed_day"] = maxi(1, day)
    return {"ok": true, "stage": stage.duplicate(true), "next_stage": current_stage(state), "complete": is_complete(state), "cost": cost.duplicate(true)}

func is_complete(state: Dictionary) -> bool:
    return int(state.get("stage", 0)) >= stage_count()

func consequence_flags(state: Dictionary) -> Dictionary:
    var stage := int(state.get("stage", 0))
    return {
        "commons_foundation": stage >= 1,
        "commons_shelter": stage >= 2,
        "commons_complete": stage >= 3
    }

func from_dict(source: Dictionary) -> Dictionary:
    var result := default_state()
    if not source is Dictionary:
        return result
    result["stage"] = clampi(int(source.get("stage", 0)), 0, stage_count())
    result["support_events"] = source.get("support_events", {}).duplicate(true) if source.get("support_events", {}) is Dictionary else {}
    result["contributions"] = source.get("contributions", {}).duplicate(true) if source.get("contributions", {}) is Dictionary else {}
    result["completed_day"] = maxi(0, int(source.get("completed_day", 0)))
    return result

func to_dict(state: Dictionary) -> Dictionary:
    return from_dict(state)

func _can_afford(inventory: Dictionary, cost: Dictionary) -> bool:
    for material_variant in cost.keys():
        if int(inventory.get(str(material_variant), 0)) < int(cost[material_variant]):
            return false
    return true

func _missing(inventory: Dictionary, cost: Dictionary) -> Dictionary:
    var result := {}
    for material_variant in cost.keys():
        var amount := int(cost[material_variant]) - int(inventory.get(str(material_variant), 0))
        if amount > 0:
            result[str(material_variant)] = amount
    return result
