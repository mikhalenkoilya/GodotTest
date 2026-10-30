class_name SkillEffect
extends Resource

# Optional: A description for the developer to see in the inspector
@export var description: String = "Base effect"

# Each effect implements its own logic. 
# Returns true if the effect successfully resolved (useful for conditional effects).
func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	push_warning("execute() not implemented in base SkillEffect")
