extends Node
class_name ShamGameState

signal money_changed(amount: int)
signal wanted_changed(level: int)
signal outfit_changed(outfit_id: String)

var money: int = 0
var wanted_level: int = 0
var outfit_id: String = "default"
var completed_missions: Array[String] = []

func earn_money(amount: int) -> void:
    if amount <= 0:
        return
    money += amount
    money_changed.emit(money)

func spend_money(amount: int) -> bool:
    if amount < 0 or money < amount:
        return false
    money -= amount
    money_changed.emit(money)
    return true

func set_wanted(level: int) -> void:
    wanted_level = clampi(level, 0, 5)
    wanted_changed.emit(wanted_level)

func set_outfit(id: String) -> void:
    if id.is_empty():
        return
    outfit_id = id
    outfit_changed.emit(id)

func complete_mission(id: String, reward: int) -> bool:
    if id.is_empty() or completed_missions.has(id) or reward < 0:
        return false
    completed_missions.append(id)
    earn_money(reward)
    return true

func to_dict() -> Dictionary:
    return {"money":money,"wanted_level":wanted_level,"outfit_id":outfit_id,"completed_missions":completed_missions}

func restore(data: Dictionary) -> void:
    money = maxi(0, int(data.get("money", 0)))
    wanted_level = clampi(int(data.get("wanted_level", 0)), 0, 5)
    outfit_id = str(data.get("outfit_id", "default"))
    completed_missions.clear()
    var missions = data.get("completed_missions", [])
    if missions is Array:
        for mission in missions:
            if mission is String and not completed_missions.has(mission):
                completed_missions.append(mission)
    money_changed.emit(money)
    wanted_changed.emit(wanted_level)
    outfit_changed.emit(outfit_id)
