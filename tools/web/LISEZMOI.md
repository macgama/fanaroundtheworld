# Version navigateur (artéfact claude.ai)

1. Exporter avec le préréglage « Web » (sans threads, hors ligne, sans GodotSteam) :
   `godot --headless --path . --export-release "Web" build/web/index.html`
   (modèle `web_nothreads_release.zip` de Godot 4.7 requis).
2. Les artéfacts refusent les fichiers de plus de 15 Mo et les types inconnus. Donc :
   - `gzip -9 -c build/web/index.wasm | split -b 14000000 -d -a 1 - data/moteur-` puis renommer en `.wasm`
   - `split -b 14000000 -d -a 1 build/web/index.pck data/jeu-` puis renommer en `.wasm`
3. Publier `artefact.html` avec `index.js`, les deux `index.audio*.worklet.js` et les morceaux `data/*.wasm`.
   La page recolle les morceaux (et décompresse le moteur) en interceptant `fetch`.
   Mettre à jour la liste des morceaux et `TAILLES` dans la page si leur nombre change.
