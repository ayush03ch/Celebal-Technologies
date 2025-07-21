#!/bin/bash

# Azure Load Balancer Setup Script with External + Internal LB and SSH Key Authentication

# ---------- CONFIG ----------
RG="LoadBalancerRG"
LOC="eastus"
VNET="LBVNet"
SUBNET="LBSubnet"
VM_SIZE="Standard_B1s"
USERNAME="azureuser"
IMAGE="Ubuntu2204"
ILB_PRIVATE_IP="10.0.0.100"
SSH_KEY_PATH="$HOME/.ssh/lb_vm_key.pub"

# ---------- CREATE RG & NETWORK ----------
az group create --name $RG --location $LOC

az network vnet create \
  --resource-group $RG \
  --name $VNET \
  --subnet-name $SUBNET

# ---------- CREATE 2 VMs ----------
for i in 1 2; do
  az vm create \
    --resource-group $RG \
    --name VM$i \
    --vnet-name $VNET \
    --subnet $SUBNET \
    --image $IMAGE \
    --admin-username $USERNAME \
    --ssh-key-values $SSH_KEY_PATH \
    --size $VM_SIZE \
    --public-ip-sku Standard \
    --nsg-rule SSH
done

# ---------- INSTALL NGINX & HTML ----------
for i in 1 2; do
  az vm run-command invoke \
    --resource-group $RG \
    --name VM$i \
    --command-id RunShellScript \
    --scripts "sudo apt update && sudo apt install -y nginx && echo 'This is VM$i' | sudo tee /var/www/html/index.html"
done

# ---------- PUBLIC IP FOR EXTERNAL LB ----------
az network public-ip create \
  --resource-group $RG \
  --name PublicLBIP \
  --sku Standard \
  --allocation-method Static

# ---------- CREATE EXTERNAL LB ----------
az network lb create \
  --resource-group $RG \
  --name ExternalLB \
  --sku Standard \
  --frontend-ip-name PublicFrontend \
  --backend-pool-name BackendPoolExt \
  --public-ip-address PublicLBIP

# ---------- CREATE INTERNAL LB ----------
az network lb create \
  --resource-group $RG \
  --name InternalLB \
  --sku Standard \
  --frontend-ip-name InternalFrontend \
  --backend-pool-name BackendPoolInt \
  --vnet-name $VNET \
  --subnet $SUBNET \
  --private-ip-address $ILB_PRIVATE_IP

# ---------- HEALTH PROBES ----------
az network lb probe create \
  --resource-group $RG \
  --lb-name ExternalLB \
  --name HealthProbeExt \
  --protocol tcp \
  --port 80

az network lb probe create \
  --resource-group $RG \
  --lb-name InternalLB \
  --name HealthProbeInt \
  --protocol tcp \
  --port 80

# ---------- LB RULES ----------
az network lb rule create \
  --resource-group $RG \
  --lb-name ExternalLB \
  --name HTTPRule \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name PublicFrontend \
  --backend-pool-name BackendPoolExt \
  --probe-name HealthProbeExt

az network lb rule create \
  --resource-group $RG \
  --lb-name InternalLB \
  --name ILBRule \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name InternalFrontend \
  --backend-pool-name BackendPoolInt \
  --probe-name HealthProbeInt

# ---------- ATTACH VMs TO BACKEND POOLS ----------
for i in 1 2; do
  NIC=$(az vm show --resource-group $RG --name VM$i --query "networkProfile.networkInterfaces[0].id" -o tsv | awk -F/ '{print $NF}')

  az network nic ip-config address-pool add \
    --resource-group $RG \
    --nic-name $NIC \
    --ip-config-name ipconfig1 \
    --lb-name ExternalLB \
    --address-pool BackendPoolExt

  az network nic ip-config address-pool add \
    --resource-group $RG \
    --nic-name $NIC \
    --ip-config-name ipconfig1 \
    --lb-name InternalLB \
    --address-pool BackendPoolInt
done

# ---------- OUTPUT ----------
echo -e "\nSetup complete."

echo -n "External LB Public IP: "
az network public-ip show \
  --resource-group $RG \
  --name PublicLBIP \
  --query ipAddress \
  --output tsv

echo -e "\nInternal LB IP: $ILB_PRIVATE_IP (test via curl inside VMs)"
