extends Node

enum Mode { CAMPAIGN, PROCEDURAL }
enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_INFO := {
	Difficulty.EASY: {
		"label": "FÁCIL",
		"grid": "5×5",
		"desc": "Sin abismos, pocos muros y rutas directas (3–5 pasos)."
	},
	Difficulty.NORMAL: {
		"label": "NORMAL",
		"grid": "6×6",
		"desc": "Abismos moderados, bloques de apoyo y síntesis media (5–9 pasos)."
	},
	Difficulty.HARD: {
		"label": "DIFÍCIL",
		"grid": "7×7",
		"desc": "Alta densidad de muros, 3–6 abismos y múltiples acoples (8+ pasos)."
	}
}

const SAVE_PATH := "user://save.cfg"

var mode: Mode = Mode.CAMPAIGN
var difficulty: Difficulty = Difficulty.NORMAL

var perfect_streak: int = 0
var best_streak: int = 0


func _ready() -> void:
	_load_save()


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_streak = int(cfg.get_value("records", "best_streak", 0))


func _save_records() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_streak", best_streak)
	cfg.save(SAVE_PATH)


func start_campaign() -> void:
	mode = Mode.CAMPAIGN
	perfect_streak = 0


func start_procedural(diff: Difficulty) -> void:
	mode = Mode.PROCEDURAL
	difficulty = diff
	perfect_streak = 0


func register_level_clear(was_perfect: bool) -> void:
	if was_perfect:
		perfect_streak += 1
		if perfect_streak > best_streak:
			best_streak = perfect_streak
			_save_records()
	else:
		perfect_streak = 0


func reset_streak() -> void:
	perfect_streak = 0


func get_difficulty_info(diff: Difficulty = difficulty) -> Dictionary:
	return DIFFICULTY_INFO.get(diff, DIFFICULTY_INFO[Difficulty.NORMAL])
