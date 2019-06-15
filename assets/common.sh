#!/bin/bash
set -e

setup_kubernetes() {
  payload=$1
  source=$2

  mkdir -p /root/.kube
  kubeconfig_path=$(jq -r '.params.kubeconfig_path // ""' < $payload)
  absolute_kubeconfig_path="${source}/${kubeconfig_path}"
  if [ -f "$absolute_kubeconfig_path" ]; then
    cp "$absolute_kubeconfig_path" "/root/.kube/config"
  else
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

      ca_path="/root/.kube/ca.pem"
      echo "$cluster_ca" | base64 -d > $ca_path
      kubectl config set-cluster default --server=$cluster_url --certificate-authority=$ca_path

      if [ -f "$source/$token_path" ]; then
        kubectl config set-credentials admin --token=$(cat $source/$token_path)
      elif [ ! -z "$token" ]; then
        kubectl config set-credentials admin --token=$token
      else
        mkdir -p /root/.kube
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
  fi

  kubectl version
}

setup_tls() {
  tls_enabled=$(jq -r '.source.tls_enabled // "false"' < $payload)
  tillerless=$(jq -r '.source.tillerless // "false"' < $payload)
  if [ "$tls_enabled" = true ]; then
    if [ "$tillerless" = true ]; then
      echo "Setting both tls_enabled and tillerless is not supported"
      exit 1
    fi

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
  # $1 is the name of the payload file
  # $2 is the name of the source directory
  init_server=$(jq -r '.source.helm_init_server // "false"' < $1)

  # Compute tiller_namespace as follows:
  # If kubeconfig_tiller_namespace is set, then tiller_namespace is the namespace from the kubeconfig
  # If tiller_namespace is set and it is the name of a file, then tiller_namespace is the contents of the file
  # If tiller_namespace is set and it is not the name of a file, then tiller_namespace is the literal
  # Otherwise tiller_namespace defaults to kube-system
  kubeconfig_tiller_namespace=$(jq -r '.source.kubeconfig_tiller_namespace // "false"' <$1)
  if [ "$kubeconfig_tiller_namespace" = "true" ]
  then
    tiller_namespace=$(kubectl config view --minify -ojson | jq -r .contexts[].context.namespace)
  else
    tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)
    if [ "$tiller_namespace" != "kube-system" -a -f "$2/$tiller_namespace" ]
    then
      tiller_namespace=$(cat "$2/$tiller_namespace")
    fi
  fi

  tillerless=$(jq -r '.source.tillerless // "false"' < $payload)
  tls_enabled=$(jq -r '.source.tls_enabled // "false"' < $payload)
  history_max=$(jq -r '.source.helm_history_max // "0"' < $1)
  stable_repo=$(jq -r '.source.stable_repo // ""' < $payload)

  if [ "$tillerless" = true ]; then
    echo "Using tillerless helm"
    helm_bin="helm tiller run ${tiller_namespace} -- helm"
  else
    helm_bin="helm"
  fi

  if [ -n "$stable_repo" ]; then
    echo "Stable Repo URL : ${stable_repo}"
    stable_repo="--stable-repo-url=${stable_repo}"
  fi

  if [ "$init_server" = true ]; then
    if [ "$tillerless" = true ]; then
      echo "Setting both init_server and tillerless is not supported"
      exit 1
    fi
    tiller_service_account=$(jq -r '.source.tiller_service_account // "default"' < $1)

    helm_init_wait=$(jq -r '.source.helm_init_wait // "false"' <$1)
    helm_init_wait_arg=""
    if [ "$helm_init_wait" = "true" ]; then
      helm_init_wait_arg="--wait"
    fi

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
      $helm_bin init --tiller-tls --tiller-tls-cert $tiller_cert_path --tiller-tls-key $tiller_key_path --tiller-tls-verify --tls-ca-cert $tiller_key_path --tiller-namespace=$tiller_namespace --service-account=$tiller_service_account --history-max=$history_max $stable_repo --upgrade $helm_init_wait_arg
    else
      $helm_bin init --tiller-namespace=$tiller_namespace --service-account=$tiller_service_account --history-max=$history_max $stable_repo --upgrade $helm_init_wait_arg
    fi
    wait_for_service_up tiller-deploy 10
  else
    export HELM_HOST=$(jq -r '.source.helm_host // ""' < $1)
    $helm_bin init -c --tiller-namespace $tiller_namespace $stable_repo > /dev/null
  fi

  tls_enabled_arg=""
  if [ "$tls_enabled" = true ]; then
    tls_enabled_arg="--tls"
  fi
  $helm_bin version $tls_enabled_arg --tiller-namespace $tiller_namespace

  helm_setup_purge_all=$(jq -r '.source.helm_setup_purge_all // "false"' <$1)
  if [ "$helm_setup_purge_all" = "true" ]; then
    local release
    for release in $(helm ls -aq --tiller-namespace $tiller_namespace )
    do
      helm delete $tls_enabled_arg --purge "$release" --tiller-namespace $tiller_namespace
    done
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
  plugins=$(jq -c '(try .source.plugins[] catch [][])' < $1)

  kubeconfig_tiller_namespace=$(jq -r '.source.kubeconfig_tiller_namespace // "false"' <$1)
  if [ "$kubeconfig_tiller_namespace" = "true" ]
  then
    tiller_namespace=$(kubectl config view --minify -ojson | jq -r .contexts[].context.namespace)
  else
    tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)
  fi

  local IFS=$'\n'

  for pl in $plugins; do
    plurl=$(echo $pl | jq -cr '.url')
    plversion=$(echo $pl | jq -cr '.version // ""')
    if [ -n "$plversion" ]; then
      plversionflag="--version $plversion"
    fi
    helm plugin install $plurl $plversionflag
  done

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
  tracing_enabled=$(jq -r '.source.tracing_enabled // "false"' < $1)
  if [ "$tracing_enabled" = "true" ]; then
    set -x
  fi

  echo "Initializing kubectl..."
  setup_kubernetes $1 $2
  echo "Initializing helm..."
  setup_tls $1
  setup_helm $1 $2
  setup_repos $1
}
