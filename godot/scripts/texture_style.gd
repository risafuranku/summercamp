extends RefCounted
class_name TextureStyle

const TEXTURE_ROOT_PRIMARY := "res://assets/textury/redneck"
const TEXTURE_ROOT_SECONDARY := "res://assets/textury/redneck"
const TEXTURE_ROOT_SECONDARY_ALIAS := "res://assets/textury/redneck"
const TEXTURE_ROOTS := [TEXTURE_ROOT_PRIMARY, TEXTURE_ROOT_SECONDARY, TEXTURE_ROOT_SECONDARY_ALIAS]
const SUPPORTED_EXT := ["png", "jpg", "jpeg", "webp", "bmp", "tga", "exr", "hdr"]

# Curated virtual folders/tags for stable texture assignment.
const CATEGORY_OVERRIDES := {
	"grass": ["grass.png", "RRTX0296.png", "RRTX0292.png", "RRTX0606.png"],
	"foliage": ["RRTX0283.png", "RRTX0284.png", "RRTX0285.png", "RRTX0296.png"],
	"water": ["RRTX0203.png", "RRTX0205.png"],
	"wood": ["RRTX0111.png", "RRTX0242.png", "RRTX0198.png", "RRTX0600.png", "RRTX0458.png", "RRTX0599.png"],
	"brick": ["RRTX0610.png", "RRTX0544.png", "RRTX0293.png", "RRTX0294.png", "RRTX0295.png"],
	"stone": ["RRTX0606.png", "RRTX0597.png", "RRTX0292.png", "RRTX0380.png", "RRTX0381.png"],
	"metal": ["RRTX0556.png", "RRTX0557.png", "RRTX0581.png", "RRTX0475.png", "RRTX0478.png", "RRTX0609.png"],
	"road": ["RRTX0606.png", "RRTX0597.png", "RRTX0292.png", "RRTX0242.png"],
	"roof": ["strechy/strecha.png", "zdi/plechy.png", "RRTX0141.png"],
	"paper": ["RRTX0102.png", "RRTX0123.png", "RRTX0103.png"],
	"fabric": ["RRTX0246.png", "RRTX0247.png", "RRTX0248.png", "RRTX0249.png", "RRTX0250.png"],
	"wall": ["RRTX0610.png", "RRTX0544.png", "RRTX0293.png", "RRTX0242.png", "RRTX0111.png", "RRTX0606.png"],
	"floor": ["RRTX0606.png", "RRTX0597.png", "RRTX0292.png", "RRTX0242.png", "RRTX0111.png", "RRTX0246.png"],
	"decor": ["RRTX0242.png", "RRTX0111.png", "RRTX0246.png", "RRTX0247.png", "RRTX0102.png", "RRTX0123.png", "RRTX0556.png"],
	"decor_wood": ["RRTX0242.png", "RRTX0111.png", "RRTX0198.png", "RRTX0458.png"],
	"decor_fabric": ["RRTX0246.png", "RRTX0247.png", "RRTX0248.png", "RRTX0249.png", "RRTX0250.png"],
	"decor_metal": ["RRTX0556.png", "RRTX0557.png", "RRTX0581.png", "RRTX0475.png"],
	"decor_paper": ["RRTX0102.png", "RRTX0123.png", "RRTX0103.png"],
	"glass": ["RRTX0203.png", "RRTX0205.png", "RRTX0556.png"],
	"tree_bark": ["RRTX0122.png", "RRTX0198.png", "RRTX0242.png"],
	"tree_canopy": ["RRTX0031.png"],
	"cabin_lv1_exterior_wall": ["RRTX0293.png", "RRTX0294.png", "RRTX0610.png"],
	"cabin_lv1_exterior_wood": ["RRTX0294.png", "RRTX0293.png"],
	"cabin_lv1_exterior_roof": ["zdi/plechy.png"],
	"cabin_lv1_exterior_stone": ["RRTX0606.png"],
	"cabin_lv2_exterior_wall": ["RRTX0294.png", "RRTX0295.png", "RRTX0610.png"],
	"cabin_lv2_exterior_wood": ["RRTX0295.png", "RRTX0294.png"],
	"cabin_lv2_exterior_roof": ["zdi/plechy.png"],
	"cabin_lv2_exterior_stone": ["RRTX0597.png"],
	"cabin_lv3_exterior_wall": ["RRTX0295.png", "zdi/RRTX0612.png", "RRTX0610.png"],
	"cabin_lv3_exterior_wood": ["RRTX0295.png", "RRTX0294.png"],
	"cabin_lv3_exterior_roof": ["zdi/plechy.png"],
	"cabin_lv3_exterior_stone": ["RRTX0597.png"],
	"cabin_lv1_wall": ["zdi/RRTX1163.png", "drevo/RRTX0937.png"],
	"cabin_lv1_floor": ["drevo/RRTX0937.png"],
	"cabin_lv1_wood": ["drevo/RRTX0937.png"],
	"cabin_lv1_fabric": ["RRTX0246.png"],
	"cabin_lv1_bed": ["RRTX0247.png"],
	"cabin_lv1_metal": ["RRTX0556.png"],
	"cabin_lv2_wall": ["zdi/RRTX1164.png", "drevo/RRTX0936.png"],
	"cabin_lv2_floor": ["drevo/RRTX0936.png"],
	"cabin_lv2_wood": ["drevo/RRTX0936.png"],
	"cabin_lv2_drawer": ["RRTX0085.png"],
	"cabin_lv2_fabric": ["RRTX0248.png"],
	"cabin_lv2_bed": ["RRTX0249.png"],
	"cabin_lv2_metal": ["RRTX0557.png"],
	"cabin_lv3_wall": ["zdi/RRTX1169.png", "drevo/RRTX1248.png"],
	"cabin_lv3_floor": ["drevo/RRTX1248.png"],
	"cabin_lv3_wood": ["drevo/RRTX1248.png"],
	"cabin_lv3_drawer": ["RRTX0085.png"],
	"cabin_lv3_fabric": ["RRTX0250.png"],
	"cabin_lv3_bed": ["RRTX0246.png"],
	"cabin_lv3_metal": ["RRTX0581.png"],
	"office_wall": ["zdi/RRTX0670.png"],
	"office_wall_dim": ["zdi/RRTX0655.png"],
	"office_wall_near_light": ["zdi/RRTX0654.png"],
	"office_floor_scatter_26": ["RRTX0026.png"],
	"office_floor_scatter_27": ["RRTX0027.png"],
	"office_shelf": ["RRTX0082.png"],
	"office_drawer": ["RRTX0085.png"],
	"office_calendar": ["RRTX0102.png"],
	"office_tabletop": ["RRTX0458.png"],
	"office_wood": ["RRTX0242.png", "RRTX0198.png"],
	"office_pc_light": ["RRTX0478.png", "RRTX0556.png"],
	"office_sign_post": ["RRTX0122.png"],
	"office_sign_front": ["RRTX0123.png"],
	"office_sign_back": ["RRTX0242.png"],
	"office_roof_fan2": ["random/FAN2_2.png"],
	"interior_switch_on": ["switche/RRSW04_1.png", "random/RRSW04_1.png"],
	"interior_switch_off": ["switche/RRSW04_2.png", "random/RRSW04_2.png"],
	"cabin_switch_on": ["switche/RRSW10_1.png"],
	"cabin_switch_off": ["switche/RRSW10_2.png"],
	"cabin_lv3_front": ["RRTX0382.png"],
	"cabin_lv3_side": ["RRTX0136.png"],
	"building_door": ["random/dveresvetlo.png", "random/dveretma.png", "RRTX0370.png"],
	"building_window": ["zdi/RRTX0625.png", "RRTX0534.png", "RRTX0528.png"],
	"service_block_exterior_wall": ["zdi/RRTX0612.png"],
	"service_block_ext_427": ["RRTX0427.png"],
	"service_block_ext_428": ["RRTX0428.png"],
	"service_block_ext_429": ["RRTX0429.png"],
	"service_block_ext_430": ["RRTX0430.png"],
	"utility_exterior_wall": ["zdi/RRTX0612.png"],
	"utility_power_side_610": ["RRTX0610.png"],
	"utility_power_back_609": ["RRTX0609.png"],
	"service_block_exterior_roof": ["RRTX0141.png"],
	"service_sewer_roof_patch": ["RRTX0119.png"],
	"service_rest_wall": ["RRTX0507.png"],
	"service_rest_floor": ["RRTX0198.png"],
	"service_rest_ceiling": ["RRTX0111.png"],
	"service_rest_booth": ["RRTX0247.png"],
	"service_rest_booth_restaurant": ["RRTX0092.png"],
	"service_rest_tabletop": ["RRTX0458.png"],
	"service_rest_counter": ["RRTX0600.png"],
	"service_pub_shelf": ["RRTX0118.png"],
	"service_rest_decor": ["RRTX0123.png"],
	"service_kitchen_wall": ["RRTX0556.png"],
	"service_kitchen_floor": ["RRTX0516.png"],
	"service_kitchen_ceiling": ["RRTX0581.png"],
	"service_kitchen_counter": ["RRTX0475.png"],
	"service_kitchen_tabletop": ["RRTX0478.png"],
	"service_kitchen_island_front": ["RRTX0148.png"],
	"service_kitchen_island_top": ["RRTX0149.png"],
	"service_kitchen_decor": ["RRTX0557.png"],
	"service_kitchen_shelf": ["RRTX0134.png"],
	"service_kitchen_stove_top": ["RRTX0149.png"],
	"service_kitchen_freezer_door": ["RRTX0192.png"],
	"service_kitchen_fridge_door": ["RRTX0498.png"],
	"service_kitchen_cabinet": ["RRTX0205.png"],
	"service_kitchen_sign": ["RRTX0519.png"],
	"service_kitchen_drain": ["RRTX0522.png"],
	"service_toilet_wall": ["RRTX0501.png"],
	"service_toilet_floor": ["RRTX0478.png"],
	"service_toilet_ceiling": ["RRTX0501.png"],
	"service_toilet_fixture": ["RRTX0205.png"],
	"service_wash_wall": ["RRTX0202.png"],
	"service_wash_floor": ["RRTX0203.png"],
	"service_wash_fixture": ["RRTX0204.png"],
	"service_sewer_wall": ["RRTX0425.png"],
	"service_sewer_floor": ["RRTX0425.png"],
	"service_sewer_channel_521": ["RRTX0521.png"],
	"service_sewer_channel_522": ["RRTX0522.png"],
	"service_sewer_ceiling": ["RRTX0425.png"],
	"service_basement_wall": ["zdi/RRTX0991.png"],
	"service_basement_floor": ["RRTX0504.png"],
	"service_basement_machine": ["RRTX0540.png"],
	"service_basement_machine_anim_539": ["RRTX0539.png"],
	"service_basement_machine_anim_540": ["RRTX0540.png"],
	"service_basement_machine_anim_541": ["RRTX0541.png"],
	"service_basement_machine_anim_542": ["RRTX0542.png"],
	"service_basement_rect_523": ["RRTX0523.png"],
	"map_fence": ["zdi/kroviplot.png", "zdi/kroviplot2.png", "zdi/kroviplot3.png"],
	"service_vecerka_wall": ["zdi/RRTX1459.png"],
	"service_vecerka_storage": ["RRTX0513.png"],
	"service_vecerka_shelf": ["RRTX0116.png", "RRTX0117.png", "RRTX0118.png"],
	"service_vecerka_poster": ["RRTX0101.png", "RRTX0103.png"],
	"service_vecerka_cola": ["RRTX0063.png"],
	"weather_rain": ["auta/RRTX1393.png"],
	"weather_wind": ["auta/RRTX1394.png"],
	"weather_needles": ["auta/RRTX1395.png"],
	"weather_lightning": ["auta/RRTX1396.png"],
	"weather_mega_rain": ["auta/RRTX1392.png"]
}

