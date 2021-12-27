tool

const Logger = preload("./util/logger.gd")


const CHUNK_SIZE = 32
const AABBS_CACHE_SIZE = 1024

var _terrain = null
var _detail_layers := []

# Vector3 => AABB
var _cached_aabbs := {}

var _logger := Logger.get_for(self)


func set_terrain(terrain):
	assert(terrain is Spatial)
	_terrain = terrain

func update_materials():
	for layer in _detail_layers:
		layer.update_material()

func add_map(index: int):
	for layer in _detail_layers:
		# Shift indexes up since one was inserted
		if layer.layer_index >= index:
			layer.layer_index += 1
		layer.update_material()

func remove_map(index: int):
	for layer in _detail_layers:
		# Shift indexes down since one was removed
		if layer.layer_index > index:
			layer.layer_index -= 1
		layer.update_material()

func set_transform(terrain_transform: Transform):
	update_materials()
	# Clear cached aabbs because the transform changed
	_cached_aabbs.clear()
		
func process(delta: float, viewer_pos: Vector3):
	if _terrain == null:
		_logger.error("Detailer processing while terrain is null!")
		return

	var local_viewer_pos = _terrain.global_transform.affine_inverse() * viewer_pos
	
	var viewer_cx = local_viewer_pos.x / CHUNK_SIZE
	var viewer_cz = local_viewer_pos.z / CHUNK_SIZE

	var map_res = _terrain.get_data().get_resolution()
	var map_scale = _terrain.map_scale

	var terrain_size_x = map_res * map_scale.x
	var terrain_size_z = map_res * map_scale.z

	var terrain_chunks_x = terrain_size_x / CHUNK_SIZE
	var terrain_chunks_z = terrain_size_z / CHUNK_SIZE

	for layer in _detail_layers:
		if !layer.visible:
			continue
	
		var cr = int(layer.view_distance) / CHUNK_SIZE + 1
	
		var cmin_x = viewer_cx - cr
		var cmin_z = viewer_cz - cr
		var cmax_x = viewer_cx + cr
		var cmax_z = viewer_cz + cr
	
		if cmin_x < 0:
			cmin_x = 0
		if cmin_z < 0:
			cmin_z = 0
		if cmax_x > terrain_chunks_x:
			cmax_x = terrain_chunks_x
		if cmax_z > terrain_chunks_z:
			cmax_z = terrain_chunks_z

		layer.update(_terrain, local_viewer_pos, range(cmin_x, cmax_x), range(cmin_z, cmax_z))
		layer.update_wind_time(_terrain, delta)

func add_layer(layer):
	assert(_detail_layers.find(layer) == -1)
	layer.set_callbacks(funcref(self, "_cb_chunk_aabb"))
	_detail_layers.append(layer)


func remove_layer(layer):
	assert(_detail_layers.find(layer) != -1)
	_detail_layers.erase(layer)


func get_layers() -> Array:
	return _detail_layers.duplicate()


func _cb_chunk_aabb(lpos: Vector3) -> AABB:
	return _get_chunk_aabb(lpos)

# Gets local-space AABB of a detail chunk.
# This only apply map_scale in Y, because details are not affected by X and Z map scale.
func _get_chunk_aabb(lpos: Vector3) -> AABB:
	var aabb = null

	if _cached_aabbs.has(lpos):
		aabb = _cached_aabbs[lpos]
	else:
		var terrain_scale = _terrain.map_scale
		var terrain_data = _terrain.get_data()
		var origin_cells_x := int(lpos.x / terrain_scale.x)
		var origin_cells_z := int(lpos.z / terrain_scale.z)
		var size_cells_x := int(CHUNK_SIZE / terrain_scale.x)
		var size_cells_z := int(CHUNK_SIZE / terrain_scale.z)
		
		aabb = terrain_data.get_region_aabb(
			origin_cells_x, origin_cells_z, size_cells_x, size_cells_z)
			
		aabb.position = Vector3(lpos.x, lpos.y + aabb.position.y * terrain_scale.y, lpos.z)
		aabb.size = Vector3(CHUNK_SIZE, aabb.size.y * terrain_scale.y, CHUNK_SIZE)
		_cache_chunk_aabb(lpos, aabb)
	
	return aabb

func _cache_chunk_aabb(lpos: Vector3, aabb: AABB):
	if _cached_aabbs.size() >= AABBS_CACHE_SIZE:
		_cached_aabbs.erase(_cached_aabbs.keys()[0])
	
	_cached_aabbs[lpos] = aabb