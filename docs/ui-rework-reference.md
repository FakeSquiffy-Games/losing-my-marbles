# UI Rework Reference

How the card and marble rendering system is being rebuilt from procedural `_draw()` circles to layered, asset-driven visuals with node-based architecture editable in the Godot editor.

---

## 1. Design Goals

| Goal | Approach |
|---|---|
| **Replace procedural placeholders** with asset-ready node structure | Three-layer card system (frame → sprite → text), sprite-based marbles |
| **Editor-editable components** | `.tscn` scenes with unique-name (`%`) nodes, `@export` script properties |
| **Zero addon modifications** | Exploit `Card.front_face_texture`/`back_face_texture` exports for visibility sync |
| **Type-distinct card frames** | Frame fill + accent colors differ per `CardTypeEnum` |
| **Backward compatible** | Existing `.tres` card resources need no schema changes beyond `description` |

---

## 2. Card Visual Architecture

### 2.1 Scene Template

**File:** `scenes/ui/card_visual.tscn`

```
Card (Control, script=res://addons/card-framework/card.gd)
│   front_face_texture = NodePath("FrontFace/FrameRect")
│   back_face_texture  = NodePath("BackFace/BackRect")
│
├── FrontFace (Control, script=CardVisualController)
│   └── FrameRect (TextureRect, 150×210)          [unique: %FrameRect]
│       ├── SpriteRect (TextureRect, 130×110)     [unique: %SpriteRect]
│       ├── ManaCostLabel (Label, 44×22)          [unique: %ManaCostLabel]
│       ├── CardNameLabel (Label, 150×24)         [unique: %CardNameLabel]
│       └── CardDescLabel (Label, 126×54)         [unique: %CardDescLabel]
│
└── BackFace (Control)
    └── BackRect (TextureRect, 150×210)           [no unique name needed]
```

### 2.2 Why FrameRect is the Parent

Godot renders children on top of parents. The frame image has a **transparent rectangular hole** (10,10 → 140,120). Since SpriteRect is a child of FrameRect:

1. FrameRect texture draws first (opaque border + transparent hole)
2. SpriteRect draws next, filling the transparent hole area
3. Labels draw last, on top of everything

**Crucially**, the Card base class toggles `front_face_texture.visible` when `show_front` changes. Because SpriteRect and all labels are children of FrameRect, they **inherit visibility automatically** — no extra script needed to hide/show the full front face.

### 2.3 CardVisualController

**File:** `scripts/ui/card_visual_controller.gd`

Attached to `FrontFace`. Responsibilities:

| Method | What It Does |
|---|---|
| `apply_card_data(card_data: CardData)` | Sets frame texture, sprite texture, and all three label texts + styles |
| `apply_back(back_rect: TextureRect)` | Sets the back-face texture on BackRect |
| `_make_frame(type)` | Generates 150×210 `ImageTexture` — solid fill with transparent hole, 2px outer/inner border |
| `_make_sprite(type)` | Generates 130×110 `ImageTexture` — circular gradient in type accent color |
| `_make_back()` | Generates 150×210 `ImageTexture` — dark blue with diamond pattern |

**Texture caching:** Frame textures and back texture are cached in static dictionaries so they're generated once per type, not per card instance.

### 2.4 Type-to-Color Mapping

| CardType | Enum | Frame Fill | Accent Border | Label Tint |
|---|---|---|---|---|
| MARBLE | 0 | `(0.18, 0.10, 0.08)` dark red-brown | `(0.9, 0.45, 0.25)` orange-red | Blue mana label |
| POWER_UP | 1 | `(0.08, 0.12, 0.22)` dark blue | `(0.25, 0.50, 0.9)` blue | Blue mana label |
| TRICK | 2 | `(0.08, 0.20, 0.10)` dark green | `(0.25, 0.80, 0.35)` green | Blue mana label |
| TERRAIN | 3 | `(0.20, 0.16, 0.10)` dark brown | `(0.65, 0.50, 0.30)` gold-brown | Blue mana label |
| AoE | 4 | `(0.18, 0.10, 0.22)` dark purple | `(0.65, 0.35, 0.80)` purple | Blue mana label |

