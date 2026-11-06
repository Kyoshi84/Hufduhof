extends GutTest
## Zadanie z wiadrami: znajdź 3, napełnij przy studni, ugaś barykadę.

func test_full_flow():
	var q := BucketQuest.new(3)
	assert_eq(q.state, BucketQuest.State.NOT_STARTED)
	assert_true(q.start())
	assert_false(q.start(), "drugi start nic nie robi")
	assert_true(q.pick_bucket("kuznia"))
	assert_true(q.pick_bucket("mlyn"))
	assert_eq(q.carrying_empty(), 2)
	assert_eq(q.fill_at_well(), 2)
	assert_eq(q.carrying_full(), 2)
	assert_true(q.pour_on_barricade())
	assert_true(q.pour_on_barricade())
	assert_false(q.pour_on_barricade(), "brak pełnego wiadra")
	assert_false(q.is_barricade_out())
	assert_true(q.pick_bucket("stodola"))
	assert_eq(q.fill_at_well(), 1)
	assert_true(q.pour_on_barricade())
	assert_true(q.is_barricade_out())
	assert_eq(q.state, BucketQuest.State.EXTINGUISHED)
	q.complete()
	assert_eq(q.state, BucketQuest.State.DONE)

func test_cannot_fill_without_empty_bucket():
	var q := BucketQuest.new(3)
	q.start()
	assert_eq(q.fill_at_well(), 0)
	q.pick_bucket("a")
	q.fill_at_well()
	assert_eq(q.fill_at_well(), 0, "już pełne")

func test_same_bucket_once_and_max_three():
	var q := BucketQuest.new(3)
	assert_true(q.pick_bucket("a"), "podniesienie wiadra samo rozpoczyna zadanie")
	assert_eq(q.state, BucketQuest.State.ACTIVE)
	assert_false(q.pick_bucket("a"))
	q.pick_bucket("b")
	q.pick_bucket("c")
	assert_false(q.pick_bucket("d"))
	assert_eq(q.found_count(), 3)

func test_log_shows_progress():
	var q := BucketQuest.new(3)
	q.start()
	q.pick_bucket("a")
	var lines := "\n".join(q.log_lines())
	assert_string_contains(lines, "Wiadra: 1/3")
	assert_string_contains(lines, "Napełnione: 0/3")
	q.fill_at_well()
	assert_string_contains("\n".join(q.log_lines()), "Napełnione: 1/3")

func test_serialization_roundtrip():
	var q := BucketQuest.new(3)
	q.pick_bucket("a")
	q.pick_bucket("b")
	q.fill_at_well()
	q.pour_on_barricade()
	var q2 := BucketQuest.from_dict(JSON.parse_string(JSON.stringify(q.to_dict())))
	assert_eq(q2.found_count(), 2)
	assert_eq(q2.carrying_full(), 1)
	assert_eq(q2.poured, 1)
	assert_eq(q2.state, BucketQuest.State.ACTIVE)

func test_level_has_three_buckets_well_and_barricade():
	var d := Data.load_json("res://data/levels/wioska.json")
	var buckets := 0
	var wells := 0
	var barricades := 0
	for o in d.get("obiekty", []):
		match str(o.get("typ", "")):
			"wiadro": buckets += 1
			"studnia": wells += 1
			"barykada": barricades += 1
	assert_eq(buckets, 3)
	assert_eq(wells, 1)
	assert_eq(barricades, 3, "3 części barykady")
