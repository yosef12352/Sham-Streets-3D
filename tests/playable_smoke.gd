extends SceneTree

const WORLD := preload("res://main.tscn")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _run() -> void:
    if "--isolated-save" not in OS.get_cmdline_user_args():
        push_error("Run with the isolated XDG data directory documented in README.md.")
        quit(2)
        return
    if FileAccess.file_exists(ShamSaveSystem.SAVE_PATH) or FileAccess.file_exists(ShamSaveSystem.BACKUP_PATH):
        push_error("The test requires an empty save directory.")
        quit(2)
        return
    var first := WORLD.instantiate()
    root.add_child(first)
    await frames(15)
    check(first.districts.blocks.size() > 0 and first.districts.blocks.size() < 64, "Only nearby buildings should spawn")
    var pedestrian := first.pedestrians.get_child(0) as CharacterBody3D
    check(pedestrian.position.z > 8.1, "Market pedestrians should walk their routes")
    check(first.player.is_on_floor(), "Player should settle on the road")
    first._jump()
    await frames(12)
    check(first.player.position.y > 1.3, "Jump should leave the ground")
    first.player.position = Vector3(-0.6, 1.0, 8.0)
    first._request_interaction()
    await frames(2)
    check(first.driving and first.car.driver_active, "Player should enter the nearby car")
    var start_z: float = first.car.position.z
    Input.action_press("ui_up")
    await frames(35)
    Input.action_release("ui_up")
    check(first.car.position.z < start_z - 0.7, "Driving input should move the car")
    first.braking = true
    await frames(45)
    first.braking = false
    check(absf(first.car.forward_speed) < 0.1, "Brake should stop the car")
    first._request_interaction()
    await frames(2)
    check(not first.driving and first.player.visible, "Player should exit the stopped car")
    first.player.position = first.PICKUP + Vector3.UP
    first._request_interaction()
    await frames(2)
    check(first.missions.active_mission == first.JOB, "Pickup should start delivery")
    first.queue_free()
    await process_frame
    var second := WORLD.instantiate()
    root.add_child(second)
    await frames(2)
    check(second.missions.active_mission == second.JOB, "Scene reload should recover the delivery")
    var old_block := Vector2i(1, 2)
    check(second.districts.blocks.has(old_block), "Block near the market should be loaded")
    second.player.position = second.DELIVERY + Vector3.UP
    second._request_interaction()
    await frames(2)
    check(second.state.money == 150, "Delivery should award 150")
    check(not second.districts.blocks.has(old_block), "Distant market blocks should unload")
    second._request_interaction()
    await frames(2)
    check(second.state.money == 150, "Delivery must award money only once")
    second.player.position = second.SHOP + Vector3.UP
    second._request_interaction()
    await frames(2)
    check(second.state.money == 100 and second.state.outfit_id == "market", "Shop should deduct 50 and equip the outfit")
    second.queue_free()
    await process_frame
    var third := WORLD.instantiate()
    root.add_child(third)
    await frames(2)
    check(third.state.money == 100 and third.state.outfit_id == "market", "Reload should preserve money and clothes")
    var corrupted := FileAccess.open(ShamSaveSystem.SAVE_PATH, FileAccess.WRITE)
    corrupted.store_string("{truncated")
    corrupted.close()
    check(ShamSaveSystem.load_game().get("money") == 150, "Corrupt current save should recover previous valid save")
    if failures == 0:
        print("PASS: streaming, pedestrians, movement, car, delivery, shop, reload and backup recovery")
    quit(failures)
