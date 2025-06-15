## granular_need_definition.gd
## Defines a specific, measurable need (e.g., Hunger, Thirst, Sleep).
## These resources are loaded by EntityManager and used by NPCAI to manage
## the physiological and psychological states of NPCs.
class_name GranularNeedDefinition extends Resource

## A unique identifier for this granular need.
@export var need_id: String = ""
## A human-readable name for the need.
@export var need_name: String = ""
## The Maslow's Hierarchy of Needs level this granular need belongs to
## (e.g., "Physiological", "Safety", "Belonging", "Esteem", "Self-Actualization").
@export var linked_maslow_level: String = ""
## The base rate at which this need decays (increases in value) per game minute.
## A higher decay rate means the NPC gets hungry/thirsty/sleepy faster.
@export var base_decay_rate: float = 0.01
## The maximum value this need can reach (typically 1.0, representing full unmet need).
@export var max_value: float = 1.0
## An importance modifier that can influence how critically the AI perceives this need.
@export var importance_modifier: float = 1.0
## The threshold below which this granular need is considered "satisfied".
## For example, if 'HUNGER' is 0.1 and 'satisfaction_threshold' is 0.2, hunger is satisfied.
## Needs values usually range from 0.0 (satisfied/full) to 1.0 (completely unmet/empty).
@export var satisfaction_threshold: float = 0.2
