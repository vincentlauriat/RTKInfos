# TODOS

## 🚀 Release v1.1.0 — REPRENDRE ICI

Tout est prêt côté code/git. Version `1.1.0` / build `2`, tag `v1.1.0` poussé,
clé Sparkle alignée sur MarkdownViewer, docs à jour. Procédure complète dans
`docs/RELEASE.md`.

**Fait :**
- [x] Bump version (project.yml 1.1.0 / 2), build vérifié
- [x] Clé Sparkle → réutilise celle de MarkdownViewer (`9PD2SB…`, compte Keychain `MarkdownViewer`)
- [x] Profil notarization → `AppliMacVincentGithub` (apple-id `vincent@lauriat.fr`)
- [x] Script `build-release.sh` fiabilisé (clean `build/`, bon profil par défaut)
- [x] Tag `v1.1.0` + docs (CHANGES, README, ARCHITECTURE, RELEASE, index.html)

**Reste à faire (3 commandes, voir docs/RELEASE.md) :**
- [ ] **1.** Lancer le build signé/notarisé :
  ```
  SIGNING_IDENTITY="Developer ID Application: Vincent LAURIAT (KFLACS69T9)" ./scripts/build-release.sh 1.1.0
  ```
- [ ] **2.** `gh release create v1.1.0 ./RTKInfos-1.1.0.dmg --title "v1.1.0 — Compression Gauge UX" --notes "…"`
- [ ] **3.** `git add appcast.xml && git commit -m "release: appcast for v1.1.0" && git push`

> ⚠️ Les clients v1.0.0 devront télécharger v1.1.0 manuellement une fois (changement de clé Sparkle).

---

# Refonte UX « Compression Gauge »

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
- [x] `sectionTitle` en Geist label uppercase (cohérence avec COMPRESSION/TOKENS SAVED)
- [ ] Chart 7 j → sparkline plus discrète (optionnel — le bar chart émeraude marche déjà)

## Phase 3 — Sections secondaires ✅
- [x] `Live Trace` : % en intensité émeraude (plus de rouge)
- [x] `Live Trace` : point pulsant à chaque nouvelle commande (reduceMotion respecté)
- [x] `Live Trace` + `By Command` : police Geist Mono
- [x] `By Command` re-stylé (barres natives `Capsule`, suppression `█░`)
- [x] Bandeau `TODAY` compact (saved · cmds · %)

## Phase 4 — Finitions
- [x] Unifier la langue → **anglais partout** (libellés, dates en_US, bannières)
- [x] Glyphe ◆ custom (remplace `bolt.fill` jaune) — header + menu bar
- [ ] Audit accessibilité (focus clavier, reduceMotion ok, contraste AA)
- [ ] Chart sparkline (optionnel)
