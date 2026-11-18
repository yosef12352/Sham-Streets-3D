extends Node
class_name ShamGameplayController

signal hud_changed(money: int, wanted: int, mission: String)

var state: ShamGameState
var missions: ShamMissionManager

func _ready() -> void:
    state = ShamGameState.new()
    add_child(state)
    missions = ShamMissionManager.new()
    add_child(missions)
    state.restore(ShamSaveSystem.load_game())
    state.money_changed.connect(_emit_hud)
    state.wanted_changed.connect(_emit_hud)
    missions.mission_started.connect(_emit_mission)
    missions.mission_completed.connect(_mission_completed)
    _emit_hud()

func begin_delivery() -> bool:
    if state.completed_missions.has("first_delivery"):
        return false
    var ok := missions.start_mission("first_delivery", 3, 250)
    if ok:
        _emit_hud()
    return ok

func delivery_checkpoint() -> bool:
    if missions.active_mission != "first_delivery":
        return false
    var completed := missions.advance()
    if completed and missions.claim(state):
        save()
    _emit_hud()
    return true

func add_wanted_level(amount: int = 1) -> void:
    state.set_wanted(state.wanted_level + amount)

func buy_outfit(id: String, cost: int) -> bool:
    if id.is_empty() or cost < 0 or not state.spend_money(cost):
        return false
    state.set_outfit(id)
    save()
    return true

func save() -> bool:
    return ShamSaveSystem.save_game(state.to_dict())

func _emit_mission(_id: String) -> void:
    _emit_hud()

func _mission_completed(_id: String, _reward: int) -> void:
    _emit_hud()

func _emit_hud(_unused: int = 0) -> void:
    hud_changed.emit(state.money, state.wanted_level, missions.active_mission)
