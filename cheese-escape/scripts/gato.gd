extends CharacterBody2D

@export var velocidade: float = 90.0
# Tamanho de cada quadradinho da grade de navegação (em pixels)
@export var tamanho_celula: float = 8.0
# Células a menos de "raio_obstaculo" de uma parede ficam bloqueadas para o gato
@export var raio_obstaculo: float = 15.0
# De quanto em quanto tempo o gato recalcula o caminho até o rato
@export var intervalo_caminho: float = 0.15
# Raio usado para testar se dá para ir em linha reta sem bater (igual ao corpo do gato)
@export var raio_visao: float = 14.0
# Quantos pontos do caminho à frente o gato tenta "enxergar" em linha reta
@export var alcance_visao: int = 40
# Tempo mínimo entre uma virada de lado e outra (evita ficar virando toda hora)
@export var tempo_minimo_virar: float = 0.3

# A grade cobre a tela inteira (1152x648) + 64px de margem em volta,
# porque o gato começa um pouco fora do labirinto.
const ORIGEM := Vector2(-64, -64)
const TAMANHO_GRADE := Vector2i(160, 96)

@onready var rato = get_parent().get_node_or_null("Rato")
@onready var animacao: AnimatedSprite2D = $Animacao

var matou: bool = false
var grade: AStarGrid2D = null
var caminho: PackedVector2Array = PackedVector2Array()
var tempo_caminho: float = 0.0
var frames_espera: int = 2 # espera a física registrar as paredes antes de montar a grade

var alvo_atual: Vector2 = Vector2.ZERO
var seguindo_direto: bool = false # true = rato visível em linha reta, vai direto nele
var consulta_linha: PhysicsShapeQueryParameters2D = null

var direcao_suave: Vector2 = Vector2.ZERO
var tempo_virar: float = 0.0


func _physics_process(delta):
	if rato == null or matou:
		return

	# Monta a grade uma vez, depois que as paredes já existem na física
	if grade == null:
		frames_espera -= 1
		if frames_espera <= 0:
			criar_grade()
			criar_consulta_linha()
			atualizar_caminho()
		return

	tempo_caminho -= delta
	if tempo_caminho <= 0.0:
		tempo_caminho = intervalo_caminho
		atualizar_caminho()

	var alvo: Vector2 = rato.global_position if seguindo_direto else alvo_atual

	# Chegou perto do alvo: já escolhe o próximo
	if global_position.distance_to(alvo) < 3.0:
		tempo_caminho = 0.0

	var direcao = (alvo - global_position).normalized()
	velocity = direcao * velocidade
	move_and_slide()

	animacao.play("andando")
	atualizar_virada(direcao, delta)
	verificar_colisao_com_rato()


# Vira o sprite para o lado em que o gato anda.
# O desenho olha para a direita. A direção é suavizada e há um tempo mínimo
# entre viradas, para o gato não ficar piscando de um lado para o outro.
func atualizar_virada(direcao: Vector2, delta: float):
	direcao_suave = direcao_suave.lerp(direcao, 0.1)
	tempo_virar -= delta
	if tempo_virar > 0.0:
		return

	if direcao_suave.x < -0.3 and not animacao.flip_h:
		animacao.flip_h = true
		tempo_virar = tempo_minimo_virar
	elif direcao_suave.x > 0.3 and animacao.flip_h:
		animacao.flip_h = false
		tempo_virar = tempo_minimo_virar


# Descobre quais células da grade são parede (testando a colisão de verdade)
func criar_grade():
	grade = AStarGrid2D.new()
	grade.region = Rect2i(Vector2i.ZERO, TAMANHO_GRADE)
	grade.cell_size = Vector2(tamanho_celula, tamanho_celula)
	grade.offset = ORIGEM + grade.cell_size / 2.0
	# Não corta quina de parede nas diagonais
	grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grade.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grade.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grade.update()

	var forma := CircleShape2D.new()
	forma.radius = raio_obstaculo

	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	# Ignora o próprio gato e o rato: só sobram as paredes
	consulta.exclude = [get_rid(), rato.get_rid()]

	var espaco = get_world_2d().direct_space_state

	for x in TAMANHO_GRADE.x:
		for y in TAMANHO_GRADE.y:
			var id := Vector2i(x, y)
			consulta.transform = Transform2D(0.0, centro_da_celula(id))
			if not espaco.intersect_shape(consulta, 1).is_empty():
				grade.set_point_solid(id, true)


