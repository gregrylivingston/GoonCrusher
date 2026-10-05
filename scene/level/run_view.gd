class_name RunView extends SubViewportContainer

#Render Resolution 720p / 540p: a run (level, HUD and in-run menus) is drawn into a SubViewport of that
#height and scaled up to the window. The SubViewport keeps the 1600x900 logical canvas
#(size_2d_override), so the camera shows the same world and every layout is unchanged; only fewer
#pixels are drawn. Night lighting is fill-bound on integrated GPUs (HD 620, S3 night: 57 fps at
#1080p, 121 fps at 720p), which is what this is for.

const HEIGHTS = {"720": 720, "540": 540}

var view: SubViewport

#the node to make the current scene for `level`: the level itself, or a RunView around it
static func wrap(level: Node) -> Node:
	if not HEIGHTS.has(Settings.get_value("display/render_res")): return level
	var runView = RunView.new()
	runView.name = "RunView"
	runView.view.add_child(level)
	return runView

func _init():
	stretch = false
	view = SubViewport.new()
	view.audio_listener_enable_2d = true #2D sounds play only in a viewport that listens
	view.size_2d_override_stretch = true
	view.canvas_item_default_texture_filter = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")
	add_child(view)

func _enter_tree():
	get_tree().root.size_changed.connect(resize)
	Settings.changed.connect(onSettingChanged)
	resize()

func onSettingChanged(key: String, _value) -> void:
	if key == "display/render_res": resize()

func resize() -> void:
	var logical = get_tree().root.get_visible_rect().size  #1600x900 unless the window's aspect differs
	var pixels = Vector2(get_window().size)
	var height = HEIGHTS.get(Settings.get_value("display/render_res"), 0)
	#never above the window's own resolution (Native/Auto picked mid-run means full resolution)
	var factor = minf(float(height) / pixels.y, 1.0) if height > 0 else 1.0
	var renderSize = Vector2i((pixels * factor).round()).max(Vector2i.ONE)
	view.size = renderSize
	view.size_2d_override = Vector2i(logical.round())
	size = Vector2(renderSize)
	self.scale = logical / Vector2(renderSize)
