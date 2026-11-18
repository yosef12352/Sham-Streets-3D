extends RefCounted
class_name ShamSaveSystem

const SAVE_PATH := "user://sham_streets_save.json"
const SAVE_VERSION := 1

static func save_game(data: Dictionary) -> bool:
    var payload := {"version": SAVE_VERSION, "data": data}
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Unable to open save file")
        return false
    file.store_string(JSON.stringify(payload))
    file.close()
    return true

static func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        return {}
    if parsed.get("version", -1) != SAVE_VERSION:
        push_warning("Unsupported save version")
        return {}
    var data = parsed.get("data", {})
    return data if data is Dictionary else {}