# Consulta reutilizada para testar "dá para ir em linha reta até ali?"
func criar_consulta_linha():
	var forma := CircleShape2D.new()
	forma.radius = raio_visao

	consulta_linha = PhysicsShapeQueryParameters2D.new()
	consulta_linha.shape = forma
	consulta_linha.collision_mask = 1
	consulta_linha.exclude = [get_rid(), rato.get_rid()]


func centro_da_celula(id: Vector2i) -> Vector2:
	return ORIGEM + Vector2(id) * tamanho_celula + Vector2(tamanho_celula, tamanho_celula) / 2.0


func celula_de(posicao: Vector2) -> Vector2i:
	var c := Vector2i(((posicao - ORIGEM) / tamanho_celula).floor())
	return c.clamp(Vector2i.ZERO, TAMANHO_GRADE - Vector2i.ONE)


# Se a célula for parede (ex.: rato colado na parede), usa a célula livre mais próxima
func celula_livre_proxima(celula: Vector2i) -> Vector2i:
	if not grade.is_point_solid(celula):
		return celula

	var melhor := celula
	var melhor_dist := INF
	for raio in range(1, 7):
		for dx in range(-raio, raio + 1):
			for dy in range(-raio, raio + 1):
				var v := celula + Vector2i(dx, dy)
				if not grade.is_in_boundsv(v) or grade.is_point_solid(v):
					continue
				var d := Vector2(dx, dy).length()
				if d < melhor_dist:
					melhor_dist = d
					melhor = v
		if melhor_dist < INF:
			break
	return melhor


func atualizar_caminho():
	var origem := celula_livre_proxima(celula_de(global_position))
	var destino := celula_livre_proxima(celula_de(rato.global_position))
	caminho = grade.get_point_path(origem, destino)
	escolher_alvo()


# Em vez de seguir ponto por ponto da grade (o que faz zigue-zague),
# o gato mira no ponto mais distante do caminho que ele consegue alcançar em linha reta.
func escolher_alvo():
	var espaco = get_world_2d().direct_space_state

	# 1) Rato visível em linha reta: vai direto nele
	if linha_livre(espaco, rato.global_position):
		seguindo_direto = true
		return
	seguindo_direto = false

	# 2) Ponto mais distante do caminho que dá para alcançar em linha reta
	var ultimo: int = mini(caminho.size() - 1, alcance_visao)
	for i in range(ultimo, 0, -1):
		if linha_livre(espaco, caminho[i]):
			alvo_atual = caminho[i]
			return

	# 3) Plano B (ex.: gato encostado na parede): primeiro ponto do caminho ainda não alcançado
	alvo_atual = rato.global_position
	for i in range(1, caminho.size()):
		if global_position.distance_to(caminho[i]) > 4.0:
			alvo_atual = caminho[i]
			break


# true se o gato consegue andar em linha reta até "destino" sem bater em parede
func linha_livre(espaco: PhysicsDirectSpaceState2D, destino: Vector2) -> bool:
	consulta_linha.transform = Transform2D(0.0, global_position)
	consulta_linha.motion = destino - global_position
	var resultado = espaco.cast_motion(consulta_linha)
	return resultado.size() >= 2 and resultado[0] >= 0.999


# Encostou no rato = o gato mata o rato na hora
func verificar_colisao_com_rato():
	for corpo in $Area2D.get_overlapping_bodies():
		if corpo.name == "Rato":
			matou = true
			rato.set_physics_process(false) # rato para de andar
			rato.get_node("Animação").play("parado")
			animacao.play("parado")
			rato.modulate = Color.RED
			await get_tree().create_timer(0.4).timeout
			get_tree().current_scene.derrota("O gato pegou o rato!")
			return
