extends Node2D
## Draw the same rung grid that the character grips; this adds no interaction.
const LADDER=preload("res://scripts/core/ladder_geometry.gd")
func _draw() -> void:
	var level=get_parent().get_parent()
	for rect in level.ladders:
		LADDER.draw(self,rect,Color("ad9e73"),rect in level.side_ladders)
