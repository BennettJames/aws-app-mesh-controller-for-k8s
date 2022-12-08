#!/usr/bin/env bash

set -eo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
ROOT_DIR="$SCRIPTS_DIR/.."
INT_TEST_DIR="$ROOT_DIR/test/integration"

source "$SCRIPTS_DIR/lib/aws.sh"
source "$SCRIPTS_DIR/lib/common.sh"
source "$SCRIPTS_DIR/lib/k8s.sh"

check_is_installed curl
check_is_installed docker
check_is_installed jq
check_is_installed uuidgen
check_is_installed wget
check_is_installed kind "You can install kind with the helper scripts/install-kind.sh"
check_is_installed kubectl "You can install kubectl with the helper scripts/install-kubectl.sh"
check_is_installed kustomize "You can install kustomize with the helper scripts/install-kustomize.sh"
check_is_installed controller-gen "You can install controller-gen with the helper scripts/install-controller-gen.sh"

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "Found no set '\$AWS_ACCOUNT_ID', trying to read from environment..."
  AWS_ACCOUNT_ID=$( aws_account_id )
fi
AWS_REGION="${AWS_REGION:-"us-west-2"}"

if [[ -z "$VPC_ID" ]]; then
  echo "Found no set '\$VPC_ID', trying to read from environment..."
  VPC_ID="$( vpc_id )"
fi

if [[ -z "$ADA_ROLE" ]]; then
  echo "Must set '\$ADA_ROLE' to an available aws role for ada to use" 1>&2
  exit 1
fi

