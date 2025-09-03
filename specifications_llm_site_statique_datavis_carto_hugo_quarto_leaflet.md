# Spécifications LLM — Site statique datavis + carto (Hugo + Quarto + Leaflet)

**But** : générer un site statique (Hugo) combinant narration (Hugo/Quarto) et exploration cartographique (Leaflet) pour des milliers de lieux en France, organisés par régions, à partir de CSV régionaux comportant des colonnes d’Ancien Régime / Révolution et des séries démographiques 1790–1982.

---

## 0) Résumé exécutif
- **Colonne gauche** : article Hugo *ou* page Quarto (HTML) avec graphiques.
- **Colonne droite** : carte Leaflet centrée sur la France, affichant les lieux de la région active.
- **Données** : un CSV par région → pipeline Quarto/Python → GeoJSON + JSON agrégés → chargés côté client par Leaflet.
- **Navigation** : par région ; timeline/slider année ; filtres (facultatifs) par catégorie/mesure.
- **Performances** : clustering + agrégations pré-calculées ; données servies depuis `/static/data/`.

---

## 1) Périmètre & objectifs
- **Objectif** : permettre l’exploration des hiérarchies administratives (Ancien Régime / XIXe–XXe) et des dynamiques démographiques.
- **Non-objectifs (v1)** :
  - Aucune écriture côté serveur ; pas d’édition en ligne.
  - Enrichissements externes (géocodage automatique) seulement si fichiers de coordonnées sont fournis.
  - Analyses statistiques avancées au-delà de l’exploration interactive.

**Personae** : historien·ne, datajournaliste, curieux·se.

---

## 2) Sources de données & conventions
- **Format source** : CSV (un par région). Exemple de colonnes observées (extrait *Eure-et-Loir*):
  - Identité : `n°ordre-alph18012`, `nom`, `insee`, `section`, `superficie`.
  - Hiérarchie Ancien Régime : `intendance`, `election`, `subdelegation`, `grenier`, `coutume`, `parlement`, `bailliage`, `gouvernement`, `diocese`, `archidiacone`, `doyenne`, `vocable`, `presentateur`.
  - Révolution & XIXe–XXe : `district_1790`, `canton_1790`, `canton_1801`, `arrondissement_1982`, `canton_1982`.
  - Démographie (séries) : préfixe `V_` puis période et suffixe indiquant la nature :
    - `..._f`, `..._f_tot`, `..._f_masc` (féminin/feux/total/masculin selon période),
    - `..._h` (habitants),
    - `..._g` (type inconnu **à conserver tel quel**),
    - formes républicaines : `V_an_II_h`, `V_an_IV_h`, `V_an_XII_h`, etc.
- **Valeurs manquantes et drapeaux** :
  - `lac.` = lacune (NaN) ; `n_c` = non communiqué (NaN) ; `s_o` = sans objet (NaN).
  - Valeurs avec `!` → conserver la valeur numérique et poser `flag_incertitude=true`.
  - Espaces insécables, virgules, etc. → normaliser.

> ⚠️ Les CSV fournis ne contiennent pas explicitement `latitude` / `longitude`. Le pipeline prévoit un **fichier de coordonnées** (par ex. centroids des communes par code INSEE) à fournir ultérieurement. Sans ce fichier, les entités sont chargées **sans géométrie** (carte inactive) mais la colonne gauche reste fonctionnelle.

---

## 3) Schémas de sortie (fichiers générés)

