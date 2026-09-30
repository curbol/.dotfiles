#!/usr/bin/env python3
"""Shortcut helpers for grooming an epic.

Every write that replaces a description goes through `apply`, which refuses to
overwrite a description that changed after its snapshot was taken.

Reads SHORTCUT_API_TOKEN, and SHORTCUT_API_BASE when set (tests point it at a
stub server).
"""

import argparse
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request

API_BASE = os.environ.get("SHORTCUT_API_BASE", "https://api.app.shortcut.com/api/v3")
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "grooming-an-epic"
)
ATTEMPTS = 4


class ApiError(Exception):
    pass


def request(method, path, body=None):
    token = os.environ.get("SHORTCUT_API_TOKEN")
    if not token:
        raise ApiError("SHORTCUT_API_TOKEN is not set")
    data = json.dumps(body).encode() if body is not None else None
    last = None
    for attempt in range(ATTEMPTS):
        req = urllib.request.Request(
            API_BASE + path,
            method=method,
            data=data,
            headers={"Shortcut-Token": token, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as err:
            # A 4xx is the API's answer, not a transport failure, so it is not retried.
            if err.code < 500:
                raise ApiError(f"{method} {path}: HTTP {err.code}: {err.read()[:300].decode(errors='replace')}")
            last = err
        except (urllib.error.URLError, ConnectionError, TimeoutError) as err:
            last = err
        time.sleep(min(2 ** attempt, 8) if attempt < ATTEMPTS - 1 else 0)
    raise ApiError(f"{method} {path}: failed after {ATTEMPTS} attempts: {last}")


def target(ref):
    """Map `123` or `story:123` to a story path, and `epic:123` to an epic path."""
    kind, _, ident = ref.rpartition(":")
    kind = kind or "story"
    if kind not in ("story", "epic") or not ident.isdigit():
        raise ApiError(f"not a story or epic reference: {ref}")
    return kind, int(ident), f"/{'stories' if kind == 'story' else 'epics'}/{ident}"


def snapshot_path(directory, kind, ident):
    return os.path.join(directory, f"{kind}-{ident}.json")


def draft_path(directory, kind, ident):
    return os.path.join(directory, f"{kind}-{ident}.new.md")


def cmd_snapshot(args):
    os.makedirs(args.dir, exist_ok=True)
    for ref in args.refs:
        kind, ident, path = target(ref)
        obj = request("GET", path)
        with open(snapshot_path(args.dir, kind, ident), "w") as f:
            json.dump(obj, f)
        print(f"{kind}:{ident} snapshot, {len(obj.get('description') or '')} chars")


def cmd_apply(args):
    refused = 0
    for ref in args.refs:
        kind, ident, path = target(ref)
        snap_file, draft_file = snapshot_path(args.dir, kind, ident), draft_path(args.dir, kind, ident)
        if not os.path.exists(snap_file) or not os.path.exists(draft_file):
            print(f"{kind}:{ident} skipped: needs {os.path.basename(snap_file)} and {os.path.basename(draft_file)}")
            refused += 1
            continue
        with open(snap_file) as f:
            snap = json.load(f)
        with open(draft_file) as f:
            draft = f.read().strip() + "\n"
        current = request("GET", path)
        if (current.get("description") or "") != (snap.get("description") or ""):
            print(f"{kind}:{ident} refused: its description changed after the snapshot; re-snapshot and redo the draft")
            refused += 1
            continue
        if args.dry_run:
            print(f"{kind}:{ident} would update, {len(snap.get('description') or '')} -> {len(draft)} chars")
            continue
        out = request("PUT", path, {"description": draft})
        print(f"{kind}:{ident} updated, {len(snap.get('description') or '')} -> {len(out.get('description') or '')} chars")
    return 1 if refused else 0


def workflow_states(story):
    workflow = request("GET", f"/workflows/{story['workflow_id']}")
    return {s["id"]: s for s in workflow["states"]}


def cmd_get(args):
    kind, ident, path = target(args.ref)
    obj = request("GET", path)
    if kind == "story":
        state = workflow_states(obj).get(obj["workflow_state_id"], {}).get("name")
        print(json.dumps({
            "id": obj["id"], "name": obj["name"], "state": state, "epic_id": obj.get("epic_id"),
            "description_chars": len(obj.get("description") or ""),
            "links": [(l["subject_id"], l["verb"], l["object_id"], l["id"]) for l in obj.get("story_links", [])],
            "pull_requests": [(p.get("number"), p.get("merged"), p.get("closed")) for p in obj.get("pull_requests", [])],
        }, indent=2))
    else:
        print(json.dumps({"id": obj["id"], "name": obj["name"], "description_chars": len(obj.get("description") or "")}, indent=2))


def cmd_comment(args):
    text = sys.stdin.read() if args.text == "-" else args.text
    _, ident, _ = target(args.ref)
    out = request("POST", f"/stories/{ident}/comments", {"text": text})
    print(f"story:{ident} comment {out['id']}")


def cmd_state(args):
    _, ident, path = target(args.ref)
    story = request("GET", path)
    states = workflow_states(story)
    by_name = {s["name"].lower(): s["id"] for s in states.values()}
    wanted = args.state if args.state.isdigit() else by_name.get(args.state.lower())
    if wanted is None or int(wanted) not in states:
        raise ApiError(f"no state '{args.state}' in this story's workflow: {sorted(s['name'] for s in states.values())}")
    request("PUT", path, {"workflow_state_id": int(wanted)})
    print(f"story:{ident} -> {states[int(wanted)]['name']}")


def cmd_move(args):
    _, ident, path = target(args.ref)
    request("PUT", path, {"epic_id": args.epic})
    print(f"story:{ident} -> epic {args.epic}")


def cmd_links(args):
    _, ident, path = target(args.ref)
    for l in request("GET", path).get("story_links", []):
        print(f"{l['id']}\t{l['subject_id']} {l['verb']} {l['object_id']}")


def cmd_link(args):
    out = request("POST", "/story-links", {"subject_id": args.subject, "verb": args.verb, "object_id": args.object})
    print(f"link {out['id']}: {args.subject} {args.verb} {args.object}")


def cmd_unlink(args):
    request("DELETE", f"/story-links/{args.link_id}")
    print(f"link {args.link_id} deleted")


def watermark_file(epic):
    return os.path.join(STATE_DIR, f"epic-{epic}.json")


def cmd_changed(args):
    since = args.since
    if since is None and os.path.exists(watermark_file(args.epic)):
        with open(watermark_file(args.epic)) as f:
            since = json.load(f)["since"]
    if since is None:
        raise ApiError(f"no watermark for epic {args.epic} yet; pass --since <ISO time>")
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    stories = request("GET", f"/epics/{args.epic}/stories")
    states = {}
    for workflow in request("GET", "/workflows"):
        for s in workflow["states"]:
            states[s["id"]] = s
    moved = sorted(
        (s for s in stories if (s.get("moved_at") or "") > since),
        key=lambda s: s.get("moved_at") or "",
    )
    for s in moved:
        state = states.get(s["workflow_state_id"], {})
        print(f"{s['moved_at']}\t{s['id']}\t{state.get('name')}\t{state.get('type')}\t{s['name']}")
    print(f"{len(moved)} stories changed state since {since}", file=sys.stderr)
    if args.advance:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(watermark_file(args.epic), "w") as f:
            json.dump({"since": now}, f)
        print(f"watermark advanced to {now}", file=sys.stderr)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("snapshot", help="save stories or epics as <dir>/<kind>-<id>.json")
    p.add_argument("dir"); p.add_argument("refs", nargs="+")
    p.set_defaults(func=cmd_snapshot)

    p = sub.add_parser("apply", help="write <dir>/<kind>-<id>.new.md unless the description changed since its snapshot")
    p.add_argument("dir"); p.add_argument("refs", nargs="+"); p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_apply)

    p = sub.add_parser("get", help="summarize a story (state, links, PRs) or an epic")
    p.add_argument("ref"); p.set_defaults(func=cmd_get)

    p = sub.add_parser("comment", help="comment on a story; '-' reads the text from stdin")
    p.add_argument("ref"); p.add_argument("text"); p.set_defaults(func=cmd_comment)

    p = sub.add_parser("state", help="move a story to a state, by name or id, within its own workflow")
    p.add_argument("ref"); p.add_argument("state"); p.set_defaults(func=cmd_state)

    p = sub.add_parser("move", help="move a story to another epic")
    p.add_argument("ref"); p.add_argument("epic", type=int); p.set_defaults(func=cmd_move)

    p = sub.add_parser("links", help="list a story's links")
    p.add_argument("ref"); p.set_defaults(func=cmd_links)

    p = sub.add_parser("link", help="link two stories, e.g. 'link 101 blocks 102'")
    p.add_argument("subject", type=int); p.add_argument("verb", choices=["blocks", "duplicates", "relates to"])
    p.add_argument("object", type=int); p.set_defaults(func=cmd_link)

    p = sub.add_parser("unlink", help="delete a story link by id")
    p.add_argument("link_id", type=int); p.set_defaults(func=cmd_unlink)

    p = sub.add_parser("changed", help="list the epic's stories that changed state since the watermark")
    p.add_argument("epic", type=int); p.add_argument("--since")
    p.add_argument("--advance", action="store_true", help="move the watermark to now after listing")
    p.set_defaults(func=cmd_changed)

    args = parser.parse_args(argv)
    try:
        return args.func(args) or 0
    except ApiError as err:
        print(f"error: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
