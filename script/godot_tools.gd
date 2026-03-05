extends GExtension
var title: String = "Godot Tools"
var icon: ImageTexture = gload_image("../image/godot_icon_dark.png")
var link: String = "https://github.com/BielyDev/godot-tools-gridex"
var mesh_collision: ImageTexture = gload_image("../image/mesh_collision.png")
var layer_collision: ImageTexture = gload_image("../image/layer_collision.png")
var window: WindowContainer
var button: MenuButton = MenuButton.new()
var representation: Button
var path: String
var with_static_collision: bool = true
var a_static_body_per_layer: bool = true
var export_layers: Dictionary = {}#name, bool
var collision_layers: Dictionary = {}#name, bool

func _config() -> Dictionary:
	var plugin_config: Dictionary = {}
	
	plugin_config["icon"] = icon
	plugin_config["name"] = title
	plugin_config["link"] = link
	
	return plugin_config

func _enable() -> void:
	enable_godot_tools()
	create_additional_options()

func _disable() -> void:
	disabled_godot_tools()

func enable_godot_tools() -> void:
	GridExExtension.add_node_in_bar(button, 0, 0)
	button.text = title

func create_additional_options() -> void:
	var additional_exporter: Dictionary = GridExExtension.get_additional_exporter()
	var additional_add_tile: Dictionary = GridExExtension.get_additional_add_tile()

	additional_exporter["export tscn"] = {
		"icon" : icon,
		"callable" : _on_export_tscn,
		"type" : "tscn"
	}

	additional_add_tile["Add scene"] = {
		"icon" : icon,
		"callable" : _on_export_tscn,
		"resource" : SceneWrapper.new()
	}

	GridExExtension.set_additional_exporter(additional_exporter)
	GridExExtension.set_additional_add_tile(additional_add_tile)

func disabled_godot_tools() -> void:
	GridExExtension.remove_node_in_bar(button, 0, 0)

func create_window() -> void:
	window = WindowManager.window_container(get_window(), title)
	window.size_window(0.6)

	var ok_button: Button = window.add_down_button("OK",_on_confirm)
	var cancel_button: Button = window.add_down_button("CANCEL", _on_cancel)

	ok_button.custom_minimum_size.x = 80
	cancel_button.custom_minimum_size.x = 80

	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_END

	var w_check: PropertyBool = window.add_center_bool("COLLISION",with_static_collision,_on_with_static_collision)
	var a_check: PropertyBool = window.add_center_bool("LAYER_AS_STATIC_BODY",a_static_body_per_layer,_on_a_static_body_per_layer)

	representation = window.add_center_button("")
	representation.expand_icon = true
	representation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	representation.icon = mesh_collision
	representation.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	representation.custom_minimum_size = Vector2(100,100)

	w_check.box_min_size = Vector2(120,32)
	w_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_check.box_size_flags_h = Control.SIZE_EXPAND_FILL

	a_check.box_min_size = Vector2(120,32)
	a_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_check.box_size_flags_h = Control.SIZE_EXPAND_FILL

	var list_layer_export: BoxContainer = window.add_center_foldable("Export Layers")
	var list_layer_collision: BoxContainer = window.add_center_foldable("Collision Layers")

	for layer in Index.Layers.get_children():
		var layer_bool_export: PropertyBool = window.create_bool(layer.name, layer.get_child_count() > 0)
		var layer_bool_collision: PropertyBool = window.create_bool(layer.name, layer.get_child_count() > 0)

		layer_bool_export.callable = _on_layer_change_export.bind(layer_bool_export, layer_bool_collision)
		layer_bool_collision.callable = _on_layer_change_collision.bind(layer_bool_collision)

		layer_bool_export.box_size_flags_h = Control.SIZE_EXPAND_FILL
		layer_bool_collision.box_size_flags_h = Control.SIZE_EXPAND_FILL

		list_layer_export.add_child(layer_bool_export)
		list_layer_collision.add_child(layer_bool_collision)

		export_layers[layer_bool_export.text] = layer_bool_export.button_pressed
		collision_layers[layer_bool_collision.text] = layer_bool_collision.button_pressed

		layer_bool_export.callable.call()
		layer_bool_collision.callable.call()

	_on_a_static_body_per_layer(a_check.button_pressed)

