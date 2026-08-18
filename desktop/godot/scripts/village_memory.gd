extends RefCounted
class_name ClovermereVillageMemory

const MOMENTS := ["morning", "day", "evening"]

const RESIDENT_DEFINITIONS := {
    "alda-fen": {
        "speaker": "Alda Fen",
        "favor_id": "foxglove-gathering",
        "favor_name": "Foxglove Gathering",
        "cost": {"herbs": 2},
        "reward": {"energy": 10},
        "gift_reward": {"energy": 3},
        "gift": "The garden saved a little tonic for you. Take it before the road asks too much.",
        "intro": {
            "morning": "Alda Fen checks the foxglove beds. I am Alda. If you are staying, let the garden learn your footsteps.",
            "day": "Alda Fen looks up from the garden. I am Alda. The village has room for another pair of willing hands.",
            "evening": "Alda Fen shelters a lantern by the garden gate. I am Alda. Come back in daylight and we will find a useful beginning."
        },
        "pending": {
            "morning": "The foxglove is ready for a careful gathering. Bring me two bundles of herbs, and I will show you which leaves keep their strength.",
            "day": "Bring me two bundles of herbs from the patches beyond the lane. A careful gatherer is a friend to every garden.",
            "evening": "The beds can wait until morning. Bring two bundles of herbs when the light returns, and we will make something kind of them."
        },
        "ready": "You found the herbs. Leave them with me, and the garden will answer with a little strength for your next walk.",
        "trusted": {
            "morning": "The foxglove remembers your hands. Take ten minutes of borrowed strength, then leave the roots room to breathe.",
            "day": "The garden is generous because you have learned when not to take. There is a tonic waiting whenever the road feels long.",
            "evening": "The garden is settled for the night. You have earned a warm welcome here, whenever the paths bring you back."
        }
    },
    "tobin-wren": {
        "speaker": "Tobin Wren",
        "favor_id": "forge-kindling",
        "favor_name": "Forge Kindling",
        "cost": {"stone": 2, "ore": 1},
        "reward": {"inventory": {"timber": 2}},
        "gift_reward": {"inventory": {"timber": 1}},
        "gift": "Tobin has set aside one straight piece of timber. It will become something useful in your hands.",
        "intro": {
            "morning": "Tobin Wren opens the workshop shutters. I am Tobin. Good work starts with knowing what the day can carry.",
            "day": "Tobin Wren weighs a piece of ore in his palm. I am Tobin. Bring questions to the workbench, not just materials.",
            "evening": "Tobin Wren banks the forge. I am Tobin. A quiet workshop is still preparing for tomorrow."
        },
        "pending": {
            "morning": "Bring two sound stones and one piece of ore. I need kindling for the forge, and I will return the favor in timber.",
            "day": "Two stones and one ore will keep the forge useful through the afternoon. Bring them when you have a moment.",
            "evening": "The forge is banked, but the work remains. Two stones and one ore tomorrow will help us both."
        },
        "ready": "That is exactly what the forge needs. Leave the stones and ore here, and take this timber for the next useful thing.",
        "trusted": {
            "morning": "You know the difference between a tool and a solution now. The bench is yours whenever you need a patient answer.",
            "day": "The village lasts because someone keeps repairing what matters. You have become one of those someones.",
            "evening": "The embers are low, but the workshop is not lonely. Come back tomorrow and we will make the next good thing."
        }
    },
    "orin-reed": {
        "speaker": "Orin Reed",
        "favor_id": "lane-markers",
        "favor_name": "Lane Markers",
        "cost": {"timber": 3},
        "reward": {"inventory": {"stone": 1}},
        "gift_reward": {"inventory": {"stone": 1}},
        "gift": "Orin leaves one good marker-stone by the lane. The next path will be easier to trust.",
        "intro": {
            "morning": "Orin Reed marks the eastern lane. I am Orin. If you wander beyond the village, keep one landmark behind you.",
            "day": "Orin Reed studies the crossroads. I am Orin. A place becomes home when people know how to return to it.",
            "evening": "Orin Reed lights the first lane lantern. I am Orin. The safest path is the one we remember together."
        },
        "pending": {
            "morning": "Bring three pieces of timber and I will make markers for the eastern lane. It is easier to explore when home can point the way back.",
            "day": "Three pieces of timber will mark the eastern lane before dusk. Bring them and I will make the road clearer for everyone.",
            "evening": "The markers can wait until morning. Three pieces of timber will make tomorrow's walk safer."
        },
        "ready": "The timber is enough. I will mark the eastern lane, and this stone will remind you that every good route begins with a firm footing.",
        "trusted": {
            "morning": "The eastern lane is clearer now, and so are you. Mark a landmark, take a breath, and keep going.",
            "day": "You have learned the first rule of Clovermere: every road is shared. The village will remember the paths you improve.",
            "evening": "Lanterns first, questions after. You know the way home now, and the village knows you belong on its roads."
        }
    }
}

