extends SceneTree
# Decompress a compressed GDScript token file (.gdc, "GDSC" + version + size + zstd) and print its identifiers.
# usage: godot --headless -s gdc_strings.gd -- <file.gdc> <out.bin>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var data := FileAccess.get_file_as_bytes(args[0])
	var magic := data.slice(0, 4).get_string_from_ascii()
	var version := data.decode_u32(4)
	var size := data.decode_u32(8)
	print("magic=", magic, " version=", version, " decompressed_size=", size)
	var raw := data.slice(12).decompress(size, FileAccess.COMPRESSION_ZSTD)
	print("decompressed bytes=", raw.size())
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
	quit(0)
