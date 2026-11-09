extends Node2D



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Rato":
		print("comeu migalha!")
		get_tree().current_scene.ganhar_vida()
		queue_free()
