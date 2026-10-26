extends Camera2D

# Settings for your 8x8 grid
@export var grid_tiles: Vector2i = Vector2i(8, 8)
@export var tile_size: int = 32

func _ready() -> void:
	# Recalculate zoom when window is resized
	get_tree().root.size_changed.connect(_update_zoom)
	_update_zoom()

func _update_zoom() -> void:
	var window_size = get_viewport().get_visible_rect().size
	var grid_pixel_size = Vector2(grid_tiles.x * tile_size, grid_tiles.y * tile_size)
	
	# Calculate how much we need to scale the grid to fit the window
	var scale_x = window_size.x / grid_pixel_size.x
	var scale_y = window_size.y / grid_pixel_size.y
	
	# Use the smaller scale to ensure the whole grid fits without cutting off
	var final_scale = min(scale_x, scale_y)
	
	# Optional: Add a little padding (e.g., 0.9 = 90% of screen)
	final_scale *= 0.95
	
	# Apply zoom (Godot Camera2D zoom is the inverse of scale)
	zoom = Vector2(final_scale, final_scale)
	
	print("📷 Camera zoomed to fit grid: ", zoom)
