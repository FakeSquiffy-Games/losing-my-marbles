This API documentation provides a comprehensive overview of the **YARD (Yet Another Resource Database)** plugin for Godot 4.x. YARD is designed to bridge the gap between simple preloaded resource lists and complex external databases, providing a structured, editor-integrated way to manage and query Godot Resources.

---

# Registry
**Inherits:** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)

A collection of resources grouped by class, providing a spreadsheet-like editor interface and a high-performance runtime API for querying and loading.

## Brief Description
The `Registry` is the core data structure of YARD. It stores references to resources using stable string IDs and UIDs, allowing for efficient filtering and loading without the overhead of preloading every resource in the collection.

## Detailed Description
YARD operates on two levels:
1.  **Editor-Side:** It provides a table view to manage resources. You can sync a registry with a specific directory, restrict it to a specific [Resource] type, and "bake" property indexes.
2.  **Runtime-Side:** The `Registry` exists as a `.tres` file. It does not contain the actual resource data but rather a map of IDs to UIDs. This allows you to query the database (e.g., "find all items with rarity 'Legendary'") without loading the actual resource files into memory until they are needed.

## Properties

| Type | Property | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `String` | `class_restriction` | `""` | Limits the registry to a specific class name. Only resources of this type (or its subclasses) can be added. |
| `String` | `scan_directory` | `""` | The project path (e.g., `res://data/items/`) to automatically sync resources from. |
| `PackedStringArray` | `indexed_properties` | `[]` | A list of property names whose values are baked into the registry for zero-cost runtime filtering. |

## Methods

### Lookup & Validation
- **has(id: Variant) -> bool**  
  Returns `true` if the provided string ID (`StringName`) or UID (`int`) exists in the registry.
- **has_string_id(string_id: StringName) -> bool**  
  Returns `true` if the specific string ID exists.
- **has_uid(uid: int) -> bool**  
  Returns `true` if the specific Resource UID exists.
- **get_uid(id: Variant) -> int**  
  Resolves a string ID or UID to its internal Godot UID. Returns `-1` if not found.

### Loading
- **load_entry(id: Variant) -> Resource**  
  Synchronously loads and returns the resource associated with the given ID.
- **load_all_blocking() -> Array[Resource]**  
  Loads every resource in the registry immediately. Warning: This may cause frame drops for large registries.
- **load_all_threaded_request() -> RefCounted**  
  Initiates an asynchronous background load of all resources. Returns a tracker object (typically used to check progress or completion).

### Querying & Filtering
*Note: Filtering methods require the target properties to be defined in `indexed_properties` and baked in the editor.*

- **is_property_indexed(property: StringName) -> bool**  
  Returns `true` if the specified property has been baked into the runtime index.
- **filter_by_value(property: StringName, value: Variant) -> PackedStringArray**  
  Returns an array of string IDs for all entries where the indexed `property` exactly matches `value`.
- **filter_by(property: StringName, predicate: Callable) -> PackedStringArray**  
  Returns an array of string IDs where the `predicate` function returns `true` when passed the property value.  
  *Example predicate:* `func(v): return v >= 10`
- **filter_by_values(criteria: Dictionary) -> PackedStringArray**  
  Performs an "AND" query. Returns string IDs that match all key-value pairs provided in the `criteria` dictionary.

## Examples

### Basic Usage
This example demonstrates how to load a specific resource from a registry using a string ID.

```gdscript
extends Node

# Preload the registry resource created in the editor
const ITEMS: Registry = preload("res://data/item_registry.tres")

func _ready() -> void:
    if ITEMS.has(&"iron_sword"):
        var sword = ITEMS.load_entry(&"iron_sword")
        print("Loaded: ", sword.item_name)
```

### Advanced Filtering
This example shows how to query a registry for specific items without loading them first.

```gdscript
extends Node

const WEAPONS: Registry = preload("res://data/weapon_registry.tres")

func get_legendary_swords() -> Array[Resource]:
    # Query the baked index for multiple criteria
    # This operation is nearly instantaneous and doesn't load the resources
    var ids := WEAPONS.filter_by_values({
        &"rarity": "Legendary",
        &"type": "Sword"
    })
    
    var results: Array[Resource] = []
    for id in ids:
        results.append(WEAPONS.load_entry(id))
    
    return results
```