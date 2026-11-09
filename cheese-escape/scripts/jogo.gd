extends Node2D

# Vidas do rato
@export var vidas: int = 3
@export var vidas_maximas: int = 5

@onready var rato = $Rato
@onready var label_vidas: Label = $CanvasLayer/LabelVidas


func _ready():
	atualizar_ui()
	print("Cheese-Escape iniciado! Vidas: ", vidas)


# Atualiza o texto da label que mostra as vidas na tela
func atualizar_ui():
	label_vidas.text = "Vidas: " + str(vidas)


# Chamada pela ratoeira e pelo gato quando o rato é atingido
func perder_vida(motivo: String = ""):
	vidas -= 1
	atualizar_ui()
	print(motivo, " Vidas restantes: ", vidas)

	if vidas <= 0:
		derrota("Perdeu todas as vidas!")
		return

	piscar_rato(Color.RED)


# Chamada pela migalha quando o rato come
func ganhar_vida():
	if vidas < vidas_maximas:
		vidas += 1
	atualizar_ui()
	print("Migalha coletada! Vidas: ", vidas)
	piscar_rato(Color.GREEN)


# Deixa o rato de outra cor por um instante (feedback visual)
func piscar_rato(cor: Color):
	rato.modulate = cor
	await get_tree().create_timer(0.2).timeout
	rato.modulate = Color.WHITE


func vitoria():
	print("VITÓRIA! Comeu o queijo!")
	get_tree().change_scene_to_file("res://cenas/vitoria.tscn")


func derrota(motivo: String):
	print("DERROTA: ", motivo)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://cenas/derrota.tscn")


# Essa função vai ser chamada pela Ratoeira pra aumentar dificuldade
func _on_timer_spawn_timeout():
	var nova = preload("res://cenas/ratoeira.tscn").instantiate()
	# Pega uma posição aleatória no labirinto
	nova.global_position = Vector2(randf_range(100, 600), randf_range(100, 500))
	add_child(nova)