const CATEGORY_FALLBACKS := {
	"wall": ["brick", "wood", "stone", "fabric"],
	"floor": ["road", "stone", "wood", "fabric"],
	"decor": ["decor_wood", "decor_fabric", "decor_metal", "decor_paper", "wood", "metal", "paper", "fabric"],
	"glass": ["water", "metal"],
	"tree_bark": ["wood"],
	"tree_canopy": ["foliage"],
	"cabin_lv1_exterior_wall": ["wood", "wall"],
	"cabin_lv1_exterior_wood": ["decor_wood", "wood"],
	"cabin_lv1_exterior_roof": ["roof"],
	"cabin_lv1_exterior_stone": ["stone"],
	"cabin_lv2_exterior_wall": ["wood", "wall"],
	"cabin_lv2_exterior_wood": ["decor_wood", "wood"],
	"cabin_lv2_exterior_roof": ["roof"],
	"cabin_lv2_exterior_stone": ["stone"],
	"cabin_lv3_exterior_wall": ["stone", "wall"],
	"cabin_lv3_exterior_wood": ["decor_wood", "wood"],
	"cabin_lv3_exterior_roof": ["roof", "metal"],
	"cabin_lv3_exterior_stone": ["stone"],
	"cabin_lv1_wall": ["wall", "wood"],
	"cabin_lv1_floor": ["floor", "wood"],
	"cabin_lv1_wood": ["decor_wood", "wood"],
	"cabin_lv1_fabric": ["decor_fabric", "fabric"],
	"cabin_lv1_bed": ["decor_fabric", "fabric"],
	"cabin_lv1_metal": ["decor_metal", "metal"],
	"cabin_lv2_wall": ["wall", "wood"],
	"cabin_lv2_floor": ["floor", "stone"],
	"cabin_lv2_wood": ["decor_wood", "wood"],
	"cabin_lv2_drawer": ["decor_wood", "wood"],
	"cabin_lv2_fabric": ["decor_fabric", "fabric"],
	"cabin_lv2_bed": ["decor_fabric", "fabric"],
	"cabin_lv2_metal": ["decor_metal", "metal"],
	"cabin_lv3_wall": ["wall", "stone"],
	"cabin_lv3_floor": ["floor", "stone"],
	"cabin_lv3_wood": ["decor_wood", "wood"],
	"cabin_lv3_drawer": ["decor_wood", "wood"],
	"cabin_lv3_fabric": ["decor_fabric", "fabric"],
	"cabin_lv3_bed": ["decor_fabric", "fabric"],
	"cabin_lv3_metal": ["decor_metal", "metal"],
	"office_wall": ["wall", "fabric"],
	"office_wall_dim": ["office_wall", "wall"],
	"office_wall_near_light": ["office_wall_dim", "office_wall", "wall"],
	"office_floor_scatter_26": ["decor_paper", "paper", "floor"],
	"office_floor_scatter_27": ["decor_paper", "paper", "floor"],
	"office_shelf": ["decor_wood", "wood"],
	"office_drawer": ["decor_wood", "wood"],
	"office_calendar": ["decor_paper", "paper"],
	"office_tabletop": ["decor_wood", "wood"],
	"office_wood": ["decor_wood", "wood"],
	"office_pc_light": ["decor_metal", "metal"],
	"office_sign_post": ["wood", "decor_wood"],
	"office_sign_front": ["paper", "decor_paper"],
	"office_sign_back": ["wood", "decor_wood"],
	"office_roof_fan2": ["roof", "metal", "decor_metal"],
	"interior_switch_on": ["decor_metal", "metal", "decor"],
	"interior_switch_off": ["decor_metal", "metal", "decor"],
	"cabin_switch_on": ["interior_switch_on", "decor_metal", "metal"],
	"cabin_switch_off": ["interior_switch_off", "decor_metal", "metal"],
	"cabin_lv3_front": ["wall", "decor_paper"],
	"cabin_lv3_side": ["wall"],
	"utility_exterior_wall": ["service_block_exterior_wall", "wall", "stone"],
	"building_door": ["decor_wood", "wood"],
	"building_window": ["glass", "water", "metal"],
	"service_block_exterior_wall": ["wall", "stone"],
	"service_block_ext_427": ["service_block_exterior_wall", "wall", "stone"],
	"service_block_ext_428": ["service_block_exterior_wall", "wall", "stone"],
	"service_block_ext_429": ["service_block_exterior_wall", "wall", "stone"],
	"service_block_ext_430": ["service_block_exterior_wall", "wall", "stone"],
	"utility_power_side_610": ["utility_exterior_wall", "wall", "stone"],
	"utility_power_back_609": ["utility_power_side_610", "utility_exterior_wall", "metal", "wall"],
	"map_fence": ["wall", "wood", "decor"],
	"service_block_exterior_roof": ["roof"],
	"service_sewer_roof_patch": ["service_block_exterior_roof", "roof", "metal"],
	"service_rest_wall": ["wall"],
	"service_rest_floor": ["floor"],
	"service_rest_ceiling": ["wall"],
	"service_rest_booth": ["decor_fabric", "fabric"],
	"service_rest_booth_restaurant": ["service_rest_booth", "decor_fabric", "fabric"],
	"service_rest_tabletop": ["decor_wood", "wood"],
	"service_rest_counter": ["decor_wood", "wood"],
	"service_pub_shelf": ["service_rest_counter", "decor_wood", "wood"],
	"service_rest_decor": ["decor", "decor_paper", "paper"],
	"service_kitchen_wall": ["metal", "wall"],
	"service_kitchen_floor": ["metal", "floor", "stone"],
	"service_kitchen_ceiling": ["metal", "wall"],
	"service_kitchen_counter": ["decor_metal", "metal"],
	"service_kitchen_tabletop": ["decor_metal", "metal"],
	"service_kitchen_island_front": ["service_kitchen_counter", "decor_metal", "metal"],
	"service_kitchen_island_top": ["service_kitchen_tabletop", "decor_metal", "metal"],
	"service_kitchen_decor": ["decor_metal", "metal", "decor"],
	"service_kitchen_shelf": ["decor_metal", "metal"],
	"service_kitchen_stove_top": ["decor_metal", "metal"],
	"service_kitchen_freezer_door": ["decor_metal", "metal"],
	"service_kitchen_fridge_door": ["decor_metal", "metal"],
	"service_kitchen_cabinet": ["decor_wood", "wood", "decor"],
	"service_kitchen_sign": ["decor_paper", "paper", "decor"],
	"service_kitchen_drain": ["decor_metal", "metal", "stone"],
	"service_toilet_wall": ["wall", "stone"],
	"service_toilet_floor": ["floor", "stone"],
	"service_toilet_ceiling": ["wall", "stone"],
	"service_toilet_fixture": ["decor_metal", "metal", "stone"],
	"service_wash_wall": ["wall", "stone"],
	"service_wash_floor": ["floor", "stone"],
	"service_wash_fixture": ["decor_metal", "metal", "stone"],
	"service_sewer_wall": ["wall", "stone"],
	"service_sewer_floor": ["floor", "stone"],
	"service_sewer_channel_521": ["service_sewer_floor", "floor", "stone", "metal"],
	"service_sewer_channel_522": ["service_sewer_floor", "floor", "stone", "metal"],
	"service_sewer_ceiling": ["wall", "stone"],
	"service_basement_wall": ["wall", "stone"],
	"service_basement_floor": ["floor", "stone"],
	"service_basement_machine": ["decor_metal", "metal", "decor"],
	"service_basement_machine_anim_539": ["service_basement_machine", "decor_metal", "metal", "decor"],
	"service_basement_machine_anim_540": ["service_basement_machine", "decor_metal", "metal", "decor"],
	"service_basement_machine_anim_541": ["service_basement_machine", "decor_metal", "metal", "decor"],
	"service_basement_machine_anim_542": ["service_basement_machine", "decor_metal", "metal", "decor"],
	"service_basement_rect_523": ["service_basement_wall", "wall", "decor_paper", "decor"],
}

