#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#


# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1

source .env
source utils.sh

CHANNEL_NAME=channel1
CC_NAME=fabcar
CC_PATH="fabcar"
CC_VER=1

echo "Clearing environment.."

if [ -f "docker-compose.yml" ]; then
   docker-compose -f docker-compose.yml down
fi

echo "Removing old chaincode images.."
docker rmi $(docker images | grep example.com-${CC_NAME} | tr -s ' ' | cut -d ' ' -f 3)

# Exit on first error
set -ev

docker-compose -f docker-compose.yml up -d 
sleep 10

# Create the channel
executeAsOrg 1
peer channel create -o $ORDERER_URL --tls --cafile $ORDERER_TLSCA \
  -c $CHANNEL_NAME -f ${GENERATED_FOLDER}/configtx/channel1.tx

# Join peer0.org1.example.com to the channel.
executeAsOrg 1
peer channel join -b channel1.block

# Join peer0.org2.example.com to the channel.
executeAsOrg 2
peer channel join -b channel1.block

# Updating anchor peers 
executeAsOrg 1
peer channel update -o $ORDERER_URL --tls --cafile $ORDERER_TLSCA \
  -c channel1 -f ${GENERATED_FOLDER}/configtx/Org1MSPanchors.tx

# Updating anchor peers 
executeAsOrg 2
peer channel update -o $ORDERER_URL --tls --cafile $ORDERER_TLSCA \
  -c channel1 -f ${GENERATED_FOLDER}/configtx/Org2MSPanchors.tx

# Package chaincode 
GOPATH=$(pwd)/chaincode peer lifecycle chaincode package ${GENERATED_FOLDER}/configtx/${CC_NAME}.tar.gz \
    --label ${CC_NAME}_${CC_VER} --lang golang --path ${CC_PATH}

# Install chaincode in peer0.org1.example.com
executeAsOrg 1
peer lifecycle chaincode install ${GENERATED_FOLDER}/configtx/${CC_NAME}.tar.gz

# Install chaincode in peer0.org2.example.com
executeAsOrg 2
peer lifecycle chaincode install ${GENERATED_FOLDER}/configtx/${CC_NAME}.tar.gz

rm -f pid.txt

# Query installed chaincode
executeAsOrg 1
peer lifecycle chaincode queryinstalled -O json | jq -r ".installed_chaincodes[] | select(.label | contains(\"$CC\")) | .package_id" > pid.txt

CC_PACKAGE_ID=$(cat pid.txt)

# Approve chaincode for Org1MSP
executeAsOrg 1
peer lifecycle chaincode approveformyorg -o $ORDERER_URL \
  --tls true --cafile $ORDERER_TLSCA \
  --channelID $CHANNEL_NAME --name $CC_NAME --version $CC_VER --channel-config-policy "/Channel/Application/Endorsement" \
  --package-id $CC_PACKAGE_ID --sequence 1 --waitForEvent

# Approve chaincode for Org2MSP
executeAsOrg 2
peer lifecycle chaincode approveformyorg -o $ORDERER_URL \
  --tls true --cafile $ORDERER_TLSCA \
  --channelID $CHANNEL_NAME --name $CC_NAME --version $CC_VER --channel-config-policy "/Channel/Application/Endorsement" \
  --package-id $CC_PACKAGE_ID --sequence 1 --waitForEvent

# Check commit readiness
peer lifecycle chaincode checkcommitreadiness \
  --channelID $CHANNEL_NAME --name $CC_NAME --version $CC_VER --channel-config-policy "/Channel/Application/Endorsement" \
  --sequence 1 --output json

# Commit chaincode
peer lifecycle chaincode commit -o $ORDERER_URL \
  --tls true --cafile $ORDERER_TLSCA \
  --peerAddresses localhost:7051 --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -C $CHANNEL_NAME --name $CC_NAME --version $CC_VER --channel-config-policy "/Channel/Application/Endorsement" \
  --sequence 1 --waitForEvent

sleep 2

# Query committed chaincode
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME -O json

# Invoke chaincode
peer chaincode invoke -o $ORDERER_URL \
  --tls true --cafile $ORDERER_TLSCA \
  --peerAddresses localhost:7051 --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -C ${CHANNEL_NAME} -n ${CC_NAME} -c '{"function":"initLedger","Args":[]}' --waitForEvent

# Query chaincode
executeAsOrg 1
peer chaincode query -C ${CHANNEL_NAME} -n ${CC_NAME} -c '{"function":"queryAllCars","Args":[]}'

echo "Done!!"

# # For chaincode1
# # Invoke chaincode
# peer chaincode invoke -o $ORDERER_URL \
#   --tls true --cafile $ORDERER_TLSCA \
#   --peerAddresses localhost:7051 --peerAddresses localhost:9051 \
#   --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
#   --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
#   -C ${CHANNEL_NAME} -n ${CC_NAME} -c '{"function":"put","Args":["z","5"]}' --waitForEvent

# # Query chaincode
# executeAsOrg 1
# peer chaincode query -C ${CHANNEL_NAME} -n ${CC_NAME} -c '{"function":"query","Args":["z"]}'

# # For marbles02
# # Invoke chaincode
# peer chaincode invoke -o $ORDERER_URL \
#   --tls true --cafile $ORDERER_TLSCA \
#   --peerAddresses localhost:7051 --peerAddresses localhost:9051 \
#   --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
#   --tlsRootCertFiles ${CRYPTO}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
#   -C ${CHANNEL_NAME} -n ${CC_NAME} -c '{"function":"initMarble","Args":["marble2","blue","100","khawei"]}' --waitForEvent

# # Query chaincode
# executeAsOrg 1
# peer chaincode query -C ${CHANNEL_NAME} -n ${CC_NAME} -c '{"function":"readMarble","Args":["marble2"]}'