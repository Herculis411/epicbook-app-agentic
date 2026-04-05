#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Book Review App — Frontend Bootstrap Script
# Next.js served via Nginx (Web Tier — PUBLIC EC2)
# Ubuntu 22.04 LTS — runs once on first EC2 boot via user_data
#
# Architecture flow:
#   Browser → Public ALB → THIS EC2 → Nginx:80
#     Nginx /api/*  → Internal ALB:3001 → App EC2 (Node.js)
#     Nginx /*      → Next.js:3000 (local)
#
# Fixes applied:
#   1. PM2 flags (--name, --time) placed BEFORE -- separator
#      so they are passed to PM2, not to npm start
#   2. Removed --log /var/log/... — ubuntu user cannot write there;
#      PM2 uses ~/.pm2/logs/ by default which works correctly
#
# Terraform templatefile() injects at deploy time:
#   internal_alb_dns — Internal ALB hostname (Nginx proxy target)
#   public_alb_dns   — Public ALB DNS (NEXT_PUBLIC_API_URL base)
# ═══════════════════════════════════════════════════════════════════

exec > /var/log/book-review-setup.log 2>&1
echo "================================================"
echo " Book Review Frontend Bootstrap Started"
echo " $(date)"
echo "================================================"

# ── 1. System Update ──────────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt update -y && apt upgrade -y
apt install -y curl git nginx unzip software-properties-common
echo "  System update complete."

# ── 2. Install Node.js 18 LTS ─────────────────────────────────────
echo "[2/8] Installing Node.js 18 LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
echo "  Node.js: $(node -v)  npm: $(npm -v)"

# ── 3. Install PM2 ────────────────────────────────────────────────
echo "[3/8] Installing PM2..."
npm install -g pm2
echo "  PM2: $(pm2 --version)"

# ── 4. Clone Repository ───────────────────────────────────────────
echo "[4/8] Cloning repository..."
cd /home/ubuntu
if [ ! -d "book-review-app" ]; then
  git clone https://github.com/pravinmishraaws/book-review-app.git
fi
chown -R ubuntu:ubuntu /home/ubuntu/book-review-app
echo "  Repository cloned."

# ── 5. Write .env.local ───────────────────────────────────────────
# NEXT_PUBLIC_API_URL must point to the PUBLIC ALB DNS.
# The browser uses this URL for all API calls.
# Nginx on this server catches /api/* and proxies to the Internal ALB
# — the browser never directly contacts the private backend.
echo "[5/8] Writing .env.local..."

cat > /home/ubuntu/book-review-app/frontend/.env.local << ENVEOF
NEXT_PUBLIC_API_URL=http://${public_alb_dns}
ENVEOF

chown ubuntu:ubuntu /home/ubuntu/book-review-app/frontend/.env.local
chmod 600 /home/ubuntu/book-review-app/frontend/.env.local
echo "  NEXT_PUBLIC_API_URL=http://${public_alb_dns}"

# ── 6. Install Dependencies and Build ─────────────────────────────
echo "[6/8] Building Next.js app..."

sudo -u ubuntu bash << 'BUILDEOF'
  cd /home/ubuntu/book-review-app/frontend
  npm install
  npm run build
BUILDEOF

echo "  Next.js build complete."

# ── 7. Configure Nginx ────────────────────────────────────────────
# /api/* proxied to Internal ALB — never exposed publicly
# /*    proxied to Next.js on localhost:3000
echo "[7/8] Configuring Nginx..."

rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/book-review << NGINXEOF
server {
    listen 80;
    server_name _;

    # Backend API proxy — browser calls /api/* → Nginx → Internal ALB → App EC2
    location /api/ {
        proxy_pass         http://${internal_alb_dns}:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout    30s;
        proxy_send_timeout    30s;
    }

    # Next.js frontend — all other traffic
    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 60s;
        proxy_read_timeout    60s;
    }

    # ALB health check endpoint
    location /health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/book-review \
       /etc/nginx/sites-enabled/book-review

nginx -t
systemctl enable nginx
systemctl restart nginx
echo "  Nginx: /api/* → ${internal_alb_dns}:3001 | /* → localhost:3000"

# ── 8. Start Next.js with PM2 ─────────────────────────────────────
# FIX: --name and --time flags placed BEFORE the -- separator
#      so PM2 receives them, not npm start.
# FIX: no --log flag — PM2 writes to ~/.pm2/logs/ automatically
#      which the ubuntu user has full write access to.
echo "[8/8] Starting Next.js with PM2..."

sudo -u ubuntu bash << 'PM2EOF'
  cd /home/ubuntu/book-review-app/frontend
  pm2 delete book-review-frontend 2>/dev/null || true
  pm2 start npm \
    --name "book-review-frontend" \
    --time \
    -- start
  pm2 save
PM2EOF

# Configure PM2 to restart automatically on system reboot
env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
systemctl enable pm2-ubuntu
echo "  PM2 started and configured for auto-restart."

# ── Health Check ──────────────────────────────────────────────────
echo "Waiting 25s for Next.js to start..."
sleep 25

NEXT_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:3000 || echo "000")
echo "  Next.js (port 3000): HTTP $NEXT_CODE"

NGINX_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:80 || echo "000")
echo "  Nginx  (port 80):    HTTP $NGINX_CODE"

API_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost/api/books || echo "000")
echo "  API    (/api/books): HTTP $API_CODE"

echo ""
echo "================================================"
echo " Frontend Bootstrap Complete: $(date)"
echo "------------------------------------------------"
echo " App URL:         http://${public_alb_dns}"
echo " API via Nginx:   http://${public_alb_dns}/api/books"
echo " Internal target: http://${internal_alb_dns}:3001"
echo "------------------------------------------------"
echo " PM2 logs:   sudo -u ubuntu pm2 logs book-review-frontend"
echo " Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo " Setup log:  tail -f /var/log/book-review-setup.log"
echo "================================================"
