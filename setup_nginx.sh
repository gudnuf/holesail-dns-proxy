#!/bin/bash
set -e

# Function to check if a certificate is valid and not expired
check_cert_validity() {
    local domain=$1
    local cert_file="/etc/letsencrypt/live/$domain/fullchain.pem"
    
    if [ ! -f "$cert_file" ]; then
        return 1
    fi
    
    # Check certificate expiration
    local expiration_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    local expiration_epoch=$(date -d "$expiration_date" +%s)
    local current_epoch=$(date +%s)
    
    # Check if the certificate is still valid for at least 30 days
    if [ $((expiration_epoch - current_epoch)) -gt $((30 * 24 * 3600)) ]; then
        return 0
    else
        return 1
    fi
}

# Function to generate or renew SSL certificate
generate_or_renew_cert() {
    local domain=$1
    
    if check_cert_validity "$domain"; then
        echo "A valid SSL certificate already exists for $domain. Using the existing certificate."
    else
        echo "Generating a new SSL certificate for $domain..."
        sudo certbot certonly --webroot -w /var/www/certbot -d "$domain" --non-interactive --agree-tos --email your-email@example.com
        
        if [ $? -eq 0 ]; then
            echo "SSL certificate successfully generated for $domain."
        else
            echo "Failed to generate SSL certificate for $domain."
            exit 1
        fi
    fi
}

# Prompt for full subdomain
read -p "Enter your full subdomain (e.g., test.domain.com): " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-localhost}

# Create initial Nginx configuration file with only HTTP
cat << EOF > nginx_http.conf
events {
    worker_connections 1024;
}
http {
    server {
        listen 80;
        server_name $SERVER_NAME;
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files \$uri =404;
        }
        location / {
            proxy_pass http://localhost:3338;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# Create the webroot directory for Certbot
sudo mkdir -p /var/www/certbot

# Stop any existing Nginx container
sudo docker stop nginx-proxy || true
sudo docker rm nginx-proxy || true

# Start Nginx container with HTTP only
sudo docker run -d \
    --name nginx-proxy \
    --network host \
    -v $(pwd)/nginx_http.conf:/etc/nginx/nginx.conf:ro \
    -v /var/www/certbot:/var/www/certbot:ro \
    nginx:latest

# Wait for Nginx to start
sleep 5

# Test Nginx configuration
echo "Testing Nginx configuration..."
curl -I http://$SERVER_NAME/.well-known/acme-challenge/test

# Generate or renew SSL certificate
generate_or_renew_cert "$SERVER_NAME"

# Create final Nginx configuration file with both HTTP and HTTPS
cat << EOF > nginx_https.conf
events {
    worker_connections 1024;
}
http {
    server {
        listen 80;
        server_name $SERVER_NAME;
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files \$uri =404;
        }
        location / {
            return 301 https://\$host\$request_uri;
        }
    }
    server {
        listen 443 ssl;
        server_name $SERVER_NAME;
        ssl_certificate /etc/letsencrypt/live/$SERVER_NAME/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$SERVER_NAME/privkey.pem;
        location / {
            proxy_pass http://localhost:3338;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# Restart Nginx container with HTTPS enabled
sudo docker stop nginx-proxy
sudo docker rm nginx-proxy
sudo docker run -d \
    --name nginx-proxy \
    --network host \
    -v $(pwd)/nginx_https.conf:/etc/nginx/nginx.conf:ro \
    -v /etc/letsencrypt:/etc/letsencrypt:ro \
    -v /var/www/certbot:/var/www/certbot:ro \
    nginx:latest

echo "Nginx proxy server is now running with SSL. Your local service on port 3338 should be accessible via both http://$SERVER_NAME and https://$SERVER_NAME"

# Check if the Nginx container is running
if sudo docker ps | grep -q nginx-proxy; then
    echo "Nginx container is running successfully."
else
    echo "Error: Nginx container failed to start. Checking logs..."
    sudo docker logs nginx-proxy
fi
