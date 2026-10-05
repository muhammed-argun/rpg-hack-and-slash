extends Control
## The kit in use, three RPG screens of plain Controls styled by one Theme: an adventure (the hero's
## portrait and bars, settings, an inventory of rarity slots, a quest scroll, a hotbar, dialogue), a
## spellbook (skills by school, health and mana orbs, a hotbar cooling down) and a smithy (tiered
## gear set against what the hero wears). The buttons along the bottom swap the theme and the screen.

const KIT := "res://addons/pixel_ui_fantasy/"
const ALL_THEMES: Array[String] = ["parchment", "leather", "iron", "gilded", "elven", "arcane"]
const ART_HEIGHT := 360.0
const FIRST := "gilded"
const SCREENS: Array[String] = ["adventure", "spells", "shop"]
const SCHOOLS: Array[String] = ["fire", "frost", "storm", "nature", "holy", "shadow", "arcane", "might"]
const SKILLS: Array[String] = ["bolt", "nova", "ward", "mend", "strike", "rain", "aura", "summon"]
const DOES := {"bolt": "Hurls a bolt of %s at one foe.", "nova": "A burst of %s strikes every foe around you.",
	"ward": "A shield of %s soaks up the next blows.", "mend": "%s knits your wounds over time.",
	"strike": "Your next blow carries %s.", "rain": "%s falls on an area for a few seconds.",
	"aura": "Allies near you gain the strength of %s.", "summon": "Calls a spirit of %s to fight beside you."}
const ELEMENT := {"fire": "flame", "frost": "ice", "storm": "lightning", "nature": "thorns", "holy": "light",
	"shadow": "shadow", "arcane": "arcane force", "might": "steel"}
## A gear tier's rarity, and its attack (or armour) and price over the plain item's.
const TIERS := {"": ["common", 1.0, 1.0], "bronze": ["uncommon", 1.5, 2.5], "gold": ["rare", 2.2, 6.0],
	"mythril": ["epic", 3.2, 15.0]}
const GEAR := {"sword": ["Attack", 8, 40], "axe": ["Attack", 10, 45], "dagger": ["Attack", 5, 25],
	"hammer": ["Attack", 12, 55], "helmet": ["Armour", 3, 30], "chestplate": ["Armour", 7, 60]}
const RARITY_INK := {"common": Color("9e9e9e"), "uncommon": Color("5ac860"), "rare": Color("4892f0"),
	"epic": Color("b060e8")}

## Store capture only: switch to the next theme every this many frames.
@export var cycle_frames := 0
## The screen to open on, and the theme to open in when not FIRST.
@export_enum("adventure", "spells", "shop") var screen := "adventure"
@export var first_theme := ""

var frame := 0
var theme_buttons := {}
var pages := {}
var page: Control
var cooldowns: Array[TextureProgressBar] = []
var cooling: Array[float] = []  # each one's time to go, past 100 a rest with it ready
var picked: PanelContainer
var details: VBoxContainer
var compare: VBoxContainer


## Draws the UI at a whole-number scale so the art pixels stay square: the largest that still
## fits `art_height` pixels of art on screen.
static func pixel_scale(node: Node, art_height: float) -> void:
	var window := node.get_tree().root
	window.content_scale_factor = 1.0
	window.content_scale_factor = maxf(1.0, floorf(window.get_visible_rect().size.y / art_height))


static func themes() -> Array[String]:
	var installed: Array[String] = []
	for n in ALL_THEMES:
		if ResourceLoader.exists(KIT + "themes/%s.tres" % n):
			installed.append(n)
	return installed


## The named theme, or the first one installed.
static func kit_theme(name: String) -> Theme:
	return load(KIT + "themes/%s.tres" % (name if name in themes() else themes()[0]))


## Null when the icon isn't installed. Skill icons are "skills/<school>_<skill>".
static func icon_texture(name: String) -> Texture2D:
	var path := KIT + "icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func icon(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## The installed skill icons' names, school by school.
