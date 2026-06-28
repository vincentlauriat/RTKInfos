# TODOS — Refonte UX « Compression Gauge »

Voir `PLAN.md` pour le design system complet et la justification.

## À décider (bloquant Phase 0)
- [x] Langue d'interface : **anglais partout** (data + messages d'état + dates en_US)
- [x] Police : **embarquer Geist + Geist Mono** (variable TTF, OFL, repli SF)

## Phase 0 — Fondations ✅
- [x] Tokens couleur adaptatifs (`RTKTheme` : ink/slate/mist/emerald, light+dark)
- [x] Helpers typo (`rtkDisplay`/`rtkLabel`/`rtkData`) + repli SF
- [x] Polices Geist + Geist Mono embarquées (registration runtime CoreText)
- [x] `colorForPct` (feu tricolore) → `rtkIntensity` (émeraude, mist sous 35 %)

## Phase 1 — Signature ✅
- [x] Composant `CompressionGauge` (barre input→output animée + `#Preview`)
- [x] Intégration en tête de `DashboardView` (remplace les 4 KPI cards)
- [x] Bloc héros « tokens saved » en Display XL Geist

## Phase 2 — Affinage data viz
- [ ] Chart 7 j → sparkline plus discrète (optionnel — le bar chart émeraude marche déjà)
- [ ] `sectionTitle` en Geist label uppercase (cohérence avec COMPRESSION/TOKENS SAVED)

## Phase 3 — Sections secondaires
- [x] `Live Trace` : % en intensité émeraude (plus de rouge)
- [ ] `Live Trace` : point pulsant à chaque nouvelle commande
- [ ] `By Command` re-stylé (barres natives, suppression `█░`)
- [ ] Bandeau `TODAY` compact (today stats ne sont plus affichées)

## Phase 4 — Finitions
- [x] Unifier la langue → **anglais partout** (libellés, dates en_US, bannières)
- [ ] Glyphe ◆ custom (remplace `bolt.fill` jaune) — header + menu bar
- [ ] Audit accessibilité (focus clavier, reduceMotion ok, contraste AA)
- [ ] Capture finale avant/après
