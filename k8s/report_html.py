#!/usr/bin/env python3
"""Builds the HTML report of one bench run: gen.py <run-dir> [extra-run-dir...] > report.html"""
import json
import math
import sys
from pathlib import Path

SYSTEMS = ["ferriskey", "keycloak"]
LABEL = {"ferriskey": "FerrisKey", "keycloak": "Keycloak"}
COLOR = {"ferriskey": "var(--chart-1)", "keycloak": "var(--chart-2)"}
SCEN = ["client_credentials", "password", "refresh", "introspect", "userinfo", "jwks"]
DESC = {
    "client_credentials": "POST /token, grant client_credentials",
    "password": "POST /token, grant password (Argon2id)",
    "refresh": "POST /token, grant refresh_token avec rotation",
    "introspect": "POST /token/introspect",
    "userinfo": "GET /userinfo",
    "jwks": "GET /certs",
}

data = {}
for d in sys.argv[1:]:
    for s in SYSTEMS:
        for f in sorted((Path(d) / s).glob("*.json")):
            r = json.loads(f.read_text())
            data.setdefault(r["scenario"], {}).setdefault(s, {})[r["target_rps"]] = r


def ok(r):
    return r["error_rate"] < 0.01 and r["achieved_rps"] >= 0.95 * r["target_rps"] and (r["latency_ms"]["p95"] or 0) <= 250


def sustained(steps):
    good = [r for r in steps.values() if ok(r)]
    return max(good, key=lambda r: r["target_rps"]) if good else None


def peak(steps):
    return max(steps.values(), key=lambda r: r["achieved_rps"])


def fr(v, n):
    return f"{v:.{n}f}".replace(".", ",")


def f0(v):
    return f"{v:,.0f}".replace(",", " ")


def chart(sc):
    W, H, L, R, T, B = 340, 200, 44, 12, 12, 30
    rates = sorted({k for s in data[sc].values() for k in s})
    lo, hi = math.log2(rates[0]), math.log2(rates[-1])
    p95s = [r["latency_ms"]["p95"] for s in data[sc].values() for r in s.values()]
    ymax = max(p95s)
    ylo, yhi = math.log10(0.5), math.log10(max(ymax * 1.3, 10))
    x = lambda v: L + (math.log2(v) - lo) / (hi - lo or 1) * (W - L - R)
    y = lambda v: T + (1 - (math.log10(max(v, 0.5)) - ylo) / (yhi - ylo)) * (H - T - B)
    g = []
    for t in [1, 10, 100, 1000, 10000]:
        if ylo <= math.log10(t) <= yhi:
            g.append(f'<line x1="{L}" x2="{W-R}" y1="{y(t):.1f}" y2="{y(t):.1f}" class="grid"/>'
                     f'<text x="{L-6}" y="{y(t)+3:.1f}" class="ax" text-anchor="end">{t:g} ms</text>')
    if ylo <= math.log10(250) <= yhi:
        g.append(f'<line x1="{L}" x2="{W-R}" y1="{y(250):.1f}" y2="{y(250):.1f}" class="slo"/>'
                 f'<text x="{W-R}" y="{y(250)-4:.1f}" class="ax" text-anchor="end">SLO 250 ms</text>')
    for v in rates:
        g.append(f'<text x="{x(v):.1f}" y="{H-B+16}" class="ax" text-anchor="middle">{v if v < 1000 else f"{v/1000:g}k"}</text>')
    for s in SYSTEMS:
        steps = data[sc].get(s, {})
        pts = [(x(k), y(steps[k]["latency_ms"]["p95"])) for k in sorted(steps)]
        g.append(f'<polyline points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in pts)}" fill="none" stroke="{COLOR[s]}" stroke-width="2"/>')
        for k in sorted(steps):
            r = steps[k]
            sat = r["achieved_rps"] < 0.95 * k or r["error_rate"] >= 0.01
            tip = (f'{LABEL[s]} · cible {f0(k)} req/s|servi {f0(r["achieved_rps"])} req/s|'
                   f'p50 {fr(r["latency_ms"]["p50"],1)} · p95 {fr(r["latency_ms"]["p95"],1)} · p99 {fr(r["latency_ms"]["p99"],1)} ms|'
                   f'erreurs {fr(r["error_rate"]*100,2)} %|CPU {fr(float(r["sut"]["cpu_cores"]),2)} cœur · base {fr(float(r["db"]["cpu_cores"]),2)}')
            fill = "var(--background)" if sat else COLOR[s]
            g.append(f'<circle cx="{x(k):.1f}" cy="{y(r["latency_ms"]["p95"]):.1f}" r="4.5" fill="{fill}" stroke="{COLOR[s]}" '
                     f'stroke-width="2" class="pt"/><circle cx="{x(k):.1f}" cy="{y(r["latency_ms"]["p95"]):.1f}" r="11" '
                     f'fill="transparent" class="hit" data-tip="{tip}"/>')
    return f'<svg viewBox="0 0 {W} {H}" width="100%" height="{H}" preserveAspectRatio="xMidYMid meet">{"".join(g)}</svg>'


