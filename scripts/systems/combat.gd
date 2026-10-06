class_name Combat
extends RefCounted
## Savaşla ilgili ortak tanımlar.
##
## Saldırı türleri:
##   NORMAL       bloklanabilir, parry'lenebilir
##   HEAVY        bloklanabilir ama stamina'yı çok tüketir, parry'lenebilir (turuncu uyarı)
##   UNBLOCKABLE  blok ve parry işe yaramaz, yalnızca yuvarlanarak kaçılır (kırmızı uyarı)

enum Kind { NORMAL, HEAVY, UNBLOCKABLE }

## Oyuncunun bir saldırıya verdiği tepkinin sonucu
enum Result { HIT, BLOCKED, PARRIED, DODGED, GUARD_BROKEN }

const KIND_COLORS := {
	Kind.NORMAL: Color(1.0, 0.9, 0.5),
	Kind.HEAVY: Color(1.0, 0.55, 0.15),
	Kind.UNBLOCKABLE: Color(1.0, 0.15, 0.15),
}


## Uyarı alanının (telegraph) dolgu rengi
static func telegraph_color(kind: Kind) -> Color:
	match kind:
		Kind.UNBLOCKABLE:
			return Color(0.95, 0.1, 0.1, 0.28)
		Kind.HEAVY:
			return Color(1.0, 0.5, 0.1, 0.25)
	return Color(1.0, 0.85, 0.3, 0.2)


## Uyarı alanının kenar rengi
static func edge_color(kind: Kind) -> Color:
	match kind:
		Kind.UNBLOCKABLE:
			return Color(1.0, 0.2, 0.15, 0.9)
		Kind.HEAVY:
			return Color(1.0, 0.6, 0.2, 0.85)
	return Color(1.0, 0.9, 0.4, 0.8)


## Saniyelerce oyunu yavaşlatır (vuruş hissi / "hit stop"). Gerçek zamanla geri alınır.
static func hit_stop(tree: SceneTree, duration: float = 0.07, scale: float = 0.05) -> void:
	Engine.time_scale = scale
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
