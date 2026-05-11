# Losing My Marbles! — Implementation Plan
**Version:** 3.0 | **Created:** May 2026
**Audience:** Core Engineering Team, AI Development Agents

---

## Table of Contents

1. [Project State Summary](#1-project-state-summary)
2. [Architecture Philosophy](#2-architecture-philosophy)
3. [Technology Stack & Plugins](#3-technology-stack--plugins)
4. [Locked Decisions](#4-locked-decisions)
5. [Phase Roadmap](#5-phase-roadmap)
6. [Testing & Quality Strategy](#6-testing--quality-strategy)
7. [Code Standards](#7-code-standards)

---

## 1. Project State Summary

**Status: Full Greenfield Rebuild**
The project is being rewritten from scratch to implement a full system overhaul. No legacy code will be retained. Historical bugs—such as raw node references causing use-after-free crashes, trailing commas breaking compilation, and manual physics position teleporting—are eliminated by adopting strict Godot 4.6 idioms and a decoupled architecture.

### Primary Objectives of the Rebuild:
- Clean, decoupled `SignalBus` architecture from day one.
- Native Godot 2D physics implementation (`linear_damp` and `Area2D` gravity) instead of manual velocity overrides.
- Data-driven card architecture utilizing the Command Pattern via `.tres` Resources.
- Complete UI suites (Matchmaking, Deck Builder, Offline Pass-and-Play) built on a scalable state machine.

---

## 2. Architecture Philosophy

**Composition Over Inheritance**
Deep inheritance chains are explicitly avoided. Marbles and Obstacles share physical traits but differ conceptually. We utilize a `PhysicsObjectData` Resource. `MarbleData` (which extends `CardData`) will contain a `@export var physics: PhysicsObjectData`. `ObstacleData` (not a card) will also contain a `PhysicsObjectData`. The physics engine reads from the component resource without needing a shared object base class.

**Command Pattern Effects**
Cards do not possess hardcoded game logic. Instead, they hold an `Array[EffectData]`. The `EffectHandler` iterates through this array and uses a `Callable` registry to dispatch logic based strictly on the `effect_id` string, passing the `value` and `target` Enum. Adding a new effect means registering a new Callable, never modifying the `EffectHandler` itself.

**Field State Layering**
Map physics (Friction, Stickiness, Gravity, Elasticity) are dynamic. A `FieldStateManager` autoload/node recalculates global physics states using the additive formula: `Map Base + Terrain Delta + Sum(Active AOE Deltas)`. Properties are pushed to Godot's engine primitives only when a layer changes, avoiding expensive per-tick physics polling.

**Full SignalBus Observer Pattern**
No node shall store a reference to a sibling or cousin. All cross-system communication routes through the `SignalBus` autoload. 

**Server-Authoritative Match State**
Godot State Charts runs the match FSM **on the server only**. Clients receive state integers via RPC to update UI. There is no client prediction or lag compensation; the latency of waiting for server confirmation is imperceptible and acceptable in a turn-based context.

---

## 3. Technology Stack & Plugins

### Engine
- **Godot 4.6** — GL Compatibility Renderer (Target: PC Desktop; Web/Mobile supported)
- **Physics:** Native Godot 2D Physics (`RigidBody2D`, `Area2D`). 

### Plugins
| Plugin | Role | Scope |
|---|---|---|
| **Godot State Charts** | Match FSM | Server-side only; clients receive enum via RPC |
| **Card Framework 1.3.3** | UI / Card rendering | Replaces custom dragging logic; manages Hand/Pile UI |
| **Phantom Camera (v0.6+)** | Camera Management | Simplifies Cinemachine-style transitions between Field Overview and Fine-Tune Aim views via `priority` swapping. |
| **YARD (Yet Another Resource DB)**| Data Querying | Creates a fast, searchable index of `.tres` cards. Replaces manual directory parsing for the Deck Builder. |
| **GUT 9.6.0** | Unit & integration tests | Deferred to Polish Phase (Phase 6) |
| **GDScript Linter** | Static code quality | Active; warnings-only (Exit 1 allowed) during rapid dev |

*(Note: Beehive, GDSync, Input Helper, and Panku Console have been explicitly excluded from the project scope).*

---

## 4. Locked Decisions

| # | Topic | Decision |
|---|---|---|
| D1 | Stickiness Implementation | Additive map/AOE stickiness is applied directly as a `linear_damp` modifier to `RigidBody2D` instances via the `FieldStateManager`. |
| D2 | Gravity Implementation | The playing field is wrapped in an `Area2D` with `gravity_override = true`. `FieldStateManager` updates its directional vector and magnitude. |
| D3 | Effect Targeting | Marbles do not track owners. `EffectData` utilizes an Enum: `Target { KNOCKER, OPPONENT, BOTH, FIELD }`. Harm/Benefit is determined inherently by the effect `value` (e.g., negative health is harmful). |
| D4 | Multiplier System | A threshold table (e.g., 3/5/7 knocks) managed by `MatchManager` scales the numerical `value` inside the `EffectHandler` for the duration of the turn. |
| D5 | Aiming Mechanics | Aim Phase uses 4 inputs: Map Rotation + Fine-Tune Angle + Flick Slider + Character Power (base modifier). |
| D6 | Single-Player Offline | Implemented via `OfflineMultiplayerPeer`. Operates strictly as a pass-and-play local game. Requires a "Pass Device" UI screen to intercept and hide hand information between turns. |
| D7 | Session Discovery | Matchmaking strictly uses 6-character UDP broadcast Session Keys. Direct IP connect fields are purged from the project. |
| D8 | Object Lifecycle | If the launched shooting marble comes to rest without exiting the field, it sheds its "shooter" state and becomes a standard field marble inside the shared pool. |
| D9 | Marble Reference Safety | `GameState.active_marble` must be implemented as a computed property backed by a `WeakRef` internally to prevent use-after-free hazards during ejection or freeing. |
| D10 | Input/Prediction Throttling | `update_prediction()` calls must be throttled by a threshold logic; updates fire only when the difference between the current flick pull and `prev_pull` exceeds 0.01. |
| D11 | Anti-Overlap Spawning | The `MatchManager` or a utility module must implement a `find_valid_position()` algorithm that checks for existing `RigidBody2D` overlaps before instantiating new marbles on the field. |


---

## 5. Phase Roadmap

Each phase builds a functional pillar of the game. **Do not advance to the next phase until the current phase's objectives are manually verified.**

### Phase 0: Scaffolding & Data Schema
**Goal:** Setup project structure, Linter, Plugins, and base Resource definitions.
1. Initialize Godot 4.6 project. Setup standard directories (`scenes/`, `scripts/`, `resources/`, `assets/`, `autoloads/`).
2. Install GDScript Linter (set to warnings-only).
3. Install **YARD** and configure the Card Registry pointing to `res://resources/cards/`.
4. Create fundamental Resource definitions:
   - `EffectData.gd` (`effect_id: String`, `value: float`, `target: TargetEnum`)
   - `PhysicsObjectData.gd` (`friction`, `stickiness`, `gravity_modifier`, `elasticity`, `weight`)
   - `CardData.gd` (`type: CardTypeEnum`, `mana_cost: int`, `effects: Array[EffectData]`)
   - `MarbleData.gd` (extends `CardData`, adds `@export var physics: PhysicsObjectData`)
   - `CharacterData.gd` (`health`, `mana`, `power: float`)

### Phase 1: Lobby & Deck Management
**Goal:** Implement Session Key matchmaking, character select, and deck building.
1. `NetworkManager.gd`: ENet Host/Client setup with UDP broadcast for 6-character Session Keys.
2. Implement Main Menu and Matchmaking Lobby UI.
3. Implement Character Selection UI.
4. Implement Deck Builder UI using YARD queries to populate available cards. Build the Private Deck and the fixed-size Public Marble Pool.
5. Implement `OfflineMultiplayerPeer` path with the "Pass Device" UI screen for local play.

### Phase 2: Match Flow (FSM)
**Goal:** Godot State Charts setup and server-authoritative phase transitions.
1. Install Godot State Charts. Create the Match FSM (`Init → Draw → Play → Aim → Simulating → EndTurn`) on the server.
2. `MatchManager.gd`: Manage state progression. Clients send action RPCs (`_request_next_phase`), Server validates and triggers state transitions. Server broadcasts `_sync_state.rpc()`.
3. Implement turn order, active player tracking, and server-side mana generation.

### Phase 3: Field & Aiming Mechanics
**Goal:** Map simulation, aiming mechanics, Phantom Camera, and physics layering.
1. Implement Map scene. Wrap field in `Area2D` for custom gravity.
2. Create `FieldStateManager.gd`. Implement calculation logic: `Map Base + Terrain Delta + Sum(Active AOE Deltas)`. Push updates to `Area2D` and RigidBodies on state change.
3. Install **Phantom Camera (v0.6+)**. Setup `PhantomCamera2D` nodes for the Board Overview and Shooter Focus. Manage swapping by adjusting camera `priority` based on the Match Phase.
4. Implement Aim Phase UI: Map rotation, fine-tune angle offset, and flick strength slider.
5. Implement shot execution: `impulse = (slider_val + char.power)`. Add logic ensuring un-exited marbles join the field pool.

### Phase 4: Card Framework Integration
**Goal:** UI card handling and server-authoritative play validation.
1. Install Card Framework 1.3.3. Write a custom `CardFactory` that parses `CardData.tres`.
2. Implement Hand UI and dragging into the play area.
3. Server-side deck management: Deal cards, validate mana costs upon `_request_play_card` RPC.
4. Implement RPCs to trigger card play animations on the opponent's screen before the effect resolves.
5. Merge players' public decks into a shared randomized marble pool at the `Init` phase.

### Phase 5: Effects & Multipliers
**Goal:** Execute the Command Pattern and calculate multipliers.
1. Create `EffectHandler.gd` with a Dictionary `Callable` registry.
2. Register individual effects (e.g., `"deal_damage"`, `"spawn_obstacle"`, `"apply_aoe"`).
3. Implement Enum routing so effects correctly apply to `KNOCKER`, `OPPONENT`, `BOTH`, or `FIELD`.
4. Implement the Knockout Multiplier tiered table in `MatchManager`. Apply the multiplier to `EffectData.value` dynamically during the `Simulating` phase.
5. Setup AOE duration tracking (decrements turn counters on `EndTurn`, requests `FieldStateManager` recalculation upon expiry).

### Phase 6: Polish & Testing
**Goal:** Turn on strict validation and deploy GUT tests.
1. Install GUT 9.6.0.
2. Write integration tests for:
   - Multiplayer Network Flow (Connection, Lobby, Offline Peer).
   - Turn FSM (State transitions, turn rejection).
   - Physics Stacking (Verifying `FieldStateManager` outputs correct sums).
   - Effect Command Dispatch (Mock effect execution).
3. Configure GDScript Linter to strict mode (Exit 2 on criticals).
4. Clear all remaining technical debt and finalize the codebase.

---

## 6. Testing & Quality Strategy

**Linter Gates**
During Phases 0-5, the GDScript Linter runs in development mode. Warnings are logged to the console, but an exit code of `1` allows development to proceed rapidly without blocking builds. In Phase 6, strict mode is enabled, and all type/syntax warnings must be resolved.

**Test Deferral Strategy**
To allow rapid iteration of the completely overhauled UI and FSM during the greenfield rebuild, GUT tests are deliberately deferred to Phase 6. During Phases 1-5, developers will rely strictly on Godot's **"Run Multiple Instances" (Host + Client)** debug tool to verify multiplayer logic manually at the end of each Phase.

---

## 7. Code Standards

### Type Annotations
Strict static typing is mandatory. Return types must be explicitly declared.
```gdscript
var health: int = 20

func take_damage(amount: int) -> void:
    health -= amount
```

### SignalBus Observer Pattern
Hardcoded paths (e.g., `$"../Node"`) are strictly forbidden. All cross-system events must route through the global `SignalBus.gd` autoload.
```gdscript
# Emitting from a Marble Node
SignalBus.marble_knocked_out.emit(marble_id, knocker_id)

# Listening from the MatchManager
func _ready() -> void:
    SignalBus.marble_knocked_out.connect(_on_marble_knocked_out)
```

### Server Authority & RPCs
State mutations happen exclusively on the Server. Client-to-Server RPCs must validate the sender.
```gdscript
@rpc("any_peer", "call_local", "reliable")
func _request_play_card(card_id: String) -> void:
    if not multiplayer.is_server(): 
        return
    
    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id != active_player_id:
        push_warning("Out of turn play request from: ", sender_id)
        return
        
    # Proceed with server-side validation...
```

### Signal Connection Cleanup
* All nodes connecting to `SignalBus` or other Autoload signals in `_ready()` **must** explicitly disconnect in `_exit_tree()`.
* This prevents "orphan" callbacks where freed nodes attempt to execute logic, causing crashes in long-running multiplayer sessions.

### Input Efficiency
* Per-frame physics polling or UI updates (such as trajectory prediction) should be gated by state-change checks or numerical delta thresholds (e.g., the 0.01 pull delta).
* Explicit type annotations and static typing remain mandatory for all new logic.

### Memory Hazard Prevention
* Direct raw node references to transient physics objects (Marbles) are forbidden.
* Use `WeakRef` or `instance_id` tracking for any object that may be ejected or freed during a simulation step.