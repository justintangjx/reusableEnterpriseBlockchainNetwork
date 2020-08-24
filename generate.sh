#!/bin/sh
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}

CHANNEL_NAME=channel1
GENERATED_FOLDER=generated

# create the GENERATED_FOLDER
if [ -d $GENERATED_FOLDER ]; then 

    # ask to confirm to clear it 
    read -p "Folder ${GENERATED_FOLDER} exists. Clear ? (Y to continue): " S_CONTINUE
    if [[ "${S_CONTINUE:-Y}" =~ ^[Yy]$ ]]; then

        # remove previous crypto material and config transactions
        rm -fr $GENERATED_FOLDER
        mkdir -p $GENERATED_FOLDER/configtx
    else 
        exit 1
    fi
else
    # create the folder
    mkdir -p $GENERATED_FOLDER
    mkdir -p $GENERATED_FOLDER/configtx
fi

# TODO: put a version check on cryptogen and configtxgen

# generate crypto material
cryptogen generate --config=./crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

# generate genesis block for orderer
configtxgen -profile TwoOrgsOrdererGenesis -outputBlock ./$GENERATED_FOLDER/configtx/genesis.block -channelID testchainid
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# generate channel configuration transaction
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./$GENERATED_FOLDER/configtx/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel configuration transaction..."
  exit 1
fi

configtxgen -profile TwoOrgsChannel \
    -outputAnchorPeersUpdate ./$GENERATED_FOLDER/configtx/Org1MSPanchors.tx \
    -channelID $CHANNEL_NAME -asOrg Org1MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org1..."
  exit 1
fi

configtxgen -profile TwoOrgsChannel \
    -outputAnchorPeersUpdate ./$GENERATED_FOLDER/configtx/Org2MSPanchors.tx \
    -channelID $CHANNEL_NAME -asOrg Org2MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org2..."
  exit 1
fi

mv crypto-config ./$GENERATED_FOLDER/

rm -f .env

echo "GENERATED_FOLDER=$GENERATED_FOLDER" >> .env
echo "\nCOMPOSE_PROJECT_NAME=net" >> .env
echo "\nROOT_FOLDER=$(PWD)" >> .env

# Rename key files to key.pem
for file in $(find ./$GENERATED_FOLDER/crypto-config/ -iname *_sk); do dir=$(dirname $file); mv ${dir}/*_sk ${dir}/key.pem; done
