class_name ProbeThing
extends RefCounted
static var loaded := ""
static func reload(manifest_path: String = "") -> bool:
	loaded = "static reload called with '%s'" % manifest_path
	return true
