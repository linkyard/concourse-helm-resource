# Helm & Helmfile Resource for Concourse

Deploy to [Kubernetes Helm](https://github.com/kubernetes/helm) from [Concourse](https://concourse.ci/).

## Installing

Add the resource type to your pipeline:

```yaml
resource_types:
- name: helmfile
  type: docker-image
  source:
    repository: quoinedev/concourse-helmfile-resource
```

## Source Configuration

* `cluster_url`: *Optional.* URL to Kubernetes Master API service. Do not set when using the `kubeconfig_path` parameter, otherwise required.
* `cluster_ca`: *Optional.* Base64 encoded PEM. Required if `cluster_url` is https.
* `token`: *Optional.* Bearer token for Kubernetes.  This, 'token_path' or `admin_key`/`admin_cert` are required if `cluster_url` is https.
* `token_path`: *Optional.* Path to file containing the bearer token for Kubernetes.  This, 'token' or `admin_key`/`admin_cert` are required if `cluster_url` is https.
* `admin_key`: *Optional.* Base64 encoded PEM. Required if `cluster_url` is https and no `token` or 'token_path' is provided.
* `admin_cert`: *Optional.* Base64 encoded PEM. Required if `cluster_url` is https and no `token` or 'token_path' is provided.
* `release`: *Optional.* Name of the release (not a file, a string). (Default: autogenerated by helm)
* `namespace`: *Optional.* Kubernetes namespace the chart will be installed into. (Default: default)
* `tillerless`: *Optional.* Set to true to use tiller-less mode (Default: false). See <https://rimusz.net/tillerless-helm/>.
* `tillerless_silent`: *Optional.* Set to `true` to make tiller-less mode silent (Default: true). Activating tillerless helm without making it silent **will make credentials to leak in the build output** when using `override_values` parameter with `hide: true`.
* `helm_init_server`: *Optional.* Installs helm into the cluster if not already installed. (Default: false). Not supported when using tillerless.
* `tiller_namespace`: *Optional.* Kubernetes namespace where tiller is running (or will be installed to). (Default: kube-system)
* `tiller_cert`: *Optional* Certificate for Tiller (only applies if tls_enabled and helm_init_server are true).
* `tiller_key`: *Optional* Key created for Tiller when doing a secure Tiller install (only applies if tls_enabled and helm_init_server are true).
* `tiller_service_account`: *Optional* Name of the service account that tiller will use (only applies if helm_init_server is true).
* `helm_ca`: *Optional* Private CA that is used to issue certificates for Tiller clients and servers (only applies if tls_enabled is true).
* `helm_cert`: *Optional* Certificate for Client (only applies if tls_enabled is true).
* `helm_key`: *Optional* Key created for Client when doing a secure Tiller install (only applies if tls_enabled is true).
* `tls_enabled`: *Optional* Uses TLS for all interactions with Tiller. (Default: false). Not supported when using tillerless.
* `helm_history_max`: *Optional.* Limits the maximum number of revisions. (Default: 0 = no limit)
* `helm_host`: *Optional* Address of Tiller. Skips helm discovery process. (only applies if `helm_init_server` is false).
* `repos`: *Optional.* Array of Helm repositories to initialize, each repository is defined as an object with properties `name`, `url` (required) username and password (optional).
* `plugins`: *Optional.* Array of Helm plugins to install, each defined as an object with properties `url` (required), `version` (optional).
* `stable_repo`: *Optional* Override default Helm stable repo <https://kubernetes-charts.storage.googleapis.com>. Useful if running helm deploys without internet access.
* `kubeconfig_namespace`: *Optional.* Use the kubeconfig context namespace as the helm namespace. (Default: false)
* `kubeconfig_tiller_namespace`: *Optional.* Use the kubeconfig context namespace as the tiller namespace. (Default: false)
* `tracing_enabled`: *Optional.* Enable extremely verbose tracing for this resource. Useful when developing the resource itself. May allow secrets to be displayed. (Default: false)
* `helm_init_wait`: *Optional.* When initializing the helm server, use the `--wait` option. (Default: false)
* `helm_setup_purge_all`: *Optional.* Delete and purge every helm release. Use with extreme caution. (Default: false)

*For Helmfile*

* `helmfile`: *Optional.* The helmfile.yaml. If this param is specified, helmfile will execute instead.
* `dir`: *Optional.* The dir name of where the helmfile is.
* `environment`: *Optional.* Helmfile environment name.
* `state_values_file`: *Optional.* Helmfile --state-value-file option.
* `state_values_set`: *Optional.* Helmfile --state-values-set option.
* `selector`: *Optional.* Helmfile --selector option.
* `env_vars`: *Optional.* Container Environment variables to be set before executing helmfile command.

## Behavior

### `check`: Check for new releases

Any new revisions to the release are returned, no matter their current state. The release and cluster url must be specified in the
source for `check` to work.

### `in`: Not Supported

### `out`: Deploy the helm chart

Deploys a Helm chart onto the Kubernetes cluster. Tiller must be already installed
on the cluster.

#### Parameters

* `chart`: *Required.* Either the file containing the helm chart to deploy (ends with .tgz), the path to a local directory containing the chart or the name of the chart from a repo (e.g. `stable/mysql`).
* `namespace`: *Optional.* Either a file containing the name of the namespace or the name of the namespace. (Default: taken from source configuration).
* `release`: *Optional.* Either a file containing the name of the release or the name of the release. (Default: taken from source configuration).
* `values`: *Optional.* File containing the values.yaml for the deployment. Supports setting multiple value files using an array.
* `override_values`: *Optional.* Array of values that can override those defined in values.yaml. Each entry in
  the array is a map containing a key and a value or path. Value is set directly while path reads the contents of
  the file in that path. A `hide: true` parameter ensures that the value is not logged and instead replaced with `***HIDDEN***`.
  A `type: string` parameter makes sure Helm always treats the value as a string (uses the `--set-string` option to Helm; useful if the value varies
  and may look like a number, eg. if it's a Git commit hash).
  A `verbatim: true` parameter escapes backslashes so the value is passed as-is to the Helm chart (useful for `((credentials))`).
  The default behaviour of backslashes in `--set` is to quote the next character so `val\ue` is treated as `value` by Helm.
* `token_path`: *Optional.* Path to file containing the bearer token for Kubernetes.  This, 'token' or `admin_key`/`admin_cert` are required if `cluster_url` is https.
* `version`: *Optional* Chart version to deploy, can be a file or a value. Only applies if `chart` is not a file.
* `delete`: *Optional.* Deletes the release instead of installing it. Requires the `name`. (Default: false)
* `test`: *Optional.* Test the release instead of installing it. Requires the `release`. (Default: false)
* `purge`: *Optional.* Purge the release on delete. (Default: false)
* `replace`: *Optional.* Replace deleted release with same name. (Default: false)
* `force`: *Optional.* Force resource update through delete/recreate if needed. (Default: false)
* `devel`: *Optional.* Allow development versions of chart to be installed. This is useful when wanting to install pre-release
  charts (i.e. 1.0.2-rc1) without having to specify a version. (Default: false)
* `debug`: *Optional.* Dry run the helm install with the debug flag which logs interpolated chart templates. (Default: false)
* `wait_until_ready`: *Optional.* Set to the number of seconds it should wait until all the resources in
    the chart are ready. (Default: `0` which means don't wait).
* `check_is_ready`: *Optional.* Requires that `wait_until_ready` is set to Default. Applies --wait without timeout. (Default: false)
* `atomic`: *Optional.* This flag will cause failed installs to purge the release, and failed upgrades to rollback to the previous release. (Default: false)
* `recreate_pods`: *Optional.* This flag will cause all pods to be recreated when upgrading. (Default: false)
* `show_diff`: *Optional.* Show the diff that is applied if upgrading an existing successful release. Will not be used when `devel` is set. (Default: false)
* `exit_after_diff`: *Optional.* Show the diff but don't actually install/upgrade. (Default: false)
* `reuse_values`: *Optional.* When upgrading, reuse the last release's values. (Default: false)
* `reset_values`: *Optional.* When upgrading, reset the values to the ones built into the chart. (Default: false)
* `wait`: *Optional.* Allows deploy task to sleep for X seconds before continuing to next task. Allows pods to restart and become stable, useful where dependency between pods exists. (Default: 0)
* `kubeconfig_path`: *Optional.* File containing a kubeconfig. Overrides source configuration for cluster, token, and admin config.

## Example

### Out

Define the resource:

```yaml
resources:
- name: myapp-helm
  type: helm
  source:
    cluster_url: https://kube-master.domain.example
    cluster_ca: _base64 encoded CA pem_
    admin_key: _base64 encoded key pem_
    admin_cert: _base64 encoded certificate pem_
    repos:
      - name: some_repo
        url: https://somerepo.github.io/charts
```

Add to job:

```yaml
jobs:
  # ...
  plan:
  - put: myapp-helm
    params:
      chart: source-repo/chart-0.0.1.tgz
      values: source-repo/values.yaml
      override_values:
      - key: replicas
        value: 2
      - key: version
        path: version/number # Read value from version/number
      - key: secret
        value: ((my-top-secret-value)) # Pulled from a credentials backend like Vault
        hide: true # Hides value in output
      - key: image.tag
        path: version/image_tag # Read value from version/number
        type: string            # Make sure it's interpreted as a string by Helm (not a number)
```
