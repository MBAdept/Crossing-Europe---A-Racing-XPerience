class_name ThingDB
extends RefCounted
static var calls := 0
static func reload(path: String = "") -> bool:
	calls += 1
	print("ThingDB.reload reached with '", path, "'")
	return true
