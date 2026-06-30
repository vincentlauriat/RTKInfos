# TODOS

## ✅ Release v1.1.0 — PUBLIÉE (2026-06-30)

Version `1.1.0` / build `2` livrée. DMG signé/notarisé/staplé, release GitHub
publiée, appcast servi depuis `main` → l'auto-update Sparkle est actif.

- [x] Bump version (project.yml 1.1.0 / 2), build vérifié
- [x] Clé Sparkle → réutilise celle de MarkdownViewer (`9PD2SB…`, compte Keychain `MarkdownViewer`)
- [x] Profil notarization → `AppliMacVincentGithub` (apple-id `vincent@lauriat.fr`)
- [x] Script `build-release.sh` fiabilisé (clean `build/`, bon profil par défaut)
- [x] Tag `v1.1.0` + docs (CHANGES, README, ARCHITECTURE, RELEASE, index.html)
- [x] **Fix régression** : retrait de la section `info:` de `project.yml` qui faisait
      régénérer `Info.plist` par xcodegen (versions 1.0/1, clés Sparkle perdues). PR #9.
- [x] Build signé/notarisé → `RTKInfos-1.1.0.dmg` (v1.1.0/2, Sparkle OK, Gatekeeper accepted)
- [x] Release GitHub : https://github.com/vincentlauriat/RTKInfos/releases/tag/v1.1.0
- [x] `appcast.xml` mergé sur `main` (PR #9) → feed v1.1.0 servi via raw GitHub

> ⚠️ Les clients v1.0.0 devront télécharger v1.1.0 manuellement une fois (changement de clé Sparkle).
>
> 📌 Note machine : `/Applications/RTKInfos.app` est encore en v1.0 — installer le DMG
> ou attendre que Sparkle propose la mise à jour (téléchargement manuel requis cette fois).

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
