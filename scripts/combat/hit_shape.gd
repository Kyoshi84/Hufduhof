class_name HitShape
extends RefCounted
## Jedno źródło prawdy dla geometrii walki. Wszystko liczone na płaszczyźnie podłoża (x, y=głębia)
## względem PUNKTU STÓP aktora - niezależnie od rozmiaru sprite'a, skali i kamery.
##
## Hitbox ataku:  prostokąt od `hit_start` (przed ciałem) do `reach` w kierunku ataku,
##                opcjonalnie `back` za plecami (ataki obszarowe), pasmo głębi +-`depth`.
## Hurtbox celu:  stopa aktora: +-body_half w poziomie, +-foot_half w głębi.
## Wizualizacja zamachu i tryb diagnostyczny rysują dokładnie te same prostokąty.

const DEFAULT_START := 14.0

static func attack_rect(pos: Vector2, facing: int, atk: Dictionary) -> Rect2:
	var reach: float = float(atk.get("reach", 80.0))
	var back: float = float(atk.get("back", 0.0))
	var start: float = float(atk.get("hit_start", DEFAULT_START))
	var depth: float = float(atk.get("depth", 36.0))
	var a: float = pos.x + facing * reach
	var b: float = pos.x - facing * back if back > 0.0 else pos.x + facing * start
	var x0: float = minf(a, b)
	var x1: float = maxf(a, b)
	return Rect2(x0, pos.y - depth, x1 - x0, depth * 2.0)

static func hurt_rect(pos: Vector2, body_half: float, foot_half: float) -> Rect2:
	return Rect2(pos.x - body_half, pos.y - foot_half, body_half * 2.0, foot_half * 2.0)

## Zwraca "hit", "reach" (za daleko/za blisko w poziomie) albo "depth" (inna linia głębi).
static func test(atk_rect: Rect2, target_rect: Rect2) -> String:
	var x_ok: bool = atk_rect.position.x <= target_rect.end.x and atk_rect.end.x >= target_rect.position.x
	var y_ok: bool = atk_rect.position.y <= target_rect.end.y and atk_rect.end.y >= target_rect.position.y
	if x_ok and y_ok:
		return "hit"
	if not y_ok:
		return "depth"
	return "reach"
