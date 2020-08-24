#!/bin/bash

export PATH=$PWD/bin:$PATH

if ! [ -x "$(command -v peer)" ]; then
  echo 'Error: peer is not installed.' >&2
  exit 1
fi

echo "Good to Go!!"

# Set environment variables for the peer org
function executeAsOrg() {
  USING_ORG=$1

  export CRYPTO=${ROOT_FOLDER}/${GENERATED_FOLDER}/crypto-config
  export ORDERER_URL=localhost:7050
  export ORDERER_TLSCA=${CRYPTO}/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

  if [ $USING_ORG -eq 1 ]; then
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE=${CRYPTO}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${CRYPTO}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
  elif [ $USING_ORG -eq 2 ]; then
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_TLS_ROOTCERT_FILE=${CRYPTO}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${CRYPTO}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
  else
    echo "================== ERROR !!! ORG Unknown =================="
  fi
}