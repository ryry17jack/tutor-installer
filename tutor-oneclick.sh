#!/bin/bash

#############################################
# OpenEdX One-Click Complete Setup
# ติดตั้งและตั้งค่าทุกอย่างอัตโนมัติ
#############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURRENT_USER=$(whoami)
HOME_DIR="/home/$CURRENT_USER"

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║                                               ║"
    echo "║      OpenEdX Complete Setup Wizard           ║"
    echo "║                                               ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[i]${NC} $1"
}

# ตรวจสอบ root
if [ "$EUID" -eq 0 ]; then 
    print_error "กรุณาอย่ารันสคริปต์นี้ด้วย sudo หรือ root"
    exit 1
fi

# ฟังก์ชันสำหรับรับข้อมูล
get_configuration() {
    print_section "ข้อมูลการติดตั้ง"
    
    read -p "$(echo -e ${CYAN}ชื่อโดเมน LMS:${NC}) " LMS_DOMAIN
    LMS_DOMAIN=${LMS_DOMAIN:-lms.krujackz.org}
    
    read -p "$(echo -e ${CYAN}ชื่อโดเมน Studio:${NC}) " CMS_DOMAIN
    CMS_DOMAIN=${CMS_DOMAIN:-studio.krujackz.org}
    
    read -p "$(echo -e ${CYAN}ชื่อโดเมน phpMyAdmin:${NC}) " PMA_DOMAIN
    PMA_DOMAIN=${PMA_DOMAIN:-pmad.krujackz.org}
    
    read -p "$(echo -e ${CYAN}อีเมล admin:${NC}) " ADMIN_EMAIL
    
    read -p "$(echo -e ${CYAN}ชื่อแพลตฟอร์ม:${NC}) " PLATFORM_NAME
    PLATFORM_NAME=${PLATFORM_NAME:-My OpenEdX Platform}
    
    while true; do
        read -sp "$(echo -e ${CYAN}รหัสผ่าน MySQL Root:${NC}) " MYSQL_ROOT_PASSWORD
        echo ""
        read -sp "$(echo -e ${CYAN}ยืนยันรหัสผ่าน MySQL:${NC}) " MYSQL_CONFIRM
        echo ""
        if [ "$MYSQL_ROOT_PASSWORD" = "$MYSQL_CONFIRM" ]; then
            break
        else
            print_error "รหัสผ่านไม่ตรงกัน กรุณาลองใหม่"
        fi
    done
    
    while true; do
        read -sp "$(echo -e ${CYAN}รหัสผ่าน Admin OpenEdX:${NC}) " ADMIN_PASSWORD
        echo ""
        read -sp "$(echo -e ${CYAN}ยืนยันรหัสผ่าน Admin:${NC}) " ADMIN_CONFIRM
        echo ""
        if [ "$ADMIN_PASSWORD" = "$ADMIN_CONFIRM" ]; then
            break
        else
            print_error "รหัสผ่านไม่ตรงกัน กรุณาลองใหม่"
        fi
    done
    
    read -p "$(echo -e ${CYAN}อีเมลสำหรับรับการแจ้งเตือน [${ADMIN_EMAIL}]:${NC}) " ALERT_EMAIL
    ALERT_EMAIL=${ALERT_EMAIL:-$ADMIN_EMAIL}
    
    read -p "$(echo -e ${CYAN}Slack/Discord Webhook URL [ไม่ใส่ได้]:${NC}) " WEBHOOK_URL
    
    # แสดงสรุป
    print_section "สรุปข้อมูลการติดตั้ง"
    echo -e "${YELLOW}LMS Domain:${NC} $LMS_DOMAIN"
    echo -e "${YELLOW}CMS Domain:${NC} $CMS_DOMAIN"
    echo -e "${YELLOW}phpMyAdmin Domain:${NC} $PMA_DOMAIN"
    echo -e "${YELLOW}Admin Email:${NC} $ADMIN_EMAIL"
    echo -e "${YELLOW}Platform Name:${NC} $PLATFORM_NAME"
    echo -e "${YELLOW}Alert Email:${NC} $ALERT_EMAIL"
    echo -e "${YELLOW}Webhook:${NC} ${WEBHOOK_URL:-ไม่ได้ตั้งค่า}"
    echo ""
    
    read -p "$(echo -e ${CYAN}ข้อมูลถูกต้องหรือไม่? [y/n]:${NC}) " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "ยกเลิกการติดตั้ง"
        exit 0
    fi
}

