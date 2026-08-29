import json, sys
d = json.load(sys.stdin)
for p in d["result"]["panes"]:
    label = p.get("label")
    if label:
        print("  {:16s} {}".format(label, p["agent_status"]))