func resident_ids() -> Array[String]:
    return ["alda-fen", "tobin-wren", "orin-reed"]

func default_state() -> Dictionary:
    var result: Dictionary = {}
    for resident_id in resident_ids():
        result[resident_id] = {
            "stage": 0,
            "favor_completed": false,
            "introduced_day": 0,
            "completed_day": 0,
            "last_gift_day": 0
        }
    return result

func definition_for(npc_id: String) -> Dictionary:
    var definition = RESIDENT_DEFINITIONS.get(npc_id, {})
    return definition.duplicate(true) if definition is Dictionary else {}

func state_for(state: Dictionary, npc_id: String) -> Dictionary:
    var value = state.get(npc_id, {})
    return value.duplicate(true) if value is Dictionary else {}

func mark_introduced(state: Dictionary, npc_id: String, day: int) -> bool:
    if not RESIDENT_DEFINITIONS.has(npc_id):
        return false
    var resident_state := state_for(state, npc_id)
    if int(resident_state.get("stage", 0)) > 0:
        return false
    resident_state["stage"] = 1
    resident_state["introduced_day"] = maxi(1, day)
    state[npc_id] = resident_state
    return true

func complete_favor(state: Dictionary, npc_id: String, day: int) -> Dictionary:
    if not RESIDENT_DEFINITIONS.has(npc_id):
        return {"ok": false, "reason": "unknown-resident"}
    var resident_state := state_for(state, npc_id)
    if int(resident_state.get("stage", 0)) < 1:
        return {"ok": false, "reason": "not-introduced"}
    if bool(resident_state.get("favor_completed", false)):
        return {"ok": false, "reason": "already-completed"}
    var definition := definition_for(npc_id)
    resident_state["stage"] = 2
    resident_state["favor_completed"] = true
    resident_state["completed_day"] = maxi(1, day)
    state[npc_id] = resident_state
    return {
        "ok": true,
        "resident_id": npc_id,
        "favor_id": str(definition.get("favor_id", "")),
        "name": str(definition.get("favor_name", "favor")),
        "cost": definition.get("cost", {}).duplicate(true),
        "reward": definition.get("reward", {}).duplicate(true)
    }

func claim_gift(state: Dictionary, npc_id: String, day: int) -> Dictionary:
    if not RESIDENT_DEFINITIONS.has(npc_id):
        return {"ok": false, "reason": "unknown-resident"}
    var resident_state := state_for(state, npc_id)
    var current_day := maxi(1, day)
    if int(resident_state.get("stage", 0)) < 2:
        return {"ok": false, "reason": "not-trusted"}
    if current_day <= maxi(int(resident_state.get("completed_day", 0)), int(resident_state.get("last_gift_day", 0))):
        return {"ok": false, "reason": "already-claimed"}
    var definition := definition_for(npc_id)
    resident_state["last_gift_day"] = current_day
    state[npc_id] = resident_state
    return {
        "ok": true,
        "resident_id": npc_id,
        "reward": definition.get("gift_reward", {}).duplicate(true),
        "text": str(definition.get("gift", "A small gift waits for you.")),
        "day": current_day
    }

func consequence_flags(state: Dictionary) -> Dictionary:
    return {
        "garden_bloom": bool(state_for(state, "alda-fen").get("favor_completed", false)),
        "forge_ember": bool(state_for(state, "tobin-wren").get("favor_completed", false)),
        "lane_markers": bool(state_for(state, "orin-reed").get("favor_completed", false))
    }

