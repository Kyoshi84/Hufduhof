class_name BucketQuest
extends RefCounted
## Zadanie główne Poziomu 1: płonąca barykada blokuje wyjście; trzeba znaleźć 3 wiadra,
## napełnić je przy studni i każdym pełnym wiadrem ugasić część barykady.
## Czysta logika (bez sceny) - testowana w tests/test_bucket_quest.gd.

enum State { NOT_STARTED, ACTIVE, EXTINGUISHED, DONE }

var total: int = 3
var state: int = State.NOT_STARTED
var found: Array = []           # identyfikatory znalezionych wiader
var filled_total: int = 0       # ile wiader napełniono łącznie
var poured: int = 0             # ile części barykady ugaszono

func _init(n: int = 3) -> void:
	total = n

func start() -> bool:
	if state != State.NOT_STARTED:
		return false
	state = State.ACTIVE
	return true

func found_count() -> int:
	return found.size()

func carrying_empty() -> int:
	return found.size() - filled_total

func carrying_full() -> int:
	return filled_total - poured

func carrying_total() -> int:
	return carrying_empty() + carrying_full()

## Podniesienie wiadra (zadanie rusza samo, jeśli gracz nie rozmawiał jeszcze z Borubarem).
func pick_bucket(bucket_id: String) -> bool:
	if bucket_id in found or found.size() >= total or state >= State.EXTINGUISHED:
		return false
	if state == State.NOT_STARTED:
		state = State.ACTIVE
	found.append(bucket_id)
	return true

## Napełnianie przy studni: napełnia wszystkie niesione puste wiadra. Zwraca liczbę napełnionych.
func fill_at_well() -> int:
	var n := carrying_empty()
	if n <= 0:
		return 0
	filled_total += n
	return n

## Wylanie pełnego wiadra na barykadę: gasi jedną część. Zwraca true, jeśli coś ugaszono.
func pour_on_barricade() -> bool:
	if carrying_full() <= 0 or poured >= total:
		return false
	poured += 1
	if poured >= total:
		state = State.EXTINGUISHED
	return true

func is_barricade_out() -> bool:
	return poured >= total

func complete() -> void:
	if state == State.EXTINGUISHED:
		state = State.DONE

## Linie dziennika zadań.
func log_lines() -> Array:
	match state:
		State.NOT_STARTED:
			return ["Porozmawiaj z Borubarem przed karczmą"]
		State.ACTIVE:
			var lines := ["Zgaś płonącą barykadę przy bramie",
				"Wiadra: %d/%d" % [found.size(), total],
				"Napełnione: %d/%d" % [filled_total, total],
				"Barykada ugaszona: %d/%d" % [poured, total]]
			return lines
		State.EXTINGUISHED:
			return ["Barykada ugaszona!", "Wyjdź przez bramę (albo odbierz nagrodę od Borubara)"]
	return ["Zadanie ukończone", "Wyjdź przez bramę"]

func to_dict() -> Dictionary:
	return {"total": total, "state": state, "found": found.duplicate(), "filled_total": filled_total, "poured": poured}

static func from_dict(d: Dictionary) -> BucketQuest:
	var q := BucketQuest.new(int(d.get("total", 3)))
	q.state = int(d.get("state", State.NOT_STARTED))
	q.found = d.get("found", []).duplicate()
	q.filled_total = int(d.get("filled_total", 0))
	q.poured = int(d.get("poured", 0))
	return q
