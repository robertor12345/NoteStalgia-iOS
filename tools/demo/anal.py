"""Summarise a macOS `sample` report: main-thread busy %, top inclusive app frames."""
import re, sys
from collections import defaultdict
txt = open(sys.argv[1]).read().split("\n")
filt = sys.argv[2] if len(sys.argv) > 2 else "NoteStalgia-iOS"
start = next(i for i, l in enumerate(txt) if "Main Thread" in l)
end = next(i for i in range(start + 1, len(txt)) if re.match(r"^\s{4}\d+ Thread_", txt[i]) or txt[i].startswith("Total number"))
rows = []
for l in txt[start:end]:
    m = re.match(r"^([\s+!:|]*)(\d+) (.*)$", l)
    if m:
        rows.append((len(m.group(1)), int(m.group(2)), m.group(3)))
total = rows[0][1]
idle = sum(c for d, c, s in rows if s.startswith("mach_msg2_trap") or s.startswith("__psynch_cvwait") or s.startswith("__semwait_signal"))
print(f"main thread samples {total}, blocked/idle {idle} ({100*idle/total:.0f}%)")
inc = defaultdict(int)
stack = []
for d, c, s in rows:
    while stack and stack[-1][0] >= d:
        stack.pop()
    key = re.sub(r"\s+\+ \d+.*$", "", s)
    key = re.sub(r"\s+\[0x.*$", "", key)
    if filt in s and key not in [k for _, k in stack]:
        inc[key] += c
    stack.append((d, key))
for k, v in sorted(inc.items(), key=lambda kv: -kv[1])[:int(sys.argv[3]) if len(sys.argv) > 3 else 25]:
    print(f"{v:6d} {100*v/total:5.1f}%  {k[:150]}")
