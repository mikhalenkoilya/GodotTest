extends Resource
class_name StatusEffect

enum Type { ROOT, DISARM, STUN, BUFF }

@export var status_name: String = "New Status"
@export var type: Type = Type.STUN
@export var duration: int = 1 # Number of turns it lasts
@export_multiline var description: String = "Describe the effect."
