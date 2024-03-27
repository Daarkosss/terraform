#!/bin/bash

# Before you run this script, run docker-compose and push images to docker hub
# docker tag tic_tac_toe-frontend daarkosss/tic_tac_toe_terraform:frontend
# docker push daarkosss/tic_tac_toe_terraform:frontend
# docker tag tic_tac_toe-backend daarkosss/tic_tac_toe_terraform:backend
# docker push daarkosss/tic_tac_toe_terraform:backend

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

# Run the frontend container
sudo docker run -d --restart unless-stopped -p 3000:80 daarkosss/tic_tac_toe_terraform:frontend
