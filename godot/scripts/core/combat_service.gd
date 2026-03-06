class_name CombatService
extends RefCounted

func resolve(attacker, defender, defender_terrain: String, rules, rng: RandomNumberGenerator) -> Dictionary:
	var defense_bonus := rules.terrain_defense_bonus(defender_terrain)
	var attack_roll := attacker.attack + rng.randi_range(1, 4) + int(attacker.hp / 3)
	var defense_roll := defender.attack + defense_bonus + rng.randi_range(1, 3) + int(defender.hp / 4)

	var dealt := max(2, attack_roll - int(defense_roll / 2))
	var retaliation := max(1, int(defense_roll / 2))

	defender.hp -= dealt
	attacker.moves_left = 0
	if defender.hp > 0:
		attacker.hp -= retaliation

	return {
		"damage_to_defender": dealt,
		"damage_to_attacker": retaliation if defender.hp > 0 else 0,
		"defender_died": defender.hp <= 0,
		"attacker_died": attacker.hp <= 0,
	}
