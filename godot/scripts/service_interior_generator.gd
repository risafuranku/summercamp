extends "res://scripts/service_interior.gd"


# The generator shed has its own room (service_interior.gd _build_generator_layout):
# brick and concrete, the diesel set, fuel drums.
func _profile_for_service(service_type: String) -> String:
	if service_type == "power_generator":
		return "generator"
	return super._profile_for_service(service_type)
