extends Node2D



func _on_reiniciar_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/jogo.tscn")


func _on_sair_pressed() -> void:
	get_tree().quit()
