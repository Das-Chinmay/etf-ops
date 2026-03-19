#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Corgi ETF Ops — AWS EC2 Auto-Deploy Script
#  Run this ONCE from your local machine.
#  It creates everything and gives you a live URL at the end.
# ─────────────────────────────────────────────────────────────

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ─── CONFIG — edit these ──────────────────────────────────────
APP_NAME="etf-ops"
REGION="us-east-1"          # change if you prefer another region
INSTANCE_TYPE="t2.micro"    # free tier eligible
KEY_NAME="etf-ops-key"      # SSH key name (will be created)
LLM_PROVIDER="gemini"       # gemini | openai | anthropic | groq
LLM_API_KEY="YOUR_API_KEY_HERE"   # ← PASTE YOUR KEY HERE
# ─────────────────────────────────────────────────────────────

section "Checking prerequisites"
command -v aws  >/dev/null 2>&1 || err "AWS CLI not installed. Run: brew install awscli  OR  pip install awscli"
command -v ssh  >/dev/null 2>&1 || err "SSH not found"
command -v zip  >/dev/null 2>&1 || err "zip not found"

aws sts get-caller-identity >/dev/null 2>&1 || err "AWS not configured. Run: aws configure"
log "AWS credentials OK"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log "Account: $ACCOUNT_ID | Region: $REGION"

section "Creating SSH Key Pair"
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
  warn "Key pair '$KEY_NAME' already exists — skipping"
else
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query 'KeyMaterial' \
    --output text > "${KEY_NAME}.pem"
  chmod 400 "${KEY_NAME}.pem"
  log "Key saved to ${KEY_NAME}.pem — keep this safe!"
fi

section "Creating Security Group"
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
log "Using VPC: $VPC_ID"

SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters Name=group-name,Values="${APP_NAME}-sg" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name "${APP_NAME}-sg" \
    --description "ETF Ops Platform security group" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query 'GroupId' --output text)
  log "Created security group: $SG_ID"

  # Allow SSH, HTTP, HTTPS, and app ports
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --region "$REGION" --ip-permissions \
    '[{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
      {"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
      {"IpProtocol":"tcp","FromPort":443,"ToPort":443,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
      {"IpProtocol":"tcp","FromPort":8000,"ToPort":8000,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
      {"IpProtocol":"tcp","FromPort":3000,"ToPort":3000,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]}]' \
    >/dev/null
  log "Security group rules added"
else
  warn "Security group already exists: $SG_ID"
fi

section "Launching EC2 Instance"
# Amazon Linux 2023 AMI (free tier, us-east-1)
AMI_ID=$(aws ec2 describe-images \
  --region "$REGION" \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023*-x86_64' 'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
  --output text)
log "Using AMI: $AMI_ID"

# User data script — runs on first boot
USER_DATA=$(cat <<'USERDATA_EOF'
#!/bin/bash
set -e
exec > /var/log/etf-ops-setup.log 2>&1

echo "=== Starting ETF Ops setup ==="

# Update and install deps
dnf update -y
dnf install -y python3.11 python3.11-pip python3.11-devel postgresql15 postgresql15-server git nginx

# Init postgres
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# Create DB and user
sudo -u postgres psql -c "CREATE USER etfops WITH PASSWORD 'etfops123';" || true
sudo -u postgres psql -c "CREATE DATABASE etfops OWNER etfops;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE etfops TO etfops;" || true

# Fix pg_hba.conf for password auth
sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf
sed -i 's/peer/md5/g' /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

echo "=== Postgres ready ==="

# App dir
mkdir -p /opt/etf-ops
chown ec2-user:ec2-user /opt/etf-ops

echo "=== Setup complete, waiting for app files ==="
touch /tmp/setup-done
USERDATA_EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${APP_NAME}}]" \
  --region "$REGION" \
  --query 'Instances[0].InstanceId' \
  --output text)

log "Instance launched: $INSTANCE_ID"

section "Waiting for instance to be ready"
log "This takes ~2 minutes..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

log "Instance running at: $PUBLIC_IP"
log "Waiting 90 seconds for SSH to be ready..."
sleep 90

section "Packaging app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create app archive
zip -r /tmp/etf-ops-app.zip . \
  --exclude "*.pem" \
  --exclude "*.zip" \
  --exclude "__pycache__/*" \
  --exclude ".git/*" \
  --exclude ".env" \
  >/dev/null