# ติดตั้งระบบพื้นฐาน
install_base_system() {
    print_section "ติดตั้งระบบพื้นฐาน"
    
    print_info "อัพเดทระบบ..."
    sudo apt update && sudo apt upgrade -y
    
    print_info "ติดตั้ง packages..."
    sudo apt install -y curl wget git vim nano ufw fail2ban apt-transport-https \
        ca-certificates gnupg lsb-release python3-pip python3-venv htop net-tools
    
    print_status "ติดตั้งระบบพื้นฐานเสร็จสิ้น"
}

# ติดตั้ง Docker
install_docker() {
    print_section "ติดตั้ง Docker"
    
    if ! command -v docker &> /dev/null; then
        print_info "ดาวน์โหลดและติดตั้ง Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $CURRENT_USER
        rm get-docker.sh
        print_status "Docker ติดตั้งสำเร็จ"
    else
        print_warning "Docker ติดตั้งแล้ว"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_info "ติดตั้ง Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        print_status "Docker Compose ติดตั้งสำเร็จ"
    else
        print_warning "Docker Compose ติดตั้งแล้ว"
    fi
    
    # ตั้งค่า Docker logging
    print_info "ตั้งค่า Docker..."
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    sudo systemctl restart docker
    print_status "Docker ตั้งค่าเสร็จสิ้น"
}

# ติดตั้ง Tutor
install_tutor() {
    print_section "ติดตั้ง Tutor OpenEdX (PEP 668 Compliant)"
    
    # ลบ venv เก่าถ้ามี
    if [ -d "$VENV_DIR" ]; then
        print_warning "พบ virtual environment เก่า กำลังลบ..."
        rm -rf "$VENV_DIR"
    fi
    
    print_info "สร้าง Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    
    print_info "เปิดใช้งาน virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    print_info "อัพเกรด pip ใน virtual environment..."
    pip install --upgrade pip setuptools wheel
    
    print_info "ติดตั้ง Tutor ใน virtual environment..."
    pip install "tutor[full]"
    
    # สร้าง wrapper script
    print_info "สร้าง wrapper script..."
    sudo tee /usr/local/bin/tutor > /dev/null << EOFWRAPPER
#!/bin/bash
source "$VENV_DIR/bin/activate"
exec "$VENV_DIR/bin/tutor" "\$@"
EOFWRAPPER
    
    sudo chmod +x /usr/local/bin/tutor
    
    # เพิ่ม alias ใน bashrc
    if ! grep -q "TUTOR_VENV" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOFBASH'

# Tutor OpenEdX Virtual Environment
export TUTOR_VENV="$HOME/.tutor-venv"
alias tutor-venv='source $TUTOR_VENV/bin/activate'
EOFBASH
    fi
    
    deactivate 2>/dev/null || true
    
    # ทดสอบ tutor command
    if /usr/local/bin/tutor --version &> /dev/null; then
        print_status "Tutor ติดตั้งสำเร็จ: $(tutor --version)"
    else
        print_error "ไม่สามารถติดตั้ง Tutor ได้"
        exit 1
    fi
}

