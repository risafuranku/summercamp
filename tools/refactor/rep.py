# rep.py FILE: replacements read from stdin as a python list of (old, new); keeps the file's line ends.
import sys, ast
path = sys.argv[1]
raw = open(path, 'rb').read()
crlf = b'\r\n' in raw
s = raw.decode('utf-8').replace('\r\n', '\n')
pairs = ast.literal_eval(sys.stdin.buffer.read().decode("utf-8"))
for old, new in pairs:
    n = s.count(old)
    if n != 1:
        sys.exit("%s: %d matches for %r" % (path, n, old[:80]))
    s = s.replace(old, new)
out = s.replace('\n', '\r\n') if crlf else s
open(path, 'wb').write(out.encode('utf-8'))
print("ok", path, "crlf" if crlf else "lf")
