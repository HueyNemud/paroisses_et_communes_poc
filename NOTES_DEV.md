# 📝 Notes de développement - Cartoscope Hugo

## ✅ Étape 0 : Initialisation Git & déploiement (TERMINÉE)

### Réalisations

- [x] Repository Git initialisé avec `.gitignore` adapté
- [x] Workflow GitHub Actions configuré (`.github/workflows/hugo-quarto.yml`)
- [x] Instructions Copilot avec feuille de route (`.copilot-instructions.md`)
- [x] README.md complet
- [x] Premier commit effectué

## ✅ Étape 1 : Squelette Hugo (TERMINÉE)

### Réalisations

- [x] `config.toml` Hugo configuré (lang=fr, params carte/données)
- [x] Arborescence complète créée (layouts, content, static)
- [x] Leaflet 1.9.4 + MarkerCluster 1.5.3 installés dans `static/lib/`
- [x] Layout 2 colonnes responsive (`layouts/_default/single.html`)
- [x] Layout page d'accueil (`layouts/_default/home.html`)
- [x] Layout listes/sections (`layouts/_default/list.html`)
- [x] Partiel carte interactive (`layouts/partials/map.html`)
- [x] Page d'accueil créée (`content/_index.md`)
- [x] Page liste régions (`content/regions/_index.md`)

### Validation étape 1

- [x] Hugo build sans erreur
- [x] Page d'accueil accessible avec design moderne
- [x] Fond de carte OSM visible avec contrôles interactifs
- [x] Layout responsive (2 colonnes desktop, carte sous texte mobile)
- [x] Navigation fonctionnelle entre pages
- [x] Assets Leaflet correctement chargés

### Fonctionnalités implémentées

- **Interface 2 colonnes** : Contenu à gauche, carte interactive à droite
- **Design responsive** : Adaptation automatique mobile/desktop (breakpoint 920px)
- **Contrôles carte** : Timeline (slider années), sélecteur mesures, info données
- **Navigation** : Menu principal, liens entre sections
- **Carte Leaflet** : Fond OSM, clustering, popups, contrôles URL
- **Gestion états** : Chargement, erreurs, données manquantes

### Configuration GitHub Pages
Pour activer le déploiement automatique :
1. Pusher le repository sur GitHub
2. Aller dans Settings → Pages → Source: "GitHub Actions"
3. Le workflow se déclenchera automatiquement sur chaque push vers `main`

### Fichiers créés
- `.gitignore` : Ignore Hugo, Quarto, Python, IDE files
- `.github/workflows/hugo-quarto.yml` : CI/CD automatique
- `.copilot-instructions.md` : Guide pour Copilot avec feuille de route
- `README.md` : Documentation complète du projet

## ✅ Étape 2 : Pipeline ETL (TERMINÉE)

### Réalisations

- [x] Configuration Quarto (`_quarto.yml`)
- [x] Pipeline ETL Python complet (`pipeline.py`)
- [x] Environnement Python configuré (venv + pandas, numpy, jupyter)
- [x] Processing CSV Eure-et-Loir → JSON/GeoJSON réussi
- [x] Génération des 4 fichiers de sortie par région
- [x] Page région Eure-et-Loir créée et intégrée
- [x] Test d'intégration site + données fonctionnel

### Validation étape 2

- [x] Pipeline ETL s'exécute sans erreur
- [x] 4 fichiers JSON/GeoJSON générés et valides (9.1 MB total)
- [x] 489 communes traitées avec 22 687 points de données
- [x] 13 types de suffixes détectés (h, f, f_tot, etc.)
- [x] Site Hugo intègre et affiche les données correctement
- [x] Contrôles carte fonctionnels (timeline, sélecteurs)

### Données traitées - Résumé