static func skills() -> Array[String]:
	var installed: Array[String] = []
	for school in SCHOOLS:
		for s in SKILLS:
			if icon_texture("skills/%s_%s" % [school, s]):
				installed.append("%s_%s" % [school, s])
	return installed


## A titled window; add its content to the returned VBox.
static func window(parent: Control, title: String, at: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = at
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"Title"
	box.add_child(label)
	return box


static func row(parent: Control, separation := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


static func bar(parent: Control, colour: String, value: float, width: float) -> ProgressBar:
	var b := ProgressBar.new()
	if colour != "":
		b.theme_type_variation = StringName(colour + "Bar")
	b.show_percentage = false
	b.value = value
	b.custom_minimum_size = Vector2(width, 10)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


static func slider(parent: Control, label: String, value: float) -> void:
	var r := row(parent)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 42
	r.add_child(l)
	var s := HSlider.new()
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(s)


static func label(parent: Control, text: String, variation := &"") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	parent.add_child(l)
	return l


## A 24x24 item slot (`rarity` "" for a plain one) holding an icon and a count above 1.
static func slot(parent: Control, item: String, count := 1, rarity := "") -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = StringName(rarity.capitalize() + "Slot") if rarity else &"InsetPanel"
	s.custom_minimum_size = Vector2(24, 24)
	parent.add_child(s)
	if item == "" or icon_texture(item) == null:
		return s
	var art := icon(item)
	s.tooltip_text = item.capitalize()
	s.add_child(art)
	if count > 1:
		var n := Label.new()
		n.text = str(count)
		n.add_theme_color_override("font_color", Color.WHITE)
		n.add_theme_color_override("font_shadow_color", Color.BLACK)
		art.add_child(n)
		n.position = Vector2(19, 6) - Vector2(n.get_minimum_size().x, 0)
	return s


## A 20x20 skill frame (`SkillSlot`) round a skill icon, or empty for "".
static func skill(parent: Control, name: String) -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = &"SkillSlot"
	s.custom_minimum_size = Vector2(20, 20)
	parent.add_child(s)
	if name != "":
		s.add_child(icon("skills/" + name))
		s.tooltip_text = name.capitalize()
	return s


## A 40x40 orb filled `value` percent from the bottom with a bars/orb_<colour>.png, glinting under
## bars/orb_glass.png, in the ring of whichever kit theme it is under.
static func orb(parent: Control, colour: String, value: float) -> TextureProgressBar:
	var o := TextureProgressBar.new()
	o.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	o.texture_progress = load(KIT + "bars/orb_%s.png" % colour)
	o.texture_progress_offset = Vector2(4, 4)
	o.texture_over = load(KIT + "bars/orb_glass.png")
	o.value = value
	o.theme_changed.connect(func() -> void:  # each theme's orb.png sits by its portrait.png
		var ring := o.get_theme_stylebox(&"panel", &"PortraitPanel") as StyleBoxTexture
		if ring and ring.texture:
			o.texture_under = load(ring.texture.resource_path.get_base_dir().path_join("orb.png")))
	parent.add_child(o)
	return o


## An icon at twice its size in the portrait frame, 48x48 in all.
static func portrait(parent: Control, item: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"PortraitPanel"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := icon(item)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(32, 32)
	p.add_child(face)
	parent.add_child(p)
	return p


func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # project.godot's, for a project without it
	pixel_scale(self, ART_HEIGHT)
	add_child(Backdrop.new())
	var first := first_theme if first_theme != "" else FIRST
	theme = kit_theme(first)
	for s in SCREENS:
		pages[s] = Control.new()
		pages[s].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages[s].mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pages[s])
	page = pages["adventure"]
	_hud()
	_settings()
	_inventory()
	_hotbar()
	_quests()
	_dialogue()
	page = pages["spells"]
	_spellbook()
	_effects()
	_casting()
	page = pages["shop"]
	_purse()
	_wares()
	_bag()
	_smith()
	var switcher := row(self, 3)
	switcher.position = Vector2(6, 334)
	var group := ButtonGroup.new()
	for name in themes():
		var b := Button.new()
		b.text = name.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = name == kit_theme(first).resource_path.get_file().get_basename()
		b.toggled.connect(func(on: bool) -> void:
			if on:
				theme = kit_theme(name))
		switcher.add_child(b)
		theme_buttons[name] = b
	var screens := row(self, 3)
	var screen_group := ButtonGroup.new()
	for s in SCREENS:
		var b := Button.new()
		b.text = s.capitalize()
		b.icon = icon_texture({"adventure": "quest", "spells": "spellbook", "shop": "coin"}[s])
		b.toggle_mode = true
		b.button_group = screen_group
		b.button_pressed = s == screen
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_show(s))
		screens.add_child(b)
	screens.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_show(screen)


func _show(which: String) -> void:
	for s in pages:
		pages[s].visible = s == which


func _process(delta: float) -> void:
	for i in cooldowns.size():  # each hotbar skill comes round at its own pace, with a rest between
		cooling[i] = fposmod(cooling[i] - delta * 100.0 / (2.0 + i), 160.0)
		cooldowns[i].value = cooling[i] if cooling[i] <= 100.0 else 0.0
	if cycle_frames <= 0:
		return
	frame += 1
	if frame % cycle_frames == 0:
		var names := themes()
		var start := first_theme if first_theme != "" else FIRST
		var next: String = names[(maxi(0, names.find(start)) + frame / cycle_frames) % names.size()]
		theme_buttons[next].button_pressed = true


func _hud() -> void:
	var top := row(page, 4)
	top.position = Vector2(6, 6)
	portrait(top, "helmet")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	top.add_child(rows)
	label(rows, "Aria  Lv 7", &"Nameplate")
	for pair in [["heart", "Red", 72], ["mana", "Blue", 48], ["xp", "Gold", 64]]:
		var r := row(rows, 2)
		r.add_child(icon(pair[0]))
		bar(r, pair[1], pair[2], 96)
	_purse()


func _purse() -> void:
	var purse := PanelContainer.new()
	page.add_child(purse)
	var money := row(purse, 2)
	for pair in [["coin", "1250"], ["gem", "12"], ["key", "3"]]:
		money.add_child(icon(pair[0]))
		label(money, pair[1]).custom_minimum_size.x = 28
	purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)


