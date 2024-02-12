extends Resource
class_name GameStats

@export var ball_spawn_timer: float = 0.15

@export var ball_radius: float = 20.0
@export var ball_speed: float = 2000.0
@export var ball_color: Color = Color.WHITE

@export var pickup_ball_animation_radius_start: float = 25.0
@export var pickup_ball_animation_radius_end: float = 35.0
@export var pickup_ball_animation_duration: float = 0.75
@export var pickup_ball_collision_radius: float = 65.0

@export var coin_radius: float = 25.0
@export var coin_color: Color = Color.GOLD
@export var coin_line_thickness: float = 5.0
@export var coin_collision_radius: float = 65.0

@export var shot_line_color: Color = Color.WHITE
@export var shot_line_width: float = 8.0
@export var shot_line_antialiased: bool = true

@export var block_columns:  int = 7
@export var block_spacing: int = 2
@export var block_hue_start: float = 130.0
@export var block_saturation: float = 50.0
@export var block_brightness: float = 45.0

@export var launch_point_global_position: Vector2 = Vector2(540, 1720)


func save_stats():
    return {
        "ball_speed": ball_speed,
        "ball_color": ball_color,
        "coin_color": coin_color,
        "shot_line_color": shot_line_color,
        "block_hue_start": block_hue_start,
        "block_saturation": block_saturation,
        "block_brightness": block_brightness
    }


func load_stats(obj: Dictionary):
    ball_speed = obj.ball_speed
    ball_color = obj.ball_color
    coin_color = obj.coin_color
    shot_line_color = obj.shot_line_color
    block_hue_start = obj.block_hue_start
    block_saturation = obj.block_saturation
    block_brightness = obj.block_brightness
