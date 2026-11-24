extends RefCounted
## Timing of the headless checks on a shared machine (RINT-B; docs/renderer-modern.md §13.6). Wall-clock times on this
## VM are bimodal under the load of other jobs (the same code took 36 or 49 µs per car), so a budget check measures
## relative to a reference workload of the same process: a fixed piece of pure GDScript (vector maths, packed arrays,
## dictionary reads – what the renderer's layers do), timed INTERLEAVED with the code under test (one reference run
## next to every sample). The result is scaled to the speed at which this VM runs the reference in REF_NOMINAL_US
## (calibrated on the build VM: median of runs while it was quiet):
##     time at normal speed = median(samples) × REF_NOMINAL_US / median(reference runs)
## A budget keeps its meaning – "µs on this VM at its normal speed", as contract §4.10 states its budgets ("render()
## GDScript avg (this VM)") – whatever else the machine does at the time. (The CPU time of a thread is no help here:
## /proc/thread-self/schedstat moves only at scheduler ticks, measured 0 µs for 2 ms of work.)
## Use:
##     var clock := PerfClock.new()
##     for …: clock.sample_reference(); var t0 := Time.get_ticks_usec(); work(); clock.add(Time.get_ticks_usec() - t0)
##     clock.normal_median()   # median of the samples at normal speed; clock.factor() = the scale applied

const REF_ITER := 1500
const REF_NOMINAL_US := 600.0      ## wall µs of one reference_once() on the build VM at its normal speed (RINT-B:
                                   ## medians 592, 610 µs in normal runs, 921 µs in the slow mode of the shared VM)

var samples: Array[float] = []
var refs: Array[float] = []


## One reference run, timed (call it next to every sample).
func sample_reference() -> void:
	var t0 := Time.get_ticks_usec()
	reference_once()
	refs.append(float(Time.get_ticks_usec() - t0))


func add(us: float) -> void:
	samples.append(us)


## REF_NOMINAL_US / median of the reference runs: below 1 while the machine is slower than normal.
func factor() -> float:
	return REF_NOMINAL_US / maxf(median(refs), 1.0)


## Median of the samples, scaled to the VM's normal speed.
func normal_median() -> float:
	return median(samples) * factor()


## Quantile q (0..1) of the samples, scaled to the VM's normal speed.
func normal_quantile(q: float) -> float:
	if samples.is_empty():
		return 0.0
	var s := samples.duplicate()
	s.sort()
	return float(s[clampi(int(float(s.size() - 1) * q), 0, s.size() - 1)]) * factor()


static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var s := values.duplicate()
	s.sort()
	return float(s[s.size() / 2])


## The reference workload: a fixed mix of what the layers do per frame (no engine call that depends on a scene).
static func reference_once(iterations: int = REF_ITER) -> float:
	var acc := 0.0
	var arr := PackedFloat32Array()
	arr.resize(256)
	var d := {"a": 1.0, "b": 2.0, "c": 3.0, "set": "traffic/sedan_red"}
	var basis := Basis(Vector3.UP, 0.3)
	var v := Vector3(1.0, 2.0, 3.0)
	for i in iterations:
		var x := float(i) * 0.001
		v = basis * v + Vector3(x, -x, 0.5 * x)
		var t := Transform3D(basis, v)
		acc += (t * Vector3(0.5, 0.25, -1.0)).length() * 0.0001
		arr[i & 255] = acc
		acc += float(d.get("b", 0.0)) * sin(x) + arr[(i * 7) & 255] * 0.00001
		if str(d["set"]).begins_with("traffic/"):
			acc += 0.000001
	return acc
