"""Check repository-local Markdown links and heading anchors without network access."""

import argparse
import html
from pathlib import Path
import re
import sys
import unicodedata
from urllib.parse import unquote, urlsplit


def outside_fences(text):
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if marker:
            value = marker.group(1)
            if fence is None:
                fence = value
            elif value[0] == fence[0] and len(value) >= len(fence):
                fence = None
            lines.append("")
        else:
            lines.append(line if fence is None else "")
    return "\n".join(lines)


def heading_ids(text):
    text = outside_fences(text)
    ids = set(re.findall(r'<a\s+[^>]*(?:id|name)=["\']([^"\']+)', text, re.I))
    for match in re.finditer(r"^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$", text, re.M):
        heading = re.sub(r"!?\[([^]]*)\]\([^)]*\)", r"\1", match.group(1))
        heading = html.unescape(re.sub(r"<[^>]+>", "", heading)).lower()
        heading = heading.replace("`", "").replace("*", "")
        slug = "".join(c for c in heading if c in "-_" or unicodedata.category(c)[0] not in "PS")
        slug = slug.replace(" ", "-")
        candidate, suffix = slug, 0
        while candidate in ids:
            suffix += 1
            candidate = f"{slug}-{suffix}"
        ids.add(candidate)
    return ids


def markdown_links(text):
    text = outside_fences(text)
    references = {}
    for match in re.finditer(r"^ {0,3}\[([^]]+)\]:\s*(?:<([^>]+)>|(\S+))", text, re.M):
        references[match.group(1).strip().casefold()] = match.group(2) or match.group(3)
        yield text[:match.start()].count("\n") + 1, match.group(2) or match.group(3)
    pattern = r"!?\[[^]\n]*\]\(\s*(?:<([^>]+)>|((?:[^\s()]|\([^()]*\))+))(?:\s+[\"'][^\n]*?[\"'])?\s*\)"
    for match in re.finditer(pattern, text):
        yield text[:match.start()].count("\n") + 1, match.group(1) or match.group(2)
    for match in re.finditer(r"!?\[([^]\n]+)\]\[([^]\n]*)\]", text):
        key = (match.group(2) or match.group(1)).strip().casefold()
        if key not in references:
            yield text[:match.start()].count("\n") + 1, f"MISSING_REFERENCE:{key}"


def validate(root):
    root = root.resolve()
    errors = []
    checked = 0
    anchors = {}
    files = sorted(p for p in root.rglob("*.md") if ".git" not in p.relative_to(root).parts)
    for path in files:
        content = path.read_text(encoding="utf-8-sig")
        for line, link in markdown_links(content):
            location = f"{path.relative_to(root)}:{line}"
            if link.startswith("MISSING_REFERENCE:"):
                errors.append(f"{location}: undefined link reference {link.split(':', 1)[1]}")
                continue
            parsed = urlsplit(link)
            if parsed.scheme or parsed.netloc:
                continue
            checked += 1
            target = (root / unquote(parsed.path).lstrip("/") if parsed.path.startswith("/")
                      else path.parent / unquote(parsed.path)) if parsed.path else path
            target = target.resolve()
            if not target.is_relative_to(root):
                errors.append(f"{location}: link escapes the repository: {link}")
            elif not target.exists():
                errors.append(f"{location}: missing target: {link}")
            elif parsed.fragment and target.suffix.lower() == ".md":
                if target not in anchors:
                    anchors[target] = heading_ids(target.read_text(encoding="utf-8-sig"))
                if unquote(parsed.fragment) not in anchors[target]:
                    errors.append(f"{location}: missing heading anchor: {link}")
    return errors, len(files), checked


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    failures, files, links = validate(args.root)
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    print(f"Checked {links} local links in {files} Markdown files; {len(failures)} failure(s).")
    sys.exit(bool(failures))