var _loaded := false
var _candidates: Array[Dictionary] = []
var _category_cache: Dictionary = {}
var _tag_lookup: Dictionary = {}
var _active_roots: PackedStringArray = PackedStringArray()


func pick_texture(category: String, target_color: Color) -> Texture2D:
	_ensure_loaded()
	var canonical = _canonical_category(category)
	if canonical == "sky" and _category_cache.has(canonical):
		return _category_cache[canonical] as Texture2D

	var override_tex = _pick_override_texture(canonical)
	if override_tex != null:
		if canonical == "sky":
			_category_cache[canonical] = override_tex
		return override_tex
	if _candidates.is_empty():
		return null

	var candidate_pool = _candidate_pool_for_category(canonical)
	if candidate_pool.is_empty():
		return null
	var best_tex: Texture2D
	var best_score := 1.0e20
	for candidate in candidate_pool:
		var score := _score_candidate(candidate, canonical, target_color)
		if score < best_score:
			best_score = score
			best_tex = candidate.get("texture", null) as Texture2D

	if best_tex != null and canonical == "sky":
		_category_cache[canonical] = best_tex
	return best_tex


func pick_sky_texture(min_width: int = 512, min_height: int = 256) -> Texture2D:
	_ensure_loaded()
	var best_tex: Texture2D
	var best_width := -1

	for candidate in _candidates:
		var tex = candidate.get("texture", null) as Texture2D
		if tex == null:
			continue
		var w = tex.get_width()
		var h = tex.get_height()
		if w < min_width or h < min_height:
			continue
		var aspect = float(w) / max(1.0, float(h))
		if aspect < 1.7 or aspect > 2.3:
			continue
		if w > best_width:
			best_width = w
			best_tex = tex

	return best_tex


