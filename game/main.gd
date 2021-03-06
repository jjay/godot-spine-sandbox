extends Control

const BlendType = preload("blend.gd")
const BlendScene = preload("blend.tscn")

const BLEND_EXT = ".spineblend"

onready var box = get_node("tools/scroll/box")
onready var open_btn = box.get_node("file_open_btn")
onready var opt_box = box.get_node("misc/options")
onready var info_box = box.get_node("misc/info")
onready var size_info = info_box.get_node("info_size")
onready var animation_info = info_box.get_node("info_animation")
onready var size_factor_info = info_box.get_node("info_size_factor")
onready var load_info = info_box.get_node("info_load")
onready var anim_buttons = box.get_node("anim_buttons")
onready var skin_buttons = box.get_node("skin_buttons")
onready var file_path = box.get_node("file_path")
onready var blends = box.get_node("blend_box")
onready var add_blend = blends.get_node("blend_add")

onready var content = get_node("content")
onready var spine = content.get_node("scroll/spine")

var debug_rect
var alert_dialog

func _ready():
	set_process(true)
	var ut = OS.get_unix_time() + OS.get_ticks_msec()
	var fut1 = ut+2
	var fut = ut+1000
	var test = 1499160304+0.1
	var test2 = 1160304.1
	print(1260304.1, " ", 12360304.1, " ", 123460304.1, " ", 1234560304.1)
	open_btn.connect("pressed", self, "open_file")
	get_tree().connect("files_dropped", self, "open")
	for debug in ["bones", "region", "mesh"]:
		opt_box.get_node("opts_debug_" + debug).connect("toggled", self, "spine_debug", [debug])
	get_node("content/scroll").connect("input_event", self, "_input")
	alert_dialog = preload("alert.tscn").instance()
	get_node("/root").call_deferred("add_child", alert_dialog)
	add_blend.connect("pressed", self, "add_blend")

	
func alert(text):
	alert_dialog.get_node("label").set_text(text)
	alert_dialog.popup_centered()
		
func spine_debug(value, prop):
	spine.set("debug/" + prop, value)
	if prop == "mesh":
		spine.set("debug/skinned_mesh", value)
	
func open_file():
	var dialog = preload("file_selector.tscn").instance()
	get_tree().get_root().add_child(dialog)
	dialog.popup_centered()
	var path = yield(dialog, "file_selected")
	dialog.queue_free()
	open(path)

func open(path, screen=0):
	if typeof(path) == TYPE_STRING_ARRAY:
		path = path[0]
	if !["json", "skel"].has(path.extension()):
		alert("Wow. I can only open .json or .skel files, not this one:" + path)
		return
	
	if path.length() < 20:
		file_path.set_text(path)
	else:
		file_path.set_text("..." + path.substr(path.length()-20, path.length()))
	file_path.set_tooltip(path)
	
	if spine.get_resource() != null:
		clear_blends()
	
	spine.set_resource(null)
	yield(get_tree(), "idle_frame")

	print("opening spine file ", path)
	var start = OS.get_ticks_msec()
	var res = load(path)
	
	if !res:
		alert("Ups.. Can't open Spine resource =(")
		return
	spine.set_resource(res)
	load_info.set_value(OS.get_ticks_msec()-start)
	
	var skins = get_skins()
	for btn in skin_buttons.get_children():
		btn.queue_free()
	for skin in skins:
		var btn = Button.new()
		btn.set_text(skin)
		btn.connect("pressed", self, "set_skin", [skin])
		skin_buttons.add_child(btn)
	

	var animations = get_animations()			
	spine.play(animations[animations.size()-1])
	spine.set_scale(Vector2(1,1))
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
			
	spine.set_pos(content.get_size()*Vector2(0.5, 0.75))
	print("animations: ", animations)
	var duration = 0
	
	for btn in anim_buttons.get_children():
		btn.queue_free()
	for anim in animations:
		var btn = Button.new()
		btn.set_text(anim)
		btn.connect("pressed", self, "play", [anim])
		anim_buttons.add_child(btn)
		duration += spine.get_animation_length(anim)
		
	var f = File.new()
	f.open(res.get_path(), File.READ)
	var size = f.get_len()/1024.0
	f.close()
	size_info.set_value(size)
	size_factor_info.set_value(size/duration)
	
	load_blends()
	
