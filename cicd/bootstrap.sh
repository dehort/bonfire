#!/bin/bash

set -e

# check that unit_test.sh complies w/ best practices
URL="https://github.com/RedHatInsights/bonfire/tree/master/cicd/examples"
if test -f unit_test.sh; then
  if grep 'exit $result' unit_test.sh; then
    echo "----------------------------"
    echo "ERROR: unit_test.sh is calling 'exit' improperly, refer to examples at $URL"
    echo "----------------------------"
    exit 1
  fi
fi

export APP_ROOT=$(pwd)
export WORKSPACE=${WORKSPACE:-$APP_ROOT}  # if running in jenkins, use the build's workspace
export BONFIRE_ROOT=${WORKSPACE}/bonfire
export CICD_ROOT=${BONFIRE_ROOT}/cicd
export IMAGE_TAG=$(git rev-parse --short=7 HEAD)
export BONFIRE_BOT="true"
export BONFIRE_NS_REQUESTER="${JOB_NAME}-${BUILD_NUMBER}"

set -x
# Set up docker cfg
export DOCKER_CONF="$WORKSPACE/.docker"
rm -fr $DOCKER_CONF
mkdir $DOCKER_CONF

# Set up podman cfg
AUTH_CONF_DIR="$WORKSPACE/.podman"
rm -fr $AUTH_CONF_DIR
mkdir $AUTH_CONF_DIR
export REGISTRY_AUTH_FILE="$AUTH_CONF_DIR/auth.json"

# Set up kube cfg
export KUBECONFIG_DIR="$WORKSPACE/.kube"
export KUBECONFIG="$KUBECONFIG_DIR/config"
rm -fr $KUBECONFIG_DIR
mkdir $KUBECONFIG_DIR
set +x

# if this is a PR, use a different tag, since PR tags expire
if [ ! -z "$ghprbPullId" ]; then
  export IMAGE_TAG="pr-${ghprbPullId}-${IMAGE_TAG}"
fi

if [ ! -z "$gitlabMergeRequestIid" ]; then
  export IMAGE_TAG="pr-${gitlabMergeRequestIid}-${IMAGE_TAG}"
fi


export GIT_COMMIT=$(git rev-parse HEAD)
export ARTIFACTS_DIR="$WORKSPACE/artifacts"

rm -fr $ARTIFACTS_DIR && mkdir -p $ARTIFACTS_DIR

# TODO: create custom jenkins agent image that has a lot of this stuff pre-installed
export LANG=en_US.utf-8
export LC_ALL=en_US.utf-8

python3 -m venv .bonfire_venv
source .bonfire_venv/bin/activate

pip install --upgrade pip 'setuptools<58' wheel
pip install --upgrade 'crc-bonfire>=3.6.1'

# clone repo to download cicd scripts
rm -fr $BONFIRE_ROOT
git clone --branch master https://github.com/RedHatInsights/bonfire.git $BONFIRE_ROOT

# Gives access to helper commands such as "oc_wrapper"
export PATH=$PATH:${CICD_ROOT}/bin

# log in to ephemeral cluster
oc_wrapper login --token=$OC_LOGIN_TOKEN --server=$OC_LOGIN_SERVER
