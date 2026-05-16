extends Node

# -- Network events --
signal server_started()
signal connected_to_server()
signal connection_failed(reason: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

# -- Session discovery --
signal session_key_updated(key: String)

# -- Lobby --
signal player_ready_changed(player_id: int, ready: bool)
signal match_started()

# -- Character selection --
signal character_selected(player_id: int, character: CharacterData)

# -- Phase transitions --
signal phase_changed(phase: int)
signal phase_advance_requested(event: String)
signal turn_changed(player_id: int)
signal device_passed(next_player_id: int)

# -- Field & marble events --
signal marble_exited_boundary(marble: Marble)
signal simulation_complete(final_state: Dictionary)

# -- Aim input events --
signal aim_inputs_changed(rotation_degrees: float, flick_power: float)