def cpu_per_k(sc, s):
    """CPU cores of the SUT per 1000 req/s, at the highest step both systems sustained."""
    common = [k for k in data[sc]["ferriskey"] if k in data[sc]["keycloak"]
              and ok(data[sc]["ferriskey"][k]) and ok(data[sc]["keycloak"][k])]
    if not common:
        return None, None
    k = max(common)
    r = data[sc][s][k]
    return k, float(r["sut"]["cpu_cores"]) / r["achieved_rps"] * 1000, float(r["db"]["cpu_cores"]) / r["achieved_rps"] * 1000


rows = []
for sc in SCEN:
    sus = {s: sustained(data[sc][s]) for s in SYSTEMS}
    pk = {s: peak(data[sc][s]) for s in SYSTEMS}
    top = max(data[sc]["ferriskey"])

    def cell(s):
        r = sus[s]
        if not r:
            return "—"
        cap = " <span class='cap'>plafond du test</span>" if r["target_rps"] == top else ""
        return f'{f0(r["achieved_rps"])} <span class="mut">p95 {r["latency_ms"]["p95"]:.0f} ms</span>{cap}'

    ratio = sus["ferriskey"]["achieved_rps"] / sus["keycloak"]["achieved_rps"]
    cls = "good" if ratio > 1.05 else "bad" if ratio < 0.95 else ""
    rows.append(f'<tr><td><code>{sc}</code></td><td>{cell("ferriskey")}</td><td>{cell("keycloak")}</td>'
                f'<td class="{cls}">{fr(ratio,2)}×</td><td>{f0(pk["ferriskey"]["achieved_rps"])} / {f0(pk["keycloak"]["achieved_rps"])}</td></tr>')

cpu_rows = []
for sc in SCEN:
    res = {s: cpu_per_k(sc, s) for s in SYSTEMS}
    k = res["ferriskey"][0]
    fk, kc = res["ferriskey"], res["keycloak"]
    cpu_rows.append(f'<tr><td><code>{sc}</code></td><td>{f0(k)}</td><td>{fr(fk[1],2)}</td><td>{fr(kc[1],2)}</td>'
                    f'<td>{fr(fk[2],2)}</td><td>{fr(kc[2],2)}</td></tr>')

mem = {s: [float(r["sut"]["memory_mib"]) for sc in data.values() for r in sc[s].values()] for s in SYSTEMS}
cards = "".join(f'<div class="card"><h3><code>{sc}</code></h3><p class="mut">{DESC[sc]}</p>{chart(sc)}</div>' for sc in SCEN)
meta = json.loads((Path(sys.argv[1]) / "meta.json").read_text())

