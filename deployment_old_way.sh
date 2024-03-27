#!/bin/bash

# Install and configure docker on the ec2 instance
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo systemctl enable docker

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose


PUBLIC_DNS=$(terraform output -raw container_url)
export REACT_APP_BACKEND_HOST=$PUBLIC_DNS
export REACT_APP_BACKEND_PORT=8080

# Zdefiniuj zmienne z adresami repozytoriów
FRONTEND_REPO="https://github.com/Daarkosss/tic_tac_toe_frontend/archive/refs/heads/change-styling.zip"
BACKEND_REPO="https://github.com/Daarkosss/tic_tac_toe_backend/archive/refs/heads/master.zip"

# # Go to directory with docker-compose.yml
# cd /home/ec2-user/

# Clone frontend and backend repositories
curl -L $FRONTEND_REPO -o tic_tac_toe_frontend.zip
curl -L $BACKEND_REPO -o tic_tac_toe_backend.zip

unzip tic_tac_toe_frontend.zip
unzip tic_tac_toe_backend.zip

mv tic_tac_toe_frontend-change-styling tic_tac_toe_frontend
mv tic_tac_toe_backend-master tic_tac_toe_backend

# Add user to docker group
sudo usermod -aG docker $USER

# log out and log back in for the changes to take effect
newgrp docker

# Run container
docker-compose up --build -d
