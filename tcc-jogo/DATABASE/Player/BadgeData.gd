class_name BadgeData
extends Resource

## One gym badge. Put them in PlayerData.badges.

@export var badge_name := ""
@export var icon: Texture2D
@export_multiline var description := ""
@export var earned := false
