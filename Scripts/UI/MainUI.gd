extends CanvasLayer

@onready var status_label = $CenterContainer/VBoxContainer/Status

func _ready():
    print("MainUI initialized")

func _on_start_server_pressed():
    print("UI: Start server button pressed")
    status_label.text = "Status: Starting server..."
    GameManager.start_server(8080)

func _on_connect_client_pressed():
    print("UI: Connect client button pressed")
    status_label.text = "Status: Connecting..."
    GameManager.connect_to_server("127.0.0.1", 8080)

func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_F1:
                _on_start_server_pressed()
            KEY_F2:
                _on_connect_client_pressed()
            KEY_F12:
                GameManager.print_debug_info()
