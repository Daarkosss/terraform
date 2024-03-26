#!/bin/bash

# Install and configure docker on the ec2 instance
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo systemctl enable docker


# Login to your docker hub account
cat ./docker_password.txt | sudo docker login --username daarkosss --password-stdin

# Pull the docker backend image
sudo docker pull daarkosss/tic_tac_toe_terraform:backend

# Pull the docker frontend image
sudo docker pull daarkosss/tic_tac_toe_terraform:frontend

# Run the backend container
sudo docker run -d --restart unless-stopped -p 8080:8080 daarkosss/tic_tac_toe_terraform:backend

# Ensure the backend is fully started before starting the frontend
sleep 10

PUBLIC_DNS=$(terraform output -raw container_url)
export REACT_APP_BACKEND_HOST=$PUBLIC_DNS
export REACT_APP_BACKEND_PORT=8080

# Run the frontend container
sudo docker run -d -e REACT_APP_BACKEND_HOST="$REACT_APP_BACKEND_HOST" -e REACT_APP_BACKEND_PORT="$REACT_APP_BACKEND_PORT" -p 3000:80 daarkosss/tic_tac_toe_terraform:frontend