- **489 communes** Eure-et-Loir
- **86 colonnes temporelles** (V_1250_f à V_1982_h)
- **732 ans de données** (1250-1982)
- **99,8% complétude** (488/489 communes avec données)
- **15 flags d'incertitude** détectés et préservés
- **0 coordonnées géographiques** (carte inactive pour l'instant)

### Fichiers générés

- `eure-et-loir.geojson` (4.7 MB) : Features avec propriétés complètes
- `eure-et-loir-series.json` (4.4 MB) : Format long/tidy (22 687 records)
- `eure-et-loir-aggregates.json` (14 KB) : 83 agrégations pré-calculées
- `eure-et-loir-quality-report.json` (790 B) : Métriques de qualité

### Fonctionnalités pipeline

- **Nettoyage robuste** : Gestion `lac.`, `n_c`, `s_o`, flags `!`
- **Parsing intelligent** : Colonnes `V_ANNEE_SUFFIXE` → structures JSON
- **Suffixes composés** : Support `f_tot`, `f_masc`, etc.
- **Validation** : Contrôles JSON, métriques qualité, rapports
- **Gestion erreurs** : Coordonnées manquantes, valeurs invalides

### Commandes à exécuter
```bash
# Télécharger et installer Leaflet
wget https://unpkg.com/leaflet@1.9.4/dist/leaflet.css -P static/lib/leaflet/
wget https://unpkg.com/leaflet@1.9.4/dist/leaflet.js -P static/lib/leaflet/

# Télécharger MarkerCluster
wget https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js -P static/lib/markercluster/
wget https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css -P static/lib/markercluster/
```

### Fichiers à créer
- `config.toml` : Configuration Hugo pour site FR
- `layouts/_default/single.html` : Template 2 colonnes
- `layouts/partials/map.html` : Carte Leaflet interactive
- `content/_index.md` : Page d'accueil
- `content/regions/` : Dossier pour les pages régions

### Validation étape 1
- [ ] Hugo build sans erreur
- [ ] Page d'accueil accessible
- [ ] Fond de carte OSM visible
- [ ] Layout responsive (test mobile)

## 📊 Données disponibles

### Fichier source
- `data/Eure_et_Loire.csv` : 490 communes avec 91 colonnes
- Colonnes séries : V_1250_f à V_1982_h (146 colonnes temporelles)
- Pas de coordonnées géographiques pour l'instant

### Colonnes remarquables
- **Identité** : `n°ordre-alph18012`, `nom`, `insee`, `section`, `superficie`
- **Admin Ancien Régime** : `intendance`, `election`, `diocese`, `bailliage`...
- **Admin moderne** : `district_1790`, `canton_1801`, `arrondissement_1982`...
- **Séries demo** : Format `V_ANNÉE_SUFFIXE` (h=habitants, f=feux, etc.)

## 🔧 Configuration technique

### Hugo
- Version extended requise (pour SCSS)
- Lang : français
- BaseURL : À configurer selon déploiement

### Quarto
- Python backend
- Dépendances : pandas (minimum)
- Output : HTML + JSON/GeoJSON

### Leaflet
- Version 1.9.4 (stable)
- Plugins : MarkerCluster 1.5.3
- Tiles : OpenStreetMap (gratuit)

## 🎨 Design prévu

### Layout
- **Desktop** : 2 colonnes égales (50/50)
- **Mobile** : Carte sous le texte, pleine largeur
- **Breakpoint** : 920px

### Carte
- **Centre** : France [46.6, 2.2]
- **Zoom initial** : 6
- **Clustering** : Automatique si >500 points
- **Marqueurs** : Proportionnels aux valeurs

### Couleurs
- À définir (suggestions : bleus/verts pour cohérence cartographique)

## ⚠️ Points d'attention

### Limitations actuelles
1. **Pas de coordonnées** : Carte sera vide initialement
2. **Calendrier républicain** : `V_an_II_h` etc. nécessitent mapping
3. **Performance** : 490 communes × 146 colonnes = gros JSON

### Solutions prévues
1. Pipeline pour jointure coords futures
2. Dictionnaire années républicaines
3. Agrégations pré-calculées + clustering

## 📋 Checklist développement

### Étape 1 : Squelette Hugo
- [ ] `config.toml`
- [ ] Structure layouts/
- [ ] Assets Leaflet
- [ ] Page d'accueil
- [ ] Test build local

### Étape 2 : Pipeline ETL
- [ ] `quarto/pipeline.qmd`
- [ ] Parser CSV Eure-et-Loir
- [ ] Générer JSON/GeoJSON
- [ ] Test intégration

### Étape 3 : Page région
- [ ] `content/regions/eure-et-loir.qmd`
- [ ] Graphique Quarto
- [ ] Sync carte-contenu

### Étape 4 : Interactivité
- [ ] Timeline slider
- [ ] Sélecteur suffix
- [ ] URL synchronisée
- [ ] Marqueurs dynamiques

### Validation finale
- [ ] Build complet sans erreur
- [ ] Performance <3Mo/région
- [ ] Responsive OK
- [ ] Accessibilité basique

---

**Dernière mise à jour** : 3 septembre 2025 - 11:40  
**Status** : ✅ Étape 2 terminée, prêt pour Étape 3 (Page région + graphiques)
