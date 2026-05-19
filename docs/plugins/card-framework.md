This API documentation provides a structured overview of the **Godot Card Framework** by chun92. This framework is designed to simplify the development of card games in Godot 4.x by providing a clean separation between card data (Resources) and card visuals (Nodes), along with robust pile management logic.

---

# Card
**Inherits:** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)

The base data object representing a single card in the game.

## Brief Description
The `Card` resource stores the static and dynamic data of a card, such as its name, description, and custom gameplay properties.

## Properties
| Type | Property | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `String` | `id` | `""` | A unique identifier for the card type. |
| `String` | `name` | `""` | The display name of the card. |
| `String` | `description` | `""` | The flavor or effect text. |
| `Texture2D` | `icon` | `null` | The primary artwork for the card. |
| `Dictionary` | `data` | `{}` | A flexible container for custom stats (e.g., `{"attack": 5, "cost": 2}`). |

---

# CardPile
**Inherits:** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)

A logical collection of `Card` resources (e.g., a Deck, Hand, or Discard pile).

## Brief Description
`CardPile` handles the mathematical and logical side of card manipulation, such as shuffling, drawing, and moving cards between collections.

## Properties
| Type | Property | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `Array[Card]` | `cards` | `[]` | The internal list of card resources in this pile. |

## Methods
- **add_card(card: Card, at_index: int = -1) -> void**  
  Adds a card to the pile. If `at_index` is -1, it is added to the end.
- **remove_card(card: Card) -> void**  
  Removes the specified card from the pile.
- **shuffle() -> void**  
  Randomizes the order of the `cards` array.
- **draw_card() -> Card**  
  Removes and returns the last card in the array. Returns `null` if the pile is empty.
- **move_card_to(card: Card, target_pile: CardPile) -> void**  
  Transfers a card from this pile to another.

## Signals
- **card_added(card: Card)**  
  Emitted when a card enters the pile.
- **card_removed(card: Card)**  
  Emitted when a card leaves the pile.
- **shuffled()**  
  Emitted when the pile is randomized.

---

# CardContainer
**Inherits:** [Container](https://docs.godotengine.org/en/stable/classes/class_container.html)

The UI component responsible for displaying a `CardPile` in the game scene.

## Brief Description
The `CardContainer` automatically synchronizes with a `CardPile`. When cards are added or removed from the resource, this node instantiates or destroys the corresponding visual nodes.

## Properties
| Type | Property | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `CardPile` | `pile` | `null` | The data source this container visualizes. |
| `PackedScene` | `card_visual_scene` | `null` | The scene used to represent individual cards (must inherit from `CardVisual`). |
| `bool` | `interactive` | `true` | If false, input events on child cards are ignored. |

## Signals
- **card_gui_input(event: InputEvent, card_visual: Node)**  
  Emitted when a card within the container receives mouse input.
- **card_mouse_entered(card_visual: Node)**  
  Emitted when the mouse hovers over a card.

---

# CardVisual
**Inherits:** [Control](https://docs.godotengine.org/en/stable/classes/class_control.html)

The base class for the visual representation of a card.

## Brief Description
This script should be attached to the root of your card UI scene. It acts as the bridge, receiving a `Card` resource and updating the UI labels and textures accordingly.

## Methods
- **set_card(card: Card) -> void**  
  Virtual method. Override this to update your UI elements (Labels, Sprites) based on the card's data.

---

# Examples

### 1. Creating a Deck and Drawing a Card
This example demonstrates how to initialize a deck and move a card to a hand pile.

```gdscript
extends Node

@export var deck_resource: CardPile
@export var hand_resource: CardPile

func _ready() -> void:
	# Shuffle the deck at the start
	deck_resource.shuffle()

func draw_one_card() -> void:
	if deck_resource.cards.size() > 0:
		var card = deck_resource.draw_card()
		hand_resource.add_card(card)
		print("Drew: ", card.name)
```

### 2. Custom CardVisual Implementation
To display your cards, create a scene with this script:

```gdscript
extends CardVisual

@onready var name_label: Label = $NameLabel
@onready var art_rect: TextureRect = $Art

# This is called automatically by CardContainer
func set_card(card: Card) -> void:
	name_label.text = card.name
	art_rect.texture = card.icon
	
	# Access custom data
	var attack = card.data.get("attack", 0)
	$AttackLabel.text = str(attack)
```

---
### Design Decisions & Notes
*   **Resource-Centric:** The framework relies on Godot's `Resource` system. This means you can create your cards as `.tres` files in the editor, making it easy for designers to add content without touching code.
*   **Decoupling:** The `CardPile` does not know about the `CardContainer`. It only manages data. The `CardContainer` listens to the pile's signals to update the view, following a classic Model-View-Controller (MVC) pattern.
*   **Type Safety:** The framework uses `Array[Card]` to ensure that only card resources are processed by the pile logic.