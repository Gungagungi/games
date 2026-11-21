extends Node
## Signaux globaux, comme dans la v2 : chaque système émet ou écoute ici sans
## connaître les autres. Les positions sont des Vector3 du monde.

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal enemy_died(position: Vector3, color: Color, size: float)
signal player_stats_changed()
signal player_hurt()
signal player_died()
signal upgrade_taken(id: String)
signal screen_shake_requested(amount: float)
signal float_text_requested(position: Vector3, text: String, color: Color)
