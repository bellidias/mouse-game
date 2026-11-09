extends Node
# Controla o botão de pausa. Este nó (e a CanvasLayer) rodam mesmo com o jogo pausado.

@onready var botao: Button = $BotaoPausa
@onready var overlay: Control = $Overlay
@onready var botao_continuar: Button = $Overlay/Continuar
@onready var botao_reiniciar: Button = $Overlay/Reiniciar
@onready var botao_sair: Button = $Overlay/Sair


func _ready():
	botao.pressed.connect(alternar_pausa)
	botao_continuar.pressed.connect(alternar_pausa)
	botao_reiniciar.pressed.connect(reiniciar)
	botao_sair.pressed.connect(sair)
	overlay.visible = false


# Esc também pausa / despausa
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		alternar_pausa()
		get_viewport().set_input_as_handled()


func alternar_pausa():
	get_tree().paused = not get_tree().paused
	overlay.visible = get_tree().paused
	# O botão "Pausar" do canto some enquanto o menu de pausa está aberto
	botao.visible = not get_tree().paused


func reiniciar():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://cenas/jogo.tscn")


func sair():
	get_tree().quit()