func _settings() -> void:
	var box := window(page, "Settings", Vector2(6, 76), 166)
	slider(box, "Music", 70)
	slider(box, "Sound", 45)
	var hints := CheckBox.new()
	hints.text = "Show hints"
	hints.button_pressed = true
	box.add_child(hints)
	var group := ButtonGroup.new()
	var modes := row(box, 6)
	for m in ["Classic", "Heroic"]:
		var radio := CheckBox.new()
		radio.text = m
		radio.button_group = group
		radio.button_pressed = m == "Heroic"
		modes.add_child(radio)
	var speed := OptionButton.new()
	for s in ["Text: normal", "Text: fast", "Text: instant"]:
		speed.add_item(s)
	box.add_child(speed)
	var hero := LineEdit.new()
	hero.placeholder_text = "Hero name"
	box.add_child(hero)
	var buttons := row(box)
	for t in ["Back", "Apply"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _inventory() -> void:
	var box := window(page, "Inventory", Vector2(178, 30), 256)
	var tabs := TabContainer.new()
	box.add_child(tabs)
	var bag := GridContainer.new()
	bag.name = "Bag"
	bag.columns = 9
	bag.add_theme_constant_override("h_separation", 2)
	bag.add_theme_constant_override("v_separation", 2)
	tabs.add_child(bag)
	var items := [["sword", 1, "rare"], ["shield", 1, "uncommon"], ["bow", 1, "common"], ["staff", 1, "epic"],
		["amulet", 1, "legendary"], ["ring", 1, "rare"], ["potion_red", 5, "common"], ["potion_blue", 3, "common"],
		["potion_green", 2, "uncommon"], ["bread", 4, "common"], ["meat", 2, "common"], ["herb", 9, "common"],
		["mushroom", 3, "uncommon"], ["scroll", 2, "rare"], ["gem", 12, "epic"], ["key", 1, "common"],
		["", 1, ""], ["", 1, ""]]
	for it in items:
		var shown: bool = it[0] != "" and icon_texture(it[0]) != null
		slot(bag, it[0] if shown else "", it[1], it[2] if shown else "")
	var gear := VBoxContainer.new()
	gear.name = "Gear"
	tabs.add_child(gear)
	for pair in [["helmet", "Iron helm", "+4"], ["chestplate", "Knight's plate", "+9"], ["boots", "Swift boots", "+2"]]:
		var r := row(gear)
		slot(r, pair[0])
		var l := label(r, pair[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(r, pair[2])
	box.add_child(HSeparator.new())
	var weight := row(box)
	weight.add_child(icon("pouch"))
	label(weight, "Weight 34/50")
	bar(weight, "Green", 68, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := row(box)
	for pair in [["check", "Use"], ["cross", "Drop"], ["quest", "Info"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)


func _hotbar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(183, 198)
	page.add_child(panel)
	var r := row(panel, 2)
	var keys := ["sword", "bow", "fireball", "frost", "lightning", "potion_red", "potion_blue", "torch", "map"]
	for i in keys.size():
		_key(slot(r, keys[i]), i + 1)


## The hotkey's number in a slot's corner.
func _key(s: Control, n: int) -> void:
	var l := Label.new()
	l.text = str(n)
	l.position = Vector2(3, -1)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	s.add_child(l)
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)


func _quests() -> void:
	var scroll := PanelContainer.new()
	scroll.theme_type_variation = &"ParchmentPanel"
	scroll.position = Vector2(442, 42)
	scroll.custom_minimum_size.x = 192
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)
	var head := label(box, "Quest Log", &"Ribbon")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for q in [["check", "Find the lost key"], ["check", "Light the old beacon"], ["quest", "Slay the swamp troll"],
			["quest", "Return to the sage"], ["lock", "The sunken crypt"]]:
		var r := row(box, 3)
		r.add_child(icon(q[0]))
		label(r, q[1], &"Ink")
	label(box, "Reward: 300 gold", &"Ink").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## A line of dialogue across the bottom, a portrait beside it.
func _speech(face: String, who: String, line: String) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 262)
	panel.custom_minimum_size.x = 628
	page.add_child(panel)
	var r := row(panel, 6)
	portrait(r, face)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(box)
	label(box, who, &"Ribbon").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(box, line)
	var next := Button.new()
	next.icon = icon_texture("arrow_right")
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(next)


func _dialogue() -> void:
	_speech("spellbook" if icon_texture("spellbook") else "scroll", "Old Sage",
		"The troll guards the bridge by night. Take this torch,\nand the frost scroll: fire alone won't do.")


## Every installed skill, a row per school; pointing at one shows it in the details window.
func _spellbook() -> void:
	var box := window(page, "Spellbook", Vector2(6, 6), 0)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var known := skills()
	for school in SCHOOLS:
		if not known.any(func(n: String) -> bool: return n.begins_with(school + "_")):
			continue
		label(grid, school.capitalize()).custom_minimum_size.x = 38
		for s in SKILLS:
			var name := "%s_%s" % [school, s]
			var cell := skill(grid, name if name in known else "")
			if name in known:
				cell.mouse_entered.connect(_pick.bind(cell, name))
	details = window(page, "Skill", Vector2(250, 6), 190)
	if not known.is_empty():
		_pick(grid.get_child(1) as PanelContainer, known[0])


## Shows a skill in the details window and lights its frame.
func _pick(cell: PanelContainer, name: String) -> void:
	if picked:
		picked.theme_type_variation = &"SkillSlot"
	picked = cell
	cell.theme_type_variation = &"ActiveSkillSlot"
	for c in details.get_children().slice(1):
		c.queue_free()
	var school := name.get_slice("_", 0)
	var kind := name.get_slice("_", 1)
	var level := SKILLS.find(kind)
	var top := row(details, 6)
	portrait(top, "skills/" + name)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	top.add_child(titles)
	label(titles, name.capitalize(), &"Ribbon").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(titles, "%s school" % school.capitalize())
	label(titles, "Rank %d / 5" % (level % 5 + 1))
	var text: String = DOES[kind] % ELEMENT[school]
	var about := label(details, text[0].to_upper() + text.substr(1))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size.x = 176
	for pair in [["mana", "%d mana" % (8 + level * 4)], ["hourglass", "%ds cooldown" % (2 + level * 3)]]:
		var r := row(details, 3)
		r.add_child(icon(pair[0]))
		label(r, pair[1])
	details.add_child(HSeparator.new())
	var buttons := row(details)
	for pair in [["plus", "Learn"], ["arrow_down", "Assign"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _effects() -> void:
	var box := window(page, "Effects", Vector2(446, 6), 188)
	var known := skills()
	var shown := 0
	for pair in [["holy_ward", 80], ["nature_mend", 55], ["might_aura", 30], ["fire_ward", 90], ["fire_aura", 45],
			["fire_mend", 60]]:
		if pair[0] not in known or shown == 4:
			continue
		shown += 1
		var r := row(box, 4)
		skill(r, pair[0])
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(lines)
		label(lines, pair[0].capitalize())
		bar(lines, "Gold", pair[1], 0)
	box.add_child(HSeparator.new())
	var points := row(box, 3)
	points.add_child(icon("xp"))
	label(points, "Skill points: 3")


## The orbs either side of a hotbar of skills cooling down, and a spell being cast above it.
func _casting() -> void:
	var known := skills()
	var keys: Array[String] = []
	for name in ["fire_bolt", "frost_nova", "storm_bolt", "holy_mend", "shadow_strike", "nature_rain", "arcane_summon",
			"might_ward"]:
		if name in known:
			keys.append(name)
	for name in known:
		if keys.size() < 8 and name not in keys:
			keys.append(name)
	var cast := VBoxContainer.new()
	cast.add_theme_constant_override("separation", 0)
	cast.position = Vector2(226, 232)
	cast.custom_minimum_size.x = 188
	page.add_child(cast)
	label(cast, "Casting %s" % (keys[1].capitalize() if keys.size() > 1 else "...")) \
		.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar(cast, "Blue", 62, 0)
	var line := row(page, 6)
	line.position = Vector2(174, 258)
	_meter(line, "red", 76, "heart", "152/200")
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(panel)
	var r := row(panel, 2)
	for i in 8:
		var s := skill(r, keys[i] if i < keys.size() else "")
		if i < keys.size():
			var c := TextureProgressBar.new()
			c.fill_mode = TextureProgressBar.FILL_CLOCKWISE
			c.texture_progress = load(KIT + "bars/cooldown.png")
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(c)
			cooldowns.append(c)
			cooling.append(150.0 - i * 37)
		_key(s, i + 1)
	_meter(line, "blue", 48, "mana", "96/200")


## An orb with its amount under it.
func _meter(parent: Control, colour: String, value: float, sign: String, amount: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	orb(box, colour, value).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r := row(box, 1)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_child(icon(sign))
	label(r, amount)


## The smith's wares, every tier installed by kind, priced; pointing at one weighs it.
func _wares() -> void:
	var box := window(page, "Brannoc's Smithy", Vector2(6, 6), 290)
	var tabs := TabContainer.new()
	box.add_child(tabs)
	for tab in [["Weapons", ["sword", "axe", "dagger", "hammer"]], ["Armour", ["helmet", "chestplate"]]]:
		var grid := GridContainer.new()
		grid.name = tab[0]
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 2)
		tabs.add_child(grid)
		for tier in ["mythril", "gold", "bronze", ""]:
			for item: String in tab[1]:
				var name: String = item + ("_" + tier if tier else "")
				if icon_texture(name) == null or grid.get_child_count() >= 12:
					continue
				var r := row(grid, 4)
				r.custom_minimum_size.x = 134
				r.mouse_filter = Control.MOUSE_FILTER_STOP
				slot(r, name, 1, TIERS[tier][0])
				var lines := VBoxContainer.new()
				lines.add_theme_constant_override("separation", -1)
				r.add_child(lines)
				label(lines, _title(name))
				var price := row(lines, 2)
				price.add_child(icon("coin"))
				label(price, str(_price(name)))
				r.mouse_entered.connect(_weigh.bind(name))
	compare = window(page, "Compare", Vector2(302, 30), 168)
	for name in ["sword_mythril", "sword"]:
		if icon_texture(name):
			_weigh(name)
			break


func _tier(name: String) -> String:
	return name.get_slice("_", 1) if "_" in name else ""


func _title(name: String) -> String:
	var item: String = {"chestplate": "plate"}.get(name.get_slice("_", 0), name.get_slice("_", 0))
	return ("%s %s" % [_tier(name), item] if _tier(name) else "Iron " + item).capitalize()


func _stat(name: String) -> int:
	return roundi(GEAR[name.get_slice("_", 0)][1] * TIERS[_tier(name)][1])


## Mythril is light, gold heavy.
func _weight(name: String) -> int:
	return 4 + GEAR[name.get_slice("_", 0)][1] / 2 + {"": 0, "bronze": 1, "gold": 3, "mythril": -1}[_tier(name)]


func _price(name: String) -> int:
	return roundi(GEAR[name.get_slice("_", 0)][2] * TIERS[_tier(name)][2])


## Sets an item against the hero's own of its kind.
func _weigh(name: String) -> void:
	for c in compare.get_children().slice(1):
		c.queue_free()
	var item := name.get_slice("_", 0)
	var rarity: String = TIERS[_tier(name)][0]
	var worn: String = item if item in ["helmet", "chestplate"] else "sword"
	var top := row(compare, 5)
	slot(top, name, 1, rarity).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	top.add_child(titles)
	label(titles, _title(name), &"Nameplate").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(titles, rarity.capitalize()).add_theme_color_override("font_color", RARITY_INK[rarity])
	for pair in [[GEAR[item][0], _stat(name), _stat(worn)], ["Weight", _weight(name), _weight(worn)]]:
		var r := row(compare, 3)
		label(r, pair[0]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(r, str(pair[1]))
		var gain: int = pair[1] - pair[2]
		var d := label(r, ("+%d" % gain if gain > 0 else str(gain)) if gain else "=")
		d.custom_minimum_size.x = 22
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if gain:
			var better := gain > 0 if pair[0] != "Weight" else gain < 0
			d.add_theme_color_override("font_color", Color("6ee070") if better else Color("f06058"))
	var on := row(compare, 3)
	label(on, "Worn: " + _title(worn)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on.add_child(icon(worn))
	compare.add_child(HSeparator.new())
	var buy := Button.new()
	buy.text = "Buy  %d" % _price(name)
	buy.icon = icon_texture("coin")
	compare.add_child(buy)


func _bag() -> void:
	var box := window(page, "Your bag", Vector2(476, 30), 0)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for it in [["sword", 1, "common"], ["helmet", 1, "common"], ["shield", 1, "uncommon"], ["potion_red", 4, "common"],
			["gem", 12, "epic"], ["ring", 1, "rare"], ["bread", 3, "common"], ["herb", 6, "common"], ["", 1, ""],
			["", 1, ""], ["", 1, ""], ["", 1, ""]]:
		var shown: bool = it[0] != "" and icon_texture(it[0]) != null
		slot(grid, it[0] if shown else "", it[1], it[2] if shown else "")
	var buttons := row(box)
	for pair in [["coin", "Sell"], ["gear", "Repair"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _smith() -> void:
	_speech("hammer" if icon_texture("hammer") else "sword", "Brannoc the Smith",
		"Mythril keeps its edge through dragonfire. Bronze is for\npractice, and gold is for show.")


## A dim dungeon wall behind the UI.
class Backdrop extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for y in range(0, 400, 12):
			var shift := 12 if (y / 12) % 2 else 0
			for x in range(-24, 700, 24):
				var v := rng.randf_range(0.08, 0.12)
				draw_rect(Rect2(x + shift, y, 23, 11), Color(v * 1.1, v * 0.9, v))
