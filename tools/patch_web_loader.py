#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web/index.html")
html = path.read_text(encoding="utf-8")

style = r"""
<style id="prism-loader-style">
html,body{margin:0!important;width:100%;height:100%;overflow:hidden;background:#000!important;overscroll-behavior:none;}
body{user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;}
#canvas{display:block;width:100%;height:100%;background:#000!important;outline:none;opacity:1;}
#prism-preloader{position:fixed;inset:0;z-index:999999;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#000;opacity:1;transition:opacity .9s cubic-bezier(.22,1,.36,1);will-change:opacity;}
#prism-preloader.prism-done{opacity:0;pointer-events:none;}
#prism-loader-art{position:absolute;inset:0;opacity:0;transform:scale(.992);transition:opacity 1.1s cubic-bezier(.22,1,.36,1),transform 1.1s cubic-bezier(.22,1,.36,1);will-change:opacity,transform;}
#prism-preloader.prism-visible #prism-loader-art{opacity:1;transform:scale(1);}
#prism-loader-art picture,#prism-loader-art img{position:absolute;inset:0;width:100%;height:100%;}
#prism-loader-art img{object-fit:cover;object-position:center;-webkit-user-drag:none;}
#prism-loader-shade{position:absolute;inset:0;background:linear-gradient(180deg,rgba(0,0,0,.08) 35%,rgba(0,0,0,.54) 100%);}
#prism-loader-card{position:absolute;left:50%;bottom:max(28px,env(safe-area-inset-bottom));transform:translateX(-50%);width:min(360px,74vw);color:#fff;text-align:center;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;opacity:0;transition:opacity 1s ease .18s;}
#prism-preloader.prism-visible #prism-loader-card{opacity:1;}
#prism-loader-title{font-weight:650;letter-spacing:.16em;font-size:13px;text-shadow:0 2px 10px rgba(0,0,0,.7);}
#prism-loader-text{margin-top:8px;font-size:12px;color:rgba(255,255,255,.76);letter-spacing:.03em;text-shadow:0 2px 10px rgba(0,0,0,.7);}
#prism-loader-bar{height:2px;margin-top:14px;border-radius:99px;background:rgba(255,255,255,.15);overflow:hidden;}
#prism-loader-fill{height:100%;width:0%;border-radius:inherit;background:rgba(255,255,255,.9);transition:width .18s ease-out;}
#status{z-index:999995!important;}
@media(max-height:560px){#prism-loader-card{bottom:max(16px,env(safe-area-inset-bottom));width:min(320px,58vw);}}
@media(prefers-reduced-motion:reduce){#prism-preloader,#prism-loader-art,#prism-loader-card,#prism-loader-fill{transition-duration:1ms!important;transition-delay:0ms!important;}}
</style>
"""

loader = r"""
<div id="prism-preloader" aria-label="Loading Prism Tamer Frontier">
  <div id="prism-loader-art">
    <picture>
      <source media="(orientation: portrait)" srcset="prism_tamer_portrait.jpg">
      <img src="prism_tamer_wide.jpg" alt="">
    </picture>
    <div id="prism-loader-shade"></div>
  </div>
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
  const fill = document.getElementById('prism-loader-fill');
  const text = document.getElementById('prism-loader-text');
  const started = performance.now();
  let sawGodotStatus = false;
  let revealed = false;

  requestAnimationFrame(() => {
    requestAnimationFrame(() => loader?.classList.add('prism-visible'));
  });

  function revealGame() {
    if (revealed) return;
    revealed = true;
    if (fill) fill.style.width = '100%';
    if (text) text.textContent = 'Entering the Digital Frontier...';
    requestAnimationFrame(() => {
      requestAnimationFrame(() => loader?.classList.add('prism-done'));
    });
    setTimeout(() => loader?.remove(), 980);
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
          const pct = Math.max(0, Math.min(96, (value / max) * 100));
          fill.style.width = pct.toFixed(1) + '%';
          if (text && pct > 3) text.textContent = 'Loading game data... ' + Math.round(pct) + '%';
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
print(f"Patched premium black Prism loader into {path}")
