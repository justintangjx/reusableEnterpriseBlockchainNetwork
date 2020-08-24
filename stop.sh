# 
# © Copyright IBM Corporation 2020. All rights reserved.
#

# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1

CHAINCODE_NAME=fabcar

echo "Clearing environment.."
docker-compose -f docker-compose.yml down
docker rm -f $(docker ps -aq)

echo "Removing old chaincode images.."
docker rmi $(docker images | grep example.com-${CHAINCODE_NAME} | tr -s ' ' | cut -d ' ' -f 3)

echo "Deleting storage"
docker volume rm net_prometheus_data net_grafana_storage net_orderer net_peer0_org1 net_peer0_org2 net_couchdb_peer0_org1 net_couchdb_peer0_org2 net_ca_org1 net_ca_org2 net_wallet

echo "Removing dangling volumes.."
docker volume rm $(docker volume ls -qf dangling=true)