func _score_candidate(candidate: Dictionary, category: String, target_color: Color) -> float:
	var avg = candidate.get("avg", Vector3(0.5, 0.5, 0.5)) as Vector3
	var variance = float(candidate.get("variance", 0.1))
	var saturation = float(candidate.get("saturation", 0.2))
	var value = float(candidate.get("value", 0.5))
	var aspect = float(candidate.get("aspect", 1.0))
	var alpha_coverage = float(candidate.get("alpha_coverage", 1.0))
	var magenta_ratio = float(candidate.get("magenta_ratio", 0.0))
	var path = str(candidate.get("path", ""))
	var file_name = path.get_file().to_lower()

	var avg_color = Color(avg.x, avg.y, avg.z)
	var color_distance = Vector3(avg_color.r, avg_color.g, avg_color.b).distance_to(Vector3(target_color.r, target_color.g, target_color.b))
	var score = color_distance * 2.4 - (variance * 0.25)

	var keywords = _category_keywords(category)
	if _matches_keywords(path, keywords):
		score *= 0.86

	score += _category_penalty(category, avg_color, variance)
	score += abs(target_color.s - saturation) * 0.45
	score += abs(target_color.v - value) * 0.28

	if category != "sky":
		if _is_sky_like_candidate(candidate):
			score += 2.8
		if aspect > 1.65 or aspect < 0.55:
			score += 1.2
		elif aspect > 1.35 or aspect < 0.72:
			score += 0.38
		if alpha_coverage < 0.90:
			score += 4.0
		elif alpha_coverage < 0.98:
			score += 0.8

	if magenta_ratio > 0.02:
		score += 6.0
	elif magenta_ratio > 0.005:
		score += 2.0
	if file_name == "rrtx_grass_gen.png":
		score += 7.5

	if category == "sky":
		if _is_sky_like_candidate(candidate):
			score *= 0.50
		else:
			score *= 1.85

	return score


func _category_penalty(category: String, avg_color: Color, variance: float) -> float:
	var h = avg_color.h
	var s = avg_color.s
	var v = avg_color.v
	match category:
		"grass", "foliage", "tree_canopy":
			if h < 0.20 or h > 0.44:
				return 2.4
			if s < 0.25:
				return 1.3
			if v < 0.18 or v > 0.84:
				return 0.8
		"water", "glass":
			if h < 0.46 or h > 0.70:
				return 2.0
			if s < 0.10:
				return 0.6
		"wood", "decor_wood", "tree_bark", "cabin_lv1_exterior_wall", "cabin_lv2_exterior_wall", "cabin_lv1_exterior_wood", "cabin_lv2_exterior_wood", "cabin_lv3_exterior_wood", "cabin_lv1_wood", "cabin_lv2_wood", "cabin_lv3_wood", "office_shelf", "office_drawer", "office_tabletop", "office_wood", "office_sign_post", "office_sign_back", "service_rest_tabletop", "service_rest_counter":
			if h < 0.04 or h > 0.18:
				return 1.6
			if v > 0.80:
				return 0.5
			if s < 0.16:
				return 0.8
		"road", "floor", "cabin_lv1_floor", "cabin_lv2_floor", "cabin_lv3_floor", "office_floor_scatter_26", "office_floor_scatter_27", "service_rest_floor", "service_kitchen_floor", "service_wash_floor":
			if s > 0.42:
				return 1.2
			if v > 0.78:
				return 0.8
		"metal", "stone", "decor_metal", "cabin_lv1_metal", "cabin_lv2_metal", "cabin_lv3_metal", "cabin_lv1_exterior_stone", "cabin_lv2_exterior_stone", "cabin_lv3_exterior_stone", "cabin_lv3_exterior_wall", "service_kitchen_wall", "service_kitchen_ceiling", "service_kitchen_counter", "service_kitchen_tabletop", "service_kitchen_decor", "service_wash_fixture":
			if s > 0.34:
				return 0.9
		"roof", "wall", "cabin_lv1_exterior_roof", "cabin_lv2_exterior_roof", "cabin_lv3_exterior_roof", "cabin_lv1_wall", "cabin_lv2_wall", "cabin_lv3_wall", "office_wall", "cabin_lv3_front", "cabin_lv3_side", "service_rest_wall", "service_rest_ceiling", "service_wash_wall":
			if h > 0.22 and h < 0.88:
				return 0.7
			if s > 0.60:
				return 0.8
		"paper", "decor_paper", "office_calendar", "office_sign_front", "service_rest_decor":
			if v < 0.48:
				return 1.2
			if s > 0.30:
				return 0.7
		"fabric", "decor_fabric", "cabin_lv1_fabric", "cabin_lv2_fabric", "cabin_lv3_fabric", "cabin_lv1_bed", "cabin_lv2_bed", "cabin_lv3_bed", "service_rest_booth":
			if variance < 0.01:
				return 0.6
		"decor":
			if variance < 0.008:
				return 0.4
		_:
			pass
	return 0.0


func _matches_keywords(path: String, keywords: PackedStringArray) -> bool:
	if keywords.is_empty():
		return false
	var lower_path := path.to_lower()
	for keyword in keywords:
		if lower_path.contains(keyword):
			return true
	return false


