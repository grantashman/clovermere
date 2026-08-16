extends RefCounted
class_name ClovermereWorkAction

var status := "idle"
var progress := 0.0
var elapsed_minutes := 0.0
var duration_minutes := 0.0
var resource: Dictionary = {}
var day_state
var result: Dictionary = {}

func start(resource_definition: Dictionary, state) -> Dictionary:
    if status == "working":
        return {"ok": false, "reason": "already-working"}
    var preview: Dictionary = state.preview_work(resource_definition) if state != null else {"ok": false, "reason": "missing-day-state"}
    if not bool(preview.get("ok", false)):
        return preview
    resource = resource_definition.duplicate(true)
    day_state = state
    duration_minutes = maxf(0.1, float(preview.get("minutes", 0)))
    elapsed_minutes = 0.0
    progress = 0.0
    result = {}
    status = "working"
    return {
        "ok": true,
        "kind": str(resource.get("kind", "resource")),
        "minutes": int(preview.get("minutes", 0)),
        "energy": int(preview.get("energy", 0)),
        "amount": int(preview.get("amount", 0)),
        "yield": str(preview.get("yield", resource.get("yield", "materials")))
    }

func advance(minutes: float) -> void:
    if status != "working" or minutes <= 0.0:
        return
    elapsed_minutes = minf(duration_minutes, elapsed_minutes + minutes)
    progress = clampf(elapsed_minutes / duration_minutes, 0.0, 1.0)
    if progress >= 1.0:
        complete()

func complete() -> Dictionary:
    if status != "working":
        return result
    result = day_state.work_resource(resource) if day_state != null else {"ok": false, "reason": "missing-day-state"}
    if bool(result.get("ok", false)):
        status = "completed"
        progress = 1.0
    else:
        status = "cancelled"
    return result

func cancel() -> void:
    if status == "working":
        status = "cancelled"

func is_active() -> bool:
    return status == "working"
