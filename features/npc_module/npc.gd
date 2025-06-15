# npc.gd
# This simple script sits on the root node of the NPC scene.
class_name NPC
extends Node3D

# These variables will be set by the main spawner script.
var definition: NPCEntityDefinition
var start_location_id: int = 0
