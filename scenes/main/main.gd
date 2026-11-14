extends Control
## Scène principale (point d'entrée). Vide pour l'instant :
## elle accueillera l'écran titre puis la navigation vers la carte du monde.


func _ready() -> void:
	$Version.text = "v%s" % Game.VERSION