#
# "INTEG_TESTS" is an optional control of which integration suites are run.
#
# Example: 'INTEG_TEST="test/integration/mesh test/integration/virtualnode" ./
#
if [[ -z "$INTEG_TESTS" ]]; then
  INTEG_TESTS="$(ls -d "$ROOT_DIR/test/integration/*")"
fi

IMAGE_NAME="amazon/appmesh-controller"
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
CONTROLLER_IMAGE="${ECR_URL}/${IMAGE_NAME}"
CONTROLLER_TAG="local"

ENVOY_IMAGE_URL="public.ecr.aws/appmesh/aws-appmesh-envoy"
ENVOY_LATEST_TAG="v1.24.0.0-prod"
ENVOY_1_22_TAG="v1.22.2.0-prod"

PROXY_ROUTE_URL="840364872350.dkr.ecr.us-west-2.amazonaws.com"
PROXY_ROUTE_IMAGE="${PROXY_ROUTE_URL}/aws-appmesh-proxy-route-manager"
PROXY_ROUTE_TAG="v6-prod"

CLUSTER_NAME=""
K8S_VERSION="1.17"
TMP_DIR=""

function setup_kind_cluster {
    local __test_id=$(uuidgen | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')
    local __cluster_base_name=$(uuidgen | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')
    CLUSTER_NAME="appmesh-test-$__cluster_base_name"-"${__test_id}"
    TMP_DIR=$ROOT_DIR/build/tmp-$CLUSTER_NAME
    $SCRIPTS_DIR/provision-kind-cluster.sh "${CLUSTER_NAME}" -v "${K8S_VERSION}"
}

function install_crds {
    echo "installing CRDs ... "
    make install
    echo "ok."
}

function build_and_load_images {
  docker build --build-arg GOPROXY="$GOPROXY" -t "$CONTROLLER_IMAGE:$CONTROLLER_TAG" .
  kind load docker-image --name "$CLUSTER_NAME" "$CONTROLLER_IMAGE:$CONTROLLER_TAG"

  ecr_login "$AWS_REGION" "$ECR_URL"
  ecr_login "$AWS_REGION" "$PROXY_ROUTE_URL"

  local __images=(
      "$PROXY_ROUTE_IMAGE:$PROXY_ROUTE_TAG"
      "$ENVOY_IMAGE_URL:$ENVOY_LATEST_TAG"
      "$ENVOY_IMAGE_URL:$ENVOY_1_22_TAG"
  )
  for image in "${__images[@]}"; do
      docker pull "$image"
      kind load docker-image --name "$CLUSTER_NAME" "$image"
  done
}

function run_integration_tests {
  echo running tests

  kubectl create ns appmesh-system

  # fixme [bs]: using ada is too inflexible as it's an internal tool. Need to decide
  # on a more general system to generate and inject credentials.
  local __creds="$(ada credentials print --account="$AWS_ACCOUNT_ID" --provider isengard --role $ADA_ROLE)"
  local __access_key="$(echo $__creds | jq -r .AccessKeyId)"
  local __secret_access_key="$(echo $__creds | jq -r .SecretAccessKey)"
  local __session_token="$(echo $__creds | jq -r .SessionToken)"

  for __test_dir in ${INTEG_TESTS[@]}; do
    local __test="$(basename $__test_dir)"

    # /test_app contains test app images, and is not itself an integration test
    if [[ "$__test" == "test_app" ]]; then
      continue
    fi

    local __envoy_version="$ENVOY_LATEST_TAG"

    # This test specifically tests behavior for an older version of envoy
    if [[ "$__test" == "sidecar-v1.22" ]]; then
        __envoy_version="$ENVOY_1_22_TAG"
    fi

    # Try to delete the controller. Sometimes, carrying over controllers
    # between tests can cause some minor issues.
    helm delete -n=appmesh-system appmesh-controller || :
    # sleep 15 # todo: see if this can be reduced or eliminated

    helm upgrade -i appmesh-controller config/helm/appmesh-controller --namespace appmesh-system \
      --set image.repository="$CONTROLLER_IMAGE" \
      --set image.tag="$CONTROLLER_TAG" \
      --set sidecar.image.repository="$ENVOY_IMAGE_URL" \
      --set sidecar.image.tag="$__envoy_version" \
      --set enableBackendGroups=true \
      --set sidecar.waitUntilProxyReady=true \
      --set region="$AWS_REGION" \
      --set accountId="$AWS_ACCOUNT_ID" \
      --set "env.AWS_DEFAULT_REGION='$AWS_REGION'" \
      --set "env.AWS_ACCESS_KEY_ID='$__access_key'" \
      --set "env.AWS_SECRET_ACCESS_KEY='$__secret_access_key'" \
      --set "env.AWS_SESSION_TOKEN='$__session_token'"
    check_deployment_rollout appmesh-controller appmesh-system
    kubectl get pod -n appmesh-system

    echo -n "running integration test type $__test ... "
    ginkgo -v -r $__test_dir -- \
      --cluster-kubeconfig="$KUBECONFIG" \
      --cluster-name="$CLUSTER_NAME" \
      --aws-region="$AWS_REGION" \
      --aws-vpc-id="$VPC_ID"
    echo "ok."
  done
}

function clean_up {
  # todo [bs]: verify if this works, and if not fix or remove it
  if [ -v "$TMP_DIR" ]; then
    "$SCRIPTS_DIR"/delete-kind-cluster.sh -c "$TMP_DIR" || :
  fi
  return
}

trap "clean_up" EXIT

# ques [bs]: do I even want functions here? Arguably they muddle the control
# flow, as they set globals. Having a strict top-to-bottom flow that is well
# annotated with comments and makes use of common, external functions may be
# better.

# todo [bs]: I'd like to remove this in favor of having the same credentials for
# pulling and using images.
aws_check_credentials

# todo [bs]: let's allow the user to inject a cluster and config
#
# A related hypothetical: let's say the option _just_ requires the config file.
# Would it be possible to then sniff the cluster name from the config?

setup_kind_cluster
export KUBECONFIG="$TMP_DIR/kubeconfig"

build_and_load_images

# Generate and install CRDs
install_crds
kubectl get crds

run_integration_tests
