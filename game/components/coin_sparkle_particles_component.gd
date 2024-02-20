extends GPUParticles2D
class_name CoinSparkleParticlesComponent

@export var color: Color = Color.WHITE


func _ready():
    emitting = true
    one_shot = true
    modulate = color
    finished.connect(queue_free)
