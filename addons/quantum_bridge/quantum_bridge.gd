@tool
extends EditorPlugin


var button

func _enter_tree():
	print("Quantum Bridge plugin enabled")
	# Add a toolbar button to test
	button = Button.new()
	button.text = "Run Quantum Example"
	button.connect("pressed", self, "_on_button_pressed")
	add_control_to_container(CONTAINER_TOOLBAR, button)

func _exit_tree():
	print("Quantum Bridge plugin disabled")
	if button:
		button.queue_free()

func _on_button_pressed():
	print("This is where Python/QuTiP code would run")
