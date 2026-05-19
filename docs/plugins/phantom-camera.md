This API documentation provides an overview of the **Phantom Camera** plugin for Godot 4.x, a powerful camera management system inspired by Unity's Cinemachine.

---

# Phantom Camera
**Inherits:** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html)

A comprehensive camera management system for Godot 4, providing advanced behaviors for `Camera2D` and `Camera3D` nodes.

## Brief Description
Phantom Camera simplifies complex camera behaviors such as following targets, looking at objects, reframing scenes, and smooth transitions (tweening) between different camera positions.

## Detailed Description
The system operates using three primary components:
1.  **PhantomCamera (PCam):** The core node (available in 2D and 3D variants). It holds the positional, rotational, and tweening data for a desired camera state.
2.  **PhantomCameraHost (PCamHost):** A managerial node placed as a child of the scene's `Camera` node. It listens for active `PhantomCamera` nodes and updates the `Camera` to match the active PCam's properties.
3.  **Viewfinder:** An editor-integrated tool that allows developers to preview what the camera will see based on the active `PhantomCamera` settings.

## Core Nodes

### PhantomCamera2D / PhantomCamera3D
The primary node type for defining camera behavior. When a PCam is set to "active," it takes control of the scene's `Camera` node.

*   **Priority:** Used to dynamically switch between camera positions. The PCam with the highest priority becomes active.
*   **Follow:** Configures the camera to track a specific target node with optional smoothing/damping.
*   **Look At:** Configures the camera to rotate toward a specific target node.
*   **Tweening:** Defines the duration and easing type when transitioning between different `PhantomCamera` nodes.

### PhantomCameraHost
A "set and forget" node. It must be added as a child of the `Camera2D` or `Camera3D` node to enable the Phantom Camera system. It automatically manages the hand-off between different `PhantomCamera` nodes.

## Key Features
*   **Dynamic Switching:** Seamlessly transition between camera shots by adjusting priority values.
*   **Advanced Framing:** Automatically reframe the camera to keep multiple targets in view.
*   **Cinematic Transitions:** Built-in support for tweening camera movement and rotation.
*   **Editor Viewfinder:** Visualize camera limits and framing directly within the Godot editor.

## Examples

### Basic Setup
1.  Add a `PhantomCameraHost` as a child of your `Camera2D` or `Camera3D`.
2.  Add a `PhantomCamera2D` (or `3D`) to your scene.
3.  Set the `Follow Target` property of the `PhantomCamera` to your player node.
4.  Set the `Priority` of the `PhantomCamera` to a value greater than 0 to activate it.

### Programmatic Switching
You can switch cameras at runtime by modifying the `priority` property.

```gdscript
extends Node

@onready var pcam_player: PhantomCamera2D = $PhantomCameraPlayer
@onready var pcam_boss: PhantomCamera2D = $PhantomCameraBoss

func _on_boss_area_entered(_body):
    # Switch to boss camera
    pcam_player.priority = 0
    pcam_boss.priority = 10

func _on_boss_defeated():
    # Switch back to player camera
    pcam_player.priority = 10
    pcam_boss.priority = 0
```