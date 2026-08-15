#!/usr/bin/env python3
"""
generate_report.py
Scans the feedback/ directory for Markdown files, counts them by category,
and overwrites output.html with a Workbench HTML report.
"""

import re
from pathlib import Path
from datetime import datetime, timezone

FEEDBACK_DIR = Path(__file__).parent / "feedback"
OUTPUT_FILE = Path(__file__).parent / "output.html"

CATEGORIES = {
    "feature-requests": "Feature Requests",
    "issue-reports": "Issue Reports",
    "general": "General Feedback",
}


def collect_items():
    """Return a dict mapping category -> list of (number, filename) tuples."""
    results = {}
    for folder, label in CATEGORIES.items():
        cat_path = FEEDBACK_DIR / folder
        items = []
        if cat_path.is_dir():
            for f in sorted(cat_path.iterdir()):
                if f.suffix == ".md" and f.name != "000-template.md":
                    # Extract leading request number if present (e.g. "001-dark-mode.md")
                    m = re.match(r"^(\d+)", f.name)
                    number = m.group(1) if m else "—"
                    items.append((number, f.name))
        results[folder] = {"label": label, "items": items}
    return results


def render_html(data):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    total = sum(len(v["items"]) for v in data.values())

    rows = ""
    for folder, info in data.items():
        label = info["label"]
        items = info["items"]
        count = len(items)
        if items:
            item_list = "".join(
                f"<li><span class='num'>#{num}</span> {name}</li>"
                for num, name in items
            )
        else:
            item_list = "<li><em>No items yet.</em></li>"
        rows += f"""
        <tr>
          <td>{label}</td>
          <td class="center">{count}</td>
          <td><ul>{item_list}</ul></td>
        </tr>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Web Application Feedback Workbench Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 2rem; color: #222; }}
    h1 {{ color: #2c5f8a; }}
    p.meta {{ color: #666; font-size: 0.9rem; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ccc; padding: 0.6rem 1rem; vertical-align: top; }}
    th {{ background: #2c5f8a; color: #fff; }}
    tr:nth-child(even) {{ background: #f5f8fb; }}
    .center {{ text-align: center; }}
    .num {{ color: #888; font-size: 0.85rem; }}
    ul {{ margin: 0; padding-left: 1.2rem; }}
    li {{ margin: 0.2rem 0; }}
    .total {{ font-weight: bold; margin-top: 1rem; }}
  </style>
</head>
<body>
  <h1>Web Application Feedback Workbench Report</h1>
  <p class="meta">Generated: {now}</p>
  <p class="total">Total items: {total}</p>
  <table>
    <thead>
      <tr>
        <th>Category</th>
        <th>Count</th>
        <th>Items</th>
      </tr>
    </thead>
    <tbody>{rows}
    </tbody>
  </table>
</body>
</html>
"""


def main():
    data = collect_items()
    html = render_html(data)
    OUTPUT_FILE.write_text(html, encoding="utf-8")
    print(f"Report written to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
