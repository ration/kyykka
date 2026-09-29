extends GutTest

var _saved: Array[String]


func before_each() -> void:
	_saved = GameMode.team_names.duplicate()


func after_each() -> void:
	GameMode.team_names = _saved


func test_names_are_trimmed_and_capped() -> void:
	GameMode.set_team_names("  Teekkarit  ", "x".repeat(50))
	assert_eq(GameMode.team_names[0], "Teekkarit")
	assert_eq(GameMode.team_names[1].length(), GameMode.MAX_TEAM_NAME_LENGTH)


func test_blank_names_fall_back_to_defaults() -> void:
	GameMode.set_team_names("", "   ")
	assert_eq(GameMode.team_names, GameMode.DEFAULT_TEAM_NAMES)


func test_duplicate_names_are_told_apart() -> void:
	GameMode.set_team_names("Kylteri", "kylteri")
	assert_eq(GameMode.team_names[0], "Kylteri")
	assert_eq(GameMode.team_names[1], "kylteri 2")
