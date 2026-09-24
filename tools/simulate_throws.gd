extends SceneTree
## Throw simulator: runs many throws at realistic game distance (not
## artificially placed close-range targets, unlike the throwaway
## verification scripts used during development) and reports contact-rate,
## score-rate, and settle-time statistics, so throwing-physics changes can
## be evaluated headlessly and repeatably instead of relying on manual
## playtesting after every tweak.
##
## Usage:
##   godot --headless --path . --script tools/simulate_throws.gd -- [count]
## (default count: 16, comfortably within one half's 10-karttu-per-side
## budget so turn/half rollover doesn't need special handling)
##
## Spreads gauge (spin timing) across the full 0-180 range across the
## requested throws. Each throw points the camera (yaw and pitch, the way
## a player aims — see ThrowController._aim_distance()) at the outermost
## kyykkä still standing, not dead center: the pesä is a full 5x5m
## square, and a piece hit dead center has to travel the whole 4.85m
## remaining depth to register as a rules-engine score, which even a
## solid mechanical hit often can't manage — that's a property of the
## scoring rules, not the physics. Outer stacks sit only ~0.25m from the
## side boundary, so a real connection there reliably registers as a
## score. Re-picking the target every throw matters: aiming at one fixed
## spot kept throwing at empty ground once the first hit cleared it.
##
## "contact" (did the karttu physically move a piece at all) and "scored"
## (did that movement cross a rules-engine zone boundary) are tracked and
## reported separately — contact is the more sensitive signal for
## catching a collision/tunneling regression specifically.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := 16
	if args.size() > 0:
		count = int(args[0])

	var court := preload("res://scenes/court.tscn").instantiate()
	get_root().add_child(court)
	await create_timer(0.3).timeout

	var mc: MatchController = court.get_node("MatchController")
	var thrower: ThrowController = mc.thrower

	var contacts := 0
	var scores := 0
	var settle_frames: Array[int] = []
	var timeout_frames := int(thrower.settle_timeout_seconds * 60.0)
	var timed_out := 0

	for i in range(count):
		if not thrower.enabled:
			print("match ended early at throw %d/%d, stopping" % [i + 1, count])
			break

		var gauge: float = lerp(10.0, 170.0, float(i) / maxf(count - 1, 1))
		var attack := mc.current_attack
		var target_view: PesaView = mc.far_pesa_view if attack == mc.current_half.attack_by_team_a else mc.near_pesa_view
		var before_in_square := attack.pesa.in_square
		var before_on_line := attack.pesa.on_line
		var before_removed := attack.pesa.removed
		var before_positions: Dictionary = {}
		for piece in target_view.get_children():
			before_positions[piece] = piece.global_position

		var target_piece := _outermost_standing(target_view)
		if target_piece == null:
			print("no standing kyykkä left to aim at, stopping")
			break
		_aim_at(thrower, target_piece.global_position)
		var start_ms := Time.get_ticks_msec()
		thrower._throw(gauge)
		await thrower.throw_settled
		var frame_count := int((Time.get_ticks_msec() - start_ms) / (1000.0 / 60.0))

		var max_displacement := 0.0
		for piece in before_positions.keys():
			if not is_instance_valid(piece):
				continue
			max_displacement = maxf(max_displacement, piece.global_position.distance_to(before_positions[piece]))
		var contacted := max_displacement > 0.05
		var scored := (
			attack.pesa.in_square != before_in_square
			or attack.pesa.on_line != before_on_line
			or attack.pesa.removed != before_removed
		)
		if contacted:
			contacts += 1
		if scored:
			scores += 1
		settle_frames.append(frame_count)
		if frame_count >= timeout_frames:
			timed_out += 1
			print("  [timeout diag] karttu: sleeping=%s pos=%s lin_v=%s ang_v=%s freeze=%s" % [
				thrower._karttu.sleeping, thrower._karttu.global_position,
				thrower._karttu.linear_velocity, thrower._karttu.angular_velocity,
				thrower._karttu.freeze,
			])
			var awake_pieces := 0
			for piece in mc.near_pesa_view.get_children():
				if not piece.sleeping:
					awake_pieces += 1
			for piece in mc.far_pesa_view.get_children():
				if not piece.sleeping:
					awake_pieces += 1
			print("  [timeout diag] awake kyykka across both pesas: %d" % awake_pieces)

		print("throw %d/%d: gauge=%3.0f frames=%3d contact=%s (max_disp=%.2fm) scored=%s (in_square %d->%d, on_line %d->%d, removed %d->%d)" % [
			i + 1, count, gauge, frame_count, contacted, max_displacement, scored,
			before_in_square, attack.pesa.in_square,
			before_on_line, attack.pesa.on_line,
			before_removed, attack.pesa.removed,
		])

	print("\n--- summary ---")
	var thrown := settle_frames.size()
	print("contacts: %d/%d (%.0f%%)" % [contacts, thrown, 100.0 * contacts / maxf(thrown, 1)])
	print("scored:   %d/%d (%.0f%%)" % [scores, thrown, 100.0 * scores / maxf(thrown, 1)])
	if thrown > 0:
		var total := 0
		for f in settle_frames:
			total += f
		print("avg settle frames: %.1f (%.2fs)" % [float(total) / thrown, float(total) / thrown / 60.0])
	print("hit settle_timeout_seconds cap: %d/%d" % [timed_out, thrown])
	quit()


func _outermost_standing(view: PesaView) -> Node3D:
	var best: Node3D = null
	for piece in view.get_children():
		# Still upright (a toppled kyykkä's centre sits lower) and still
		# inside the square's width.
		if piece.global_position.y < 0.042 or absf(piece.global_position.x) > view.pesa_half_width:
			continue
		if best == null or absf(piece.global_position.x) > absf(best.global_position.x):
			best = piece
	return best


## Sets yaw and camera pitch so the look ray crosses aim_target_height
## exactly at `point`, i.e. what a player lining the crosshair up on it gets.
func _aim_at(thrower: ThrowController, point: Vector3) -> void:
	var offset := point - thrower.global_position
	offset.y = 0.0
	thrower._yaw_degrees = rad_to_deg(thrower._forward_direction.signed_angle_to(offset, Vector3.UP))
	var drop := thrower.camera_height - thrower.aim_target_height
	thrower._elevation_degrees = -rad_to_deg(atan(drop / (offset.length() + thrower.camera_back_offset)))