### 3.1 `static/data/<region-slug>.geojson`
Un FeatureCollection avec un **Feature par lieu** (si coordonnées disponibles) :
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [lon, lat]},
      "properties": {
        "id": "28001",
        "nom": "Abondant",
        "insee": "28001",
        "section": "A|B|s_o",
        "superficie": 3480,
        "admin": {
          "intendance": "Paris",
          "election": "Dreux",
          "subdelegation": "Dreux",
          "grenier": "Dreux",
          "coutume": "Chartres",
          "parlement": "Paris",
          "bailliage": "Dreux",
          "gouvernement": "Île-de-France",
          "diocese": "Chartres",
          "archidiacone": "Chartres",
          "doyenne": "Dreux"
        },
        "revolution_xix": {
          "district_1790": "Dreux",
          "canton_1790": "Bû",
          "canton_1801": "Anet",
          "arrondissement_1982": "Dreux",
          "canton_1982": "Anet"
        },
        "series": {
          "unit_note": "Conserver le suffixe (_f/_h/_g/_tot/_masc). Aucune conversion implicite.",
          "points": [
            {"key": "V_1790_f", "year": 1790, "suffix": "f", "value": 1125},
            {"key": "V_1790_h", "year": 1790, "suffix": "h", "value": 1162},
            {"key": "V_1982_h", "year": 1982, "suffix": "h", "value": 1314}
          ]
        },
        "flags": {"incertitude": false}
      }
    }
  ]
}
```

### 3.2 `static/data/<region-slug>-series.json` (long/tidy)
Format tabulaire long pour les graphiques et agrégations :
```json
[
  {"insee":"28001","nom":"Abondant","year":1790,"suffix":"f","key":"V_1790_f","value":1125},
  {"insee":"28001","nom":"Abondant","year":1790,"suffix":"h","key":"V_1790_h","value":1162}
]
```

### 3.3 `static/data/<region-slug>-aggregates.json`
Agrégats régionaux pré-calculés par (year,suffix) :
```json
[
  {"region":"eure-et-loir","year":1790,"suffix":"h","sum":12345,"n":512},
  {"region":"eure-et-loir","year":1982,"suffix":"h","sum":456789,"n":465}
]
```

---

## 4) Règles de transformation CSV → JSON/GeoJSON

### 4.1 Parsing des colonnes
- Colonnes d’identité/administratives : **copier tel quel** (trim, normalisation d’espaces).
- Colonnes de séries : clés commençant par `V_` → extraire :
  - `year` :
    - si forme `V_\d{3,4}_...` → convertir en entier.
    - si forme `V_an_[A-Z_]+_...` → **mapper via un dictionnaire externe fourni dans le repo** (ex.: `an_II→1793`, `an_IV→1795`, `an_XII→1803`). Ne pas inférer sans dictionnaire.
  - `suffix` : dernière partie après l’underscore (`f`, `h`, `masc`, `tot`, `g`, etc.). Conserver la chaîne brute ; **ne pas renommer** (les sémantiques exactes seront documentées plus tard).
  - `value` :
    - nettoyer `lac.`, `n_c`, `s_o` → `null`.
    - retirer `!` et consigner `flags.incertitude=true`.
    - convertir en entier si possible ; sinon `null`.

### 4.2 Valeurs manquantes & qualité
- Ajouter `source_key` (ex.: `V_1789_f_3`) si la clé d’origine est pertinente.
- Tenir un rapport `data-quality/<region-slug>.md` listant : colonnes non parsées, parts de valeurs nulles, champs incohérents.

### 4.3 Coordonnées
- Si un fichier `data/coords/communes-centroids.csv` est présent (`insee,lat,lon`), alors faire un **left join** sur `insee`. Sinon, la géométrie est `null`.

---

## 5) Arborescence du projet (Hugo + Quarto)
```
.
├─ config.toml
├─ assets/                     # CSS/JS bundlés par Hugo si besoin
├─ static/
│  ├─ data/
│  │  ├─ eure-et-loir.geojson
│  │  ├─ eure-et-loir-series.json
│  │  ├─ eure-et-loir-aggregates.json
│  │  └─ ... (autres régions)
│  └─ lib/
│     ├─ leaflet/
│     │  ├─ leaflet.css
│     │  └─ leaflet.js
│     └─ markercluster/
│        ├─ leaflet.markercluster.js
│        └─ MarkerCluster.Default.css
├─ content/
│  ├─ _index.md                # page d’accueil
│  └─ regions/
│     ├─ eure-et-loir.md       # article Hugo (ou)
│     └─ eure-et-loir.qmd      # page Quarto (HTML output)
├─ layouts/
│  ├─ _default/
│  │  └─ single.html           # gabarit 2 colonnes
│  └─ partials/
│     └─ map.html              # carte Leaflet + contrôles
├─ quarto/
│  ├─ pipeline.qmd             # ETL CSV→JSON/GeoJSON
│  └─ _quarto.yml
└─ data/                       # sources CSV par région
   ├─ eure-et-loir.csv
   └─ coords/communes-centroids.csv (optionnel)
