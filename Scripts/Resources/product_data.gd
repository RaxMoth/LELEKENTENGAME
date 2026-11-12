## In-app purchase definition. The id must match the product id configured in
## Google Play Console / App Store Connect.
##
## Dependencies: Types autoload
class_name ProductData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var product_type: Types.ProductType = Types.ProductType.CONSUMABLE
## Shown until the store returns a localized price.
@export var fallback_price_text: String = "$0.99"
## Currencies or items granted on purchase (e.g. {&"gems": 100} or {&"no_ads": 1}).
@export var rewards: Dictionary[StringName, int] = {}
