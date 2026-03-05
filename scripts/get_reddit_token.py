#!/usr/bin/env python3
"""Fetch a Reddit OAuth bearer token using client credentials.

Requires:
  REDDIT_CLIENT_ID
  REDDIT_CLIENT_SECRET
"""

from __future__ import annotations

import base64
import json
import os
import sys
import urllib.parse
import urllib.request


def main() -> int:
    client_id = os.environ.get("REDDIT_CLIENT_ID", "").strip()
    client_secret = os.environ.get("REDDIT_CLIENT_SECRET", "").strip()
    if not client_id or not client_secret:
        print("Missing REDDIT_CLIENT_ID or REDDIT_CLIENT_SECRET", file=sys.stderr)
        return 2

    token_url = "https://www.reddit.com/api/v1/access_token"
    data = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("utf-8")

    basic = base64.b64encode(f"{client_id}:{client_secret}".encode("utf-8")).decode("ascii")
    headers = {
        "User-Agent": "AppleWatchFitnessTrendResearch/1.0 (by /u/research-bot)",
        "Authorization": f"Basic {basic}",
        "Content-Type": "application/x-www-form-urlencoded",
    }

    req = urllib.request.Request(token_url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))

    token = payload.get("access_token", "")
    if not token:
        print(json.dumps(payload, indent=2), file=sys.stderr)
        return 1

    print(token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
