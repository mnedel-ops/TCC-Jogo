class_name PerfStats
extends RefCounted


static func mean(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s := 0.0
	for x in v:
		s += float(x)
	return s / v.size()


static func minimum(v: Array) -> float:
	var m := INF
	for x in v:
		m = minf(m, float(x))
	return m if m != INF else 0.0


static func maximum(v: Array) -> float:
	var m := -INF
	for x in v:
		m = maxf(m, float(x))
	return m if m != -INF else 0.0


static func stddev(v: Array) -> float:
	if v.size() < 2:
		return 0.0
	var m := mean(v)
	var acc := 0.0
	for x in v:
		acc += (float(x) - m) * (float(x) - m)
	return sqrt(acc / (v.size() - 1))


static func median(v: Array) -> float:
	return percentile(v, 50.0)


# Percentil pelo método do posto mais próximo (nearest-rank).
static func percentile(v: Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var s: Array = v.duplicate()
	s.sort()
	var rank := int(ceil(clampf(p, 0.0, 100.0) / 100.0 * s.size()))
	return float(s[clampi(rank - 1, 0, s.size() - 1)])


# Maior sequência consecutiva de amostras estritamente abaixo do limite.
static func longest_run_below(v: Array, threshold: float) -> int:
	var best := 0
	var run := 0
	for x in v:
		if float(x) < threshold:
			run += 1
			best = maxi(best, run)
		else:
			run = 0
	return best


static func growth_pct(first: float, last: float) -> float:
	if first <= 0.0:
		return 0.0
	return (last - first) / first * 100.0


static func strictly_increasing(v: Array) -> bool:
	if v.size() < 2:
		return false
	for i in range(1, v.size()):
		if float(v[i]) <= float(v[i - 1]):
			return false
	return true
