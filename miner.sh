#!/bin/bash

export ETH_WALLET=0x7075F17c77597BD1614e86e123335398BEFB48Cc
export WORKER_NAME=miminer

sudo apt-get update

sudo apt-get install ca-certificates curl gnupg lsb-release -y

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io -y

sudo mkdir /root/ethminer

cd ethminer

git submodule update --init --recursive

docker build -t myminer .

docker run --gpus all -e ETH_WALLET -e WORKER_NAME -P -d myminer