```

---

## 6) Templates clés

### 6.1 Layout Hugo 2 colonnes (extrait minimal)
```html
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  {{ partial "head.html" . }}
  <link rel="stylesheet" href="/lib/leaflet/leaflet.css">
  <link rel="stylesheet" href="/lib/markercluster/MarkerCluster.Default.css">
  <style>
    .page {display:grid;grid-template-columns:1fr 1fr;gap:1rem;}
    @media (max-width: 920px){.page{grid-template-columns:1fr}.map-col{order:2}}
    .map {height: calc(100vh - 6rem); min-height: 480px;}
  </style>
</head>
<body>
  <main class="page">
    <article class="text-col">{{ .Content }}</article>
    <aside class="map-col">{{ partial "map.html" . }}</aside>
  </main>
  <script src="/lib/leaflet/leaflet.js"></script>
  <script src="/lib/markercluster/leaflet.markercluster.js"></script>
</body>
</html>
```

### 6.2 Partiel `map.html` (pseudocode JS)
```html
<div id="map" class="map"></div>
<script>
  const params = new URLSearchParams(window.location.search);
  const region = params.get('region') || ({{ if .Params.region }}'{{ .Params.region }}'{{ else }}''{{ end }});
  const year = +(params.get('year') || 1982);
  const suffix = params.get('suffix') || 'h';

  const map = L.map('map').setView([46.6, 2.2], 6);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom: 18, attribution: '© OSM'}).addTo(map);

  const url = `/static/data/${region}.geojson`;
  fetch(url).then(r=>r.json()).then(fc => {
    const markers = L.markerClusterGroup();
    fc.features.forEach(f => {
      if (!f.geometry) return;
      const series = (f.properties.series?.points||[]).filter(p => p.year===year && p.suffix===suffix);
      const value = series.length? series[0].value : null;
      const marker = L.circleMarker([f.geometry.coordinates[1], f.geometry.coordinates[0]], {
        radius: value? Math.max(3, Math.sqrt(value)/10) : 4,
        weight: 1
      });
      const popup = `<strong>${f.properties.nom}</strong><br/>INSEE: ${f.properties.insee}<br/>${year} (${suffix}) : ${value ?? 'n.d.'}`;
      marker.bindPopup(popup);
      markers.addLayer(marker);
    });
    map.addLayer(markers);
  });
</script>
```

### 6.3 Quarto — pipeline ETL minimal (`quarto/pipeline.qmd`)
```yaml
---
title: "Pipeline CSV → GeoJSON/JSON"
execute:
  echo: false
format: html
---
```
```python
import pandas as pd, json, re, pathlib
SRC = pathlib.Path('../data/eure-et-loir.csv')
COORDS = pathlib.Path('../data/coords/communes-centroids.csv')
OUT = pathlib.Path('../static/data')
OUT.mkdir(parents=True, exist_ok=True)

missing_tokens = {"lac.", "n_c", "s_o", "", None}
rep_map = {"\xa0": " ", ",": ""}

# Charge CSV & coords (si disponibles)
df = pd.read_csv(SRC, dtype=str).applymap(lambda x: None if x in missing_tokens else x)
for a,b in rep_map.items():
    df = df.replace(a, b, regex=True)

coords = None
if COORDS.exists():
    coords = pd.read_csv(COORDS, dtype={"insee":str})
    coords.columns = [c.lower() for c in coords.columns]

# Détecte colonnes séries
series_cols = [c for c in df.columns if c.startswith('V_')]

# Fonction d'extraction
def parse_series(col, val):
    # val nettoyage
    if val is None: return None
    v = re.sub(r'[^0-9]', '', str(val))
    if v == '': return None
    value = int(v)
    # year
    m = re.match(r'V_(\d{3,4})_(.+)', col)
    year = int(m.group(1)) if m else None
    # suffix
    suff = col.split('_')[-1]
    return {"key": col, "year": year, "suffix": suff, "value": value}

features = []
for _, row in df.iterrows():
    props = {}
    for k in df.columns:
        if not k.startswith('V_'):
            props[k.replace(' ', '_')] = row[k]
    pts = []
    for c in series_cols:
        parsed = parse_series(c, row[c])
        if parsed: pts.append(parsed)
    props['series'] = {"points": pts}

    geom = None
    if coords is not None:
        hit = coords[coords['insee']==props.get('insee')]
        if len(hit):
            geom = {"type":"Point","coordinates":[float(hit.iloc[0]['lon']), float(hit.iloc[0]['lat'])]}

    features.append({"type":"Feature","geometry":geom,"properties":props})

geojson = {"type":"FeatureCollection","features":features}
(OUT/ 'eure-et-loir.geojson').write_text(json.dumps(geojson, ensure_ascii=False))

