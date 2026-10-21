extends "res://tools/coop_check.gd"

## The rowing boat for two (scripts/lake/lake_trip.gd, boat_rig.gd): a host and a joining
## copy on this machine (run by tools/boat_coop.py).
##   - the joining warden rows out alone: on the host's lake the boat goes with them in it,
##     its oars stroking (the host watches from the jetty);
##   - the host rows, the other climbs into the bow: each machine has them in the boat,
##     face to face;
##   - alongside the keeper's jetty: both ashore, each on their own spot of it;
##   - the host rows back: the other is in the bow again; home, both out.
## Each side's evals are tagged ["BOAT <role> <tag>", ...] in its log for the runner.
##   godot --path godot res://tools/boat_coop.tscn -- --role=host --out=DIR

const LAKE := "_lake_trip._lake_node()"
const BY_BOAT := "_player.set('global_position', _lake_trip._lake_node().boat_home.origin + Vector3(-1.6, 0.6, 0.6))"
const TO_FAR := "_lake_trip._lake_node().boat.set('global_position', _lake_trip._lake_node().far_jetty_end + Vector3(1.2, -0.48, -8.0))"
const RIG := "_lake_trip._lake_node().boat.get_node('BoatRig')"


func _burst(name: String, n: int, dt: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(["shot", "%s_%d" % [name, i]])
		out.append(["wait", dt])
	return out


func _ready() -> void:
	super._ready()
	var s: Array
	if _role == "host":
		s = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["eval", "debug_jump_to(1, 10.5)"], ["wait", 1.0],
			["coop_at_boat"], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"], ["coop_wait_file", "client_ready"], ["wait", 1.0],
			# The other rows out alone; the host watches from the jetty.
			["coop_at_boat"], ["coop_signal", "host_watching"],
			["coop_wait_file", "client_rowing"], ["wait", 0.5], ["boat_tag", "stroking"], ["boat_tag", "pose"]]
		s.append_array(_burst("h1_other_rows", 6, 0.3))
		s.append_array([
			["eval", "['BOAT host away', " + LAKE + ".boat.global_position.distance_to(" + LAKE + ".boat_home.origin)]"],
			["coop_wait_file", "client_rowed"], ["wait", 2.0], ["shot", "h2_back_home"],
			# The host rows; the other climbs into the bow.
			["eval", BY_BOAT], ["wait", 0.5], ["eval", "_lake_trip.try_interact()"], ["wait", 1.2], ["coop_signal", "host_in_boat"],
			["coop_wait_file", "client_in_bow"], ["wait", 1.5], ["shot", "h3_passenger_in_bow"],
			["boat_tag", "rider"],
			["keyhold", "W", true], ["wait", 2.0]])
		s.append_array(_burst("h4_rowing_with", 3, 0.5))
		s.append_array([["keyhold", "W", false],
			["eval", TO_FAR], ["eval", "_lake_trip.set('_yaw', 0.0)"], ["keyhold", "W", true], ["wait", 2.5], ["keyhold", "W", false], ["wait", 9.0],
			["shot", "h5_far_shore"], ["eval", "['BOAT host far', _lake_trip._state]"],
			["coop_signal", "host_far"], ["coop_wait_file", "client_far_seen"],
			["eval", "_lake_trip._look.set('yaw_deg', 40.0)"], ["wait", 1.0], ["shot", "h6_far_look"],
			["eval", "_lake_trip._look.set('yaw_deg', 0.0)"],
			["eval", "_lake_trip._start_rowing('camp')"], ["wait", 1.6], ["shot", "h7_back_in"], ["coop_signal", "host_back_in"],
			["coop_wait_file", "client_back_in"], ["wait", 1.0],
			["eval", "_lake_trip.return_home()"], ["wait", 2.0], ["shot", "h8_home"], ["coop_signal", "host_home"],
			["coop_wait_file", "client_done"], ["eval", "['BOAT host end', _lake_trip.is_active()]"], ["wait", 1.0]])
	else:
		s = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["eval", BY_BOAT], ["coop_signal", "client_ready"],
			["coop_wait_file", "host_watching"],
			["eval", "_lake_trip.try_interact()"], ["wait", 1.0], ["keyhold", "W", true], ["wait", 3.0], ["coop_signal", "client_rowing"], ["wait", 4.0], ["shot", "c1_rowing"],
			["keyhold", "W", false], ["wait", 1.0],
			["eval", "_lake_trip.return_home()"], ["wait", 1.5], ["coop_signal", "client_rowed"],
			# In the bow of the host's boat.
			["eval", BY_BOAT], ["coop_wait_file", "host_in_boat"], ["wait", 1.0],
			["eval", "['BOAT client hint', _lake_trip.hint()]"], ["eval", "_lake_trip.try_interact()"], ["wait", 1.6], ["shot", "c2_in_bow"],
			["eval", "['BOAT client bow', _lake_trip._state]"], ["coop_signal", "client_in_bow"]]
		s.append_array(_burst("c3_ride", 4, 0.6))
		s.append_array([["coop_wait_file", "host_far"], ["wait", 1.5], ["shot", "c4_far"],
			["eval", "['BOAT client far', _lake_trip._state]"],
			["eval", "['BOAT client apart', _lake_trip._cam.global_position.distance_to(" + LAKE + ".far_view)]"],
			["eval", "_lake_trip._look.set('yaw_deg', 180.0)"], ["wait", 1.0], ["shot", "c4b_far_look_back"], ["eval", "_lake_trip._look.set('yaw_deg', 0.0)"],
			["coop_signal", "client_far_seen"],
			["coop_wait_file", "host_back_in"], ["wait", 1.8], ["shot", "c5_back_in"], ["eval", "['BOAT client back', _lake_trip._state]"], ["coop_signal", "client_back_in"],
			["coop_wait_file", "host_home"], ["wait", 2.5], ["shot", "c6_home"],
			["eval", "['BOAT client end', _lake_trip.is_active()]"], ["coop_signal", "client_done"], ["wait", 1.0]])
	_steps = s


## A fact for the runner, worked out here (an eval does not reach the autoloads).
func _run_step(step: Array) -> void:
	if str(step[0]) != "boat_tag":
		super._run_step(step)
		return
	var tag := str(step[1])
	var lake = get_tree().root.find_child("CampLake", true, false)
	var rig = (lake.get("boat") as Node).get_node_or_null("BoatRig") if lake != null else null
	var other: Node3D = Coop.remote_figure()
	var v: Variant = null
	match tag:
		"stroking":
			# Watched a few frames: one oar or the other in a stroke.
			v = false
			if rig != null:
				for o in rig.get("_oars"):
					if float(o["u"]) >= 0.0:
						v = true
		"pose":
			v = str(other.get("pose")) if other != null else ""
		"rider":
			v = other.global_position.distance_to(rig.seat_xf(rig.BOW_FEET).origin) if other != null and rig != null else 99.0
	print("SHOT DRIVER eval: ", tag, " -> ", ["BOAT %s %s" % [_role, tag], v])
