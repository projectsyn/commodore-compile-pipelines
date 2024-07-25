local commodore_version = 'v1.22.1';
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
  local cluster_repo = cluster_catalog_urls[cluster];
  local ssh_gitlab = 'ssh://git@%s/' % gitlab_ssh_host;
  local catalog_path = if std.startsWith(cluster_repo, ssh_gitlab) then
    // prefix ssh://git@<host> 0 == ssh, 1 == '', 2 == <host>
    std.join('/', std.split(cluster_repo, '/')[3:]);

  local catalogInsteadOf =
    if catalog_path != null then
      [
        'git config --global url."https://gitlab-ci-token:%(access_token)s@%(gitlab_fqdn)s/%(catalog_path)s".insteadOf ssh://git@${CI_SERVER_SHELL_SSH_HOST}/%(catalog_path)s' % {
          access_token: cluster_access_token,
          catalog_path: catalog_path,
          gitlab_fqdn: gitlab_fqdn,
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
        KUBERNETES_MEMORY_LIMIT: std.get(memory_limits, cluster, '2Gi'),
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
        KUBERNETES_MEMORY_LIMIT: std.get(memory_limits, cluster, default='2Gi'),
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
