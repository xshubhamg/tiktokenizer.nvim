"""Tokenize stdin with tiktoken, print JSON.

Usage:
    python tokenize.py --encoding cl100k_base < input.txt
    echo "hello" | uvx --with tiktoken python tokenize.py --encoding o200k_base

Output:
    {"count": 8, "segments": [{"text": "This", "id": 2028}, ...]}
"""

import argparse
import json
import sys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--encoding", default="cl100k_base")
    args = ap.parse_args()

    text = sys.stdin.read()

    try:
        import tiktoken
    except ImportError:
        sys.stdout.write(json.dumps({"error": "tiktoken not installed"}))
        return 1

    try:
        enc = tiktoken.get_encoding(args.encoding)
    except Exception as e:  # unknown encoding
        sys.stdout.write(json.dumps({"error": f"bad encoding: {e}"}))
        return 1

    try:
        ids = enc.encode(text)
    except Exception as e:
        sys.stdout.write(json.dumps({"error": f"encode failed: {e}"}))
        return 1

    segments = []
    for tok_id in ids:
        try:
            # decode_single_token_bytes exists on core BPE ranks; best for display
            b = enc.decode_single_token_bytes(tok_id)
            s = b.decode("utf-8", errors="replace")
        except Exception:
            try:
                s = enc.decode([tok_id])
            except Exception:
                s = ""
        segments.append({"text": s, "id": tok_id})

    sys.stdout.write(json.dumps({"count": len(ids), "segments": segments}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
