#!/usr/bin/env python3
"""Rebuild the six Ember screen mockups as a standalone page for PNG export."""
import re
import sys

src = open(sys.argv[1]).read()

style = re.search(r"<style>(.*?)</style>", src, re.S).group(1)
screens = re.search(r'<div class="screens">(.*?)\n  </div>\n</section>', src, re.S).group(1)
script = re.search(r"<script>(.*?)</script>", src, re.S).group(1)

fonts = ('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
         'family=Archivo:wght@400;600;800;900&family=Public+Sans:wght@300;400;500;600'
         '&family=IBM+Plex+Mono:wght@400;500;600&display=swap">')

page = f"""<!doctype html><html><head><meta charset="utf-8">{fonts}
<style>
{style}
body {{ background:#EDEDED; margin:0; }}
.sheet {{ padding:44px; }}
.sheet h1 {{ font-family:"Archivo",sans-serif; font-weight:900; font-size:40px;
             color:#2E2E2B; margin:0 0 6px; letter-spacing:-.02em; }}
.sheet .sub {{ font-family:"Public Sans",sans-serif; color:#87887E; font-size:15px;
               margin:0 0 34px; }}
.screens {{ display:grid; grid-template-columns:repeat(3,320px); gap:40px 34px;
            justify-content:start; }}
.snote {{ max-width:300px; }}
</style></head><body>
<div class="sheet">
  <h1>EMBER &mdash; screens</h1>
  <p class="sub">Walk within 50&nbsp;m of a cold place and it ignites. Six screens is the whole app.</p>
  <div class="screens">{screens}</div>
</div>
<script>{script}</script>
</body></html>"""

open(sys.argv[2], "w").write(page)
print("wrote", sys.argv[2])
