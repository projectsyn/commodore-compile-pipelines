local commodore_version = 'v1.27.3';
local commodore_image = 'docker.io/projectsyn/commodore:' + commodore_version;

local to_array(param) = std.foldl(
  function(obj, elem)
    local parts = std.split(elem, '=');
    obj {
      [parts[0]]: parts[1],
    },
  std.split(std.extVar(std.rstripChars(param, ' ')), ' '),
  {},
);

local gitlab_fqdn = std.extVar('server_fqdn');
local gitlab_ssh_host = std.extVar('server_ssh_host');
local clusters = std.split(std.extVar('clusters'), ' ');
local cluster_catalog_urls = to_array('cluster_catalog_urls');
local memory_limits = to_array('memory_limits');
local cpu_limits = to_array('cpu_limits');
local cpu_requests = to_array('cpu_requests');

local gitInsteadOf(cluster) =
  local cluster_access_token = '${ACCESS_TOKEN_%s}' % std.strReplace(cluster, '-', '_');
  local cluster_access_user = '${ACCESS_USER_%s:-token}' % std.strReplace(cluster, '-', '_');
  local cluster_repo = cluster_catalog_urls[cluster];
  local ssh_gitlab = 'ssh://git@%s/' % gitlab_ssh_host;
  local catalog_path = if std.startsWith(cluster_repo, ssh_gitlab) then
    // prefix ssh://git@<host> 0 == ssh, 1 == '', 2 == <host>
    std.join('/', std.split(cluster_repo, '/')[3:]);

  local https_catalog = if std.startsWith(cluster_repo, 'https://') then
    std.substr(cluster_repo, std.length('https://'), std.length(cluster_repo));

  local catalogInsteadOf =
    if catalog_path != null then
      // set an insteadOf which injects the access token for catalog repos
      // that have an ssh catalog URL and which are hosted on the local
      // GitLab.
      [
        'git config --global url."https://gitlab-ci-token:%(access_token)s@%(gitlab_fqdn)s/%(catalog_path)s".insteadOf ssh://git@${CI_SERVER_SHELL_SSH_HOST}/%(catalog_path)s' % {
          access_token: cluster_access_token,
          catalog_path: catalog_path,
          gitlab_fqdn: gitlab_fqdn,
        },
      ]
    else if https_catalog != null then
      // set an insteadOf which injects credentials if we have a catalog URL
      // that's already HTTPS in Lieutenant.
      local replacement = 'https://%(catalog_user)s:%(access_token)s@%(https_catalog)s' % {
        catalog_user: cluster_access_user,
        access_token: cluster_access_token,
        https_catalog: https_catalog,
      };
      [
        // Overide the original https:// URL for fetch and clone. Note that we
        // use `git config --add` here so we can configure two `insteadOf` for
        // the same replacement URL.
        'git config --add --global url."%(replacement)s".insteadOf https://%(https_catalog)s' % {
          replacement: replacement,
          https_catalog: https_catalog,
        },
        // We need to configure an additional insteadOf for the ssh://git@
        // variant of a HTTPS catalog URL since Commodore will optimistically
        // rewrite all HTTPS Git URLs to have their ssh://git@ equivalent as
        // the push URL to make local component development easier.
        // Note that we can't use `pushInsteadOf` here, since Git ignores
        // `pushInsteadOf` configs for remotes that have an explicit
        // `pushurl`.
        'git config --add --global url."%(replacement)s".insteadOf ssh://git@%(https_catalog)s' % {
          replacement: replacement,
          https_catalog: https_catalog,
        },
      ]
    else
      [];

  [
    'git config --global url."https://gitlab-ci-token:${CI_JOB_TOKEN}@%(gitlab_fqdn)s".insteadOf ssh://git@${CI_SERVER_SHELL_SSH_HOST}' % {
      gitlab_fqdn: gitlab_fqdn,
    },
  ] + catalogInsteadOf;

local compile_job(cluster) =
  {
    stage: 'build',
    image:
      {
        name: commodore_image,
      },
    variables:
      {
        KUBERNETES_MEMORY_LIMIT: std.get(memory_limits, cluster, '3Gi'),
        KUBERNETES_CPU_LIMIT: std.get(cpu_limits, cluster, '2'),
        KUBERNETES_CPU_REQUEST: std.get(cpu_requests, cluster, '800m'),
      },
    before_script:
      [
        'install --directory --mode=0700 ~/.ssh',
        'echo "$SSH_KNOWN_HOSTS" >> ~/.ssh/known_hosts',
        'echo "$SSH_CONFIG" >> ~/.ssh/config',
      ],
    script:
      gitInsteadOf(cluster) + [
        '/usr/local/bin/entrypoint.sh commodore catalog compile --tenant-repo-revision-override $CI_COMMIT_SHA ' + cluster,
        '(cd catalog/ && git --no-pager diff --staged --output ../diff.txt)',
      ],
    artifacts:
      {
        paths:
          [
            'diff.txt',
          ],
        expire_in: '1 week',
      },
    rules:
      [
        { 'if': '$CI_COMMIT_REF_NAME != $CI_DEFAULT_BRANCH' },
      ],
  };

local deploy_job(cluster) =
  {
    stage: 'deploy',
    variables:
      {
        KUBERNETES_MEMORY_LIMIT: std.get(memory_limits, cluster, default='3Gi'),
        KUBERNETES_CPU_LIMIT: std.get(cpu_limits, cluster, default='2'),
        KUBERNETES_CPU_REQUEST: std.get(cpu_requests, cluster, default='800m'),
      },
    image:
      {
        name: commodore_image,
      },
    before_script:
      [
        'install --directory --mode=0700 ~/.ssh',
        'echo "$SSH_KNOWN_HOSTS" >> ~/.ssh/known_hosts',
        'echo "$SSH_CONFIG" >> ~/.ssh/config',
      ],
    script:
      gitInsteadOf(cluster) + [
        '/usr/local/bin/entrypoint.sh commodore catalog compile --push ' + cluster,
      ],
    rules:
      [
        { 'if': '$CI_COMMIT_REF_NAME == $CI_DEFAULT_BRANCH' },
      ],
  };

local compile =
  {
    [x + '_compile']: compile_job(x)
    for x in clusters
  };

local deploy =
  {
    [x + '_deploy']: deploy_job(x)
    for x in clusters
  };

compile + deploy
