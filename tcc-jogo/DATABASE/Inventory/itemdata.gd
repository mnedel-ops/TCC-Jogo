class_name ItemData
extends Resource

@export var index: int = 0
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var icone: Texture2D   # opcional: sem icone a UI mostra uma letra
@export var heal_amount: int = 0   # HP curado em combate. 0 = nao faz nada (itens genericos)

#Codigo para gerar os itens. Todo item herda este codigo, basta criar um
#resource para o novo item.
