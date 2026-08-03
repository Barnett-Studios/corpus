#!/usr/bin/env python3
"""Power for the paired sign test, re-derived on the census numbers (corpus#17).

Model, matching dotclaude#34's published analysis:
  - N nodes; each is discordant with probability d (node-aggregated deltas, Pratt drops
    exact zeros, so a concordant node contributes nothing)
  - among n discordant nodes, informed-retry wins each with probability pi
  - two-sided exact sign test at alpha = 0.05

Validated against #34's published figure before being used for anything: N=25, d=0.375,
pi=0.70 must reproduce power 0.138.
"""

from math import comb

ALPHA = 0.05


def binom_pmf(k, n, p):
    return comb(n, k) * p ** k * (1 - p) ** (n - k)


def sign_test_rejects(n):
    """Critical region of the two-sided exact sign test: number of wins w that reject."""
    rej = set()
    for w in range(n + 1):
        # two-sided p-value under H0: pi = 0.5
        tail = sum(binom_pmf(k, n, 0.5) for k in range(n + 1)
                   if abs(k - n / 2) >= abs(w - n / 2))
        if tail <= ALPHA:
            rej.add(w)
    return rej


_REJ = {}


def power(N, d, pi):
    total = 0.0
    for n in range(N + 1):
        p_n = binom_pmf(n, N, d)
        if p_n < 1e-12:
            continue
        if n not in _REJ:
            _REJ[n] = sign_test_rejects(n)
        rej = _REJ[n]
        if not rej:
            continue
        p_rej = sum(binom_pmf(w, n, pi) for w in rej)
        total += p_n * p_rej
    return total


def n_for_power(d, pi, target=0.80, lo=10, hi=2000):
    while lo < hi:
        mid = (lo + hi) // 2
        if power(mid, d, pi) >= target:
            hi = mid
        else:
            lo = mid + 1
    return lo


D = 0.375

print("=== validation against dotclaude#34's published figures (d=0.375) ===")
print("  N=25  pi=0.70 (large):    power %.3f   [#34 published 0.138]" % power(25, D, 0.70))
print("  N=250 pi=0.60:            power %.3f   [#34 published 0.45]" % power(250, D, 0.60))
print("  N=250 pi=0.65:            power %.3f   [#34 published 0.81]" % power(250, D, 0.65))
print("  N=250 pi=0.70:            power %.3f   [#34 published 0.97]" % power(250, D, 0.70))
print("  N for 80%% at pi=0.70:     %s          [#34 published 138]" % n_for_power(D, 0.70))
print("  N for 80%% at pi=0.65:     %s          [#34 published 245]" % n_for_power(D, 0.65))

print("\n=== power at the census numbers (d = 0.375) ===")
BARS = [
    ("N_instrument, all", 232),
    ("full-suite instruments only", 96),
    ("clean + full-suite (held-out)", 25),
]
print("  %-32s %8s %8s %8s" % ("stratum", "pi=0.60", "pi=0.65", "pi=0.70"))
for label, N in BARS:
    print("  %-32s %8.3f %8.3f %8.3f"
          % (label + " (N=%d)" % N, power(N, D, 0.60), power(N, D, 0.65), power(N, D, 0.70)))

print("\n=== sensitivity: what if the partial-suite nodes depress d? ===")
print("  (corpus#21: 136 of the 232 instruments grade on one test, so they land first try")
print("   in both arms and are concordant by construction)")
print("  %-10s %10s %10s %10s" % ("d", "N=232", "N=96", "N req @pi=0.70"))
for d in (0.375, 0.30, 0.25, 0.20, 0.15):
    print("  %-10.3f %10.3f %10.3f %10s"
          % (d, power(232, d, 0.70), power(96, d, 0.70), n_for_power(d, 0.70)))

print("\n=== d's own 95%% CI from #34 (9/24) is [0.212, 0.573] ===")
for d in (0.212, 0.375, 0.573):
    print("  d=%.3f -> N for 80%% at pi=0.70: %-5s   power at N=232: %.3f"
          % (d, n_for_power(d, 0.70), power(232, d, 0.70)))
