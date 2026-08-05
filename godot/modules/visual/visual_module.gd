extends Node

## Handles visual updates for buildings (rust/maintenance) and enemies (distortion FX).
## Listens to state changes and updates shader parameters.

var _grid_model
var _enemy_distortion_shader: Shader
var _enemy_fx_map: Dictionary = {}

func _ready() -> void:
    EventBus.state_changed.connect(_on_state_changed)
    EventBus.building_placed.connect(_on_building_placed)
    EventBus.building_removed.connect(_on_building_removed)
    
    # Wait for core root to be ready to get reference
    # Ideally injected, but for now via global or finding it
    # We assume CoreRoot is autoload or accessible. If not, we wait.
    call_deferred("_resolve_grid_model")

func _resolve_grid_model() -> void:
    if CoreRoot:
        _grid_model = CoreRoot.get_state().grid
        # Initial sync
        _refresh_all_visuals()

func _on_state_changed(changes: Dictionary) -> void:
    if changes.has("maintenance"):
        _refresh_all_visuals()

func _on_building_placed(_building_id: String, origin: Vector2i, _footprint: Vector2i, _rotation: int) -> void:
    # New building needs visual update (start at 0 rust usually, but just in case)
    _update_visual_at(origin)

func _on_building_removed(origin: Vector2i) -> void:
    pass

func _refresh_all_visuals() -> void:
    if not _grid_model:
        return
        
    var building_manager = _get_building_manager()
    if not building_manager:
        return

    # We need to map grid data to visual nodes.
    # BuildingManager stores structures under "Structures" node.
    # Each structure has metadata "grid_origin".
    
    var structures_root = building_manager.get_node_or_null("Structures")
    if not structures_root:
        return
        
    for child in structures_root.get_children():
        if child.has_meta("grid_origin"):
            var origin = child.get_meta("grid_origin")
            var data = _grid_model.get_cell_data(origin)
            var maintenance = data.get("maintenance", 1.0)
            _apply_maintenance_visual(child, maintenance)

func _update_visual_at(origin: Vector2i) -> void:
    if not _grid_model:
        return
    var building_manager = _get_building_manager()
    if not building_manager:
        return
        
    var structures_root = building_manager.get_node_or_null("Structures")
    if not structures_root:
        return
        
    # Find the specific child. This is O(N) but N is small.
    # Optimization: Store map in VisualModule or BuildingManager?
    for child in structures_root.get_children():
        if child.has_meta("grid_origin") and child.get_meta("grid_origin") == origin:
            var data = _grid_model.get_cell_data(origin)
            var maintenance = data.get("maintenance", 1.0)
            _apply_maintenance_visual(child, maintenance)
            return

func _apply_maintenance_visual(node: Node, maintenance: float) -> void:
    var corrosion = clamp(1.0 - maintenance, 0.0, 1.0)
    
    # Recursive set shader param
    _set_corrosion_recursive(node, corrosion)

func _set_corrosion_recursive(node: Node, amount: float) -> void:
    if node is MeshInstance3D:
        var mat = node.material_override
        if mat is ShaderMaterial:
            mat.set_shader_parameter("corrosion_amount", amount)
            
    for child in node.get_children():
        _set_corrosion_recursive(child, amount)

func _get_building_manager() -> Node:
    # Assuming Main scene structure or finding via Group
    var main = get_tree().root.get_node_or_null("Main") # Adjust path if needed
    if main and main.get("building_manager"):
        return main.building_manager
    # Fallback search
    return get_tree().get_first_node_in_group("building_manager")


## Nastav shader pro enemy distortion FX. Volat z main po bootstrap.
func setup_enemy_fx(distortion_shader: Shader) -> void:
    _enemy_distortion_shader = distortion_shader
    _enemy_fx_map.clear()


## Per-frame update: aplikuje distortion shader na všechny enemies podle time_state.
## Přesunuto z main._sync_enemy_distortion_fx(). Volat z main._process().
func sync_enemy_distortion_fx(time_state: int) -> void:
    if _enemy_distortion_shader == null:
        return
    var enemies = get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    var distortion = 0.06
    if time_state == 1:   # TIME_EVENING
        distortion = 0.09
    elif time_state == 2: # TIME_NIGHT
        distortion = 0.13
    for enemy in enemies:
        if enemy == null or not is_instance_valid(enemy):
            continue
        if enemy is Node and (enemy as Node).has_meta("skip_enemy_distortion") and bool((enemy as Node).get_meta("skip_enemy_distortion", false)):
            continue
        var key = enemy.get_instance_id()
        var mesh = _enemy_fx_map.get(key, null) as MeshInstance3D
        if mesh == null or not is_instance_valid(mesh):
            mesh = _find_first_mesh(enemy)
            if mesh == null:
                continue
            _enemy_fx_map[key] = mesh
        var shader_mat = mesh.material_override as ShaderMaterial
        if shader_mat == null or shader_mat.shader != _enemy_distortion_shader:
            shader_mat = ShaderMaterial.new()
            shader_mat.shader = _enemy_distortion_shader
            mesh.material_override = shader_mat
        shader_mat.set_shader_parameter("distortion_strength", distortion)


func _find_first_mesh(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var found = _find_first_mesh(child)
        if found != null:
            return found
    return null