func export() -> void:
	var packed: PackedScene = FileManager.get_packet_world()
	var filter_scene: PackedScene = PackedScene.new()
	var new_packed: PackedScene = PackedScene.new()

	filter_layer(packed, filter_scene)

	if with_static_collision:
		var new_scene: Node3D = filter_scene.instantiate()
		add_child(new_scene)
		create_collision(new_scene)
		FileManager.packed_tree(new_scene, new_packed, "")
		new_scene.queue_free()
	else:
		new_packed = filter_scene

	var err: Error = ResourceSaver.save(new_packed,path)
	if err == Error.OK:
		GridExConsole.print(str("Cena exportada em ",path),"Godot tools")

func filter_layer(original_scene: PackedScene, filter_scene: PackedScene) -> void:
	var new_scene: Node3D = original_scene.instantiate()
	add_child(new_scene)

	for child in new_scene.get_child(0).get_children():
		if not export_layers.get(child.name, true):
			new_scene.get_child(0).remove_child(child)
			child.queue_free()

	FileManager.packed_tree(new_scene, filter_scene, "")
	new_scene.queue_free()

func create_collision(parent: Node) -> void:
	for child: Node in parent.get_children().duplicate():
		if child is MeshInstance3D:
			if !collision_layers.has(parent.name):
				continue
			if !collision_layers[parent.name]:
				continue

			if a_static_body_per_layer:
				var collision_shape: CollisionShape3D = CollisionShape3D.new()
				collision_shape.shape = child.mesh.create_trimesh_shape()
				parent.add_child(collision_shape)
				collision_shape.global_transform = child.global_transform
			else:
				child.create_trimesh_collision()

		if child.get_child_count() > 0:
			var new_child: Node = child

			if a_static_body_per_layer:
				if new_child.get_child(0) is MeshInstance3D:
					var new_layer: StaticBody3D = StaticBody3D.new()

					var old_name: String = new_child.name
					var old_transform: Transform3D = new_child.transform
					var parent_node: Node = new_child.get_parent()
					var index: int = new_child.get_index()

					parent_node.add_child(new_layer)
					parent_node.move_child(new_layer, index)

					move_childs(new_child, new_layer)

					parent.remove_child(new_child)
					new_child.queue_free()

					new_layer.name = old_name
					new_layer.transform = old_transform

					new_child = new_layer

			create_collision(new_child)

func move_childs(de: Node, para: Node) -> void:
	for child: Node in de.get_children():
		de.remove_child(child)
		para.add_child(child)

class SceneWrapper extends TileExtension:
	@export var scene: String

#region RECEIVED SIGNAL
func _on_layer_change_export(p_e: PropertyBool, p_c: PropertyBool) -> void:
	p_c.disabled = !p_e.button_pressed
	export_layers[p_e.text] = p_e.button_pressed

func _on_layer_change_collision(p_c: PropertyBool) -> void:
	collision_layers[p_c.text] = p_c.button_pressed

func _on_export_tscn(paths : PackedStringArray) -> void:
	export_layers.clear()
	collision_layers.clear()
	path = paths[0]
	create_window()

func _on_with_static_collision(value: bool) -> void:
	with_static_collision = value

func _on_a_static_body_per_layer(value: bool) -> void:
	a_static_body_per_layer = value
	if value:
		representation.icon = layer_collision
	else:
		representation.icon = mesh_collision

func _on_confirm() -> void:
	export()
	window.quit()
	button.get_popup().add_item(str("Export in ",path),0)
	button.get_popup().id_pressed.connect(_on_menu_button)

func _on_cancel() -> void:
	window.quit()

func _on_menu_button(id: int) -> void:
	match id:
		0:
			export()
#endregion