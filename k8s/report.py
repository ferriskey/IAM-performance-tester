#!/usr/bin/env python3
"""Builds REPORT.md from the JSON results of one bench.sh run directory."""

import json
import sys
from pathlib import Path

SYSTEMS = ["ferriskey", "keycloak"]
SCENARIOS = ["client_credentials", "password", "refresh", "introspect", "userinfo", "jwks"]


def load(run_dir: Path) -> dict:
    results = {}
    for sys_name in SYSTEMS:
        for f in (run_dir / sys_name).glob("*.json") if (run_dir / sys_name).exists() else []:
            r = json.loads(f.read_text())
            results.setdefault(r["scenario"], {}).setdefault(sys_name, {})[r["target_rps"]] = r
    return results


LATENCY_SLO_MS = 250


def sustained(steps: dict) -> dict | None:
    """Highest step with < 1% errors, >= 95% of the target served and p95 within the SLO."""
    ok = [
        r for r in steps.values()
        if r["error_rate"] < 0.01
        and r["achieved_rps"] >= 0.95 * r["target_rps"]
        and (r["latency_ms"]["p95"] or 0) <= LATENCY_SLO_MS
    ]
    return max(ok, key=lambda r: r["target_rps"]) if ok else None


def peak(steps: dict) -> dict | None:
    """Step that served the most successful requests per second."""
    return max(steps.values(), key=lambda r: r["achieved_rps"]) if steps else None


def num(v, fmt="{:.1f}"):
    if v is None or v == "null":
        return "-"
    return fmt.format(float(v))


def main() -> None:
    run_dir = Path(sys.argv[1])
    meta = json.loads((run_dir / "meta.json").read_text())
    results = load(run_dir)
    out = []

    out.append("# FerrisKey vs Keycloak\n")
    out.append(f"- FerrisKey: `{meta['ferriskey_tag']}`")
    out.append(f"- Keycloak: `{meta['keycloak_image']}`")
    out.append(f"- System under test: {meta['sut_resources']}, alone on a {meta['node_type']}")
    out.append(f"- PostgreSQL 17 (CNPG), one per system, {meta.get('db_resources', '1 CPU / 768Mi')}, on a dedicated node")
    out.append(f"- {meta['user_count']} users, {meta['duration_s']} s measured per step after {meta['warmup_s']} s warmup")
    out.append("- Load: k6 open model (constant arrival rate), on a dedicated node")
    if meta.get("spread_ips"):
        out.append("- **Variant**: one X-Forwarded-For per k6 VU, FerrisKey `SERVER_TRUST_FORWARDED_FOR=true`, "
                   "to measure past the FerrisKey per-IP `/token` in-flight cap")
    for note in meta.get("notes", []):
        out.append(f"- {note}")
    out.append("")

    out.append("## Memory of the system under test\n")
    out.append("Working set over every measured step, lowest and highest.\n")
    out.append("| System | Min (MiB) | Max (MiB) |")
    out.append("|---|---|---|")
    for s in SYSTEMS:
        mems = [float(r["sut"]["memory_mib"]) for sc in results.values() for r in sc.get(s, {}).values()
                if r["sut"]["memory_mib"] not in (None, "null")]
        if mems:
            out.append(f"| {s} | {min(mems):.0f} | {max(mems):.0f} |")
    out.append("")

    out.append("## Throughput\n")
    out.append(f"- **Sustained**: highest tested rate with < 1% errors, >= 95% of the target served "
               f"and p95 <= {LATENCY_SLO_MS} ms.")
    out.append("- **Peak**: most successful requests per second served by any step, whatever the latency.\n")
    out.append("| Scenario | FK sustained (p95 ms) | KC sustained (p95 ms) | FK/KC | FK peak | KC peak | FK/KC |")
    out.append("|---|---|---|---|---|---|---|")
    for sc in SCENARIOS:
        if sc not in results:
            continue
        sus = {s: sustained(results[sc].get(s, {})) for s in SYSTEMS}
        pk = {s: peak(results[sc].get(s, {})) for s in SYSTEMS}
        def cell(r):
            return f"{r['achieved_rps']:.0f} ({num(r['latency_ms']['p95'], '{:.0f}')})" if r else "< lowest step"
        def ratio(a, b):
            return f"{a['achieved_rps'] / b['achieved_rps']:.2f}x" if a and b and b["achieved_rps"] else "-"
        fk_pk = f"{pk['ferriskey']['achieved_rps']:.0f}" if pk["ferriskey"] else "-"
        kc_pk = f"{pk['keycloak']['achieved_rps']:.0f}" if pk["keycloak"] else "-"
        out.append(f"| {sc} | {cell(sus['ferriskey'])} | {cell(sus['keycloak'])} | {ratio(sus['ferriskey'], sus['keycloak'])} "
                   f"| {fk_pk} | {kc_pk} | {ratio(pk['ferriskey'], pk['keycloak'])} |")
    out.append("")

    for sc in SCENARIOS:
        if sc not in results:
            continue
        out.append(f"## {sc}\n")
        out.append("| Target rps | System | Served/s | p50 | p95 | p99 | Errors | SUT CPU | SUT MiB | DB CPU |")
        out.append("|---|---|---|---|---|---|---|---|---|---|")
        rates = sorted({rate for s in results[sc].values() for rate in s})
        for rate in rates:
            for s in SYSTEMS:
                r = results[sc].get(s, {}).get(rate)
                if not r:
                    continue
                lat = r["latency_ms"]
                out.append(
                    f"| {rate} | {s} | {num(r['achieved_rps'], '{:.0f}')} | {num(lat['p50'])} | {num(lat['p95'])} "
                    f"| {num(lat['p99'])} | {r['error_rate'] * 100:.2f}% | {num(r['sut']['cpu_cores'], '{:.2f}')} "
                    f"| {num(r['sut']['memory_mib'], '{:.0f}')} | {num(r['db']['cpu_cores'], '{:.2f}')} |"
                )
        out.append("")

    (run_dir / "REPORT.md").write_text("\n".join(out))
    print(f"wrote {run_dir / 'REPORT.md'}")


if __name__ == "__main__":
    main()
