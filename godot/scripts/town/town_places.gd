extends Node

## The other wardens' doings in Liblice's places, everyone's to everyone
## (Coop.send_place("town", key, op, data): this node is the group "places_town"), handed
## to town_trip.coop_town_place (town_trip's own coop_place says where you are).

var trip


func _ready() -> void:
	add_to_group("places_town")


func coop_place(key: String, op: String, data: Array) -> void:
	if trip != null and is_instance_valid(trip):
		trip.coop_town_place(key, op, data)