func dialogue_for(npc_id: String, state: Dictionary, context: Dictionary = {}) -> Dictionary:
    var definition := definition_for(npc_id)
    if definition.is_empty():
        return {}
    var resident_state := state_for(state, npc_id)
    var stage := clampi(int(resident_state.get("stage", 0)), 0, 2)
    var minute := posmod(int(context.get("minute", 8 * 60)), 1440)
    var moment := _moment_for(minute)
    var inventory = context.get("inventory", {})
    var fish_count := int(inventory.get("fish", 0)) if inventory is Dictionary else 0
    var current_day := maxi(1, int(context.get("day", 1)))
    var favor_ready := _has_cost(inventory, definition.get("cost", {}))
    var completed_day := int(resident_state.get("completed_day", 0))
    var last_gift_day := int(resident_state.get("last_gift_day", 0))
    var gift_ready := stage == 2 and current_day > maxi(completed_day, last_gift_day)
    var lines: Dictionary = definition.get("intro", {})
    var text := str(lines.get(moment, ""))
    if stage == 1:
        text = str(definition.get("ready", "")) if favor_ready else str(definition.get("pending", {}).get(moment, ""))
    elif stage == 2:
        text = str(definition.get("gift", "")) if gift_ready else str(definition.get("trusted", {}).get(moment, ""))
    text = _contextualize(text, str(context.get("location", "village")), bool(context.get("work_active", false)), stage)
    if npc_id == "orin-reed" and stage >= 1 and fish_count > 0:
        text += " Orin notices the fish in your pack and nods toward the water. The river has started to know you."
    return {
        "npc_id": npc_id,
        "speaker": str(definition.get("speaker", npc_id)),
        "text": text,
        "moment": moment,
        "location": str(context.get("location", "village")),
        "stage": stage,
        "favor_id": str(definition.get("favor_id", "")),
        "favor_name": str(definition.get("favor_name", "")),
        "favor_ready": favor_ready and stage == 1,
        "gift_ready": gift_ready,
        "gift_reward": definition.get("gift_reward", {}).duplicate(true),
        "favor_completed": bool(resident_state.get("favor_completed", false)),
        "cost": definition.get("cost", {}).duplicate(true),
        "reward": definition.get("reward", {}).duplicate(true)
    }

func to_dict(state: Dictionary) -> Dictionary:
    return from_dict(state)

func from_dict(source: Dictionary) -> Dictionary:
    var result := default_state()
    for resident_id in resident_ids():
        var raw = source.get(resident_id, {})
        if not raw is Dictionary:
            continue
        result[resident_id]["stage"] = clampi(int(raw.get("stage", 0)), 0, 2)
        result[resident_id]["favor_completed"] = bool(raw.get("favor_completed", false))
        if result[resident_id]["favor_completed"]:
            result[resident_id]["stage"] = 2
        result[resident_id]["introduced_day"] = maxi(0, int(raw.get("introduced_day", 0)))
        result[resident_id]["completed_day"] = maxi(0, int(raw.get("completed_day", 0)))
        result[resident_id]["last_gift_day"] = maxi(0, int(raw.get("last_gift_day", 0)))
    return result

func _moment_for(minute: int) -> String:
    return "morning" if minute < 12 * 60 else "day" if minute < 17 * 60 else "evening"

func _has_cost(inventory_variant, cost_variant) -> bool:
    if not inventory_variant is Dictionary or not cost_variant is Dictionary:
        return false
    var inventory: Dictionary = inventory_variant
    var cost: Dictionary = cost_variant
    for material_variant in cost.keys():
        var material := str(material_variant)
        if int(inventory.get(material, 0)) < int(cost[material_variant]):
            return false
    return true

func _contextualize(text: String, location: String, work_active: bool, stage: int) -> String:
    var prefix := ""
    if location == "greenbriar-cottage":
        prefix = "By the cottage hearth, "
    elif location == "tinker-workshop":
        prefix = "In the workroom, "
    elif work_active:
        prefix = "Between your work strokes, "
    if prefix.is_empty() or stage == 0:
        return text
    return prefix + text.to_lower()
