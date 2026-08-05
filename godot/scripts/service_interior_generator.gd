extends "res://scripts/service_interior.gd"


# Generator currently reuses the sewer interior 1:1.
func _profile_for_service(service_type: String) -> String:
	if service_type == "power_generator":
		return "sewer"
	return super._profile_for_service(service_type)