func _category_keywords(category: String) -> PackedStringArray:
	match category:
		"grass", "foliage", "tree_canopy":
			return PackedStringArray(["grass", "leaf", "foliage", "bush", "forest"])
		"water", "lake", "glass":
			return PackedStringArray(["water", "lake", "river", "glass", "window"])
		"wood", "log", "plank", "decor_wood", "tree_bark", "office_shelf", "office_drawer", "office_tabletop", "office_wood", "office_sign_post", "office_sign_back", "service_rest_tabletop", "service_rest_counter":
			return PackedStringArray(["wood", "log", "plank", "board", "shelf", "table", "door"])
		"brick", "wall", "office_wall", "office_wall_dim", "office_wall_near_light", "cabin_lv3_front", "cabin_lv3_side", "service_rest_wall", "service_rest_ceiling", "service_wash_wall", "service_basement_rect_523", "utility_exterior_wall", "utility_power_side_610", "map_fence":
			return PackedStringArray(["brick", "wall", "panel"])
		"stone", "rock", "floor", "road", "path", "service_rest_floor", "service_kitchen_floor", "service_wash_floor", "service_sewer_floor", "service_sewer_channel_521", "service_sewer_channel_522":
			return PackedStringArray(["stone", "rock", "floor", "path", "dirt", "asphalt"])
		"metal", "utility", "decor_metal", "service_kitchen_wall", "service_kitchen_ceiling", "service_kitchen_counter", "service_kitchen_tabletop", "service_kitchen_decor", "service_wash_fixture", "service_basement_machine_anim_539", "service_basement_machine_anim_540", "service_basement_machine_anim_541", "service_basement_machine_anim_542", "utility_power_back_609", "interior_switch_on", "interior_switch_off", "cabin_switch_on", "cabin_switch_off":
			return PackedStringArray(["metal", "rust", "steel", "machine", "utility", "hook", "lantern"])
		"roof", "office_roof_fan2":
			return PackedStringArray(["roof", "tile", "shingle", "fan"])
		"map_fence":
			return PackedStringArray(["fence", "plot", "wall", "wood"])
		"paper", "decor_paper", "office_calendar", "office_sign_front", "service_rest_decor":
			return PackedStringArray(["paper", "poster", "calendar", "catalog"])
		"fabric", "decor_fabric", "service_rest_booth":
			return PackedStringArray(["fabric", "cloth", "canvas", "rug", "bedding"])
		"decor":
			return PackedStringArray(["decor", "prop", "furniture", "detail"])
		"sky":
			return PackedStringArray(["sky", "cloud"])
		_:
			return PackedStringArray()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_build_tag_lookup()
	_active_roots = PackedStringArray()
	for root_any in TEXTURE_ROOTS:
		var root = str(root_any)
		if DirAccess.open(root) == null:
			continue
		_active_roots.append(root)
		_load_candidates_from_dir(root)


func _build_tag_lookup() -> void:
	_tag_lookup.clear()
	for key in CATEGORY_OVERRIDES.keys():
		var category = str(key)
		if not _tag_lookup.has(category):
			_tag_lookup[category] = {}
		var file_map = _tag_lookup[category] as Dictionary
		var file_list = CATEGORY_OVERRIDES.get(category, [])
		for file_name in file_list:
			var lower_name = str(file_name).to_lower()
			file_map[lower_name] = true
			file_map[lower_name.get_file()] = true


func _load_candidates_from_dir(root: String) -> void:
	var dir = DirAccess.open(root)
	if dir == null:
		return

	var files: Array[String] = []
	var subdirs: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		if dir.current_is_dir():
			subdirs.append(file_name)
		else:
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	subdirs.sort()

	for subdir in subdirs:
		_load_candidates_from_dir(root.path_join(subdir))

	for file in files:
		var ext = file.get_extension().to_lower()
		if not SUPPORTED_EXT.has(ext):
			continue
		var path = root.path_join(file)
		var tex = _load_texture_from_path(path)
		if tex == null:
			continue
		var stats = _compute_texture_stats(tex)
		if stats.is_empty():
			continue
		_candidates.append({
			"path": path,
			"texture": tex,
			"avg": stats.get("avg", Vector3(0.5, 0.5, 0.5)),
			"variance": stats.get("variance", 0.1),
			"saturation": stats.get("saturation", 0.2),
			"value": stats.get("value", 0.5),
			"aspect": stats.get("aspect", 1.0),
			"alpha_coverage": stats.get("alpha_coverage", 1.0),
			"magenta_ratio": stats.get("magenta_ratio", 0.0),
			"top_avg": stats.get("top_avg", Vector3(0.5, 0.5, 0.5)),
			"bottom_avg": stats.get("bottom_avg", Vector3(0.5, 0.5, 0.5)),
			"tags": _tags_for_candidate(path, file),
		})


func _tags_for_candidate(path: String, file_name: String) -> Array[String]:
	var tags: Array[String] = []
	var lower_file = file_name.to_lower()

	for key in _tag_lookup.keys():
		var category = str(key)
		var file_map = _tag_lookup.get(category, {}) as Dictionary
		if file_map.has(lower_file):
			_add_tag(tags, category)

	var lower_path = path.to_lower()
	if lower_path.contains("/walls/"):
		_add_tag(tags, "wall")
	if lower_path.contains("/zdi/"):
		_add_tag(tags, "wall")
	if lower_path.contains("/floors/"):
		_add_tag(tags, "floor")
	if lower_path.contains("/paths/"):
		_add_tag(tags, "road")
		_add_tag(tags, "floor")
	if lower_path.contains("/drevo/"):
		_add_tag(tags, "wood")
		_add_tag(tags, "decor_wood")
	if lower_path.contains("/strechy/"):
		_add_tag(tags, "roof")
	if lower_path.contains("/switche/") or lower_path.contains("/switch/"):
		_add_tag(tags, "interior_switch_on")
		_add_tag(tags, "interior_switch_off")
		_add_tag(tags, "cabin_switch_on")
		_add_tag(tags, "cabin_switch_off")
		_add_tag(tags, "decor_metal")
	if lower_path.contains("/auta/"):
		_add_tag(tags, "metal")
		_add_tag(tags, "decor_metal")
	if lower_path.contains("/decor/") or lower_path.contains("/props/"):
		_add_tag(tags, "decor")
	if lower_path.contains("/random/"):
		_add_tag(tags, "decor")
	if lower_path.contains("/nature/") or lower_path.contains("/trees/"):
		_add_tag(tags, "foliage")
	if lower_path.contains("/water/") or lower_path.contains("/liquid/") or lower_path.contains("/liquids/"):
		_add_tag(tags, "water")

	_expand_composite_tags(tags)
	if tags.is_empty():
		tags.append("generic")
	return tags


