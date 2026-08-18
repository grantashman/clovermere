extends RefCounted
class_name ClovermereInteriorContract

const TILE_SIZE := 16.0
const TRANSITION_SECONDS := 0.18

const INTERIOR_DEFINITIONS := {
    "greenbriar-cottage": {
        "location": "greenbriar-cottage",
        "name": "Greenbriar Cottage · Hearth Room",
        "short_name": "Greenbriar Cottage",
        "width": 18,
        "height": 12,
        "spawn": Vector2(9.0, 9.0),
        "exit": Vector2i(9, 10),
        "wall_color": "#6f5039",
        "floor_color": "#b88a5e",
        "rug_color": "#80614e",
        "interactions": [
            {"id": "hearth", "name": "Hearth", "x": 4, "y": 5, "action": "rest"},
            {"id": "bed", "name": "Bed", "x": 14, "y": 3, "action": "sleep"},
            {"id": "storage-chest", "name": "Storage Chest", "x": 8, "y": 9, "action": "storage"},
            {"id": "pantry", "name": "Hearth Pantry", "x": 12, "y": 7, "action": "cook"}
        ]
    },
    "clovermere-hall": {
        "location": "clovermere-hall",
        "name": "Clovermere Hall · Common Room",
        "short_name": "Clovermere Hall",
        "width": 18,
        "height": 12,
        "spawn": Vector2(9.0, 9.0),
        "exit": Vector2i(9, 10),
        "wall_color": "#80644b",
        "floor_color": "#aa8259",
        "rug_color": "#6c6954",
        "interactions": [
            {"id": "notice-board", "name": "Notice Board", "x": 4, "y": 4, "action": "requests"},
            {"id": "town-table", "name": "Town Table", "x": 9, "y": 5, "action": "project"},
            {"id": "village-records", "name": "Village Records", "x": 14, "y": 4, "action": "inspect"}
        ]
    },
    "herbalists-garden": {
        "location": "herbalists-garden",
        "name": "Herbalist's Garden · Glasshouse",
        "short_name": "Herbalist's Garden",
        "width": 20,
        "height": 13,
        "spawn": Vector2(10.0, 10.0),
        "exit": Vector2i(10, 11),
        "wall_color": "#637456",
        "floor_color": "#839268",
        "rug_color": "#617351",
        "interactions": [
            {"id": "seed-table", "name": "Seed Table", "x": 6, "y": 5, "action": "inspect"},
            {"id": "drying-rack", "name": "Drying Rack", "x": 15, "y": 4, "action": "inspect"},
            {"id": "herb-bench", "name": "Herb Bench", "x": 8, "y": 8, "action": "inspect"}
        ]
    },
    "old-barn": {
        "location": "old-barn",
        "name": "Old Barn · Loft",
        "short_name": "Old Barn",
        "width": 20,
        "height": 13,
        "spawn": Vector2(10.0, 10.0),
        "exit": Vector2i(10, 11),
        "wall_color": "#754f3f",
        "floor_color": "#9b704d",
        "rug_color": "#655043",
        "interactions": [
            {"id": "hay-loft", "name": "Hay Loft", "x": 5, "y": 4, "action": "inspect"},
            {"id": "feed-bench", "name": "Feed Bench", "x": 10, "y": 5, "action": "inspect"},
            {"id": "tack-wall", "name": "Tack Wall", "x": 15, "y": 4, "action": "inspect"}
        ]
    },
    "tinker-workshop": {
        "location": "tinker-workshop",
        "name": "Tinker Workshop · Workroom",
        "short_name": "Tinker Workshop",
        "width": 20,
        "height": 13,
        "spawn": Vector2(10.0, 10.0),
        "exit": Vector2i(10, 11),
        "wall_color": "#5b4939",
        "floor_color": "#97704d",
        "rug_color": "#5b5543",
        "interactions": [
            {"id": "workbench", "name": "Workbench", "x": 7, "y": 5, "action": "craft"},
            {"id": "forge", "name": "Forge", "x": 11, "y": 5, "action": "forge"},
            {"id": "tool-rack", "name": "Tool Rack", "x": 16, "y": 3, "action": "inspect"}
        ]
    }
}

