extends Node2D
class_name Game

const BlockScene: PackedScene = preload("res://game/objects/block.tscn")
const BallScene: PackedScene = preload("res://game/objects/ball.tscn")
const CoinScene: PackedScene = preload("res://game/objects/coin.tscn")
const BombBlockScene: PackedScene = preload("res://game/objects/bomb_block.tscn")
const ScatterOrbScene: PackedScene = preload("res://game/objects/scatter_orb.tscn")

enum GameState {
    PREPARE_SHOT,
    EXECUTE_SHOT
}

var block_width: int = 0
var screen_size: Vector2 = Vector2.ZERO
var game_state: GameState = GameState.PREPARE_SHOT : set = _set_game_state
var balls_out: int = 0
var show_shot_ball: bool = true
var shot_cancelled: bool = false
var fire_ball: bool = false
var first_row: bool = true
var passthrough: bool = false
var top_offset: float = 0.0

@onready var blocks = $Blocks
@onready var game_stats = Utils.get_game_stats()
@onready var player_stats = Utils.get_player_stats()
@onready var launch_point = $LaunchPointComponent
@onready var ceiling_collision_shape_2d = $Boundaries/Ceiling/CollisionShape2D
@onready var left_wall = $Boundaries/LeftWall
@onready var right_wall = $Boundaries/RightWall
@onready var game_floor = $Boundaries/Floor
@onready var left_wall_collision_shape_2d = $Boundaries/LeftWall/CollisionShape2D
@onready var right_wall_collision_shape_2d = $Boundaries/RightWall/CollisionShape2D
@onready var camera_shake_component = $CameraShakeComponent
@onready var hud = $HUDLayer/HUD
@onready var game_ceiling = $Boundaries/Ceiling


func _ready():
    screen_size = get_viewport().get_visible_rect().size
    _adjust_boundaries(screen_size)

    block_width = Utils.get_block_width()
    launch_point.global_position = game_stats.launch_point_global_position

    print("Screen Size        : ", screen_size)
    print("Block Width        : ", block_width)
    print("Ball Radius        : ", game_stats.ball_radius)
    print("Block columns      : ", game_stats.block_columns)
    print("Block spacing      : ", game_stats.block_spacing)

    if Utils.is_new_game:
        create_row()
    elif not Utils.load_game(blocks):
        create_row()


func _adjust_boundaries(screen_size: Vector2):
    # Designed for 1080x1920 but the scale is set to expand in the height.
    # So on taller/shorter devices we need to adjust the position of the floor
    # and the size of the wall colliders
    var offset = screen_size.y - 1920
    top_offset = ceiling_collision_shape_2d.shape.size.y - offset / 2.0

    # Adjust top/bottom
    game_ceiling.global_position.y -= offset / 2.0
    game_floor.global_position.y += offset / 2.0

    # Adjust launch point
    game_stats.launch_point_global_position.y += (offset / 2.0) - game_stats.ball_radius

    # Adjust left and right boundaries
    left_wall.global_position.y = screen_size.y / 2
    right_wall.global_position.y = screen_size.y / 2
    left_wall_collision_shape_2d.shape.size.y += screen_size.y
    right_wall_collision_shape_2d.shape.size.y += screen_size.y

    print("Top: ", game_ceiling.global_position.y)
    print("Bottom: ", game_floor.global_position.y)


func _process(_delta):
    if Input.is_action_just_pressed("ui_accept") and game_state == GameState.EXECUTE_SHOT:
        balls_down()

    if game_state == GameState.EXECUTE_SHOT:
        if balls_out == 0:
            game_state = GameState.PREPARE_SHOT
            create_row()
    queue_redraw()


func _draw():
    var color = game_stats.ball_color
    if fire_ball:
        color = game_stats.fire_ball_color

    if show_shot_ball and not passthrough:
        draw_circle(launch_point.position, game_stats.ball_radius, color)
    elif show_shot_ball and passthrough:
        draw_arc(launch_point.position, game_stats.ball_radius, 0, deg_to_rad(360), 100, game_stats.ball_color, 5, true)


func get_block_value():
    if randf() <= 0.25:
        # 25% chance of the block value being double the current level
        return player_stats.level * 2

    # otherwise the new blocks value is just the level
    return player_stats.level


func create_block(x: float, y: float):
    var block = null
    if randf() <= game_stats.bomb_block_spawn_chance:
        # 10% chance of a bomb block
        block = BombBlockScene.instantiate()
        block.exploded.connect(_on_bomb_block_exploded)
    else:
        block = BlockScene.instantiate()
    var block_value = get_block_value()
    block.setup(block_width, block_value)
    blocks.add_child(block)
    block.global_position = Vector2(x + (block_width / 2.0), y + (block_width / 2.0))
    block.hit_game_floor.connect(_on_block_hit_game_floor)


func check_for_obj(x: float, y: float, delete: bool = false):
    var physics = get_world_2d().get_direct_space_state()
    var point_query = PhysicsPointQueryParameters2D.new()
    point_query.collide_with_areas = true
    point_query.collide_with_bodies = true
    point_query.position = Vector2(x, y)
    var result = physics.intersect_point(point_query)
    if len(result) > 0:
        return true
    return false