func load_blends():
	var spine_path = spine.get_resource().get_path()
	var blend_path = spine_path.basename() + BLEND_EXT
	var file = File.new()
	var blend_config = {}
	for b in blends.get_children():
		if b extends BlendType:
			b.queue_free()
	add_blend.set_disabled(false)
	if file.file_exists(blend_path):
		file.open(blend_path, File.READ)
		blend_config.parse_json(file.get_as_text())
		file.close()
		for blend_arr in blend_config["blends"]:
			var blend = add_blend()
			blend.from_array(blend_arr)
	update_blends()

var save_queued = false
func queue_save_blends():
	if save_queued:
		return
	save_queued = true
	get_tree().connect("idle_frame", self, "save_blends", [], CONNECT_DEFERRED|CONNECT_ONESHOT)

func save_blends():
	var blend_arrs = []
	for blend in blends.get_children():
		if blend.is_queued_for_deletion():
			continue
		if blend extends BlendType:
			blend_arrs.append(blend.to_array())
	var blend_path = spine.get_resource().get_path().basename() + BLEND_EXT
	var file = File.new()
	file.open(blend_path, File.WRITE)
	var save = {"blends": blend_arrs}.to_json()
	file.store_string(save)
	file.close()
	print("Saved ", save)
	save_queued = false
	update_blends()
	
func clear_blends():
	var animations = get_animations()
	for from in animations:
		for to in animations:
			spine.mix(from, to, 0)
func update_blends():
	clear_blends()
	for blend in blends.get_children():
		if !(blend extends BlendType):
			continue
		var cfg = blend.to_array()
		spine.mix(cfg[0], cfg[1], cfg[2])


func add_blend():
	var blend = BlendScene.instance()
	blends.add_child(blend)
	blends.move_child(blend, blend.get_index()-1)
	blend.connect("changed", self, "queue_save_blends")
	blend.connect("removed", self, "queue_save_blends")
	return blend

		
func get_animations():
	var animations
	var pl = spine.get_property_list()
	for p in pl:
		if p["name"] == "playback/play":
			animations = Array(p["hint_string"].split(","))
			animations.pop_front()
	return animations
	
func get_skins():
	var skins
	var pl = spine.get_property_list()
	for p in pl:
		if p["name"] == "playback/skin":
			skins = Array(p["hint_string"].split(","))
	return skins

func set_skin(name):
	var anim = spine.get_current_animation(0)
	spine.stop()
	spine.reset()
	spine.set_active(false)
	var result = spine.set_skin(name)
	print("Skin ", name, " setted: ", result)
	spine.reset()
	spine.set_active(true)
	spine.play(anim, 1, true)
		
func play(anim):
	spine.set_active(true)
	spine.play(anim, 1, true)
	
func _exit_tree():
	var dir = Directory.new()
	for file in list_files("user://res"):
		dir.remove("user://res/" + file)

func list_files(path):
    var files = []
    var dir = Directory.new()
    dir.open(path)
    dir.list_dir_begin()

    while true:
        var file = dir.get_next()
        if file == "":
            break
        elif not file.begins_with("."):
            files.append(file)

    dir.list_dir_end()

    return files


var wantdrag = false
var dragging = false
func _input(event):
	if dragging && event.type == InputEvent.MOUSE_MOTION:
		spine.set_pos(spine.get_pos() + event.relative_pos)
	elif dragging && event.type == InputEvent.MOUSE_BUTTON && !event.is_pressed() && event.button_index == BUTTON_LEFT:
		dragging = false
		wantdrag = false
	elif !wantdrag && !dragging && event.type == InputEvent.MOUSE_BUTTON && event.is_pressed() && event.button_index == BUTTON_LEFT:
		wantdrag = true
	elif wantdrag && !dragging && event.type == InputEvent.MOUSE_MOTION:
		dragging = true
	elif event.type == InputEvent.MOUSE_BUTTON && event.is_pressed() && event.button_index == BUTTON_WHEEL_UP:
		spine.set_scale(spine.get_scale() + Vector2(0.1, 0.1))
	elif event.type == InputEvent.MOUSE_BUTTON && event.is_pressed() && event.button_index == BUTTON_WHEEL_DOWN:
		if spine.get_scale().x > 0.1:
			spine.set_scale(spine.get_scale() - Vector2(0.1, 0.1))
	
func _process(delta):
	animation_info.set_value(spine.get_debug_animate_ticks_msec())