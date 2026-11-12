## The upgrades of one area of the game (lab, sales, defense, house), kept
## in that area's own file so developers working on different areas never
## edit the same list. GameConfig.upgrade_catalogs lists the catalogs.
##
## Dependencies: UpgradeData
class_name UpgradeCatalog
extends Resource

@export var area_name: String = ""
@export var upgrades: Array[UpgradeData] = []