# ตั้งค่าและเริ่ม Tutor
setup_tutor() {
    print_section "ตั้งค่า Tutor OpenEdX"
    
    mkdir -p $HOME_DIR/tutor-data
    cd $HOME_DIR/tutor-data
    
    print_info "กำลังตั้งค่า Tutor (อาจใช้เวลาหลายนาที)..."
    
    /usr/local/bin/tutor config save --set LMS_HOST=$LMS_DOMAIN \
        --set CMS_HOST=$CMS_DOMAIN \
        --set CONTACT_EMAIL=$ADMIN_EMAIL \
        --set PLATFORM_NAME="$PLATFORM_NAME" \
        --set MYSQL_IMAGE=mariadb:11.2 \
        --set MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
    
    print_info "กำลังเริ่มต้น Tutor (จะใช้เวลา 15-30 นาที)..."
    print_warning "กรุณาอดทน กำลังดาวน์โหลดและติดตั้ง Docker images..."
    
    /usr/local/bin/tutor local launch --non-interactive
    
    print_info "สร้าง admin user..."
    /usr/local/bin/tutor local createuser --staff --superuser admin $ADMIN_EMAIL --password=$ADMIN_PASSWORD
    
    print_status "Tutor OpenEdX พร้อมใช้งานแล้ว"
}

# ติดตั้ง phpMyAdmin
install_phpmyadmin() {
    print_section "ติดตั้ง phpMyAdmin"
    
    mkdir -p $HOME_DIR/phpmyadmin
    cd $HOME_DIR/phpmyadmin
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    container_name: phpmyadmin
    restart: always
    environment:
      - PMA_ARBITRARY=1
      - PMA_HOST=mysql
      - PMA_PORT=3306
      - UPLOAD_LIMIT=100M
      - MAX_EXECUTION_TIME=600
    ports:
      - "8081:80"
    networks:
      - tutor_default
    volumes:
      - phpmyadmin_data:/sessions

networks:
  tutor_default:
    external: true

volumes:
  phpmyadmin_data:
EOF
    
    docker-compose up -d
    print_status "phpMyAdmin ติดตั้งสำเร็จ"
}

# ติดตั้ง Caddy
install_caddy() {
    print_section "ติดตั้ง Caddy Web Server"
    
    print_info "เพิ่ม repository..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    
    print_info "ติดตั้ง Caddy..."
    sudo apt update
    sudo apt install -y caddy
    
    print_info "ตั้งค่า Caddyfile..."
    sudo tee /etc/caddy/Caddyfile > /dev/null << EOF
$LMS_DOMAIN {
    reverse_proxy localhost:80
}

$CMS_DOMAIN {
    reverse_proxy localhost:80
}

$PMA_DOMAIN {
    reverse_proxy localhost:8081
    
    request_body {
        max_size 100MB
    }
}
EOF
    
    sudo systemctl restart caddy
    sudo systemctl enable caddy
    print_status "Caddy ติดตั้งและตั้งค่าเสร็จสิ้น"
}

# สร้าง systemd services
create_systemd_services() {
    print_section "สร้าง Systemd Services"
    
    # Tutor service
    print_info "สร้าง tutor-openedx.service..."
    sudo tee /etc/systemd/system/tutor-openedx.service > /dev/null << EOF
[Unit]
Description=Tutor OpenEdX Platform
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$CURRENT_USER
WorkingDirectory=$HOME_DIR/tutor-data
ExecStart=$HOME_DIR/.local/bin/tutor local start -d
ExecStop=$HOME_DIR/.local/bin/tutor local stop
StandardOutput=journal
StandardError=journal
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF
    
    # phpMyAdmin service
    print_info "สร้าง phpmyadmin.service..."
    sudo tee /etc/systemd/system/phpmyadmin.service > /dev/null << EOF
[Unit]
Description=phpMyAdmin Docker Container
After=docker.service tutor-openedx.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$CURRENT_USER
WorkingDirectory=$HOME_DIR/phpmyadmin
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable tutor-openedx.service
    sudo systemctl enable phpmyadmin.service
    
    print_status "Systemd services สร้างเสร็จสิ้น"
}

