class_name BossAttack
extends Resource
## Bir boss saldırısının verisi. Boss, fazına ve oyuncuya uzaklığına uygun saldırılar arasından
## ağırlığa göre rastgele seçim yapar.
##
## Türler:
##   MELEE   yakın dövüş kombosu (combo_hits kez "attack" animasyonu)
##   SLAM    yerde daire uyarısı, sonra alan vuruşu (offset: bakılan yöne kayma)
##   RING    boss'un etrafında büyük daire vuruşu (genelde engellenemez)
##   CHARGE  çizgi uyarısı, sonra o yönde atılma
##   SUMMON     yardımcı düşman çağırma
##   PROJECTILE oyuncuya doğru yelpaze şeklinde mermi(ler) (count, spread, projectile_speed, homing)
##   TELEPORT   kaybolup oyuncunun yakınında belirme (teleport_distance)
##   BARRAGE    oyuncunun çevresine art arda düşen alan vuruşları: meteor, kemik kafes (count, spread)
##   LINE       boss'tan oyuncuya doğru uzun çizgi vuruşu: ışın, yer yarığı (length, radius = yarı kalınlık)
## CHARGE saldırıları kind ne olursa olsun UNBLOCKABLE sayılır (Boss._execute): boss hücumu bloklanamaz,
## parry'lenemez; yalnızca yuvarlanma (i-frame) kurtarır ve isabet ederse stun verir.

enum Type { MELEE, SLAM, RING, CHARGE, SUMMON, PROJECTILE, TELEPORT, BARRAGE, LINE }

@export var type: Type = Type.MELEE
@export var kind: Combat.Kind = Combat.Kind.NORMAL
## Bu saldırının kullanılabildiği en düşük faz (1 veya 2)
@export_range(1, 3) var min_phase: int = 1
## Seçilme ağırlığı (yüksek = daha sık)
@export var weight: float = 1.0
@export var damage: int = 15
## Oyuncu bu mesafe aralığındaysa saldırı seçilebilir
@export var min_range: float = 0.0
@export var max_range: float = 40.0
## Saldırıdan sonra bir sonraki saldırıya kadar bekleme
@export var recovery: float = 1.0
## Bu saldırı bir kez yapıldıktan sonra yeniden seçilebilmesi için geçmesi gereken süre (0 = sınırsız)
@export var cooldown: float = 0.0
## true ise boss min_phase fazına girince bu saldırıyı ilk olarak yapar (faz açılışı)
@export var phase_opener: bool = false
@export_group("Alan")
@export var radius: float = 36.0
@export var offset: float = 0.0
@export var windup: float = 0.7
@export_group("Animasyon")
## "attack" veya "special"
@export var animation: String = "special"
@export var hit_frame: int = 3
@export var combo_hits: int = 1
@export_group("Hücum")
@export var charge_speed: float = 280.0
@export var charge_distance: float = 130.0
## İsabet ederse oyuncunun sersemleme (stun) süresi; blok/parry/yuvarlanma korur
@export var stun_time: float = 1.0
@export_group("Mermi / Yağmur / Çizgi")
## Mermi veya yağmurdaki alan sayısı
@export var count: int = 3
## PROJECTILE: yelpaze açısı (derece). BARRAGE: oyuncunun çevresindeki dağılma yarıçapı (piksel)
@export var spread: float = 30.0
## BARRAGE: uyarı daireleri yanıp söner (kırmızı patlama daireleri)
@export var blink: bool = false
@export var projectile_speed: float = 110.0
@export_range(0.0, 1.0) var homing: float = 0.0
@export var projectile_color: Color = Color(0.75, 0.45, 1.0)
## LINE: çizginin uzunluğu
@export var length: float = 160.0
## TELEPORT: oyuncudan uzaklık
@export var teleport_distance: float = 40.0
@export_group("Çağırma")
@export var summon_scene: PackedScene
## Doluysa summon_scene yerine kullanılır: i. yardımcı summon_scenes[i % boyut] sahnesinden doğar
@export var summon_scenes: Array[PackedScene] = []
@export var summon_count: int = 2


static func make(attack_type: Type, attack_kind: Combat.Kind, attack_damage: int, range_min: float, range_max: float, phase: int = 1, attack_weight: float = 1.0) -> BossAttack:
	var attack := BossAttack.new()
	attack.type = attack_type
	attack.kind = attack_kind
	attack.damage = attack_damage
	attack.min_range = range_min
	attack.max_range = range_max
	attack.min_phase = phase
	attack.weight = attack_weight
	return attack
