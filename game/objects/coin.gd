extends Area2D
class_name Coin

@onready var game_stats = Utils.get_game_stats()
@onready var player_stats = Utils.get_player_stats()
@onready var collision_shape_2d = $CollisionShape2D


func _ready():
    collision_shape_2d.shape.radius = game_stats.coin_collision_radius


func _process(_delta):
    queue_redraw()


func _draw():
    draw_arc(Vector2.ZERO, game_stats.coin_radius, 0, deg_to_rad(360), 100, game_stats.coin_color, game_stats.coin_line_thickness, true)


func collect():
    player_stats.coins += 1
    queue_free()


func _on_body_entered(body):
    if body is Ball:
        collect()