print(f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
body{{font-family:var(--font-sans);color:var(--foreground);line-height:1.5;font-size:14px}}
h2{{font-size:17px;margin:28px 0 8px}} h3{{font-size:14px;margin:0}} p{{margin:4px 0 10px}}
.mut{{color:var(--muted-foreground)}} code{{font-family:var(--font-mono);font-size:12.5px}}
table{{border-collapse:collapse;width:100%;font-size:13px;margin:6px 0 4px}}
th,td{{text-align:left;padding:6px 8px;border-bottom:1px solid var(--border);vertical-align:top}}
th{{font-weight:600;color:var(--muted-foreground);font-size:12px}}
td.good{{color:var(--success);font-weight:600}} td.bad{{color:var(--destructive);font-weight:600}}
.cap{{font-size:11px;color:var(--muted-foreground);border:1px solid var(--border);border-radius:4px;padding:0 4px;white-space:nowrap}}
.grid2{{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}}
.card{{background:var(--card);border-radius:var(--radius);padding:16px}}
.grid{{stroke:var(--border);stroke-width:1}} .slo{{stroke:var(--warning);stroke-width:1;stroke-dasharray:4 3}}
.ax{{fill:var(--muted-foreground);font-size:10px;font-family:var(--font-sans)}}
.legend{{display:flex;gap:16px;font-size:13px;margin:4px 0 10px}} .sw{{display:inline-block;width:14px;height:3px;border-radius:2px;vertical-align:middle;margin-right:6px}}
.hollow{{display:inline-block;width:8px;height:8px;border-radius:50%;border:2px solid var(--muted-foreground);vertical-align:middle;margin-right:6px}}
#tip{{position:fixed;pointer-events:none;background:var(--popover);color:var(--popover-foreground);border:1px solid var(--border);border-radius:6px;padding:6px 9px;font-size:12px;display:none;z-index:9;box-shadow:0 4px 14px rgba(0,0,0,.25)}}
ul{{margin:4px 0 10px;padding-left:20px}} li{{margin:3px 0}}
</style></head><body>
<p class="mut">FerrisKey <code>{meta['ferriskey_tag']}</code> (main, contient 6ea8fa6) contre Keycloak <code>26.8.1</code> · k3d local · 27/10/2026</p>

<h2>Résultat</h2>
<p><b>Tenu</b> : plus haut palier avec moins de 1 % d'erreurs, au moins 95 % du débit cible servi et un p95 ≤ 250 ms. <b>Pic</b> : meilleur débit servi, quelle que soit la latence.</p>
<table><tr><th>Scénario</th><th>FerrisKey tenu (req/s)</th><th>Keycloak tenu (req/s)</th><th>FK / KC</th><th>Pic FK / KC</th></tr>{''.join(rows)}</table>
<p class="mut">« plafond du test » : le palier le plus haut de l'échelle passe encore, le vrai plafond est au-dessus.</p>

<h2>Ce qu'il faut retenir</h2>
<ul>
<li><b>Égalité au débit tenu sur 4 scénarios sur 6</b> : <code>client_credentials</code>, <code>introspect</code> et <code>jwks</code> tiennent le plus haut palier testé (3 200 ou 6 400 req/s) des deux côtés, <code>password</code> tient 160 des deux côtés. Sur <code>introspect</code> et <code>jwks</code>, FerrisKey utilise 35 à 45 % de CPU en moins.</li>
<li><b><code>password</code> (Argon2)</b> : au pic, FerrisKey sert 277 req/s, Keycloak plafonne à 160 (1,73×). Mais FerrisKey prend alors 6,4 cœurs, Keycloak 3,5, bridé par <code>ActiveProcessorCount=3</code>. Par cœur, c'est pareil : 43 à 46 req/s par cœur des deux côtés.</li>
<li><b><code>client_credentials</code> rattrape Keycloak</b> : 3 200 req/s, p95 11 ms, base à 0,33 cœur. Sur l'ancien run (<code>sha-4a964dd</code>, autre cluster), FerrisKey était à 0,5× Keycloak.</li>
<li><b><code>refresh</code> reste le point faible</b> : FerrisKey sature vers 1 050 req/s, Keycloak tient 1 600 à p95 10 ms. À 800 req/s, FerrisKey consomme 2× plus de CPU et sa base 15× plus (1,37 contre 0,09 cœur).</li>
<li><b><code>userinfo</code></b> : FerrisKey tient 3 200 puis sert 4 979 sur 6 400. Sa base monte à 3,2 cœurs, celle de Keycloak reste à 0,01. Chaque appel interroge encore la base.</li>
<li><b>Mémoire</b> : FerrisKey reste à 200–250 Mi sur les scénarios rapides, mais les 3 pods montent à 1,3 Gi pendant <code>refresh</code> (1,4 Gi au pic <code>password</code>) et ne redescendent pas ensuite. Keycloak reste entre {min(mem['keycloak']):.0f} et {max(mem['keycloak']):.0f} Mi.</li>
</ul>

<h2>Latence p95 par palier</h2>
<div class="legend"><span><span class="sw" style="background:var(--chart-1)"></span>FerrisKey</span><span><span class="sw" style="background:var(--chart-2)"></span>Keycloak</span><span class="mut"><span class="hollow"></span>point creux : palier saturé</span></div>
<p class="mut">Axes logarithmiques. Survole un point pour le détail.</p>
<div class="grid2">{cards}</div>

<h2>CPU pour 1 000 req/s</h2>
<p>Au plus haut palier tenu par les deux systèmes. Plus bas, c'est mieux.</p>
<table><tr><th>Scénario</th><th>Palier (req/s)</th><th>FerrisKey (cœurs)</th><th>Keycloak (cœurs)</th><th>Base FK</th><th>Base KC</th></tr>{''.join(cpu_rows)}</table>

<h2>Conditions</h2>
<ul>
<li>FerrisKey : 3 réplicas, request 1 CPU chacun, <b>sans limite CPU</b>, 1 Gi par pod. Keycloak : 1 réplica, request 3 CPU, <b>sans limite CPU</b>, 1536 Mi, <code>-XX:ActiveProcessorCount=3</code>, cache local.</li>
<li>PostgreSQL 17 (CNPG), une base par système : 1 CPU request, 3 Gi, <code>max_connections</code> 400. 1 000 utilisateurs seedés, base FerrisKey recréée juste avant le run.</li>
<li>k6 en modèle ouvert (débit constant), 15 s de chauffe puis 60 s mesurées par palier. Tous les paliers sont mesurés, même après saturation.</li>
</ul>

<h2>Limites</h2>
<ul>
<li><b>k3d local</b> : k6, le système testé et Postgres se partagent les 8 vCPU d'OrbStack. Sans limite CPU, chaque système peut prendre plus que sa request. Les ratios sont plus fiables que les valeurs absolues.</li>
<li><b>Image</b> : <code>sha-6ea8fa6</code> n'existe pas (build CI annulé). <code>sha-d73af3e</code> contient ce commit plus 10 mises à jour de dépendances, sans changement de code.</li>
<li><b>Plafond de l'échelle</b> : <code>client_credentials</code>, <code>introspect</code> et <code>jwks</code> ne saturent d'aucun côté. Keycloak ne sature pas non plus sur <code>refresh</code> et <code>userinfo</code>. Au-delà de 6 400 req/s, k6 prendrait trop de CPU partagé pour mesurer proprement.</li>
<li><b>Un premier run a été arrêté</b> : la base FerrisKey a été tuée par manque de mémoire. 3 réplicas × 100 connexions dépassaient les 200 autorisées. Corrigé à 400, puis tout a été relancé. Aucun redémarrage pendant le run retenu.</li>
<li><code>password</code> : les paliers 320 et 640 viennent d'un second passage, juste après le run principal.</li>
</ul>
<div id="tip"></div>
<script>
const tip=document.getElementById('tip');
document.querySelectorAll('.hit').forEach(c=>{{
 c.addEventListener('mouseenter',()=>{{tip.innerHTML=c.dataset.tip.split('|').join('<br>');tip.style.display='block'}});
 c.addEventListener('mousemove',e=>{{tip.style.left=Math.min(e.clientX+12,innerWidth-230)+'px';tip.style.top=(e.clientY+12)+'px'}});
 c.addEventListener('mouseleave',()=>tip.style.display='none');
}});
</script></body></html>""")
