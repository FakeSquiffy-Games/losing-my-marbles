# Enums.gd — Global enum definitions.
# Autoloaded as "Enums" for project-wide access without circular dependencies.

enum TriggerEnum {
    PLAY,
    SIMULATION
}

enum TargetEnum {
    SELF,
    OPPONENT,
    CURR_MARBLE,
    KNOCKER,
    KNOCKER_OPP,
    BOTH,
    FIELD_MAP,
    FIELD_MARBLES
}

enum CardTypeEnum {
    MARBLE,
    POWER_UP,
    TRICK,
    TERRAIN,
    AREA_OF_EFFECT
}

enum MatchState {
    INIT,
    DRAW,
    PLAY,
    AIM,
    SIMULATING,
    END_TURN,
    MATCH_OVER
}