### 2.5 Label Positioning (Relative to FrameRect 150×210)

| Label | Position | Size | Font | Alignment | Content Source |
|---|---|---|---|---|---|
| ManaCostLabel | (8, 4) | 44×22 | 16px, cyan `(0.3,0.85,1.0)` | Left, Center | `card_data.mana_cost` |
| CardNameLabel | (0, 125) | 150×24 | 12px, white | Center, Center | `card_data.card_name` |
| CardDescLabel | (12, 150) | 126×54 | 9px, light gray | Center, Top (autowrap) | `card_data.description` |

All labels have 2px black outline for readability against the frame.

### 2.6 CardData Schema

**File:** `scripts/resources/card_data.gd`

```gdscript
@export var card_name: String = ""
@export var type: Enums.CardTypeEnum = Enums.CardTypeEnum.TRICK
@export var mana_cost: int = 0
@export var description: String = ""       # ← Added in Batch 1
@export var effects: Array[EffectData] = []
```

---

## 3. Marble Visual Architecture (Planned — Batch 3)

### 3.1 Target State

```
Marble (RigidBody2D)
├── CollisionShape2D (CircleShape2D, radius=15)
└── Sprite (Sprite2D)          ← NEW: replaces _draw()
```

### 3.2 Sprite Loading Strategy

1. Try loading: `res://assets/sprites/marbles/{card_name.to_snake_case()}.png`
2. Fallback: generate procedural circle `ImageTexture` using `_color` (preserves current look for missing assets)
3. Apply to `%Sprite`

### 3.3 ClientMarbleVisual

Same sprite-loading strategy. Replace `_draw()` with `Sprite2D` child.

### 3.4 Shooter Marble

Uses the same sprite as the corresponding marble type. Team color (red/blue) applied via `Sprite2D.modulate` tint.

---

## 4. Implementation Batches

### Batch 1 — Foundation (COMPLETE)

- [x] Add `description: String` to `CardData`
- [x] Create `scenes/ui/card_visual.tscn` — card template scene with 5 unique-named nodes
- [x] Create `scripts/ui/card_visual_controller.gd` — procedural frame/sprite/back generation + label styling
- [x] Verify: scene loads in editor without errors, node tree matches spec

**Verification:** Open `scenes/ui/card_visual.tscn` in Godot editor. Confirm node tree, `front_face_texture`/`back_face_texture` NodePaths, and `CardVisualController` script on FrontFace. No errors in Output panel.

**Files changed/created:**
- `scripts/resources/card_data.gd` — modified (added `description`)
- `scenes/ui/card_visual.tscn` — created
- `scripts/ui/card_visual_controller.gd` — created

### Batch 2 — Wire Factory (NEXT)

1. Update `CardDataFactory.CARD_SCENE` from `addons/card-framework/card.tscn` → `scenes/ui/card_visual.tscn`
2. Simplify `create_card_from_data()`:
   - Instantiate new card scene → set `card.card_size`
   - Get `CardVisualController` from `FrontFace` → call `apply_card_data(card_data)`
   - Call `controller.apply_back()` with BackRect
   - Set `card.card_name`, `card.card_info`
   - Add to target container
3. Remove dead code: `_make_placeholder_texture()`, `_color_for_type()`, `_type_string()`, `_add_label()`

**Verification:** Run game, enter match. Cards in hand show frames with type-specific colors, sprites in hole, mana cost/card name/description labels. Card dragging and play animations still work. Back face shows dark diamond pattern.

### Batch 3 — Marble Sprites

1. Add `Sprite2D` child to `scenes/gameplay/marble.tscn` with unique name `%Sprite`
2. Update `marble.gd` `setup()`: load sprite based on `marble_data.card_name`, fallback to procedural circle
3. Remove `_draw()` from `marble.gd` (or keep as fallback)
4. Update `ClientMarbleVisual` with same Sprite2D approach
5. Shooter marble uses same sprite + modulate tint for team color

