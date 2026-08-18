extends RefCounted
class_name ClovermereRequestBoard

const REQUESTS := [
    {"id": "garden-tonic", "title": "A Tonic for the Garden", "requester": "alda-fen", "requester_name": "Alda Fen", "location": "herbalists-garden", "cost": {"herbs": 2}, "reward": {"energy": 12}, "summary": "Bring two herb bundles before the afternoon beds dry.", "consequence": "garden_request"},
    {"id": "forge-supply", "title": "Kindling for the Forge", "requester": "tobin-wren", "requester_name": "Tobin Wren", "location": "tinker-workshop", "cost": {"stone": 2, "ore": 1}, "reward": {"inventory": {"timber": 2}}, "summary": "Two stones and one ore will keep the forge working today.", "consequence": "workshop_request"},
    {"id": "river-baskets", "title": "Baskets from the River", "requester": "orin-reed", "requester_name": "Orin Reed", "location": "willowmere", "cost": {"fish": 2}, "reward": {"inventory": {"herbs": 2}}, "summary": "Trade two river fish for dried herbs at Willowmere.", "consequence": "willow_request"},
    {"id": "orchard-crates", "title": "Crates for the Orchard", "requester": "alda-fen", "requester_name": "Alda Fen", "location": "apple-orchard", "cost": {"timber": 3}, "reward": {"inventory": {"fish": 1}}, "summary": "Three sound boards before the next orchard picking day.", "consequence": "orchard_request"},
    {"id": "lookout-stones", "title": "Stones for the Lookout", "requester": "orin-reed", "requester_name": "Orin Reed", "location": "west-lookout", "cost": {"stone": 3}, "reward": {"inventory": {"ore": 1}}, "summary": "Three flat stones will steady the western lookout path.", "consequence": "lookout_request"}
]

func default_state() -> Dictionary:
    return {"day": 0, "available_ids": [], "accepted_id": "", "accepted_day": 0, "completed_ids": {}, "expired_ids": {}, "consequence_flags": {}}

func definitions() -> Array:
    return REQUESTS.duplicate(true)

func definition_for(request_id: String) -> Dictionary:
    for request in REQUESTS:
        if str(request.id) == request_id:
            return request.duplicate(true)
    return {}

func ensure_day(state: Dictionary, day: int) -> Dictionary:
    var current_day := maxi(1, day)
    var result := {"rotated": false, "expired_id": ""}
    if int(state.get("day", 0)) == current_day and not state.get("available_ids", []).is_empty():
        return result
    var accepted_id := str(state.get("accepted_id", ""))
    if not accepted_id.is_empty() and int(state.get("accepted_day", 0)) < current_day:
        var expired: Dictionary = state.get("expired_ids", {}) if state.get("expired_ids", {}) is Dictionary else {}
        expired[accepted_id] = current_day
        state["expired_ids"] = expired
        state["accepted_id"] = ""
        state["accepted_day"] = 0
        result["expired_id"] = accepted_id
    var available: Array[String] = []
    var offset := posmod(current_day - 1, REQUESTS.size())
    for index in range(3):
        available.append(str(REQUESTS[(offset + index) % REQUESTS.size()].id))
    state["day"] = current_day
    state["available_ids"] = available
    result["rotated"] = true
    return result

func board_cards(state: Dictionary, day: int, inventory: Dictionary = {}) -> Array:
    ensure_day(state, day)
    var cards: Array = []
    var accepted_id := str(state.get("accepted_id", ""))
    var completed: Dictionary = state.get("completed_ids", {}) if state.get("completed_ids", {}) is Dictionary else {}
    for request_id_variant in state.get("available_ids", []):
        var request_id := str(request_id_variant)
        var request := definition_for(request_id)
        if request.is_empty():
            continue
        var card := request.duplicate(true)
        var is_completed := completed.has(request_id)
        var is_accepted := accepted_id == request_id
        card["status"] = "completed" if is_completed else "accepted" if is_accepted else "available"
        card["can_accept"] = not is_completed and accepted_id.is_empty()
        card["can_complete"] = is_accepted and _can_afford(inventory, request.get("cost", {}))
        card["missing"] = _missing(inventory, request.get("cost", {}))
        cards.append(card)
    return cards

