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
    var traffic_z: float = third.road_response.traffic.position.z
    third.state.set_wanted(2)
    await frames(35)
    check(third.road_response.traffic.position.z > traffic_z + 0.5, "Traffic should move along the road")
    check(third.road_response.patrol.visible, "Wanted level should activate a patrol")
    third.road_response.remaining = 0.0
    await frames(2)
    check(third.state.wanted_level == 1, "Wanted level should decay")
    third.road_response.remaining = 0.0
    await frames(3)
    check(third.state.wanted_level == 0 and not third.road_response.patrol.visible, "Patrol should end at zero")
    check(third.pedestrians.get_child_count() == 32, "City should have thirty-two residents")
    check(third.car.get_node("Trim").get_child_count() >= 8, "Car trim should be attached")
    third.action_requested = "pulse"
    await frames(2)
    check(third.rounds == 7, "A shot should consume a round")
    check(third.person.launcher.visible and third.person.aim_weight > 0.8, "A shot should align the launcher and both arms")
    check(third.person.muzzle.global_position.distance_to(third.player.position) > 0.5, "Shot origin should be at the visible muzzle")
    third.action_requested = "pulse"
    await frames(2)
    check(third.rounds == 7, "Shot cooldown should prevent duplicate shots")
    await frames(27)
    third.action_requested = "reload"
    await frames(2)
    check(third.rounds == 8 and third.reserve == 23, "Reload should transfer reserve ammo")
    third._adjust_zoom(-10.0)
    check(is_equal_approx(third.zoom_scale, 0.48), "Camera zoom should clamp at the near limit")
    third._adjust_zoom(10.0)
    check(is_equal_approx(third.zoom_scale, 1.9), "Camera zoom should clamp at the far limit")
    await frames(12)
    check(third.current_zoom > 1.5, "Camera should move smoothly toward the zoom target")
    third.player.position = Vector3(-110, 1.0, -65)
    await frames(5)
    check(third.districts.blocks.has(Vector2i(-6, -3)), "Outer district should load when approached")
    check(third.pedestrians.get_child(14).visible, "Outer district should wake nearby residents")
    check(not third.pedestrians.get_child(0).visible, "Distant market residents should be hidden")
    check(third._save(), "Expanded district should be saveable")
    check(third._position_from_save(ShamSaveSystem.load_game().get("position"), Vector3.ZERO).x < -100.0, "Expanded coordinates should restore")
    third._toggle_map()
    check(third.map_layer.visible and not third.gameplay_ui.visible, "Map should replace game controls")
    third._select_district(2)
    check(third.navigation == 2 and third.minimap.navigation == 2 and not third.map_layer.visible, "Selecting Hanano should show the route in the HUD")
    check(third.current_district == 3, "West side should be identified as Maysaloun")
    check(third.road_response.local_traffic.size() == 3, "Satellite roads should have AI traffic")
    var corrupted := FileAccess.open(ShamSaveSystem.SAVE_PATH, FileAccess.WRITE)
    corrupted.store_string("{truncated")
    corrupted.close()
    check(ShamSaveSystem.load_game().get("money") == 100, "Corrupt current save should recover previous valid save")
    if failures == 0:
        print("PASS: streaming, pedestrians, traffic, patrol, movement, car, delivery, shop, reload and backup recovery")
    third.queue_free()
    await process_frame
    quit(failures)