# Tidy series
rows = []
for f in features:
    base = {"insee": f['properties'].get('insee'), "nom": f['properties'].get('nom')}
    for p in f['properties']['series']['points']:
        r = base | p
        rows.append(r)
ser = pd.DataFrame(rows)
ser.to_json(OUT/ 'eure-et-loir-series.json', orient='records', force_ascii=False)

# Agrégats
agg = ser.groupby(['year','suffix'], dropna=True)['value'].agg(['sum','count']).reset_index()
agg['region'] = 'eure-et-loir'
agg.to_json(OUT/ 'eure-et-loir-aggregates.json', orient='records', force_ascii=False)
```

> Remarques : ce prototype ignore les formes `V_an_*` (mapping à ajouter) et les suffixes multiples (`_f_tot`, `_f_masc`). À affiner à l’étape 2.

---

## 7) Interaction & UX
- **Carte** : centrée France (46.6, 2.2, zoom 6). Clustering activé si > 500 points.
- **Timeline** : slider (année) + sélecteur de suffixe (`h`, `f`, `tot`, etc.). Mettre à jour la carte et l’URL (`?region=<slug>&year=<yyyy>&suffix=<s>`).
- **Popups** : Nom, INSEE, valeur pour l’année/suffixe courants ; lien « Voir la fiche » (ancre vers la gauche si section dédiée).
- **Responsive** : carte sous le texte en < 920px ; hauteur carte `min-height:480px`.
- **Accessibilité** : focus management, labels ARIA sur contrôles, alternatives texte pour cartes (tableau des valeurs).

---

## 8) Étapes pas-à-pas (plan d’exécution LLM)

### Étape 1 — Initialisation du repo
**Entrées** : aucune.  
**Tâches** :
1. Générer l’arborescence (cf. §5) et un `README.md`.
2. Ajouter `config.toml` Hugo minimal (lang=fr, baseURL, params par défaut).
3. Installer Leaflet et, si souhaité, MarkerCluster dans `static/lib/`.
**Sorties** : squelette Hugo + fichiers vides dans `static/data/`.
**DoD** : site se build et affiche la page d’accueil vide + colonne de droite (fond de carte OSM).

### Étape 2 — ETL CSV→JSON/GeoJSON (prototype)
**Entrées** : 1 CSV régional.
**Tâches** :
1. Implémenter nettoyage (`lac.`, `n_c`, `s_o`, `!`, espaces).  
2. Détection des colonnes `V_*` ; extraction `year`, `suffix`, `value`.
3. Joindre des coordonnées si fichier fourni ; sinon géométrie `null`.
4. Émettre `region.geojson`, `region-series.json`, `region-aggregates.json`.
**Sorties** : fichiers dans `/static/data/`.
**DoD** : fichiers JSON valides, carte charge sans erreur (si coords).

### Étape 3 — Normalisation avancée des séries
**Entrées** : dictionnaire `data/dicts/republican-years.csv` (ex.: `an_II,1793`).
**Tâches** :
1. Convertir `V_an_*` en années grégoriennes via dictionnaire.
2. Démêler suffixes composés (`_f_tot`, `_f_masc`) → colonnes `suffix` et `qualifier`.
3. Journal de qualité : métriques de complétude par (year,suffix).
**Sorties** : JSON mis à jour + rapport `data-quality/<region>.md`.
**DoD** : aucun enregistrement avec `year=null` dans `-series.json` (hors `V_an_*` non mappés).

### Étape 4 — Pages de contenu (Hugo/Quarto)
**Entrées** : texte ou `.qmd` régional.
**Tâches** :
1. Créer `content/regions/<slug>.md` (ou `.qmd`).
2. Ajouter front matter : `title`, `region: <slug>`, `params: {year: 1982, suffix: h}`.
3. Dans Quarto, produire un graphique régional (somme des habitants 1790–1982) depuis `<slug>-aggregates.json`.
**Sorties** : page rendu + graphique à gauche.
**DoD** : la page montre le texte/graphique et la carte synchronisée (année/suffixe par défaut).

### Étape 5 — Contrôles interactifs (timeline + suffix)
**Entrées** : fichiers JSON.
**Tâches** :
1. Ajouter un slider année + select suffix dans `map.html`.
2. Synchroniser l’URL ; recharger/réappliquer le style des marqueurs.
3. Option : Sparkline dans la popup (via `<canvas>` + Chart.js local).
**Sorties** : interactions fonctionnelles.
**DoD** : manipuler slider met à jour les cercles et les popups ; URL répliquable.

### Étape 6 — Performance & packaging
**Tâches** :
1. Activer clustering si `features.length > 500`.
2. Réduire les JSON (minify) ; option : découper par **canton_1801** si > 10k points.
3. Auditer poids des assets ; lazy-load des bibliothèques de chart.
**DoD** : Total transféré < 2–3 Mo pour une région moyenne.

### Étape 7 — QA & accessibilité
**Tâches** :
1. Tests de build (Hugo, Quarto).  
2. Validation JSON/GeoJSON ; tests clavier, contrastes ; alternative tabulaire.
3. Vérifier cohérence : valeurs plausibles, nulls gérés, popups lisibles.
**Sorties** : rapport QA.

---

## 9) Paramétrage & conventions
- **Nommage des fichiers** : `<region-slug>` en kebab-case ; ex.: `eure-et-loir`.
- **Front matter pour région** :
```yaml
---
title: "Eure-et-Loir"
region: "eure-et-loir"
params:
  year: 1982
  suffix: "h"