const DIALOGUE_LINES := {
    "alda-fen": {
        "speaker": "Alda Fen",
        "morning": "The foxglove likes a patient hand. Bring what you gather home before the dew is gone.",
        "day": "The garden is generous when we leave a little room for it to breathe.",
        "evening": "The paths look kinder at dusk. Mind the stones, and keep a little energy for the walk home."
    },
    "tobin-wren": {
        "speaker": "Tobin Wren",
        "morning": "A good tool begins with a good plan. The workshop can make the road less tiring.",
        "day": "Bring the right materials and I can make something that lasts beyond one season.",
        "evening": "The forge is banked for the night. Tomorrow, we can make the next useful thing."
    },
    "orin-reed": {
        "speaker": "Orin Reed",
        "morning": "The eastern lane is clear. Clovermere is waking one footstep at a time.",
        "day": "If you find a place worth keeping, mark the path and come back before dark.",
        "evening": "Lanterns first, questions after. The village knows its way home."
    }
}

func location_ids() -> Array[String]:
    return ["greenbriar-cottage", "clovermere-hall", "tinker-workshop", "herbalists-garden", "old-barn"]

func transition_seconds() -> float:
    return TRANSITION_SECONDS

func definition_for(building_id: String) -> Dictionary:
    var definition = INTERIOR_DEFINITIONS.get(building_id, {})
    return definition.duplicate(true) if definition is Dictionary else {}

func is_interior(location_id: String) -> bool:
    return INTERIOR_DEFINITIONS.has(location_id)

func build_grid(location_id: String) -> Array:
    var definition := definition_for(location_id)
    if definition.is_empty():
        return []
    var width := int(definition.get("width", 0))
    var height := int(definition.get("height", 0))
    var grid: Array = []
    for y in height:
        var row: Array = []
        for x in width:
            row.append("#" if x == 0 or y == 0 or x == width - 1 or y == height - 1 else ".")
        grid.append(row)
    for furniture in definition.get("interactions", []):
        if not furniture is Dictionary:
            continue
        var tile := Vector2i(int(furniture.x), int(furniture.y))
        if tile != definition.get("exit", Vector2i(-1, -1)) and _inside(grid, tile.x, tile.y):
            grid[tile.y][tile.x] = "f"
    var exit_tile: Vector2i = definition.get("exit", Vector2i.ZERO)
    if _inside(grid, exit_tile.x, exit_tile.y):
        grid[exit_tile.y][exit_tile.x] = "."
    return grid

func is_walkable(grid: Array, tile: Vector2i) -> bool:
    if not _inside(grid, tile.x, tile.y):
        return false
    return str(grid[tile.y][tile.x]) not in ["#", "f"]

func spawn_position(location_id: String) -> Vector2:
    return definition_for(location_id).get("spawn", Vector2.ZERO)

func exit_tile(location_id: String) -> Vector2i:
    return definition_for(location_id).get("exit", Vector2i.ZERO)

func interaction_ids(location_id: String) -> Array[String]:
    var result: Array[String] = []
    for interaction in definition_for(location_id).get("interactions", []):
        if interaction is Dictionary:
            result.append(str(interaction.get("id", "")))
    return result

func interaction_at(location_id: String, tile: Vector2i) -> Dictionary:
    for interaction in definition_for(location_id).get("interactions", []):
        if interaction is Dictionary and Vector2i(int(interaction.x), int(interaction.y)) == tile:
            return interaction.duplicate(true)
    return {}

func nearest_interaction(location_id: String, position: Vector2, radius: float = 1.7) -> Dictionary:
    var best := {}
    var best_distance := radius
    for interaction in definition_for(location_id).get("interactions", []):
        if not interaction is Dictionary:
            continue
        var distance := position.distance_to(Vector2(int(interaction.x) + 0.5, int(interaction.y) + 0.5))
        if distance <= best_distance:
            best_distance = distance
            best = interaction.duplicate(true)
    return best

func enter_state(building_id: String) -> Dictionary:
    if not is_interior(building_id):
        return {"location": "village", "transition": "none", "interior": {}}
    return {"location": building_id, "transition": "enter", "interior": {"building_id": building_id}}

func exit_state() -> Dictionary:
    return {"location": "village", "transition": "exit", "interior": {}}

func dialogue_for(npc_id: String, _location_id: String, minute_of_day: int) -> Dictionary:
    var lines = DIALOGUE_LINES.get(npc_id, {})
    if not lines is Dictionary or lines.is_empty():
        return {}
    var minute := posmod(minute_of_day, 1440)
    var moment := "morning" if minute < 12 * 60 else "day" if minute < 17 * 60 else "evening"
    return {"speaker": str(lines.get("speaker", npc_id)), "text": str(lines.get(moment, "")), "moment": moment, "npc_id": npc_id}

func _inside(grid: Array, x: int, y: int) -> bool:
    return y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size()
