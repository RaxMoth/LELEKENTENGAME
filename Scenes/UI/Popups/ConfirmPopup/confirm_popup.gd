## Yes/no or single-button message dialog. Prefer UI.confirm() over opening it directly.
##
## popup_data keys: title, message, confirm_text, cancel_text ("" hides cancel)
## Result: true when confirmed, false otherwise.
##
## Dependencies: BasePopup
class_name ConfirmPopup
extends BasePopup

@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _on_opened(data: Dictionary) -> void:
	_title_label.text = str(data.get("title", ""))
	_message_label.text = str(data.get("message", ""))
	_message_label.visible = not _message_label.text.is_empty()
	_confirm_button.text = str(data.get("confirm_text", tr("Yes")))
	_cancel_button.text = str(data.get("cancel_text", tr("No")))
	_cancel_button.visible = not _cancel_button.text.is_empty()


func handle_back() -> void:
	close(false)


func _on_confirm_button_pressed() -> void:
	close(true)


func _on_cancel_button_pressed() -> void:
	close(false)
