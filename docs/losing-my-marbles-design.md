# Losing My Marbles! — Game Design Document
**Version:** 3.0 | **Updated:** May 2026
**Authors:** Keith Ashly Domingo, Adriel Neyro Caraig (FakeThird, iskwipi)

---

## Table of Contents

1. [Executive Overview](#1-executive-overview)
2. [Core Gameplay Loop](#2-core-gameplay-loop)
3. [Player Goals](#3-player-goals)
4. [Game Elements](#4-game-elements)
5. [Game Mechanics](#5-game-mechanics)
6. [Game Systems](#6-game-systems)
7. [Network Architecture](#7-network-architecture)
8. [Genre & Inspirations](#8-genre--inspirations)
9. [Feasibility & Risks](#9-feasibility--risks)
10. [Scope Management](#10-scope-management)

---

## 1. Executive Overview

**Title:** Losing My Marbles!
**Tagline:** "For all the marbles. Just flick."
**Hook:** A turn-based, multiplayer deck-builder reimagining of the Filipino game *Holen*. Players build strategic card hands to manipulate the playing field, then execute precise marble shots in a simulated 2D physics environment. Every card played sets up the shot; every shot determines what cards matter next.

**Platform:** PC Desktop (primary). Mobile and Web supported via GL Compatibility rendering.
**Players:** 2 players (LAN multiplayer via Session Keys). Local Offline supported via pass-and-play.
**Turn Structure:** Fully turn-based. One player acts at a time. No real-time elements during decision phases.

### Design Pillars

- **Tactical depth from simple inputs.** The depth comes entirely from card choices made before the shot and the fine-tuning of aim and flick strength.
- **Physics as the great equalizer.** No amount of card advantage guarantees a shot outcome. Genuine uncertainty must be planned around.
- **Mayhem is the point.** Cards are designed to cause chaos — terrain shifts, sticky traps, marble swaps, and gravity anomalies.

---

## 2. Core Gameplay Loop

The loop is structured around a single player's turn, divided into distinct phases. Both bullets (b) and (c) below can repeat multiple times per turn as long as the player has sufficient mana.

```
a) DRAW     → Player draws cards from their private deck; mana is generated
b) PLAY     → Player spends mana to play cards (altering field, preparing shot)
              → Played cards display animations on both players' screens
c) AIM      → Player fine-tunes aim (map rotation + ball angle) and sets flick strength slider
              → Physics simulation runs; marbles bounce, stick, and are knocked out
              → Knocked-out marble effects trigger (applying to KNOCKER, OPPONENT, or BOTH)
              → Multiplier thresholds trigger if enough marbles are knocked out
              → If shooting marble doesn't exit, it becomes a permanent field marble
              → If field is empty, refill from the shared public marble pool
d) END TURN → Unplayed cards reshuffle into private deck; remaining mana discards
              → Next player's turn begins
```

A player may perform multiple AIM/PLAY cycles per turn. After completing as many shots as they can resource, they end their turn voluntarily.

---

## 3. Player Goals

### Before a Match
- **Character Selection:** Choose a character whose *Mana* and *Power* stats, alongside their exclusive card pool, fit the intended strategy.
- **Deck Building (Private):** Construct a deck with a clear win condition (field control, area-of-effect stacking, high-burst damage).
- **Deck Building (Public):** Fill a fixed-size public deck with owned marbles. These will populate the shared field pool.

### During a Match
- Knock opposing marbles off the field to trigger their effects and deal damage to your opponent.
- Protect your own health total from reaching zero.
- Manipulate physics (gravity, stickiness, friction) using Terrain and Area-of-Effect cards.
- Execute precise shots utilizing the character's *Power* modifier combined with the flick slider.

### Win Condition
- A player is eliminated when their health reaches zero.
- The last player with health remaining wins.

---

## 4. Game Elements

### 4.1 The Map & Field State
The playing field where all marbles and obstacles exist and interact. Properties are stacked additively using the formula: `Effective Value = Map Base + Terrain Delta + Sum(Active AOE Deltas)`.

| Property | Description |
|---|---|
| Friction | How quickly moving bodies lose velocity over time |
| Stickiness | Environmental dampening (e.g., honey traps) that drastically limits movement |
| Gravity | Directional pull (or anomalies) altering marble trajectories |
| Elasticity | Bounciness of the field boundaries |

### 4.2 The Character
Each player selects one character before a match begins.

| Property | Description |
|---|---|
| Health | Starting life total; losing all health = elimination |
| Mana | Amount generated per turn; determines how many cards can be played |
| Power | Base modifier added to the flick slider to determine final shot impulse |
| Exclusive Cards | A set of cards only accessible when this character is selected |

### 4.3 The Decks

#### Public Deck (Shared Pool)
- Fixed size for all players. Players populate it exclusively with owned Marble cards.
- At match start, the system secretly combines all players' public decks into a single shared marble pool (no manual reveal required).
- Marbles are drawn from this pool to populate the field initially and refill it when empty.

#### Private Deck
- Contains Marbles, Power-Ups, Tricks, Terrains, and Area-of-Effects (AOEs).
- The player draws from this deck at the start of each turn.
- When the private deck is exhausted, all consumed cards reshuffle back into it.
- Never visible to opponents (hidden information).

### 4.4 Physics Objects (Marbles & Obstacles)
Both marbles and obstacles share underlying physics properties, allowing them to interact smoothly within the physics engine. They are decoupled from card logic:
- **Marbles:** Spawned from the shared pool. They **do not track ownership**.
- **Obstacles:** Static or dynamic non-card objects placed by the Map or Trick cards (e.g., bumpers, walls).

### 4.5 Cards & The Command Pattern
Cards are the primary strategic resource. They do not have hardcoded game logic; instead, they possess an array of *Effects*. Each effect is an isolated Command defined by:
- `effect_id`: Internal identifier (e.g., "deal_damage", "spawn_obstacle").
- `value`: Numerical scaling (handles whether it's harmful or beneficial, e.g., `-5` health vs `+5` health).
- `target`: Enum dictating who/what receives the effect (`KNOCKER`, `OPPONENT`, `BOTH`, `FIELD`).

### 4.6 Card Types

1. **MARBLE:**
   - **Active (In Hand):** Modifies the properties of the marble the player is about to shoot.
   - **Passive (On Field):** Places a marble into the public pool. Has physics properties and an effect array that automatically fires when the marble is knocked off the field.

2. **POWER_UP:**
   - Buffs or modifies the current shooting marble (e.g., increase power, add a ricochet modifier).

3. **TRICK:**
   - Instant-execution effects targeting the field, decks, or game state (e.g., swap field marbles, spawn obstacles, destroy opponent's deck cards).

4. **TERRAIN:**
   - Global field modifier. **Only one active at a time.** Replaces the previous Terrain card. Acts as a delta on Map base properties until overridden or match ends.

5. **AREA_OF_EFFECT (AOE):**
   - Persists for a set number of *Turns*.
   - Modifies physics properties (stickiness, gravity, friction) locally or globally.
   - **Multiple AOEs stack additively** alongside the active Terrain and Map base.

---

## 5. Game Mechanics

### 5.1 Match Initialization

1. A map is randomly selected. Its base surface properties are applied immediately.
2. The system merges players' public decks into the shared marble pool and shuffles.
3. A set number of marbles are drawn from the pool and placed randomly on the field.
4. Turn order is randomly determined and broadcasted.
5. Players receive starting health. Mana begins at zero.

### 5.2 Player Turn (Detailed)

**DRAW Phase:**
- Player draws from their private deck.
- Mana pool fills based on character stat.
- If deck is empty, discard pile immediately reshuffles to refill.
- If the private deck is exhausted and the discard pile is empty, the player draws only the available cards (no partial draw crash).

**PLAY Phase:**
- Player may play cards as long as mana permits.
- Card play animations trigger on both players' screens.
- Only one MARBLE card may be played per shot.
- Only one TERRAIN may be active. AOEs stack based on their duration parameters.

**AIM Phase:**
- **Map Rotation:** Player rotates the entire map environment to find their preferred angle.
- **Fine-Tune Angle:** Player adjusts a secondary control to precisely tune the ball launch direction.
- **Flick Slider:** Player sets the strength. The final force applied is `slider_value + character.power`.
- **Visual Feedback:** A trajectory prediction raycast is rendered to preview the initial path and the first bounce angle before shot execution.

**SIMULATING Phase:**
- Physics simulation runs (uninterruptible).
- Knocked-out marbles trigger their passive effects (applying to `KNOCKER`, `OPPONENT`, `BOTH`, or `FIELD`).
- Multiplier tracks how many marbles are knocked out. Reaching threshold tiers (e.g., 3, 5, 7) boosts the `value` of subsequent effects.
- If the shooting marble **fails to exit the field**, it loses its "shooting" status and stays on the playing field as a normal marble.
- If the shooting marble exits the field boundary, it is despawned normally. Passive effects do not trigger for shooting marbles that go out-of-bounds.
- If the field is empty, new marbles are drawn from the shared pool.

**END TURN:**
- AOE durations tick down. Expired AOEs are removed from the Field State stack.
- Unplayed hand cards shuffle back into the private deck. Unused mana discards.

### 5.3 Offline / Pass-and-Play Mechanic

Single-player mode allows one user to control both sides. Because hands and private decks are hidden information, transitioning turns invokes a "Pass Device" UI screen. The game board and UI are completely hidden until the player confirms they are ready to begin the next turn, preventing accidental intelligence gathering.

---

## 6. Game Systems

### 6.1 State Machine
Governs the flow of a match enforcing phase transitions (`Init → Draw → Play → Aim → Simulating → EndTurn`). The server is the absolute authority. Clients request state changes; the server validates, executes, and replicates the new state to clients via RPC.

### 6.2 Physics Engine & Field State Manager
Simulates all physical interactions strictly via 2D engine primitives:
- **FieldStateManager:** An active system that constantly aggregates properties (`Effective Value = Map Base + Terrain Delta + Sum(AOE Deltas)`).
- **Stickiness:** Applied via dynamic `linear_damp` updates on RigidBody2D nodes.
- **Gravity:** Applied by wrapping the field in an `Area2D` with `gravity_override = true` and modulating its parameters.

### 6.3 Effect Handler (Command Pattern)
A stateless dispatcher utilizing a `Callable` registry. Instead of hardcoded logic, it reads the `EffectData` resource from a card and dispatches execution based on the `effect_id` string, passing the numerical `value` and routing it according to the `target` Enum.

### 6.4 Card System
Manages private deck draw/reshuffle logic, mana verification, and card lifecycle. The server maintains an authoritative dictionary of all players' hands to prevent cheating or desyncs.

### 6.5 User Interfaces
- **Matchmaking / Lobby:** Interface to share/input the 6-character Session Key.
- **Deck Builder:** Pre-match interface to populate the fixed-size Public Marble deck and craft the Private Deck.
- **Character Select:** Pre-match interface choosing stats and exclusive card pool.

#### 6.6 HUD Element Specification
The Main HUD must provide real-time access to the following critical parameters without obscuring the field:

* **Vitals:** Current health total and current mana pool.
* **Context:** Active phase indicator and turn order status.
* **Interactive:** Hand display (drag-and-drop cards) and aiming overlay.
* **Session Data:** Multiplier counter and current 6-character Session Key.

---

## 7. Network Architecture

### 7.1 Model
Server-authoritative host-client model over **ENet (UDP)**. One player hosts (running server logic + local client); the other connects as a client. 

### 7.2 Session Discovery
The game exclusively uses **6-character Session Keys** broadcast via UDP. Direct IP connection fields are intentionally removed to streamline UX and prevent network exposure mistakes.

### 7.3 Authority Model
The server dictates all critical game states:
- Match phases and turn orders.
- Health, mana, and multiplier thresholds.
- Card play validity and effect execution.
- Physics outcomes (Simulated on the host, results broadcast to client).

### 7.4 RPC Communication Pattern

| Direction | RPC Type | Purpose |
|---|---|---|
| Server → All clients | `@rpc("authority", "call_local")` | State sync, stat sync, confirmed card plays, **card animations** |
| Client → Server | `@rpc("any_peer", "call_local")` | Phase advance requests, card play requests |
| Lateral (UI) | Signals | Local drag-and-drop or slider adjustments |

### 7.5 Offline / Single Player
Utilizes Godot's `OfflineMultiplayerPeer`. No network traffic is generated. Relies entirely on the Pass-and-Play UI intercept to handle local turn sharing without AI opponents.

---

## 8. Genre & Inspirations

**Primary Genre:** Turn-Based Strategy / Deck Builder
**Secondary:** Simulated Physics, Casual Competitive

| Reference | What We Take |
|---|---|
| **Kabuto Park** | Overall visual vibe; the sensation of marbles as characters with personality |
| **Peglin** | Marble varieties with inherent physics properties interacting with environmental elements |
| **Balatro** | The setup-and-payoff structure; cascading multipliers turning good setups into great payouts |
| **Pokémon TCGP / Slay the Spire** | Deck construction as strategic preparation; variance producing different viable tactics |

**What Makes This Different:**
Unlike purely card-based games, perfect card play does not guarantee perfect outcomes due to the physics layer. Unlike purely physics-based games, the card layer provides deep pre-shot decisions, AOE layering, and environmental manipulation.

---

## 9. Feasibility & Risks

### 9.1 Technical Risks

**Physics State Stacking (Stickiness/Gravity)**
Dynamically calculating and applying physics overwrites across multiple overlapping AOEs and Terrain cards can lead to jitter or desync if applied improperly.
*Mitigation:* The `FieldStateManager` aggregates all values into a single delta *before* pushing updates to `linear_damp` or `Area2D` gravity parameters, avoiding conflicting physics engine ticks.

**Network State Synchronization**
Ensuring physics outcomes visually align between Host and Client.
*Mitigation:* Physics runs exclusively on the server. Clients receive final positions and knockout events, trading visual millisecond-smoothness for absolute competitive correctness.

**Card Balance with Multipliers**
High-tier multipliers combined with powerful AOE effects risk exponential numeric scaling.
*Mitigation:* The Multiplier tier table is stored as an easily adjustable data dictionary. Effect strengths are modified via generic Resource values, requiring no code recompilation to balance.

### 9.2 Feasibility Milestones

| Phase | Target |
|---|---|
| **Phase 1** | Session Key network lobby, Character Select, and Deck Builder UIs. |
| **Phase 3** | Functional Map simulation, FieldStateManager (Stickiness/Gravity), and Aiming inputs. |
| **Phase 5** | Fully integrated Command Pattern Effect Handler, Card plays, and Multiplier System. |
| **Phase 6** | End-to-end Pass-and-Play and Multiplayer verification, strict-mode linter compliance. |

---

## 10. Scope Management

### 10.1 Minimum Viable Product (MVP)
A complete, playable 2-player game demonstrating all core rebuilt mechanics:
- Network Lobby (Session Key) and Pass-and-Play Offline mode.
- Character Select and Deck Builder UIs.
- 2 sample Characters (different Mana/Power stats).
- All 5 Card Types (Marble, Power-Up, Trick, Terrain, AOE).
- Physics Simulation with Additive Stacking (Friction, Stickiness, Gravity).
- Fully functional Aim phase (Map Rotation, Angle Fine-tune, Flick Slider).
- Knockout Multiplier System and Un-exited Marble logic.

### 10.2 Stretch Goals
- Expanded card library and diverse Maps with baked-in physical obstacles.
- Deep visual polish (Particle effects, screen shakes on heavy collisions).
- Match history and post-game statistics screen.
- Enhanced sound design corresponding to varying impact forces.

### 10.3 Maximum Final Product (Long-Term Vision)
- Online multiplayer via dedicated cloud matchmaking.
- Player accounts with persistent card collections.
- Ranked matchmaking and seasonal competitive play.
- Progressive PvE AI campaigns.

### 10.4 Explicitly Excluded (All Scopes)
- Direct IP entry for network connections.
- 3D physics simulation.
- Real-time action gameplay.
- AI Opponent Behavior Trees (Beehive).
- Cloud Account / External Server persistence (GDSync).