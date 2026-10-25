# Mise en production

## 1. Serveur

Une machine Linux, qui peut être celle du serveur FiveM, avec Node.js 20+ et MySQL/MariaDB. Il faut un nom de domaine pointant vers elle.

## 2. Construire

```bash
cd boutique/backend && npm ci && npm run build && npm run migrate:prod
cd ../web && npm ci && npm run build
cd ../backend && npm run admin:create:prod -- patron owner
```

## 3. Lancer en service (systemd)

```ini
# /etc/systemd/system/boutique-elyzea.service
[Unit]
Description=Boutique Elyzea (API + site)
After=network.target mariadb.service

[Service]
WorkingDirectory=/opt/boutique/backend
ExecStart=/usr/bin/node dist/index.js
Restart=always
User=boutique
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

`systemctl enable --now boutique-elyzea`, puis `journalctl -u boutique-elyzea -f` pour les journaux.

## 4. HTTPS (Caddy, le plus simple)

```
boutique.elyzea.fr {
    reverse_proxy 127.0.0.1:3000
}
```

Avec Nginx : `proxy_pass http://127.0.0.1:3000;`, `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`, `proxy_set_header X-Forwarded-Proto $scheme;`, et le certificat Let's Encrypt. Dans `.env` : `TRUST_PROXY=1`, `COOKIE_SECURE=true`.

N'exposez **pas** le port 3000 directement sur internet.

## 5. Serveur FiveM

Voir le README (section « Ressource FiveM »). Si l'API tourne sur la même machine, `shop_api_url` peut être `http://127.0.0.1:3000`. `Config.SiteUrl` doit rester l'adresse publique en https.

## 6. Sauvegardes

Sauvegardez la base `elyzea_boutique` (commandes, récompenses, journaux) chaque jour, par exemple avec `mysqldump --single-transaction`.

## 7. Mises à jour

```bash
git pull
cd backend && npm ci && npm run build && npm run migrate:prod
cd ../web && npm ci && npm run build
systemctl restart boutique-elyzea
```

Les migrations déjà appliquées ne sont jamais rejouées. Pour modifier le schéma, ajoutez un nouveau fichier `database/migrations/003_….sql`.

## 8. Vérifications après déploiement

- `https://VOTRE-SITE/api/health` répond `{"ok":true}`.
- Tebex › Webhooks : la validation est passée.
- En jeu, la console affiche `[server_shop] prêt (framework : elyzea)`. `/boutique` ouvre la boutique.
- Faites un achat test (voir docs/TEBEX.md).