func _expand_composite_tags(tags: Array[String]) -> void:
	if _has_tag(tags, "decor_wood") or _has_tag(tags, "decor_fabric") or _has_tag(tags, "decor_metal") or _has_tag(tags, "decor_paper"):
		_add_tag(tags, "decor")
	if _has_tag(tags, "decor_wood"):
		_add_tag(tags, "wood")
	if _has_tag(tags, "decor_fabric"):
		_add_tag(tags, "fabric")
	if _has_tag(tags, "decor_metal"):
		_add_tag(tags, "metal")
	if _has_tag(tags, "decor_paper"):
		_add_tag(tags, "paper")
	if _has_tag(tags, "floor") or _has_tag(tags, "road"):
		_add_tag(tags, "road")
	if _has_tag(tags, "grass"):
		_add_tag(tags, "floor")
	if _has_tag(tags, "glass"):
		_add_tag(tags, "water")
	if _has_tag(tags, "tree_bark"):
		_add_tag(tags, "wood")
	if _has_tag(tags, "tree_canopy"):
		_add_tag(tags, "foliage")


func _add_tag(tags: Array[String], tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)


func _has_tag(tags: Array[String], tag: String) -> bool:
	return tags.has(tag)


func _candidate_pool_for_category(category: String) -> Array[Dictionary]:
	if _candidates.is_empty():
		return []
	if category == "sky" or category == "generic":
		return _candidates

	var required_tags = _required_tags_for_category(category)
	if required_tags.is_empty():
		return _candidates

	var filtered: Array[Dictionary] = []
	for candidate in _candidates:
		var tags = candidate.get("tags", []) as Array
		if _contains_any_tag(tags, required_tags):
			filtered.append(candidate)
	if not filtered.is_empty():
		return filtered

	var fallback_tags = CATEGORY_FALLBACKS.get(category, [])
	if fallback_tags.is_empty():
		return _candidates
	for candidate in _candidates:
		var tags = candidate.get("tags", []) as Array
		if _contains_any_tag(tags, fallback_tags):
			filtered.append(candidate)
	if not filtered.is_empty():
		return filtered
	if _is_strict_category(category):
		return []
	return _candidates


func _contains_any_tag(tags: Array, wanted) -> bool:
	if wanted.is_empty():
		return true
	for tag in wanted:
		if tags.has(str(tag)):
			return true
	return false


func _is_strict_category(category: String) -> bool:
	return category.begins_with("tree_") or category.begins_with("cabin_lv") or category.begins_with("office_") or category.begins_with("service_")