---
```
- **Centres carte** : France `[46.6, 2.2]`, zoom `6`.
- **Couleurs & style** : privilégier CSS natif, marqueurs proportionnels au rayon `sqrt(value)/10` (ajuster par région).

---

## 10) Checklist « Definition of Done » (par région)
- [ ] CSV placé dans `data/` et lisible.
- [ ] ETL exécuté : `*.geojson`, `*-series.json`, `*-aggregates.json` générés.
- [ ] Page `content/regions/<slug>.(md|qmd)` créée avec front matter correct.
- [ ] Carte affiche les points ; popups contiennent (nom, insee, valeur année/suffixe).
- [ ] Slider année + select suffix fonctionnels et synchronisés avec l’URL.
- [ ] Build Hugo/Quarto passe sans erreur ; inspection Lighthouse > 80 sur mobile/desktop.

---

## 11) Points à clarifier ultérieurement (todo)
- Dictionnaire sémantique des suffixes (`_f`, `_h`, `_g`, `_tot`, `_masc`) et unités par période (ex. *feux* vs *habitants*).
- Mapping complet calendrier républicain → années grégoriennes.
- Fichier de coordonnées de référence (centroids par code INSEE ; version et licence).
- Politique de *thinning*/échantillonnage si > 50k features.

---

## 12) Exemples de prompts LLM (opérationnels)

### Créer le squelette Hugo
> Crée l’arborescence décrite au §5, remplis `config.toml` pour un site FR, copie Leaflet et MarkerCluster dans `static/lib/`, ajoute le layout `layouts/_default/single.html` et le partiel `layouts/partials/map.html` avec le code des §6.1–6.2.

### Implémenter l’ETL sur *Eure-et-Loir*
> Dans `quarto/pipeline.qmd`, implémente en Python le chargement du CSV `data/eure-et-loir.csv`, le nettoyage (`lac.`, `n_c`, `s_o`, `!`), l’extraction des colonnes `V_*` vers un format long, la jonction avec `data/coords/communes-centroids.csv` si présent, puis exporte `static/data/eure-et-loir.geojson`, `static/data/eure-et-loir-series.json` et `static/data/eure-et-loir-aggregates.json`.

### Ajouter une page région
> Crée `content/regions/eure-et-loir.qmd` avec le front matter §9. Charge `static/data/eure-et-loir-aggregates.json` et trace une courbe d’évolution (année → somme) ; ajoute un paragraphe introductif.

### Activer timeline & suffix
> Étends `layouts/partials/map.html` pour inclure un `<input type="range">` années et un `<select>` pour `suffix`. Synchronise l’URL et applique le styling des marqueurs.

---

## 13) Licences & crédits
- Données : préciser la source, la licence et la version.
- Fonds de carte : © contributeurs OpenStreetMap (ODbL).  
- Code : MIT (par défaut), à ajuster selon besoin.

---

## 14) Maintenance
- **Mise à jour** : déposer un nouveau CSV → relancer `quarto render quarto/pipeline.qmd` → `hugo`.
- **Ajout d’une région** : dupliquer la page région, changer le `slug`, relancer l’ETL.
- **CI/CD** : Netlify/GitHub Pages ; hook pour rendre Quarto puis builder Hugo.