func create_coin(x: float, y: float):
    var coin = CoinScene.instantiate()
    blocks.add_child(coin)
    coin.global_position = Vector2(x + (block_width / 2.0), y + (block_width / 2.0))


func create_pickup_ball(x: float, y: float):
    var ball = BallScene.instantiate()
    ball.is_colletible = true
    blocks.add_child(ball)
    ball.global_position = Vector2(x + (block_width / 2.0), y + (block_width / 2.0))


func create_scatter_orb(x: float, y: float):
    var orb = ScatterOrbScene.instantiate()
    blocks.add_child(orb)
    orb.global_position = Vector2(x + (block_width / 2.0), y + (block_width / 2.0))


func balls_down():
    shot_cancelled = true
    for child in launch_point.get_children():
        if not child is Ball:
            continue
        child.drop()


func create_row():
    var x: float = game_stats.block_spacing / 2
    var y: float = top_offset
    var coin_column: int = game_stats.block_columns
    var pickup_ball_column: int = game_stats.block_columns

    # Check and remove any scatter orbs from last turn
    for child in blocks.get_children():
        if child is ScatterOrb:
            child.disolve()

    # Level starts at 0 so we increment first
    player_stats.level += 1

    # Generate a coin and pickup ball per row
    coin_column = randi_range(0, game_stats.block_columns - 1)
    pickup_ball_column = randi_range(1, game_stats.block_columns - 1)
    if coin_column == pickup_ball_column:
        pickup_ball_column -= 1

    # Add blocks to the row
    for col in range(game_stats.block_columns):
        if col == coin_column:
            create_coin(x, y)
        elif col == pickup_ball_column:
            create_pickup_ball(x, y)
        else:
            create_block(x, y)
        x += block_width + game_stats.block_spacing

    var chance = randf()
    if chance <= game_stats.scatter_orb_spawn_chance:
        x = randi_range(0, game_stats.block_columns - 1) * block_width
        y += randi_range(1, 4) * block_width
        if not check_for_obj(x + (block_width / 2.0), y + (block_width / 2.0)):
            create_scatter_orb(x, y)

    _move_down()
    first_row = false


func _move_down():
    # Tween the row down
    var tween = get_tree().create_tween()
    var tween_dest = Vector2.ZERO
    tween_dest = blocks.position + Vector2(0, block_width + game_stats.block_spacing)
    tween.tween_property(blocks, "position", tween_dest, 0.25)


func _set_game_state(value: GameState):
    game_state = value
    match game_state:
        GameState.PREPARE_SHOT:
            launch_point.enabled = true
        GameState.EXECUTE_SHOT:
            launch_point.enabled = false


func _on_ball_tree_exiting():
    show_shot_ball = true
    balls_out = max(balls_out - 1, 0)


func _on_bomb_block_exploded():
    camera_shake_component.add_screenshake(0.15, 0.1)


func _on_block_hit_game_floor():
    Utils.clear_save_game()
    get_tree().change_scene_to_file("res://game/menu/main_menu.tscn")


func _on_launch_point_component_fire(dir: Vector2):
    game_state = GameState.EXECUTE_SHOT
    show_shot_ball = false
    shot_cancelled = false

    if fire_ball:
        camera_shake_component.add_screenshake(0.25, 0.1)

    for _idx in range(player_stats.balls):
        var ball = BallScene.instantiate()
        
        # Configure first
        ball.tree_exiting.connect(_on_ball_tree_exiting)
        ball.fire_ball = fire_ball
        ball.passthrough = passthrough

        # Then add it to the scene and fire
        launch_point.add_child(ball)
        ball.fire(dir)
        balls_out += 1

        await get_tree().create_timer(game_stats.ball_spawn_timer).timeout

        if fire_ball:
            break
        if shot_cancelled:
            break

    # Cleanup
    launch_point.render_count = 1
    shot_cancelled = false
    fire_ball = false
    launch_point.fire_ball = false
    passthrough = false
    launch_point.passthrough = false


func _on_hud_balls_down_button_pressed():
    balls_down()


func _on_hud_shot_lines_button_pressed():
    launch_point.render_count = 3


func _on_hud_fire_ball_button_pressed():
    fire_ball = true
    launch_point.fire_ball = true
    passthrough = false
    launch_point.passthrough = false


func _on_hud_kill_bottom_row_button_pressed():
    var lowest_row_y_vals = 0
    for child in blocks.get_children():
        if child is ScatterOrb:
            continue
        if child.global_position.y > lowest_row_y_vals:
            lowest_row_y_vals = child.global_position.y
    
    for child in blocks.get_children():
        if child.global_position.y == lowest_row_y_vals:
            if child.has_method("destroy"):
                child.destroy()
            if child.has_method("collect"):
                child.collect()


func _on_hud_passthrough_button_pressed():
    passthrough = true
    launch_point.passthrough = true
    fire_ball = false
    launch_point.fire_ball = false