func _required_tags_for_category(category: String) -> PackedStringArray:
	match category:
		"grass":
			return PackedStringArray(["grass"])
		"foliage":
			return PackedStringArray(["foliage"])
		"tree_canopy":
			return PackedStringArray(["tree_canopy", "foliage"])
		"water":
			return PackedStringArray(["water"])
		"wood":
			return PackedStringArray(["wood", "decor_wood"])
		"tree_bark":
			return PackedStringArray(["tree_bark"])
		"brick":
			return PackedStringArray(["brick"])
		"stone":
			return PackedStringArray(["stone", "road"])
		"metal":
			return PackedStringArray(["metal", "decor_metal"])
		"road":
			return PackedStringArray(["road", "floor", "stone"])
		"roof":
			return PackedStringArray(["roof"])
		"paper":
			return PackedStringArray(["paper", "decor_paper"])
		"fabric":
			return PackedStringArray(["fabric", "decor_fabric"])
		"wall":
			return PackedStringArray(["wall", "brick", "wood", "stone", "fabric"])
		"floor":
			return PackedStringArray(["floor", "road", "stone", "wood", "fabric"])
		"decor":
			return PackedStringArray(["decor", "decor_wood", "decor_fabric", "decor_metal", "decor_paper"])
		"decor_wood":
			return PackedStringArray(["decor_wood", "wood"])
		"decor_fabric":
			return PackedStringArray(["decor_fabric", "fabric"])
		"decor_metal":
			return PackedStringArray(["decor_metal", "metal"])
		"decor_paper":
			return PackedStringArray(["decor_paper", "paper"])
		"glass":
			return PackedStringArray(["glass", "water", "metal"])
		"cabin_lv1_exterior_wall", "cabin_lv2_exterior_wall", "cabin_lv3_exterior_wall":
			return PackedStringArray([category, "wall", "wood", "stone"])
		"cabin_lv1_exterior_wood", "cabin_lv2_exterior_wood", "cabin_lv3_exterior_wood":
			return PackedStringArray([category, "decor_wood", "wood"])
		"cabin_lv1_exterior_roof", "cabin_lv2_exterior_roof", "cabin_lv3_exterior_roof":
			return PackedStringArray([category, "roof", "metal"])
		"cabin_lv1_exterior_stone", "cabin_lv2_exterior_stone", "cabin_lv3_exterior_stone":
			return PackedStringArray([category, "stone"])
		"cabin_lv1_wall", "cabin_lv2_wall", "cabin_lv3_wall":
			return PackedStringArray([category, "wall", "wood", "stone"])
		"cabin_lv1_floor", "cabin_lv2_floor", "cabin_lv3_floor":
			return PackedStringArray([category, "floor", "road", "wood", "stone"])
		"cabin_lv1_wood", "cabin_lv2_wood", "cabin_lv3_wood":
			return PackedStringArray([category, "decor_wood", "wood"])
		"cabin_lv1_fabric", "cabin_lv2_fabric", "cabin_lv3_fabric":
			return PackedStringArray([category, "decor_fabric", "fabric"])
		"cabin_lv1_bed", "cabin_lv2_bed", "cabin_lv3_bed":
			return PackedStringArray([category, "decor_fabric", "fabric"])
		"cabin_lv1_metal", "cabin_lv2_metal", "cabin_lv3_metal":
			return PackedStringArray([category, "decor_metal", "metal"])
		"office_wall":
			return PackedStringArray(["office_wall", "wall", "fabric"])
		"office_wall_dim":
			return PackedStringArray(["office_wall_dim", "office_wall", "wall"])
		"office_wall_near_light":
			return PackedStringArray(["office_wall_near_light", "office_wall_dim", "office_wall", "wall"])
		"office_floor_scatter_26":
			return PackedStringArray(["office_floor_scatter_26", "decor_paper", "paper", "floor"])
		"office_floor_scatter_27":
			return PackedStringArray(["office_floor_scatter_27", "decor_paper", "paper", "floor"])
		"office_shelf":
			return PackedStringArray(["office_shelf", "decor_wood", "wood"])
		"office_drawer":
			return PackedStringArray(["office_drawer", "decor_wood", "wood"])
		"office_calendar":
			return PackedStringArray(["office_calendar", "decor_paper", "paper"])
		"office_tabletop":
			return PackedStringArray(["office_tabletop", "decor_wood", "wood"])
		"office_wood":
			return PackedStringArray(["office_wood", "decor_wood", "wood"])
		"office_pc_light":
			return PackedStringArray(["office_pc_light", "decor_metal", "metal"])
		"office_sign_post":
			return PackedStringArray(["office_sign_post", "decor_wood", "wood"])
		"office_sign_front":
			return PackedStringArray(["office_sign_front", "decor_paper", "paper"])
		"office_sign_back":
			return PackedStringArray(["office_sign_back", "decor_wood", "wood"])
		"office_roof_fan2":
			return PackedStringArray(["office_roof_fan2", "roof", "metal", "decor_metal"])
		"interior_switch_on":
			return PackedStringArray(["interior_switch_on", "decor_metal", "metal"])
		"interior_switch_off":
			return PackedStringArray(["interior_switch_off", "decor_metal", "metal"])
		"cabin_switch_on":
			return PackedStringArray(["cabin_switch_on", "interior_switch_on", "decor_metal", "metal"])
		"cabin_switch_off":
			return PackedStringArray(["cabin_switch_off", "interior_switch_off", "decor_metal", "metal"])
		"cabin_lv3_front":
			return PackedStringArray(["cabin_lv3_front", "wall", "decor_paper"])
		"cabin_lv3_side":
			return PackedStringArray(["cabin_lv3_side", "wall"])
		"utility_exterior_wall":
			return PackedStringArray(["utility_exterior_wall", "service_block_exterior_wall", "wall", "stone"])
		"utility_power_side_610":
			return PackedStringArray(["utility_power_side_610", "utility_exterior_wall", "wall", "stone"])
		"utility_power_back_609":
			return PackedStringArray(["utility_power_back_609", "utility_power_side_610", "utility_exterior_wall", "metal", "wall"])
		"service_block_ext_427":
			return PackedStringArray(["service_block_ext_427", "service_block_exterior_wall", "wall", "stone"])
		"service_block_ext_428":
			return PackedStringArray(["service_block_ext_428", "service_block_exterior_wall", "wall", "stone"])
		"service_block_ext_429":
			return PackedStringArray(["service_block_ext_429", "service_block_exterior_wall", "wall", "stone"])
		"service_block_ext_430":
			return PackedStringArray(["service_block_ext_430", "service_block_exterior_wall", "wall", "stone"])
		"service_rest_wall":
			return PackedStringArray(["service_rest_wall", "wall"])
		"service_rest_floor":
			return PackedStringArray(["service_rest_floor", "floor", "road"])
		"service_rest_ceiling":
			return PackedStringArray(["service_rest_ceiling", "wall"])
		"service_rest_booth":
			return PackedStringArray(["service_rest_booth", "decor_fabric", "fabric"])
		"service_rest_booth_restaurant":
			return PackedStringArray(["service_rest_booth_restaurant", "service_rest_booth", "decor_fabric", "fabric"])
		"service_rest_tabletop":
			return PackedStringArray(["service_rest_tabletop", "decor_wood", "wood"])
		"service_rest_counter":
			return PackedStringArray(["service_rest_counter", "decor_wood", "wood"])
		"service_rest_decor":
			return PackedStringArray(["service_rest_decor", "decor", "decor_paper", "paper"])
		"service_kitchen_wall":
			return PackedStringArray(["service_kitchen_wall", "metal", "wall"])
		"service_kitchen_floor":
			return PackedStringArray(["service_kitchen_floor", "floor", "metal", "stone"])
		"service_kitchen_ceiling":
			return PackedStringArray(["service_kitchen_ceiling", "metal", "wall"])
		"service_kitchen_counter":
			return PackedStringArray(["service_kitchen_counter", "decor_metal", "metal"])
		"service_kitchen_tabletop":
			return PackedStringArray(["service_kitchen_tabletop", "decor_metal", "metal"])
		"service_kitchen_island_front":
			return PackedStringArray(["service_kitchen_island_front", "service_kitchen_counter", "decor_metal", "metal"])
		"service_kitchen_island_top":
			return PackedStringArray(["service_kitchen_island_top", "service_kitchen_tabletop", "decor_metal", "metal"])
		"service_kitchen_decor":
			return PackedStringArray(["service_kitchen_decor", "decor_metal", "metal", "decor"])
		"service_kitchen_shelf":
			return PackedStringArray(["service_kitchen_shelf", "decor_metal", "metal"])
		"service_kitchen_stove_top":
			return PackedStringArray(["service_kitchen_stove_top", "decor_metal", "metal"])
		"service_kitchen_freezer_door":
			return PackedStringArray(["service_kitchen_freezer_door", "decor_metal", "metal"])
		"service_kitchen_fridge_door":
			return PackedStringArray(["service_kitchen_fridge_door", "decor_metal", "metal"])
		"service_kitchen_cabinet":
			return PackedStringArray(["service_kitchen_cabinet", "decor_wood", "wood", "decor"])
		"service_kitchen_sign":
			return PackedStringArray(["service_kitchen_sign", "decor_paper", "paper", "decor"])
		"service_kitchen_drain":
			return PackedStringArray(["service_kitchen_drain", "decor_metal", "metal", "stone"])
		"service_toilet_wall":
			return PackedStringArray(["service_toilet_wall", "wall", "stone"])
		"service_toilet_floor":
			return PackedStringArray(["service_toilet_floor", "floor", "stone"])
		"service_toilet_ceiling":
			return PackedStringArray(["service_toilet_ceiling", "wall", "stone"])
		"service_toilet_fixture":
			return PackedStringArray(["service_toilet_fixture", "decor_metal", "metal", "stone"])
		"service_wash_wall":
			return PackedStringArray(["service_wash_wall", "wall", "stone"])
		"service_wash_floor":
			return PackedStringArray(["service_wash_floor", "floor", "stone"])
		"service_wash_fixture":
			return PackedStringArray(["service_wash_fixture", "decor_metal", "metal", "stone"])
		"service_sewer_wall":
			return PackedStringArray(["service_sewer_wall", "wall", "stone"])
		"service_sewer_floor":
			return PackedStringArray(["service_sewer_floor", "floor", "stone"])
		"service_sewer_channel_521":
			return PackedStringArray(["service_sewer_channel_521", "service_sewer_floor", "floor", "stone", "metal"])
		"service_sewer_channel_522":
			return PackedStringArray(["service_sewer_channel_522", "service_sewer_floor", "floor", "stone", "metal"])
		"service_sewer_ceiling":
			return PackedStringArray(["service_sewer_ceiling", "wall", "stone"])
		"service_basement_wall":
			return PackedStringArray(["service_basement_wall", "wall", "stone"])
		"service_basement_floor":
			return PackedStringArray(["service_basement_floor", "floor", "stone"])
		"service_basement_machine":
			return PackedStringArray(["service_basement_machine", "decor_metal", "metal", "decor"])
		"service_basement_machine_anim_539":
			return PackedStringArray(["service_basement_machine_anim_539", "service_basement_machine", "decor_metal", "metal", "decor"])
		"service_basement_machine_anim_540":
			return PackedStringArray(["service_basement_machine_anim_540", "service_basement_machine", "decor_metal", "metal", "decor"])
		"service_basement_machine_anim_541":
			return PackedStringArray(["service_basement_machine_anim_541", "service_basement_machine", "decor_metal", "metal", "decor"])
		"service_basement_machine_anim_542":
			return PackedStringArray(["service_basement_machine_anim_542", "service_basement_machine", "decor_metal", "metal", "decor"])
		"service_basement_rect_523":
			return PackedStringArray(["service_basement_rect_523", "service_basement_wall", "wall", "decor_paper", "decor"])
		"map_fence":
			return PackedStringArray(["map_fence", "wall", "wood", "decor"])
		_:
			return PackedStringArray()


