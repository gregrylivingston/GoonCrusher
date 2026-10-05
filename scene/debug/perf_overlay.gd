class_name PerfOverlay extends CanvasLayer

#F3 performance overlay. mode 0 = off, 1 = fps, 2 = detailed

const HISTORY = 300
var mode: int = 0
var frameTimes: PackedFloat32Array = []
var frameIndex: int = 0
var refreshTimer: float = 0.0
var lightCount: int = 0
var lightTimer: float = 0.0
var label: Label

func _ready():
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	frameTimes.resize(HISTORY)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(8, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 0)
	panel.add_child(label)
	add_child(panel)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	setMode(mode)

func setMode(newMode: int) -> void:
	mode = newMode
	visible = mode > 0
	set_process(mode > 0)

func _process(delta):
	frameTimes[frameIndex % HISTORY] = delta * 1000.0
	frameIndex += 1
	lightTimer -= delta
	if mode == 2 && lightTimer <= 0.0:
		lightTimer = 1.0
		lightCount = GameStats.lights(get_tree())
	refreshTimer -= delta
	if refreshTimer > 0.0: return
	refreshTimer = 0.25
	var fps = Engine.get_frames_per_second()
	if mode == 1:
		label.text = "%d fps  %.1f ms" % [fps, 1000.0 / max(fps, 1)]
		return
	var samples = frameTimes.slice(0, min(frameIndex, HISTORY))
	samples.sort()
	var total = 0.0
	for i in samples: total += i
	var avg = total / max(samples.size(), 1)
	var p99 = samples[int(samples.size() * 0.99)] if samples.size() > 0 else 0.0
	var worst = samples[samples.size() - 1] if samples.size() > 0 else 0.0
	var vp = get_viewport().get_viewport_rid()
	var gpu = RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var gpuText = "n/a" if gpu <= 0.0 else "%.2f ms" % gpu
	label.text = "\n".join([
		"%d fps   frame avg %.1f / p99 %.1f / max %.1f ms" % [fps, avg, p99, worst],
		"process %.2f ms   physics %.2f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0],
		"gpu %s   render cpu %.2f ms" % [gpuText, RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()],
		"draw calls %d   nodes %d   physics objects %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)],
		"goons %d   chunks %d   lights %d" % [GameStats.goons(), GameStats.chunks(), lightCount],
		"renderer %s  (%s)" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()],
	])
