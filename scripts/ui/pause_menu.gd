class_name PauseMenu
extends Control
## In-race pause overlay. Owner: UI module. Public API = contract.
## STUB: three plain buttons – the UI module replaces it.

signal resume_requested
signal restart_requested
signal quit_requested

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_box)
	for pair in [[tr("Weiterfahren"), resume_requested], [tr("Etappe neu starten"), restart_requested], [tr("Aufgeben"), quit_requested]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(func() -> void: (pair[1] as Signal).emit())
		_box.add_child(b)
	hide()


func open() -> void:
	show()
	(_box.get_child(0) as Button).grab_focus()


func close() -> void:
	hide()
