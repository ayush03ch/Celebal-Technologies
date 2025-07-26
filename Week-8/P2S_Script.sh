# Resource Group Name: P2S-RG
# Location: Central India
az group create --name P2S-RG --location "Central India"


# Virtual Network for P2S VPN
az network vnet create \
  --name P2S-VNet \
  --resource-group P2S-RG \
  --location centralindia \
  --address-prefix 10.1.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.1.0.0/24



# Add a Gateway Subnet to the Virtual Network
az network vnet subnet create \
  --resource-group P2S-RG \
  --vnet-name P2S-VNet \
  --name GatewaySubnet \
  --address-prefix 10.1.255.0/27


# Create Public IP for the VPN Gateway
az network public-ip create \
  --resource-group P2S-RG \
  --name P2S-Gateway-PIP \
  --allocation-method Dynamic \
  --sku Standard \
  --location centralindia

# Create the VPN Gateway
az network vnet-gateway create \
  --resource-group P2S-RG \
  --name P2S-Gateway \
  --public-ip-addresses P2S-Gateway-PIP \
  --vnet P2S-VNet \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw1 \
  --location centralindia

