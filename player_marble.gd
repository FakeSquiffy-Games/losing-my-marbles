extends CharacterBody2D 

# Custom signals for decoupled communication
var dragging = false
var offset = Vector2.ZERO
var is_aiming: bool = false
var start_pos: Vector2 = Vector2.ZERO
var launch_velocity: Vector2 = Vector2.ZERO

# Exported variables appear in Inspector
@export var max_pull: float = 150.0  # Max drag distance
@export var friction: float = 0.98   # How fast it slows down
@export var power_mult: float = 5.0   # Speed multiplier
@export var speed: float = 350.0

# Internal state
var screensize: Vector2 = DisplayServer.window_get_size()

func _ready() -> void:
	$"../ResetPosition".pressed.connect(reset_position)
	position.x = screensize.x / 2
	position.y = 450
	
func reset_position() -> void:
	position.x = screensize.x / 2
	position.y = 450
	
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_aiming = true
			start_pos = get_global_mouse_position()
			velocity = Vector2.ZERO # Stop current movement while aiming

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and is_aiming:
			# Calculate the launch: Opposite of the pull direction
			var pull_vector = get_global_mouse_position() - start_pos
			
			# Clamp the pull so you can't launch at infinite speed
			pull_vector = pull_vector.limit_length(max_pull)
			
			# Launch in the OPPOSITE direction (Pool/Slingshot style)
			velocity = -pull_vector * power_mult
			is_aiming = false

func _physics_process(delta: float) -> void:
	if is_aiming:
		$AnimatedSprite2D.animation = Constants.CUE_STANDBY
		return # Don't run movement code while aiming

	# Apply movement
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		# If we hit another ball, push it!
		if collider is CharacterBody2D and "velocity" in collider:
			collider.velocity = -collision.get_normal() * (velocity.length() * 0.9)
		
		# Bounce the cue ball itself
		velocity = velocity.bounce(collision.get_normal()) * 0.8
		$Bounce.volume_db = clamp(linear_to_db(velocity.length() / speed), -20.0, 0.0)
		$Bounce.play()
	
	# Apply friction
	velocity *= friction 

	# Animation and stop logic
	if velocity.length() > 5: # Lowered threshold slightly
		$AnimatedSprite2D.animation = Constants.CUE_PUSHED
	else:
		$AnimatedSprite2D.animation = Constants.CUE_STANDBY
		velocity = Vector2.ZERO
	# Flip sprite based on horizontal direction
	
func start() -> void:
	"""Reset player for new game."""
	set_process(true)
	position = screensize / 2
	$AnimatedSprite2D.animation = Constants.CUE_STANDBY


#func _on_area_entered(area: Area2D) -> void:
	#if area.has_method("apply_effect"):
		#area.apply_effect(self)
		#
#class pickupable:
	#func apply_effect(player):
		#player.pickup.emit()
#
#class cactus:
	#func apply_effect(player):
		#player.hurt.emit()
		#player.die()
