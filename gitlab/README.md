# GitLab Commodore compile pipeline

This is a pipeline definition which is suitable to build and push commodore catalogs from a Project Syn tenant repository hosted on a GitLab instance.

Features:

* Show diffs on commits, MRs and master/main
* Push changes automatically from master/main
* Override CI job memory limits for individual clusters (if using the GitLab K8s runner)

## Usage

The pipeline can be used in a Project Syn tenant repository as follows:

1. Copy the `gitlab-ci.yml.default` from this directory to `.gitlab-ci.yml` in the tenant repo.
1. Add the clusters to compile to the `CLUSTERS` in the `.gitlab-ci.yml` in the tenant repo.
1. Create a project access token for the cluster catalog repository of each cluster listed in `CLUSTERS`.
   Set the "role" to "Maintainer" and select the `write_repository` scope.
1. Create a CI/CD variable named `ACCESS_TOKEN_CLUSTERNAME` for each cluster in `CLUSTERS`, where `CLUSTERNAME` is the name of the cluster with `-` replaced by `_`. 
   Set each variable's value to the corresponding catalog project access token you created before.
1. Create CI/CD variables `COMMODORE_API_URL` and `COMMODORE_API_TOKEN` which contain the Lieutenant API URL and a suitable API token for the tenant.

> [!NOTE]
> Project access tokens for catalog repositories are only required for cluster catalog repositories which are hosted on the same GitLab instance as the tenant repo.
> See below for configuring access to external cluster catalog repositories via SSH.

> [!TIP]
> If the pipeline needs to clone projects other than the cluster's catalog repo from the local GitLab instance, you need to deactivate the feature _"Limit access to this project"_ in "Settings > CI/CD > Token Access" on those repositories.
> Alternatively, you can allow access for the job tokens of each tenant repository that needs to access the project.

> [!TIP]
> Lieutenant supports managing the CI pipeline configuration for "managed" tenant and cluster catalog repositories.
> See the [Lieutenant documentation](https://syn.tools/lieutenant-operator/how-tos/compile-pipeline-setup.html) for details.

### Commodore API Token

To get the `COMMODORE_API_TOKEN`, connect to the Kubernetes cluster hosting your Lieutenant instance and run the following command:

```bash
TENANT_NAME=t-tenant-id-1234 # Replace with actual tenant id
kubectl get secret -n lieutenant ${TENANT_NAME} -o go-template='{{.data.token|base64decode}}'
```

Alternatively, configure the Tenant to manage the `COMMODORE_API_TOKEN` CI/CD variable by adding the following in the `Tenant` resource (for example with `kubectl -n lieutenant edit tenant t-tenant-id-1234`):

```bash
spec:
  gitRepoTemplate:
    ciVariables:
      - name: COMMODORE_API_TOKEN
        valueFrom:
          secretKeyRef:
            key: token
            name: t-tenant-id-1234
        gitlabOptions:
          masked: true
```

### External cluster catalog via SSH

If the cluster catalog is hosted externally and can be cloned via SSH, you can specify an SSH key which has access to the cluster catalog and the relevant known hosts entry via CI/CD variables on the tenant repo:

1. Create a CI/CD variable named `SSH_PRIVATE_KEY` containing the SSH private key.
1. Create a CI/CD varaible named `SSH_KNOWN_HOSTS` containing the know hosts entry.
1. (optional) Create a CI/CD variable named `SSH_CONFIG` containing any required SSH configuration.

### External cluster catalog via HTTPS

If the cluster catalog is hosted externally and must be cloned via HTTPS, you can configure HTTPS credentials via CI/CD variables on the tenant repo:

1. Create a CI/CD variable named `ACCESS_USER_CLUSTERNAME` where `CLUSTERNAME` is the Project Syn ID of the cluster. 
   Set this variable's value to the username used to access the catalog repo.
1. Create a CI/CD variable named `ACCESS_TOKEN_CLUSTERNAME` where `CLUSTERNAME` is the Project Syn ID of the cluster.
   Set this variable's value to the password or token used to access the catalog repo.

> [!NOTE]
> To make this work, the Project Syn cluster must be configured to provide its `catalogURL` with a `https://` prefix.

> [!TIP]
> The variable `ACCESS_USER_CLUSTERNAME` is optional.
> If it's not provided, the CI pipeline will fallback to username `token`.

### Test new pipeline generation image

The image used to generate the compile and deploy pipelines can be adjusted by setting the following variables.

```yaml
variables:
  PIPELINE_GENERATION_IMAGE_NAME: ghcr.io/projectsyn/commodore-compile-pipelines/gitlab
  PIPELINE_GENERATION_IMAGE_TAG: mytestbranch
```

## FAQ

### How can the compile pipeline fetch components hosted on the local GitLab instance

The pipeline is configured to use the GitLab CI `CI_JOB_TOKEN` token when fetching repos from the local GitLab instance.
The `CI_JOB_TOKEN` token has the same permissions to access the API as the user that caused the job to run.
Therefore, the compile pipeline can access components hosted in all GitLab projects to which that user has access.


### Why do pipelines for some MRs fail

One common cause for pipeline failures for MRs is that the GitLab user who created the MR doesn't have access to the cluster catalog repo or another repo hosted on the local GitLab instance.
To fix the issue:

* Add the MR creator to the cluster catalog repositories as a "Developer" for read-only, or "Maintainer" for read-write access.
* Add the MR creator to other repositories as a "Developer".

### Configure cpu requests and limits

The following options can be configured as CI/CD variables when the GitLab instance uses a K8s CI runner:

* `CPU_REQUESTS`, which defaults to `800m`
* `CPU_LIMITS`, which defaults to `2`
* `MEMORY_LIMITS`, which defaults to `2Gi`

The job generator expects that each of these variables has space-separated entries of the form `c-cluster-id-1234=value` if it's present.

Example:

```yaml
variables:
  MEMORY_LIMITS: "c-my-cluster=3Gi c-my-other-cluster=3Gi"
```
