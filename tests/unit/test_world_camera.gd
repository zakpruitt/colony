extends GutTest
## Unit tests for WorldCamera details the acceptance test does not pin down.

const STEP: float = 1.0 / 60.0


func _camera() -> WorldCamera:
	var camera := WorldCamera.new()
	add_child_autofree(camera)
	return camera


func test_snap_rounds_to_whole_pixels() -> void:
	var camera: WorldCamera = _camera()
	camera.snap_to(Vector2(400.4, 200.6))
	assert_eq(camera.position, Vector2(400, 201))
	assert_eq(camera.target, Vector2(400.4, 200.6), "the target is kept exactly")


func test_weaker_shake_does_not_cut_a_stronger_one_short() -> void:
	var camera: WorldCamera = _camera()
	camera.snap_to(Vector2(960, 300))
	camera.shake(10.0)
	camera.shake(1.0)
	var biggest: float = 0.0
	for i: int in 5:
		camera._process(STEP)
		biggest = maxf(biggest, maxf(absf(camera.offset.x), absf(camera.offset.y)))
	assert_gt(biggest, 1.0, "the strong shake is still running")


func test_offset_without_shake_is_zero() -> void:
	var camera: WorldCamera = _camera()
	camera.snap_to(Vector2(960, 300))
	camera.target = Vector2(1000, 320)
	for i: int in 30:
		camera._process(STEP)
		assert_eq(camera.offset, Vector2.ZERO)
