extends Node
## Signaux globaux. Évite que les systèmes se connaissent les uns les autres :
## chacun émet ou écoute ici, là où la v1 faisait des appels directs.

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal enemy_died(position: Vector2, is_boss: bool)
signal boss_spawned(boss: Node, display_name: String, max_hp: float)
signal boss_hp_changed(ratio: float)
signal boss_phase_changed(phase: int, phase_count: int)
signal boss_defeated()
signal player_stats_changed()
signal player_died()
signal upgrade_taken(id: String)
signal screen_shake_requested(amount: float)
signal float_text_requested(position: Vector2, text: String, color: Color)
