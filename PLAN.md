# PLAN — Refonte UX « Compression Gauge »

> **Statut : LIVRÉ** (mergé dans `main`, inclus dans la release v1.1.0). Phases 0,
> 1, 3 terminées ; 2 et 4 quasi complètes. Restant optionnel (suivi dans
> `TODOS.md`) : audit accessibilité et sparkline.

Direction validée : **Compression Gauge**. L'app cesse d'être un dashboard SwiftUI
générique pour devenir un *instrument de mesure* : calme, dense, précis, avec un
seul élément spectaculaire — la jauge de compression `input → output`.

Principe directeur du skill design : **dépenser son audace à un seul endroit**.
Ici, l'audace = la jauge de compression. Tout le reste reste discipliné et silencieux.

---

## 1. Design tokens

### Couleur — un seul accent, zéro feu tricolore

| Token            | Hex (light)   | Hex (dark)    | Usage                                  |
|------------------|---------------|---------------|----------------------------------------|
| `rtk.ink`        | `#16191D`     | `#ECEFF2`     | Texte principal, grands nombres        |
| `rtk.slate`      | `#5B6470`     | `#9AA3AE`     | Texte secondaire, labels               |
| `rtk.mist`       | `#9AA3AE`     | `#5B6470`     | Texte tertiaire, état neutre/faible    |
| `rtk.emerald`    | `#12B886`     | `#1FD79B`     | **Accent unique** — la part « tuée »   |
| `rtk.emeraldDim` | `#12B88622`   | `#1FD79B22`   | Remplissage doux, fonds de jauge       |
| `rtk.surface`    | matériau natif `.windowBackground` + hairline `rtk.ink @ 8%` |

**Règle dure : plus jamais de rouge ni d'orange pour encoder la donnée.**
Le produit ne fait que du positif → l'échelle va de `mist` (neutre, faible gain)
à `emerald` (fort gain) **par intensité**, pas par teinte. Le rouge/orange est
réservé EXCLUSIVEMENT aux vraies erreurs système (DB introuvable), visuellement
séparé de la donnée.

