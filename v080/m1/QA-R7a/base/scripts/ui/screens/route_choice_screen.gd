class_name RouteChoiceScreen
extends UiScreen
## Route choice when GameData.next_options offers more than one leg. Every option is shown as the
## whole route to the next target (UiData.route_option: next leg + continuation), so the design's
## trade-off is visible where the player decides – length to the target, "Route über …", stages,
## autobahn km, km without limit, radars, fuel stations, tunnels, traffic, countries. The focused
## option is highlighted on the map: its first leg plus the planned continuation, intermediate cities
## labelled; the other options' first legs dashed. The view fits all options' routes (no jumping).

var _map: MapView
var _options: Array = []
var _infos: Array[Dictionary] = []       ## UiData.route_option() per option (same order)
var cards: Array[RouteCard] = []


func build() -> void:
	var race: RaceState = GameFlow.race
	_options = params.get("options", [])
	var sub := ""
	if race != null:
		sub = tr("Etappe %d ab %s  ·  nächstes Ziel: %s") % [race.next_stage_number(), UiData.city_name(race.current_city), UiData.city_name(race.next_target())]
	add_header(tr("Route wählen"), sub, race.race_name if race != null else "")
	hints = [[["ud"], tr("Route")], [["Enter", "pad:A"], tr("Diese Route")], [["Esc", "pad:B"], tr("Hauptmenü")]]
	_map = MapView.new()
	_map.set_network(UiData.cities(), UiData.stages(), UiData.ferries(), UiData.map_data())
	if race != null:
		_map.route = race.route.duplicate()
		_map.route_done = race.route.size() - 1
		_map.current_city = race.current_city
	UiKit.place(self, _map, Rect2(48, 104, 560, 560))
	var box := UiKit.vbox(10)
	UiKit.place(self, box, Rect2(628, 104, 604, 560))
	var first: Control = null
	var card_h := 150.0 if _options.size() <= 3 else 132.0
	for i in _options.size():
		var leg: Dictionary = _options[i]
		var info := {}
		if race != null and str(leg.get("kind", "stage")) == "stage":
			info = UiData.route_option(leg, race.race_id, race.visited(), race.next_target())
		_infos.append(info)
		var card := RouteCard.new(leg, info)
		card.custom_minimum_size = Vector2(604, card_h)
		card.pressed.connect(func() -> void: GameFlow.choose_leg(leg))
		card.focus_entered.connect(func() -> void: _focus_leg(leg))
		box.add_child(card)
		cards.append(card)
		if first == null:
			first = card
	if _options.is_empty():
		var msg := UiKit.label(tr("Von hier gibt es keine Weiterfahrt zum nächsten Ziel. Das Streckennetz ist noch unvollständig."), UiTheme.F.BODY_MEDIUM, 22, UiTheme.WARN)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(msg)
		var b := UiKit.button(tr("Hauptmenü"), 24)
		b.pressed.connect(GameFlow.leave_race_to_title)
		box.add_child(b)
		first = b
	default_focus = first
	if not _options.is_empty():
		_focus_leg(_options[0])


func _focus_leg(leg: Dictionary) -> void:
	var hl: Array[Dictionary] = []
	var focus: Array[String] = []
	var labels: Array[String] = []
	for i in _options.size():
		var o: Dictionary = _options[i]
		var sel: bool = o == leg
		var style := "option_selected" if sel else "option"
		if str(o.get("kind", "")) == "ferry":
			style = "ferry" if sel else "option"
		hl.append({"from": str(o.get("from", "")), "to": str(o.get("to", "")), "style": style})
		focus.append(str(o.get("to", "")))
		var info: Dictionary = _infos[i] if i < _infos.size() else {}
		for l in info.get("continuation", []):
			focus.append(str((l as Dictionary).get("to", "")))
			if sel:
				hl.append({"from": str(l.get("from", "")), "to": str(l.get("to", "")), "style": "ferry" if str(l.get("kind", "")) == "ferry" else "planned"})
		if sel:
			for c in info.get("via", []):
				labels.append(str(c))
	var race: RaceState = GameFlow.race
	if race != null:
		focus.append(race.current_city)
		focus.append(race.next_target())
		for c in race.route:
			focus.append(c)
	_map.highlight = hl
	_map.label_ids.clear()
	_map.label_ids.append_array(labels)
	if race != null:
		_map.label_ids.append(race.next_target())
	_map.fit_to(focus)


func on_cancel() -> void:
	GameFlow.leave_race_to_title()
