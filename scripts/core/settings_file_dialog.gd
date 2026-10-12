extends FileDialog

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		# Handle Escape in this window's viewport, including embedded dialogs.
		set_input_as_handled()
		canceled.emit()
