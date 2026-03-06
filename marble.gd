extends CharacterBody2D

@export var friction: float = 0.98
var marble_color: String = "red"  # use a regular var, not @export

func _ready():
	call_deferred("setup_animation")

func setup_animation():
	$AnimatedSprite2D.animation = marble_color + "_idle"
	$AnimatedSprite2D.play()

func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		var collider = collision.get_collider()
		if collider is CharacterBody2D and "velocity" in collider:
			collider.velocity = -collision.get_normal() * (velocity.length() * 0.9)
		velocity = velocity.bounce(collision.get_normal()) * 0.8
		$Bounce.volume_db = clamp(linear_to_db(velocity.length() / 500.0), -20.0, 0.0)
		$Bounce.play()

	velocity *= friction

	if velocity.length() > 5:
		$AnimatedSprite2D.animation = marble_color + "_pushed"
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.animation = marble_color + "_idle"
		$AnimatedSprite2D.play()
		velocity = Vector2.ZERO
