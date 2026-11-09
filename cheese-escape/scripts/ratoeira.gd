extends Node2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Rato":
		get_tree().current_scene.perder_vida("Ai! Ratoeira!")
		queue_free()