log "App packaged"

section "Uploading app to server"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=30 -i ${KEY_NAME}.pem"

# Upload app
scp $SSH_OPTS /tmp/etf-ops-app.zip ec2-user@${PUBLIC_IP}:/opt/etf-ops/
log "Files uploaded"

section "Deploying on server"
ssh $SSH_OPTS ec2-user@${PUBLIC_IP} << REMOTE_EOF
set -e

echo "=== Waiting for initial setup to complete ==="
for i in \$(seq 1 30); do
  [ -f /tmp/setup-done ] && break
  echo "Waiting... (\$i/30)"
  sleep 10
done

echo "=== Installing app ==="
cd /opt/etf-ops
unzip -o etf-ops-app.zip -d . >/dev/null

# Install Python deps
cd /opt/etf-ops/backend
pip3.11 install -r requirements.txt -q

# Create .env
cat > /opt/etf-ops/backend/.env << ENV_EOF
DATABASE_URL=postgresql://etfops:etfops123@localhost:5432/etfops
LLM_PROVIDER=${LLM_PROVIDER}
LLM_API_KEY=${LLM_API_KEY}
SECRET_KEY=etfops-prod-secret-$(openssl rand -hex 16)
ENV_EOF

echo "=== Setting up database ==="
PGPASSWORD=etfops123 psql -U etfops -d etfops -h localhost -f /opt/etf-ops/backend/init.sql

echo "=== Configuring nginx ==="
sudo tee /etc/nginx/conf.d/etf-ops.conf > /dev/null << NGINX_EOF
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        root /opt/etf-ops/frontend;
        index index.html;
        try_files \\\$uri \\\$uri/ /index.html;
    }

    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
    }

    # API docs
    location /docs {
        proxy_pass http://127.0.0.1:8000/docs;
        proxy_set_header Host \\\$host;
    }
}
NGINX_EOF

sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx

echo "=== Creating systemd service for backend ==="
sudo tee /etc/systemd/system/etf-ops.service > /dev/null << SERVICE_EOF
[Unit]
Description=Corgi ETF Ops Backend
After=network.target postgresql.service

[Service]
User=ec2-user
WorkingDirectory=/opt/etf-ops/backend
Environment="PATH=/usr/local/bin:/usr/bin"
ExecStart=/usr/local/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable etf-ops
sudo systemctl start etf-ops

echo "=== Waiting for backend to start ==="
sleep 5
curl -s http://localhost:8000/health && echo " — Backend healthy!"

echo "=== DONE ==="
REMOTE_EOF

section "Updating frontend API URL"
# Update frontend to use relative /api path (nginx proxies it)
ssh $SSH_OPTS ec2-user@${PUBLIC_IP} << 'FIX_EOF'
sed -i "s|const API = .*|const API = '/api';|g" /opt/etf-ops/frontend/index.html
FIX_EOF

log "Frontend API URL updated"

section "✅ Deployment Complete!"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🚀 Your app is live!${NC}"
echo ""
echo -e "  ${BLUE}App URL:${NC}      http://${PUBLIC_IP}"
echo -e "  ${BLUE}API Docs:${NC}     http://${PUBLIC_IP}/docs"
echo -e "  ${BLUE}Instance:${NC}     ${INSTANCE_ID}"
echo -e "  ${BLUE}Region:${NC}       ${REGION}"
echo ""
echo -e "  ${YELLOW}SSH access:${NC}"
echo -e "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo -e "  ${YELLOW}View backend logs:${NC}"
echo -e "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP} 'sudo journalctl -u etf-ops -f'"
echo ""
echo -e "  ${YELLOW}To stop/save costs:${NC}"
echo -e "  aws ec2 stop-instances --instance-ids ${INSTANCE_ID} --region ${REGION}"
echo -e "  aws ec2 start-instances --instance-ids ${INSTANCE_ID} --region ${REGION}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Save instance info
cat > .aws-deploy-info.txt << INFO_EOF
INSTANCE_ID=${INSTANCE_ID}
PUBLIC_IP=${PUBLIC_IP}
REGION=${REGION}
KEY_FILE=${KEY_NAME}.pem
APP_URL=http://${PUBLIC_IP}
API_DOCS=http://${PUBLIC_IP}/docs
INFO_EOF
log "Deploy info saved to .aws-deploy-info.txt"
