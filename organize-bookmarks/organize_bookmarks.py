#!/usr/bin/env python3
import os
import sys
import json
import re
import glob
from html.parser import HTMLParser
from datetime import datetime

from dotenv import load_dotenv
from openai import OpenAI

# ——— Load .env (override shell) ———
load_dotenv(override=True)

# ——— Config from .env ———
API_KEY     = os.getenv("OPENAI_API_KEY")
MODEL       = os.getenv("OPENAI_MODEL", "gpt-3.5-turbo")
TEMPERATURE = float(os.getenv("OPENAI_TEMPERATURE", "0.2"))
MAX_TOKENS  = int(os.getenv("OPENAI_MAX_TOKENS", "2000"))
CHUNK_SIZE  = int(os.getenv("CHUNK_SIZE", "100"))

if not API_KEY:
    sys.stderr.write("❌ Please set OPENAI_API_KEY in your .env or environment.\n")
    sys.exit(1)

client = OpenAI(api_key=API_KEY)

class BookmarkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.bookmarks = []
        self._in_a = False
        self._href = None
        self._title_parts = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            self._in_a = True
            for name, val in attrs:
                if name.lower() == "href":
                    self._href = val

    def handle_data(self, data):
        if self._in_a:
            self._title_parts.append(data)

    def handle_endtag(self, tag):
        if tag.lower() == "a" and self._in_a:
            title = "".join(self._title_parts).strip()
            url   = self._href or ""
            self.bookmarks.append({"title": title, "url": url})
            self._in_a = False
            self._href = None
            self._title_parts = []

def parse_bookmarks_html(path):
    parser = BookmarkParser()
    with open(path, encoding="utf-8") as f:
        parser.feed(f.read())
    return parser.bookmarks

def extract_json(text: str) -> str:
    """Find the first {…} balanced JSON in text and clean trailing commas."""
    start = text.find("{")
    if start < 0:
        raise ValueError("No JSON object found in response")
    depth = 0
    end = None
    for i, ch in enumerate(text[start:], start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise ValueError("Could not find matching closing '}'")
    snippet = text[start:end]
    # Remove trailing commas before } or ]
    snippet = re.sub(r",\s*}", "}", snippet)
    snippet = re.sub(r",\s*]", "]", snippet)
    return snippet

def ask_openai_to_categorize(batch, client, retry=True):
    prompt = (
        "You are a bookmark‐organizing assistant.  "
        "Given this list of bookmarks (title and URL), group them into sensible folders.  "
        "Return strictly valid JSON (no code fences, no extra commentary) whose keys are folder names "
        "and whose values are lists of {title, url} objects.\n\n"
        + json.dumps(batch, indent=2)
    )
    # First attempt
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": "You help organize bookmarks."},
            {"role": "user",   "content": prompt}
        ],
        temperature=TEMPERATURE,
        max_tokens=MAX_TOKENS,
    )
    raw = resp.choices[0].message.content

    def parse_or_raise(text):
        clean = extract_json(text)
        return json.loads(clean)

    try:
        return parse_or_raise(raw)
    except Exception as e1:
        if not retry:
            # give up and fallback
            print(f"⚠️ Batch parse failed: {e1}. Marking as Uncategorized.", file=sys.stderr)
            return {"Uncategorized": batch}

        # retry with a nudge
        nudge = "Please output *only* the valid JSON object, with no extra text."
        resp2 = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system",    "content": "You help organize bookmarks."},
                {"role": "user",      "content": prompt},
                {"role": "assistant", "content": raw},
                {"role": "user",      "content": nudge},
            ],
            temperature=TEMPERATURE,
            max_tokens=MAX_TOKENS,
        )
        raw2 = resp2.choices[0].message.content
        try:
            return parse_or_raise(raw2)
        except Exception as e2:
            print(f"⚠️ Retry also failed: {e2}. Marking as Uncategorized.", file=sys.stderr)
            return {"Uncategorized": batch}

def generate_output_html(grouped, out_path):
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
        "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
        f"<!-- Organized on {now} -->",
        "<TITLE>Organized Bookmarks</TITLE>",
        "<H1>Organized Bookmarks</H1>",
        "<DL><p>"
    ]
    for folder, items in grouped.items():
        lines.append(f"    <DT><H3>{folder}</H3>")
        lines.append("    <DL><p>")
        for bm in items:
            title = bm.get("title", bm["url"])
            url   = bm["url"]
            lines.append(f'        <DT><A HREF="{url}">{title}</A>')
        lines.append("    </DL><p>")
    lines.append("</DL><p>")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def chunk_list(lst, size):
    for i in range(0, len(lst), size):
        yield lst[i:i+size]

def main():
    if len(sys.argv) < 2:
        print("Usage: organize_bookmarks.py <input.html> [output.html]", file=sys.stderr)
        sys.exit(1)

    inp  = sys.argv[1]
    outp = sys.argv[2] if len(sys.argv) > 2 else "bookmarks_organized.html"

    print("📥 Parsing bookmarks from", inp)
    bookmarks = parse_bookmarks_html(inp)
    print(f"   found {len(bookmarks)} entries")

    all_grouped = {}
    batches = list(chunk_list(bookmarks, CHUNK_SIZE))
    for idx, batch in enumerate(batches, 1):
        print(f"🤖 Processing batch {idx}/{len(batches)} ({len(batch)} items)…")
        grouped = ask_openai_to_categorize(batch, client, retry=True)
        for folder, items in grouped.items():
            all_grouped.setdefault(folder, []).extend(items)

    print("💾 Writing organized HTML to", outp)
    generate_output_html(all_grouped, outp)
    print("✅ Done.")

if __name__ == "__main__":
    main()
