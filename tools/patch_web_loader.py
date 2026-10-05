#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web/index.html")
html = path.read_text(encoding="utf-8")

style = r"""
<style id="prism-loader-style">
html, body { margin:0!important; width:100%; height:100%; overflow:hidden; background:#06162d!important; }
body { overscroll-behavior:none; }
#canvas { opacity:0; background:transparent!important; transition:opacity .38s ease; }
#prism-preloader { position:fixed; inset:0; z-index:99990; overflow:hidden; background:#06162d; opacity:1; transition:opacity .42s ease,visibility .42s ease; }
#prism-preloader.prism-done { opacity:0; visibility:hidden; pointer-events:none; }
#prism-preloader picture,#prism-preloader img { position:absolute; inset:0; width:100%; height:100%; }
#prism-preloader img { object-fit:cover; object-position:center; user-select:none; -webkit-user-drag:none; }
#prism-loader-shade { position:absolute; inset:0; background:linear-gradient(180deg,rgba(3,10,24,.05) 35%,rgba(2,10,23,.42) 100%); }
#prism-loader-card { position:absolute; left:50%; bottom:max(24px,env(safe-area-inset-bottom)); transform:translateX(-50%); min-width:min(360px,76vw); padding:11px 18px 12px; border:1px solid rgba(122,224,255,.66); border-radius:14px; color:#effcff; background:rgba(4,18,38,.52); box-shadow:0 8px 32px rgba(0,0,0,.32),inset 0 0 24px rgba(85,205,255,.08); backdrop-filter:blur(8px); -webkit-backdrop-filter:blur(8px); text-align:center; font-family:system-ui,-apple-system,"Segoe UI",sans-serif; }
#prism-loader-title { font-weight:750; letter-spacing:.13em; font-size:14px; }
#prism-loader-text { margin-top:5px; font-size:12px; color:#aeeeff; letter-spacing:.04em; }
#prism-loader-bar { height:3px; margin-top:9px; border-radius:99px; background:rgba(195,245,255,.17); overflow:hidden; }
#prism-loader-fill { height:100%; width:8%; border-radius:inherit; background:linear-gradient(90deg,#59dfff,#c38cff,#69ecff); transition:width .18s ease; box-shadow:0 0 12px rgba(92,228,255,.7); }
#status { z-index:99995!important; }
@media (orientation:portrait) { #prism-loader-card { bottom:max(18px,env(safe-area-inset-bottom)); } }
</style>
"""

loader = r"""
<div id="prism-preloader" aria-label="Loading Prism Tamer Frontier">
  <picture>
    <source media="(orientation: portrait)" srcset="prism_tamer_portrait.jpg">
    <img src="prism_tamer_wide.jpg" alt="">
  </picture>
  <div id="prism-loader-shade"></div>
  <div id="prism-loader-card">
    <div id="prism-loader-title">PRISM TAMER: FRONTIER</div>
    <div id="prism-loader-text">Preparing the Digital Frontier...</div>
    <div id="prism-loader-bar"><div id="prism-loader-fill"></div></div>
  </div>
</div>
"""

script = r"""
<script id="prism-loader-script">
(() => {
  const loader = document.getElementById('prism-preloader');
  const canvas = document.getElementById('canvas') || document.querySelector('canvas');
  const fill = document.getElementById('prism-loader-fill');
  const text = document.getElementById('prism-loader-text');
  const started = performance.now();
  let sawGodotStatus = false;
  let revealed = false;

  function revealGame() {
    if (revealed) return;
    revealed = true;
    if (fill) fill.style.width = '100%';
    if (text) text.textContent = 'Entering the Digital Frontier...';
    setTimeout(() => {
      if (canvas) canvas.style.opacity = '1';
      if (loader) loader.classList.add('prism-done');
    }, 180);
    setTimeout(() => loader?.remove(), 750);
  }

  function update() {
    const status = document.getElementById('status');
    const progress = document.getElementById('status-progress');

    if (status) {
      const style = getComputedStyle(status);
      const visible = style.display !== 'none' && style.visibility !== 'hidden';
      if (visible) sawGodotStatus = true;

      if (progress && fill) {
        const max = Number(progress.max || 1);
        const value = Number(progress.value || 0);
        if (max > 0 && value >= 0) {
          const pct = Math.max(8, Math.min(96, (value / max) * 100));
          fill.style.width = pct.toFixed(1) + '%';
          if (text && pct > 12) text.textContent = 'Loading game data... ' + Math.round(pct) + '%';
        }
      }

      if (!visible && sawGodotStatus && performance.now() - started > 700) {
        revealGame();
        return;
      }
    }

    requestAnimationFrame(update);
  }

  requestAnimationFrame(update);
  setTimeout(revealGame, 20000);
})();
</script>
"""

if 'id="prism-loader-style"' not in html:
    html = html.replace("</head>", style + "\n</head>")
if 'id="prism-preloader"' not in html:
    body_pos = html.find("<body")
    body_end = html.find(">", body_pos)
    if body_pos != -1 and body_end != -1:
        html = html[:body_end + 1] + "\n" + loader + html[body_end + 1:]
if 'id="prism-loader-script"' not in html:
    html = html.replace("</body>", script + "\n</body>")

path.write_text(html, encoding="utf-8")
print(f"Patched Prism loader into {path}")
