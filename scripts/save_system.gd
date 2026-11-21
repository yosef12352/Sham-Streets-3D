extends RefCounted
class_name ShamSaveSystem

const SAVE_PATH := "user://sham_streets_save.json"
const SAVE_VERSION := 2
const TEMP_PATH := SAVE_PATH + ".tmp"
const BACKUP_PATH := SAVE_PATH + ".bak"

static func save_game(data: Dictionary) -> bool:
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"version": SAVE_VERSION, "data": data}))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK or _read(TEMP_PATH) == null:
        return false
    if _read(SAVE_PATH) != null:
        if DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH) != OK:
            return false
    return DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) == OK

static func load_game() -> Dictionary:
    for path in [SAVE_PATH, BACKUP_PATH]:
        var payload: Variant = _read(path)
        if payload is Dictionary:
            return payload["data"]
    return {}

static func _read(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var json := JSON.new()
    if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
        return null
    var parsed: Dictionary = json.data
    var version: Variant = parsed.get("version")
    if (version == 1 or version == SAVE_VERSION) and parsed.get("data") is Dictionary:
        return parsed
    return null
