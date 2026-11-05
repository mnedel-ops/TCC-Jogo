extends GdUnitTestSuite


func test_basic_statistics() -> void:
	var v := [10.0, 20.0, 30.0, 40.0]
	assert_float(PerfStats.mean(v)).is_equal(25.0)
	assert_float(PerfStats.minimum(v)).is_equal(10.0)
	assert_float(PerfStats.maximum(v)).is_equal(40.0)
	assert_float(PerfStats.median(v)).is_equal(20.0)
	assert_float(PerfStats.stddev(v)).is_equal_approx(12.9099, 0.001)


func test_empty_input_is_safe() -> void:
	assert_float(PerfStats.mean([])).is_equal(0.0)
	assert_float(PerfStats.minimum([])).is_equal(0.0)
	assert_float(PerfStats.maximum([])).is_equal(0.0)
	assert_float(PerfStats.percentile([], 99.0)).is_equal(0.0)
	assert_float(PerfStats.stddev([5.0])).is_equal(0.0)


func test_percentile_nearest_rank() -> void:
	var v: Array = []
	for i in range(1, 101):
		v.append(float(i))
	assert_float(PerfStats.percentile(v, 99.0)).is_equal(99.0)
	assert_float(PerfStats.percentile(v, 100.0)).is_equal(100.0)
	assert_float(PerfStats.percentile(v, 1.0)).is_equal(1.0)


func test_longest_run_below_threshold() -> void:
	assert_int(PerfStats.longest_run_below([60, 25, 20, 61, 10, 59], 30.0)).is_equal(2)
	assert_int(PerfStats.longest_run_below([60, 61, 62], 30.0)).is_equal(0)
	assert_int(PerfStats.longest_run_below([30, 30], 30.0)).is_equal(0)


func test_growth_and_monotonic_trend() -> void:
	assert_float(PerfStats.growth_pct(100.0, 105.0)).is_equal(5.0)
	assert_float(PerfStats.growth_pct(0.0, 5.0)).is_equal(0.0)
	assert_bool(PerfStats.strictly_increasing([1, 2, 3])).is_true()
	assert_bool(PerfStats.strictly_increasing([1, 2, 2])).is_false()
	assert_bool(PerfStats.strictly_increasing([1])).is_false()