**Verification:** Spawn marbles on field — sprites visible instead of `_draw()` circles. Different marble types show different sprites. Shooter marble shows correct team color tint.

### Batch 4 — Integration & Cleanup

1. Add `description` text to existing `.tres` card resources for testing
2. Verify full card-play flow: draw → play marble → aim → shoot → simulation
3. Remove any remaining dead `_draw()` code
4. Verify all card types render with distinct frames

---

## 5. How to Modify Card/Marble Visuals

### Adding a new card type frame

1. Add new colors to `_frame_fill()` and `_frame_accent()` in `card_visual_controller.gd`
2. The new `CardTypeEnum` value maps to those colors automatically

### Changing card layout (label positions, sizes, fonts)

1. Open `scenes/ui/card_visual.tscn` in the Godot editor
2. Select the label node (`ManaCostLabel`, `CardNameLabel`, `CardDescLabel`)
3. Adjust position/size in the Inspector or by dragging in the viewport
4. Font sizes and colors are set in `card_visual_controller.gd` → `_style_labels()`

### Replacing procedural textures with real assets

1. Add PNG files to an `assets/` directory
2. In `CardVisualController`, change `_make_frame()` from procedural generation to `load("res://assets/frames/frame_type_%d.png" % type)`
3. Same pattern for `_make_sprite()` → `load("res://assets/sprites/%s.png" % card_name.to_snake_case())`
4. Frame cache logic stays the same — just the generation method changes

### Adding a new label or visual element

1. Add the node as a child of `FrameRect` in `card_visual.tscn`
2. Set `unique_name_in_owner = true`
3. Add `@onready var my_label: Label = %MyLabel` in `card_visual_controller.gd`
4. Populate it in `apply_card_data()`

### Changing marble sprite at runtime

1. Set `%Sprite.texture = new_texture` on the Marble node
2. Use `%Sprite.modulate` for team color tinting
3. Sprite size is controlled by the texture size and `Sprite2D.scale`

---

## 6. Key Constraints

- **Card Framework addon is read-only.** Never modify `addons/card-framework/card.gd`, `hand.gd`, or any addon file.
- **Card size is fixed at 150×210.** The Card class's `_update_card_size()` resizes `front_face_texture` and `back_face_texture` when `card_size` changes.
- **FrameRect must be the front_face_texture.** The visibility toggle in `card.gd` only hides/shows the assigned TextureRect nodes. All visual children must be descendants of these nodes.
- **Marble collision shape must stay at radius 15.** Visual sprites can be larger/smaller but the physics body is 15px radius.
- **No image assets exist yet.** All textures are procedurally generated `ImageTexture` objects. When real assets arrive, swap the generation methods — the node structure stays the same.

---

## 7. Related Files

| File | Role |
|---|---|
| `scenes/ui/card_visual.tscn` | Card template scene (node hierarchy) |
| `scripts/ui/card_visual_controller.gd` | Populates card visuals, generates placeholder textures |
| `scripts/resources/card_data.gd` | Card data resource (now includes `description`) |
| `scripts/resources/card_data_factory.gd` | Factory — instantiates cards, wires controller (to be updated in Batch 2) |
| `scenes/ui/match.tscn` | Match UI — contains field, hand, play area, HUD |
| `scenes/gameplay/marble.tscn` | Marble scene (to get Sprite2D in Batch 3) |
| `scripts/gameplay/marble.gd` | Marble script — physics setup + rendering (to be updated in Batch 3) |
| `scripts/gameplay/client_marble_visual.gd` | Client-side marble rendering (to be updated in Batch 3) |
| `addons/card-framework/card.gd` | Card base class — DO NOT MODIFY |
| `addons/card-framework/card_factory.gd` | Factory base class — DO NOT MODIFY |
| `docs/card-resource-reference.md` | Card `.tres` format and effect catalog |
