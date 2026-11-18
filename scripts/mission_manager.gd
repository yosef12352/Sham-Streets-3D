extends Node
class_name ShamMissionManager

signal mission_started(id: String)
signal mission_completed(id: String, reward: int)

var active_mission: String = ""
var objective_progress: int = 0
var objective_target: int = 0
var reward: int = 0

func start_mission(id: String, target: int, prize: int) -> bool:
    if not active_mission.is_empty() or id.is_empty() or target <= 0 or prize < 0:
        return false
    active_mission = id
    objective_target = target
    objective_progress = 0
    reward = prize
    mission_started.emit(id)
    return true

func advance(amount: int = 1) -> bool:
    if active_mission.is_empty() or amount <= 0:
        return false
    objective_progress = mini(objective_target, objective_progress + amount)
    return objective_progress >= objective_target

func claim(state: ShamGameState) -> bool:
    if active_mission.is_empty() or objective_progress < objective_target:
        return false
    var id := active_mission
    var prize := reward
    if not state.complete_mission(id, prize):
        return false
    active_mission = ""
    objective_progress = 0
    objective_target = 0
    reward = 0
    mission_completed.emit(id, prize)
    return true
