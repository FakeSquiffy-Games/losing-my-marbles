This API documentation provides a comprehensive overview of the **Godot State Charts** plugin by derkork. This plugin brings Harel Statecharts to Godot 4, offering a powerful, node-based alternative to traditional Finite State Machines (FSMs) by supporting hierarchy, parallelism, and declarative transitions.

---

# StateChart
**Inherits:** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html)

The root node of a state chart. It manages the state machine's execution, event dispatching, and expression properties.

## Brief Description
The `StateChart` node acts as the entry point for your state logic. It tracks the currently active states and processes events sent from your game code.

## Detailed Description
A `StateChart` requires at least one child state (usually a `CompoundState` or `ParallelState`) to act as the root of the hierarchy. Unlike traditional FSMs, multiple states can be active at once if `ParallelState` nodes are used. Your game code typically interacts only with this node via `send_event` and `set_expression_property`.

## Properties
| Type | Property | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `NodePath` | `initial_state` | `NodePath("")` | The state that will be activated when the chart starts. |
| `bool` | `track_history` | `false` | If true, enables history tracking for `HistoryState` nodes. |

## Methods
- **send_event(event_name: StringName) -> void**  
  Triggers a transition check across all active states. If a transition is found that matches the `event_name` and passes its guard, the chart will change states.
- **set_expression_property(name: StringName, value: Variant) -> void**  
  Sets a property that can be used inside **Expression Guards** on transitions. Useful for conditional logic like `health < 50`.
- **get_expression_property(name: StringName) -> Variant**  
  Returns the current value of a previously set expression property.

## Signals
- **event_received(event_name: StringName)**  
  Emitted whenever `send_event` is called, regardless of whether a transition occurred.

---

# State (Base Class)
**Inherits:** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html)

The base class for all state nodes (`AtomicState`, `CompoundState`, `ParallelState`).

## Signals
- **state_entered()**  
  Emitted when the state becomes active.
- **state_exited()**  
  Emitted when the state is no longer active.
- **state_processing(delta: float)**  
  Emitted every frame while the state is active (equivalent to `_process`).
- **state_physics_processing(delta: float)**  
  Emitted every physics frame while the state is active (equivalent to `_physics_process`).
- **state_input(event: InputEvent)**  
  Emitted when an input event occurs while the state is active.
- **state_unhandled_input(event: InputEvent)**  
  Emitted for unhandled input events while the state is active.

---

# CompoundState / ParallelState
**Inherits:** `State`

- **CompoundState**: Only one child state can be active at a time. It requires an `initial_state` property to know which child to activate first.
- **ParallelState**: All child states are active simultaneously. This is ideal for managing independent layers of logic (e.g., "Movement" and "Combat" states running at once).

---

# Transition
**Inherits:** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html)

Defines the movement from one state to another.

## Properties
| Type | Property | Description |
| :--- | :--- | :--- |
| `NodePath` | `to` | The target state to transition to. |
| `StringName` | `event` | The event name that triggers this transition. |
| `float` | `delay` | Optional delay in seconds before the transition executes. |
| `String` | `guard` | An optional GDScript-like expression that must return `true` for the transition to fire. |

---

# Examples

### Basic Movement Logic
This example shows how to send events to the state chart from a player script.

```gdscript
extends CharacterBody2D

@onready var state_chart: StateChart = $StateChart

func _physics_process(delta: float) -> void:
    var direction = Input.get_axis("ui_left", "ui_right")
    
    if direction != 0:
        state_chart.send_event("move")
    else:
        state_chart.send_event("stop")

# Connected to the 'state_processing' signal of the 'Moving' state
func _on_moving_state_processing(delta: float) -> void:
    velocity.x = move_toward(velocity.x, 100, 10)
    move_and_slide()
```

### Using Expression Guards
You can pass data into the state chart to handle complex conditions without writing "if" statements in your transitions.

```gdscript
func take_damage(amount: int) -> void:
    health -= amount
    # Update the property used by a Transition Guard (e.g., "health <= 0")
    state_chart.set_expression_property("health", health)
    state_chart.send_event("damaged")
```