func accept_request(state: Dictionary, request_id: String, day: int) -> Dictionary:
    ensure_day(state, day)
    if not state.get("available_ids", []).has(request_id):
        return {"ok": false, "reason": "not-available", "request_id": request_id}
    if not str(state.get("accepted_id", "")).is_empty():
        return {"ok": false, "reason": "already-accepted", "request_id": str(state.get("accepted_id", ""))}
    if (state.get("completed_ids", {}) as Dictionary).has(request_id):
        return {"ok": false, "reason": "already-completed", "request_id": request_id}
    state["accepted_id"] = request_id
    state["accepted_day"] = maxi(1, day)
    return {"ok": true, "request": definition_for(request_id), "day": day}

func abandon_request(state: Dictionary) -> Dictionary:
    var request_id := str(state.get("accepted_id", ""))
    if request_id.is_empty():
        return {"ok": false, "reason": "none-accepted"}
    state["accepted_id"] = ""
    state["accepted_day"] = 0
    return {"ok": true, "request_id": request_id}

func complete_request(state: Dictionary, request_id: String, day: int) -> Dictionary:
    ensure_day(state, day)
    if str(state.get("accepted_id", "")) != request_id:
        return {"ok": false, "reason": "not-accepted", "request_id": request_id}
    var completed: Dictionary = state.get("completed_ids", {}) if state.get("completed_ids", {}) is Dictionary else {}
    if completed.has(request_id):
        return {"ok": false, "reason": "already-completed", "request_id": request_id}
    var request := definition_for(request_id)
    if request.is_empty():
        return {"ok": false, "reason": "unknown-request", "request_id": request_id}
    completed[request_id] = maxi(1, day)
    state["completed_ids"] = completed
    state["accepted_id"] = ""
    state["accepted_day"] = 0
    var consequence_flags: Dictionary = state.get("consequence_flags", {}) if state.get("consequence_flags", {}) is Dictionary else {}
    consequence_flags[str(request.get("consequence", request_id))] = true
    state["consequence_flags"] = consequence_flags
    return {"ok": true, "request": request, "reward": request.get("reward", {}).duplicate(true), "day": day}

func accepted_request(state: Dictionary, day: int) -> Dictionary:
    ensure_day(state, day)
    return definition_for(str(state.get("accepted_id", "")))

func reminder(state: Dictionary, npc_id: String, inventory: Dictionary, day: int) -> String:
    var request := accepted_request(state, day)
    if request.is_empty() or str(request.get("requester", "")) != npc_id:
        return ""
    if _can_afford(inventory, request.get("cost", {})):
        return " I have the request in mind; bring those materials to me and we can finish it."
    return " I still need %s before this request can be finished." % _cost_text(request.get("cost", {}))

func consequence_flags(state: Dictionary) -> Dictionary:
    var flags: Dictionary = state.get("consequence_flags", {}) if state.get("consequence_flags", {}) is Dictionary else {}
    return flags.duplicate(true)

func from_dict(source: Dictionary) -> Dictionary:
    var result := default_state()
    if not source is Dictionary:
        return result
    result["day"] = maxi(0, int(source.get("day", 0)))
    result["available_ids"] = source.get("available_ids", []).duplicate(true) if source.get("available_ids", []) is Array else []
    result["accepted_id"] = str(source.get("accepted_id", ""))
    result["accepted_day"] = maxi(0, int(source.get("accepted_day", 0)))
    result["completed_ids"] = source.get("completed_ids", {}).duplicate(true) if source.get("completed_ids", {}) is Dictionary else {}
    result["expired_ids"] = source.get("expired_ids", {}).duplicate(true) if source.get("expired_ids", {}) is Dictionary else {}
    result["consequence_flags"] = source.get("consequence_flags", {}).duplicate(true) if source.get("consequence_flags", {}) is Dictionary else {}
    return result

func to_dict(state: Dictionary) -> Dictionary:
    return from_dict(state)

func _can_afford(inventory: Dictionary, cost: Dictionary) -> bool:
    for material_variant in cost.keys():
        if int(inventory.get(str(material_variant), 0)) < int(cost[material_variant]):
            return false
    return true

func _missing(inventory: Dictionary, cost: Dictionary) -> Dictionary:
    var missing := {}
    for material_variant in cost.keys():
        var amount := int(cost[material_variant]) - int(inventory.get(str(material_variant), 0))
        if amount > 0:
            missing[str(material_variant)] = amount
    return missing

func _cost_text(cost: Dictionary) -> String:
    var parts: Array[String] = []
    for material_variant in cost.keys():
        parts.append("%d %s" % [int(cost[material_variant]), str(material_variant).to_upper()])
    return "  ·  ".join(parts)
