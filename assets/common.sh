#!/bin/bash
set -e

generate_aws_kubeconfig() {
  # Optional. Use the AWS EKS authenticator
  local use_aws_iam_authenticator
  use_aws_iam_authenticator="$(jq -r '.source.use_aws_iam_authenticator // ""' < "$payload")"
  local aws_eks_cluster_name
  aws_eks_cluster_name="$(jq -r '.source.aws_eks_cluster_name // ""' < "$payload")"
  if [[ "$use_aws_iam_authenticator" == "true" ]]; then
    if [ -z "$aws_eks_cluster_name" ]; then
      echo 'You must specify aws_eks_cluster_name when using aws_iam_authenticator.'
      exit 1
    fi
    local kubeconfig_file_aws
    kubeconfig_file_aws="$(mktemp "$TMPDIR/kubernetes-resource-kubeconfig-aws.XXXXXX")"
    cat <<EOF > "$kubeconfig_file_aws"
users:
- name: admin
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - token
      - -i
      - ${aws_eks_cluster_name}
      command: aws-iam-authenticator
      env: null
EOF
    # Merge two kubeconfig files
    local tmpfile
    tmpfile="$(mktemp)"
    local kubeconfig_file
    kubeconfig_file="/root/.kube/config"
    #kubectl config view --flatten > "$tmpfile"
    KUBECONFIG="$kubeconfig_file:$kubeconfig_file_aws" kubectl config view --flatten > "$tmpfile"

    #remove old user data before merging
    kubectl config unset users

    cat "$tmpfile" > $kubeconfig_file
  fi
}

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
    use_aws_iam_authenticator="$(jq -r '.source.use_aws_iam_authenticator // ""' < "$payload")"


    mkdir -p /root/.kube

    ca_path="/root/.kube/ca.pem"
    echo "$cluster_ca" | base64 -d > $ca_path
    kubectl config set-cluster default --server=$cluster_url --certificate-authority=$ca_path
    if [ -f "$source/$token_path" ]; then
      kubectl config set-credentials admin --token=$(cat $source/$token_path)
    elif [ ! -z "$token" ]; then
      kubectl config set-credentials admin --token=$token
    elif [ ! -z "$use_aws_iam_authenticator" ]; then
      generate_aws_kubeconfig
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
  kubectl version
}

setup_tls() {
  tls_enabled=$(jq -r '.source.tls_enabled // "false"' < $payload)
  if [ "$tls_enabled" = true ]; then
    helm_ca=$(jq -r '.source.helm_ca // ""' < $payload)
    helm_key=$(jq -r '.source.helm_key // ""' < $payload)
    helm_cert=$(jq -r '.source.helm_cert // ""' < $payload)
    if [ -z "$helm_ca" ]; then
      echo "invalid payload (missing helm_ca)"
      exit 1
    fi
    if [ -z "$helm_key" ]; then
      echo "invalid payload (missing helm_key)"
      exit 1
    fi
    if [ -z "$helm_cert" ]; then
      echo "invalid payload (missing helm_cert)"
      exit 1
    fi
    helm_ca_cert_path="/root/.helm/ca.pem"
    helm_key_path="/root/.helm/key.pem"
    helm_cert_path="/root/.helm/cert.pem"
    echo "$helm_ca" > $helm_ca_cert_path
    echo "$helm_key" > $helm_key_path
    echo "$helm_cert" > $helm_cert_path
  fi
}

setup_helm() {
  init_server=$(jq -r '.source.helm_init_server // "false"' < $1)
  tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)
  tls_enabled=$(jq -r '.source.tls_enabled // "false"' < $payload)
  history_max=$(jq -r '.source.helm_history_max // "0"' < $1)
  if [ "$init_server" = true ]; then
    tiller_service_account=$(jq -r '.source.tiller_service_account // "default"' < $1)
    if [ "$tls_enabled" = true ]; then
      tiller_key=$(jq -r '.source.tiller_key // ""' < $payload)
      tiller_cert=$(jq -r '.source.tiller_cert // ""' < $payload)
      if [ -z "$tiller_key" ]; then
        echo "invalid payload (missing tiller_key)"
        exit 1
      fi
      if [ -z "$tiller_cert" ]; then
        echo "invalid payload (missing tiller_cert)"
        exit 1
      fi
      tiller_key_path="/root/.helm/tiller_key.pem"
      tiller_cert_path="/root/.helm/tiller_cert.pem"
      helm_ca_cert_path="/root/.helm/ca.pem"
      echo "$tiller_key" > $tiller_key_path
      echo "$tiller_cert" > $tiller_cert_path
      helm init --tiller-tls --tiller-tls-cert $tiller_cert_path --tiller-tls-key $tiller_key_path --tiller-tls-verify --tls-ca-cert $tiller_key_path --tiller-namespace=$tiller_namespace --service-account=$tiller_service_account --history-max=$history_max --upgrade
    else
      helm init --tiller-namespace=$tiller_namespace --service-account=$tiller_service_account --history-max=$history_max --upgrade
    fi
    wait_for_service_up tiller-deploy 10
  else
    export HELM_HOST=$(jq -r '.source.helm_host // ""' < $1)
    helm init -c --tiller-namespace $tiller_namespace > /dev/null
  fi
  if [ "$tls_enabled" = true ]; then
    helm version --tls --tiller-namespace $tiller_namespace
  else
    helm version --tiller-namespace $tiller_namespace
  fi
}

wait_for_service_up() {
  SERVICE=$1
  TIMEOUT=$2
  if [ "$TIMEOUT" -le "0" ]; then
    echo "Service $SERVICE was not ready in time"
    exit 1
  fi
  RESULT=`kubectl get endpoints --namespace=$tiller_namespace $SERVICE -o jsonpath={.subsets[].addresses[].targetRef.name} 2> /dev/null || true`
  if [ -z "$RESULT" ]; then
    sleep 1
    wait_for_service_up $SERVICE $((--TIMEOUT))
  fi
}

setup_repos() {
  repos=$(jq -c '(try .source.repos[] catch [][])' < $1)
  tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)

  local IFS=$'\n'
  for r in $repos; do
    name=$(echo $r | jq -r '.name')
    url=$(echo $r | jq -r '.url')
    username=$(echo $r | jq -r '.username // ""')
    password=$(echo $r | jq -r '.password // ""')

    echo Installing helm repository $name $url
    if [[ -n "$username" && -n "$password" ]]; then
      helm repo add $name $url --tiller-namespace $tiller_namespace --username $username --password $password
    else
      helm repo add $name $url --tiller-namespace $tiller_namespace
    fi
  done

  helm repo update
}

setup_resource() {
  echo "Initializing kubectl..."
  setup_kubernetes $1 $2
  echo "Initializing helm..."
  setup_tls $1
  setup_helm $1
  setup_repos $1
}
