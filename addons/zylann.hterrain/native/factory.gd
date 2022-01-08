
const NATIVE_PATH = "res://addons/zylann.hterrain/native/"

const ImageUtilsGeneric = preload("./image_utils_generic.gd")
const TerrainDetailerGeneric = preload("./terrain_detailer_generic.gd")

# See https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-name
const _supported_os = {
	"Windows": true,
	"X11": true,
	#"OSX": true
}


static func is_native_available() -> bool:
	var os = OS.get_name()
	if not _supported_os.has(os):
		return false
	# API changes can cause binary incompatibility
	var v = Engine.get_version_info()
	return v.major == 3 and v.minor <= 5


static func get_image_utils():
	if is_native_available():
		var ImageUtilsNative = load(NATIVE_PATH + "image_utils.gdns")
		if ImageUtilsNative != null:
			return ImageUtilsNative.new()
	return ImageUtilsGeneric.new()


static func get_terrain_detailer():
	if is_native_available():
		var TerrainDetailerNative = load(NATIVE_PATH + "terrain_detailer.gdns")
		if TerrainDetailerNative != null:
			return TerrainDetailerNative.new()
	return TerrainDetailerGeneric.new()