func _compute_texture_stats(tex: Texture2D) -> Dictionary:
	var image = tex.get_image()
	if image == null:
		return {}
	if image.is_empty():
		return {}

	var img = image.duplicate()
	if img.get_width() > 32 or img.get_height() > 32:
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)

	var w = img.get_width()
	var h = img.get_height()
	var sum = Vector3.ZERO
	var count := 0.0
	var sat_sum := 0.0
	var val_sum := 0.0
	var alpha_count := 0.0
	var magenta_count := 0.0
	var top_sum := Vector3.ZERO
	var top_count := 0.0
	var bottom_sum := Vector3.ZERO
	var bottom_count := 0.0

	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.a >= 0.08:
				alpha_count += 1.0
				if c.r > 0.72 and c.b > 0.72 and c.g < 0.45:
					magenta_count += 1.0
			if c.a < 0.12:
				continue
			sum += Vector3(c.r, c.g, c.b)
			sat_sum += c.s
			val_sum += c.v
			count += 1.0
			if y < h / 2:
				top_sum += Vector3(c.r, c.g, c.b)
				top_count += 1.0
			else:
				bottom_sum += Vector3(c.r, c.g, c.b)
				bottom_count += 1.0

	if count <= 0.0:
		return {}

	var avg = sum / count
	var avg_luma = avg.dot(Vector3(0.299, 0.587, 0.114))
	var avg_sat = sat_sum / count
	var avg_val = val_sum / count
	var alpha_coverage = alpha_count / float(max(1, w * h))
	var magenta_ratio = magenta_count / max(alpha_count, 1.0)
	var top_avg = (top_sum / max(top_count, 1.0)) if top_count > 0.0 else avg
	var bottom_avg = (bottom_sum / max(bottom_count, 1.0)) if bottom_count > 0.0 else avg
	var variance_acc := 0.0

	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.a < 0.08:
				continue
			var luma = Vector3(c.r, c.g, c.b).dot(Vector3(0.299, 0.587, 0.114))
			variance_acc += (luma - avg_luma) * (luma - avg_luma)

	return {
		"avg": avg,
		"variance": variance_acc / count,
		"saturation": avg_sat,
		"value": avg_val,
		"aspect": float(tex.get_width()) / max(1.0, float(tex.get_height())),
		"alpha_coverage": alpha_coverage,
		"magenta_ratio": magenta_ratio,
		"top_avg": top_avg,
		"bottom_avg": bottom_avg
	}


func _load_texture_from_path(res_path: String) -> Texture2D:
	var tex = load(res_path) as Texture2D
	if tex != null:
		return tex

	var abs_path = ProjectSettings.globalize_path(res_path)
	var image = Image.new()
	var err = image.load(abs_path)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _is_sky_like_candidate(candidate: Dictionary) -> bool:
	var aspect = float(candidate.get("aspect", 1.0))
	var avg = candidate.get("avg", Vector3(0.5, 0.5, 0.5)) as Vector3
	var top = candidate.get("top_avg", avg) as Vector3
	var bottom = candidate.get("bottom_avg", avg) as Vector3
	var sat = float(candidate.get("saturation", 0.2))
	var val = float(candidate.get("value", 0.5))

	var top_color = Color(top.x, top.y, top.z)
	var bottom_color = Color(bottom.x, bottom.y, bottom.z)
	var avg_color = Color(avg.x, avg.y, avg.z)
	var vertical_luma_delta = abs(top_color.get_luminance() - bottom_color.get_luminance())
	var blue_bias = avg_color.b - max(avg_color.r, avg_color.g)

	if aspect >= 1.70 and aspect <= 2.35 and sat <= 0.48 and val >= 0.36:
		return true
	if blue_bias > 0.08 and val > 0.40 and sat < 0.42:
		return true
	if vertical_luma_delta > 0.12 and avg_color.h >= 0.45 and avg_color.h <= 0.70:
		return true
	return false


func _pick_override_texture(canonical: String) -> Texture2D:
	var direct = _pick_override_from_category(canonical)
	if direct != null:
		return direct

	var fallback_categories = CATEGORY_FALLBACKS.get(canonical, [])
	for fallback in fallback_categories:
		var tex = _pick_override_from_category(str(fallback))
		if tex != null:
			return tex
	return null


func _pick_override_from_category(category: String) -> Texture2D:
	var file_list = CATEGORY_OVERRIDES.get(category, [])
	if file_list.size() == 0:
		return null
	for file_name_any in file_list:
		var file_name = str(file_name_any)
		for root_any in _active_roots:
			var root = str(root_any)
			var direct = _load_texture_from_path(root.path_join(file_name))
			if direct != null:
				return direct
		var tex = _find_candidate_texture_by_file(file_name)
		if tex != null:
			return tex
	return null


func _find_candidate_texture_by_file(file_name: String) -> Texture2D:
	var wanted = file_name.to_lower().get_file()
	for candidate in _candidates:
		var path = str(candidate.get("path", ""))
		if path.get_file().to_lower() == wanted:
			return candidate.get("texture", null) as Texture2D
	return null


func _canonical_category(category: String) -> String:
	match category:
		"grass":
			return "grass"
		"foliage", "leaf", "leaves":
			return "foliage"
		"tree_canopy", "canopy":
			return "tree_canopy"
		"water", "lake":
			return "water"
		"wood", "log", "plank":
			return "wood"
		"tree_bark", "bark", "trunk":
			return "tree_bark"
		"brick":
			return "brick"
		"stone", "rock":
			return "stone"
		"metal", "utility":
			return "metal"
		"road", "path":
			return "road"
		"roof":
			return "roof"
		"paper":
			return "paper"
		"fabric":
			return "fabric"
		"wall", "walls", "interior_wall", "ceiling":
			return "wall"
		"floor", "floors", "interior_floor", "rug", "mat":
			return "floor"
		"decor", "decoration", "prop", "furniture":
			return "decor"
		"decor_wood", "counter", "table", "shelf", "crate", "door", "frame":
			return "decor_wood"
		"decor_fabric", "canvas", "bedding":
			return "decor_fabric"
		"decor_metal", "hardware":
			return "decor_metal"
		"decor_paper":
			return "decor_paper"
		"glass", "window":
			return "glass"
		_:
			return category
