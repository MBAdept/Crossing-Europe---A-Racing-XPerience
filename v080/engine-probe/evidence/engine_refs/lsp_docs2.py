import socket, json, sys, time
s = socket.socket(); s.connect(("127.0.0.1", 6077)); s.settimeout(30)
def send(obj):
    b = json.dumps(obj).encode()
    s.sendall(b"Content-Length: %d\r\n\r\n" % len(b) + b)
buf = b""
def recv():
    global buf
    while b"\r\n\r\n" not in buf:
        d = s.recv(65536)
        if not d: return None
        buf += d
    head, rest = buf.split(b"\r\n\r\n", 1)
    n = 0
    for line in head.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            n = int(line.split(b":")[1])
    while len(rest) < n:
        d = s.recv(1 << 20)
        if not d: return None
        rest += d
    body, buf = rest[:n], rest[n:]
    return json.loads(body)
send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"processId": None, "rootUri": "file://" + sys.argv[1], "capabilities": {}}})
classes = None
while True:
    m = recv()
    if m is None: break
    if m.get("id") == 1:
        send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
        continue
    if m.get("method") == "gdscript/capabilities":
        classes = [c["name"] for c in m["params"]["native_classes"]]
        break
print("classes", len(classes))
out = {}
rid = 100
for c in classes:
    rid += 1
    send({"jsonrpc": "2.0", "id": rid, "method": "textDocument/nativeSymbol", "params": {"native_class": c, "symbol_name": c}})
    while True:
        m = recv()
        if m is None: break
        if m.get("id") == rid:
            out[c] = m.get("result")
            break
json.dump(out, open(sys.argv[2], "w"))
print("done", len(out))