> Anti-générique : l'accent est un émeraude **désaturé** (`#12B886`), pas un vert
> acide hacker (`#00FF87`). En light mode c'est de l'encre sur blanc cassé — on
> évite délibérément le cliché « terminal vert-sur-noir » (défaut AI #2).

### Typographie — sortir du tout-SF

Embarquer **Geist** + **Geist Mono** (licence OFL, gratuite, esthétique technique
moderne alignée avec l'univers Rust/dev). Trois rôles :

| Rôle      | Police            | Réglage                                            |
|-----------|-------------------|----------------------------------------------------|
| Display   | Geist SemiBold    | Grands nombres. `monospacedDigit`, tracking serré  |
| Label     | Geist Medium      | UPPERCASE, tracking +8 % : `INPUT` `OUTPUT` `TODAY` |
| Data      | Geist Mono        | Valeurs, tableau By Command, Live Trace            |

Repli gracieux sur SF Pro / SF Mono si la police n'est pas chargée.

### Espacement & forme

- Grille de base **4 pt**. Sections espacées de 24 pt, padding fenêtre 24 pt.
- Rayons : 10 pt (cartes), 4 pt (barres). Hairlines à 8 % d'opacité d'encre.
- Chiffres **toujours** tabulaires (`monospacedDigit`) pour un alignement d'instrument.

---

## 2. Layout & signature

Wireframe (panneau gauche de la fenêtre) :

```
┌───────────────────────────────────────────┐
│ ◆ RTK                          EFFICIENCY  │  header sobre, glyphe ◆ custom
│                                     66.2%  │  (remplace bolt.fill jaune)
├───────────────────────────────────────────┤
│  COMPRESSION                               │  ★ SIGNATURE
│  26.9M ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░ 9.1M              │  une barre : input→output,
│  input                        output       │  la part « tuée » en émeraude
│                                            │
│            17·8M                            │  héros : total saved (Display XL)
│            TOKENS SAVED · ALL TIME         │
│                                            │
│  ▁▂▃▅▇▆▇   LAST 7 DAYS          avg 61%    │  sparkline discrète (pas bar chart)
├───────────────────────────────────────────┤
│  TODAY     40.9k saved · 129 cmds · 82%    │  bandeau compact une ligne
├───────────────────────────────────────────┤
│  BY COMMAND                                │  re-stylé, barres natives (pas █░)
│  rtk git status    8.4M  ▓▓▓▓▓▓▓▓▓▓        │
│  rtk cargo build   3.1M  ▓▓▓▓              │
└───────────────────────────────────────────┘
```

**Élément signature : la jauge de compression.** Une barre horizontale unique où
la largeur d'`input` est écrasée vers `output`, l'espace libéré au milieu peint en
émeraude = les tokens tués. C'est la seule chose visuellement forte ; elle EST le
produit. Animée à l'ouverture (l'output « se comprime » de toute la largeur vers sa
taille réelle, ~600 ms, `reduceMotion` respecté).

Panneau droit **Live Trace** conservé mais re-stylé : point émeraude qui pulse à
chaque nouvelle commande, mono cohérent, % en intensité d'émeraude (jamais rouge).

---

## 3. Revue anti-générique (exigée par le skill)

- **Gros chiffre héros (17.8M)** : normalement un défaut « template ». Justifié ici
  car le cumul économisé est la récompense émotionnelle du produit — MAIS il est
  couplé à la jauge de compression (non générique) pour ne pas être le seul moment,
  et **sans gradient**.
- **Sparkline au lieu du bar chart actuel** : choix délibéré pour libérer l'espace
  du héros, pas une simplification paresseuse.
- **Émeraude sur fond sombre** : proche du défaut AI #2 → neutralisé par la
  désaturation de l'accent + le support natif du light mode.

---

## 4. Plan d'implémentation (par phases)

### Phase 0 — Fondations design
- [ ] `Sources/.../DesignSystem/RTKColor.swift` — tokens couleur adaptatifs (Asset Catalog + extension `Color`).
- [ ] `RTKInfos/Resources/Fonts/` — embarquer Geist + Geist Mono, déclarer dans `Info.plist` (`ATSApplicationFontsPath`).
- [ ] `RTKFont.swift` — helpers `.rtkDisplay(_:)`, `.rtkLabel(_:)`, `.rtkData(_:)` avec repli SF.
- [ ] Retirer `colorForPct` (feu tricolore) → `intensityForPct` (opacité d'émeraude).

### Phase 1 — Signature
- [ ] `CompressionGauge.swift` — la barre input→output animée. Composant isolé, testable en `#Preview`.
- [ ] Intégrer en tête de `DashboardView`, remplacer la section KPIs actuelle.

### Phase 2 — Héros + sparkline
- [ ] Bloc « tokens saved » en Display XL.
- [ ] `Sparkline.swift` — remplace le `Chart` 7 jours pleine hauteur.

### Phase 3 — Sections secondaires
- [ ] Bandeau `TODAY` compact (une ligne).
- [ ] `By Command` re-stylé : barres d'impact natives (`Capsule`/`RoundedRectangle`), suppression des `█░`.
- [ ] `Live Trace` : point pulsant, cohérence mono + émeraude.

### Phase 4 — Cohérence & finitions
- [ ] Unifier la langue (décider FR **ou** EN — recommandation : EN pour les libellés data, cf. § ci-dessous).
- [ ] Header : glyphe ◆ custom à la place de `bolt.fill`.
- [ ] Audit accessibilité : focus clavier visible, `reduceMotion`, contraste AA.
- [ ] Build + capture avant/après pour validation visuelle.

### Décision de langue — TRANCHÉE : **anglais partout**
Toute l'interface passe en anglais, y compris les messages d'état, les bannières
d'erreur et les états vides. Cohérent avec le CLI et le vernaculaire dev.
À traduire : `Aujourd'hui`→`Today`, `Actualiser`→`Refresh`, `Préférences`→
`Settings`, `rtk non détecté`→`rtk not detected`, `rtk introuvable…`→`rtk not
found — install rtk and run commands to get started`, `Aucune activité depuis N
jours`→`No activity for N days`, `Pas de données`→`No data`, dates en `en_US`.

---

## 5. Risques

- **Embarquer Geist** ajoute ~400 Ko et une étape `Info.plist`. Repli SF obligatoire si chargement échoue.
- L'animation de la jauge ne doit pas rejouer à chaque refresh (1 s de polling) — l'animer **une fois** à l'apparition, puis transitions douces sur changement de valeur uniquement.
- `HSplitView` + largeurs mini : vérifier que le héros reste lisible sous 400 pt.