# สร้าง management scripts
create_management_scripts() {
    print_section "สร้าง Management Scripts"
    
    # Health check script
    print_info "สร้าง health check script..."
    sudo tee /usr/local/bin/check-services.sh > /dev/null << 'EOFSCRIPT'
#!/bin/bash
LOG_FILE="/var/log/service-health-check.log"
log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

if ! systemctl is-active --quiet docker; then
    log_message "Docker is down. Restarting..."
    systemctl restart docker && sleep 10
fi

if ! systemctl is-active --quiet tutor-openedx; then
    log_message "Tutor OpenEdX is down. Restarting..."
    systemctl restart tutor-openedx && sleep 30
fi

if ! docker ps | grep -q phpmyadmin; then
    log_message "phpMyAdmin is down. Restarting..."
    systemctl restart phpmyadmin && sleep 10
fi

if ! systemctl is-active --quiet caddy; then
    log_message "Caddy is down. Restarting..."
    systemctl restart caddy
fi
EOFSCRIPT
    
    # Backup script
    print_info "สร้าง backup script..."
    sudo tee /usr/local/bin/backup-openedx.sh > /dev/null << EOFSCRIPT
#!/bin/bash
BACKUP_DIR="$HOME_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/openedx-backup.log"
mkdir -p "\$BACKUP_DIR"

log_message() { echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" | tee -a "\$LOG_FILE"; }

log_message "Starting backup..."
cd $HOME_DIR/tutor-data
su - $CURRENT_USER -c "$HOME_DIR/.local/bin/tutor local stop"
tar -czf "\$BACKUP_DIR/tutor-data-\$DATE.tar.gz" \$($HOME_DIR/.local/bin/tutor config printroot)
su - $CURRENT_USER -c "$HOME_DIR/.local/bin/tutor local start -d"

MYSQL_CONTAINER=\$(docker ps --format '{{.Names}}' | grep mysql | head -1)
docker exec \$MYSQL_CONTAINER mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "\$BACKUP_DIR/mysql-backup-\$DATE.sql" 2>/dev/null

find "\$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
find "\$BACKUP_DIR" -name "*.sql" -mtime +7 -delete

log_message "Backup completed"
EOFSCRIPT
    
    # Restart all script
    print_info "สร้าง restart-all script..."
    sudo tee /usr/local/bin/restart-all-services.sh > /dev/null << 'EOFSCRIPT'
#!/bin/bash
echo "Restarting all services..."
sudo systemctl restart docker && sleep 10
sudo systemctl restart tutor-openedx && sleep 30
sudo systemctl restart phpmyadmin && sleep 10
sudo systemctl restart caddy
echo "All services restarted!"
docker ps
EOFSCRIPT
    
    sudo chmod +x /usr/local/bin/check-services.sh
    sudo chmod +x /usr/local/bin/backup-openedx.sh
    sudo chmod +x /usr/local/bin/restart-all-services.sh
    
    print_status "Management scripts สร้างเสร็จสิ้น"
}

# ตั้งค่า cron jobs
setup_cron_jobs() {
    print_section "ตั้งค่า Cron Jobs"
    
    print_info "เพิ่ม cron jobs..."
    (sudo crontab -l 2>/dev/null | grep -v "check-services.sh"; echo "*/5 * * * * /usr/local/bin/check-services.sh") | sudo crontab -
    (sudo crontab -l 2>/dev/null | grep -v "backup-openedx.sh"; echo "0 2 * * * /usr/local/bin/backup-openedx.sh") | sudo crontab -
    
    print_status "Cron jobs ตั้งค่าเสร็จสิ้น"
}

# ตั้งค่า firewall
setup_firewall() {
    print_section "ตั้งค่า Firewall"
    
    print_info "ตั้งค่า UFW..."
    sudo ufw --force enable
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    print_status "Firewall ตั้งค่าเสร็จสิ้น"
}

# สร้างไฟล์ข้อมูล
create_info_file() {
    print_section "สร้างไฟล์ข้อมูล"
    
    cat > $HOME_DIR/openedx-info.txt << EOF
========================================
OpenEdX Installation Information
========================================
Installation Date: $(date)

DOMAINS:
- LMS: https://$LMS_DOMAIN
- Studio: https://$CMS_DOMAIN
- phpMyAdmin: https://$PMA_DOMAIN

CREDENTIALS:
- Admin Email: $ADMIN_EMAIL
- Admin Username: admin
- Admin Password: $ADMIN_PASSWORD
- MySQL Root Password: $MYSQL_ROOT_PASSWORD

USEFUL COMMANDS:
- Check status: tutor local status
- View logs: tutor local logs -f
- Restart all: sudo /usr/local/bin/restart-all-services.sh
- Backup: sudo /usr/local/bin/backup-openedx.sh
- Health check: sudo /usr/local/bin/check-services.sh

DIRECTORIES:
- Tutor data: $HOME_DIR/tutor-data
- phpMyAdmin: $HOME_DIR/phpmyadmin
- Backups: $HOME_DIR/backups

PHPMYADMIN ACCESS:
- URL: https://$PMA_DOMAIN
- Server: mysql
- Username: root
- Password: $MYSQL_ROOT_PASSWORD

SYSTEMD SERVICES:
- sudo systemctl status tutor-openedx
- sudo systemctl status phpmyadmin
- sudo systemctl status caddy

MONITORING:
- Alert Email: $ALERT_EMAIL
- Webhook: ${WEBHOOK_URL:-Not configured}
EOF
    
    chmod 600 $HOME_DIR/openedx-info.txt
    print_status "ข้อมูลบันทึกที่: $HOME_DIR/openedx-info.txt"
}

# แสดงสรุป
show_summary() {
    print_section "สรุปการติดตั้ง"
    
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      การติดตั้งเสร็จสมบูรณ์!                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📱 URLs:${NC}"
    echo -e "   LMS: ${CYAN}https://$LMS_DOMAIN${NC}"
    echo -e "   Studio: ${CYAN}https://$CMS_DOMAIN${NC}"
    echo -e "   phpMyAdmin: ${CYAN}https://$PMA_DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}🔐 Credentials:${NC}"
    echo -e "   Admin: ${CYAN}admin${NC} / ${CYAN}$ADMIN_PASSWORD${NC}"
    echo -e "   MySQL Root: ${CYAN}$MYSQL_ROOT_PASSWORD${NC}"
    echo ""
    echo -e "${YELLOW}📁 ข้อมูลทั้งหมด:${NC} ${CYAN}$HOME_DIR/openedx-info.txt${NC}"
    echo ""
    echo -e "${RED}⚠️  สำคัญ:${NC}"
    echo -e "   1. กรุณารีสตาร์ทเซิร์ฟเวอร์: ${YELLOW}sudo reboot${NC}"
    echo -e "   2. หลังรีสตาร์ท ตรวจสอบสถานะ: ${YELLOW}tutor local status${NC}"
    echo -e "   3. อย่าลืมตั้งค่า DNS ที่ Cloudflare"
    echo ""
    echo -e "${GREEN}✅ ระบบจะทำงานอัตโนมัติหลังรีสตาร์ท${NC}"
    echo ""
}

# Main execution
main() {
    print_header
    
    # ตรวจสอบ Ubuntu version
    if ! grep -q "24.04" /etc/os-release 2>/dev/null; then
        print_warning "สคริปต์นี้ออกแบบสำหรับ Ubuntu 24.04"
        read -p "ต้องการดำเนินการต่อหรือไม่? [y/n]: " continue
        if [[ ! $continue =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    get_configuration
    install_base_system
    install_docker
    install_tutor
    setup_tutor
    install_phpmyadmin
    install_caddy
    create_systemd_services
    create_management_scripts
    setup_cron_jobs
    setup_firewall
    create_info_file
    show_summary
}

# Run
main
