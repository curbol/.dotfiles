"""Tests for sc.py against a stub Shortcut API.

Run: python3 -m unittest discover -s .claude/skills/grooming-an-epic/tests
"""

import contextlib
import http.server
import io
import json
import os
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))


class Stub(http.server.BaseHTTPRequestHandler):
    stories = {}
    workflows = {}
    epic_stories = {}
    writes = []

    def log_message(self, *args):
        pass

    def reply(self, code, obj=None):
        body = json.dumps(obj).encode() if obj is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n)) if n else None

    def do_GET(self):
        parts = self.path.strip("/").split("/")[2:]
        if parts[0] == "stories" and int(parts[1]) in self.stories:
            return self.reply(200, self.stories[int(parts[1])])
        if parts[0] == "workflows" and len(parts) == 1:
            return self.reply(200, list(self.workflows.values()))
        if parts[0] == "workflows":
            return self.reply(200, self.workflows[int(parts[1])])
        if parts[0] == "epics" and parts[2:] == ["stories"]:
            return self.reply(200, self.epic_stories[int(parts[1])])
        self.reply(404, {"message": "not found"})

    def do_PUT(self):
        parts = self.path.strip("/").split("/")[2:]
        body = self.body()
        self.writes.append(("PUT", self.path, body))
        story = self.stories[int(parts[1])]
        story.update(body)
        self.reply(200, story)

    def do_POST(self):
        body = self.body()
        self.writes.append(("POST", self.path, body))
        self.reply(201, {"id": 99, **body})


class ScTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Stub)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        os.environ["SHORTCUT_API_BASE"] = f"http://127.0.0.1:{cls.server.server_address[1]}/api/v3"
        os.environ["SHORTCUT_API_TOKEN"] = "test-token"
        global sc
        import sc  # noqa: E402  (reads SHORTCUT_API_BASE at import)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        Stub.writes.clear()
        Stub.stories.clear()
        Stub.stories[1] = {"id": 1, "name": "One", "description": "old text", "workflow_id": 7,
                           "workflow_state_id": 70, "story_links": [], "pull_requests": []}
        Stub.workflows.clear()
        Stub.workflows[7] = {"id": 7, "states": [
            {"id": 70, "name": "Unprioritized", "type": "unstarted"},
            {"id": 71, "name": "Won't Fix", "type": "done"},
        ]}
        self.dir = tempfile.mkdtemp()
        self.state_dir = tempfile.mkdtemp()
        sc.STATE_DIR = self.state_dir

    def run_sc(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = sc.main(list(argv))
        return code, out.getvalue()

    def write_draft(self, text):
        with open(os.path.join(self.dir, "story-1.new.md"), "w") as f:
            f.write(text)

    def test_apply_writes_draft_when_description_is_unchanged(self):
        self.run_sc("snapshot", self.dir, "1")
        self.write_draft("new text")
        code, out = self.run_sc("apply", self.dir, "1")
        self.assertEqual(code, 0)
        self.assertEqual(Stub.stories[1]["description"], "new text\n")
        self.assertIn("updated", out)

    def test_apply_refuses_when_description_changed_after_snapshot(self):
        self.run_sc("snapshot", self.dir, "1")
        Stub.stories[1]["description"] = "someone else's edit"
        self.write_draft("new text")
        code, out = self.run_sc("apply", self.dir, "1")
        self.assertEqual(code, 1)
        self.assertEqual(Stub.stories[1]["description"], "someone else's edit")
        self.assertIn("refused", out)
        self.assertEqual([w for w in Stub.writes if w[0] == "PUT"], [])

    def test_apply_dry_run_writes_nothing(self):
        self.run_sc("snapshot", self.dir, "1")
        self.write_draft("new text")
        code, out = self.run_sc("apply", self.dir, "1", "--dry-run")
        self.assertEqual(code, 0)
        self.assertEqual(Stub.stories[1]["description"], "old text")
        self.assertIn("would update", out)

    def test_apply_skips_a_story_without_a_draft(self):
        self.run_sc("snapshot", self.dir, "1")
        code, out = self.run_sc("apply", self.dir, "1")
        self.assertEqual(code, 1)
        self.assertIn("skipped", out)

    def test_state_resolves_a_name_within_the_story_workflow(self):
        code, out = self.run_sc("state", "1", "won't fix")
        self.assertEqual(code, 0)
        self.assertEqual(Stub.stories[1]["workflow_state_id"], 71)

    def test_state_rejects_a_name_outside_the_workflow(self):
        code, _ = self.run_sc("state", "1", "Completed")
        self.assertEqual(code, 2)
        self.assertEqual(Stub.stories[1]["workflow_state_id"], 70)

    def test_changed_lists_only_stories_moved_after_since_and_advances_the_watermark(self):
        Stub.epic_stories[5] = [
            {"id": 1, "name": "One", "workflow_state_id": 71, "moved_at": "2026-09-30T10:00:00Z"},
            {"id": 2, "name": "Two", "workflow_state_id": 70, "moved_at": "2026-09-20T10:00:00Z"},
        ]
        code, out = self.run_sc("changed", "5", "--since", "2026-09-29T00:00:00Z", "--advance")
        self.assertEqual(code, 0)
        self.assertIn("\t1\tWon't Fix\tdone\tOne", out)
        self.assertNotIn("Two", out)
        with open(os.path.join(self.state_dir, "epic-5.json")) as f:
            self.assertIn("since", json.load(f))

    def test_changed_without_a_watermark_asks_for_since(self):
        Stub.epic_stories[5] = []
        code, _ = self.run_sc("changed", "5")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
