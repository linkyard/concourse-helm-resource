#!/bin/bash
set -e

setup_kubernetes() {
  payload=$1
  source=$2
  # Setup kubectl
  cluster_url=$(jq -r '.source.cluster_url // ""' < $payload)
  if [ -z "$cluster_url" ]; then
    echo "invalid payload (missing cluster_url)"
    exit 1
  fi
  if [[ "$cluster_url" =~ https.* ]]; then

    cluster_ca=$(jq -r '.source.cluster_ca // ""' < $payload)
    admin_key=$(jq -r '.source.admin_key // ""' < $payload)
    admin_cert=$(jq -r '.source.admin_cert // ""' < $payload)
    token=$(jq -r '.source.token // ""' < $payload)
    token_path=$(jq -r '.params.token_path // ""' < $payload)

    mkdir -p /root/.kube

    ca_path="/root/.kube/ca.pem"
    echo "$cluster_ca" | base64 -d > $ca_path
    kubectl config set-cluster default --server=$cluster_url --certificate-authority=$ca_path

    if [ -f "$source/$token_path" ]; then
      kubectl config set-credentials admin --token=$(cat $source/$token_path)
    elif [ ! -z "$token" ]; then
      kubectl config set-credentials admin --token=$token
    else
      key_path="/root/.kube/key.pem"
      cert_path="/root/.kube/cert.pem"
      echo "$admin_key" | base64 -d > $key_path
      echo "$admin_cert" | base64 -d > $cert_path
      kubectl config set-credentials admin --client-certificate=$cert_path --client-key=$key_path
    fi

    kubectl config set-context default --cluster=default --user=admin
  else
    kubectl config set-cluster default --server=$cluster_url
    kubectl config set-context default --cluster=default
  fi

  kubectl config use-context default
  kubectl cluster-info
}

setup_helm() {
  helm init -c > /dev/nulll
  helm version
}

setup_repos() {
  repos=$(jq -r '(try .source.repos[] catch [][]) | (.name+" "+.url)' < $1)

  IFS=$'\n'
  for r in $repos; do
    name=$(echo $r | cut -f1 -d' ')
    url=$(echo $r | cut -f2 -d' ')
    echo Installing helm repository $name $url
    helm repo add $name $urn
  done
}

setup_resource() {
  echo "Initializing kubectl..."
  setup_kubernetes $1 $2
  echo "Initializing helm..."
  setup_helm
  setup_repos $1
}
