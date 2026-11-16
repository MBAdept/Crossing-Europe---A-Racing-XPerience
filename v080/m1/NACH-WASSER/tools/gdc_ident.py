"""Look for identifiers in a decompressed Godot 4 GDScript token buffer (identifiers: UTF-32 LE, each byte XOR 0xb6).

usage: gdc_ident.py <raw.bin> <identifier>...
"""
import sys

raw = open(sys.argv[1], "rb").read()
for ident in sys.argv[2:]:
    enc = bytes(b ^ 0xB6 for ch in ident for b in ord(ch).to_bytes(4, "little"))
    plain = ident.encode("utf-8")
    print("%-22s xor-utf32: %d  plain: %d" % (ident, raw.count(enc), raw.count(plain)))
