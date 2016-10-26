#!/bin/bash -e
echo "Hello this is the prepare script of continuous_integration";

if [[ "$DEBIAN_FRONTEND" != noninteractive ]] ;then
  echo "DEBIAN_FRONTEND=$DEBIAN_FRONTEND instead of noninteractive!" >&2
  exit -1
fi

sudo apt-get install git
