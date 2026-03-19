#!/bin/bash
# ─────────────────────────────────────────────
#  Corgi ETF Ops — Update deployed app
#  Run this after making code changes
# ─────────────────────────────────────────────

set -e
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $1"; }

# Load deploy info
[ -f .aws-deploy-info.txt ] || { echo "Run deploy-aws.sh first"; exit 1; }
source .aws-deploy-info.txt

SSH_OPTS="-o StrictHostKeyChecking=no -i ${KEY_FILE}"

log "Packaging update..."
zip -r /tmp/etf-ops-update.zip . \
  --exclude "*.pem" --exclude "*.zip" \
  --exclude "__pycache__/*" --exclude ".git/*" \
  --exclude ".env" >/dev/null

log "Uploading to ${PUBLIC_IP}..."
scp $SSH_OPTS /tmp/etf-ops-update.zip ec2-user@${PUBLIC_IP}:/opt/etf-ops/

log "Deploying..."
ssh $SSH_OPTS ec2-user@${PUBLIC_IP} << 'REMOTE'
cd /opt/etf-ops
unzip -o etf-ops-update.zip -d . >/dev/null
pip3.11 install -r backend/requirements.txt -q
sudo systemctl restart etf-ops
sleep 3
curl -s http://localhost:8000/health && echo " — Backend healthy!"
echo "Update complete!"
REMOTE

echo ""
echo -e "${BLUE}  App URL: http://${PUBLIC_IP}${NC}"
echo -e "${BLUE}  API Docs: http://${PUBLIC_IP}/docs${NC}"
