# The live workloads' manifests (CLUSTER.md) as data, a pure function of this file: each is the bare manifest with a placeholder
# digest, which `apply` replaces. `mirrored` is the volume table the Python mirror copies, in the order of diskguard.VOLUMES; the
# flake check `volume-table` holds the two equal until the mirror leaves Python.
{ lib }:
let
  registry = "git.home.lab/admin/moneymachine";
  namespace = "moneymachine-live";
  node = "prodesk7";
  appDir = "/app/repo";
  placeholder = "sha256:${lib.strings.replicate 64 "0"}";

  mirrored = [
    { name = "hl"; path = "data/live"; }
    { name = "sources"; path = "data/sources_live"; }
    { name = "datalayer"; path = "data/datalayer"; }
    { name = "thesis"; path = "data/thesis"; }
    { name = "agent"; path = "data/agent"; }
  ];
  claimPath = builtins.listToAttrs (map (v: lib.nameValuePair v.name v.path) (mirrored ++ [{ name = "ws"; path = "data/ws"; }]));
  ledgers = [ "thesis" "agent" ];

  mount = name: readOnly: { inherit name readOnly; };
  allMirrored = readOnly: map (v: mount v.name (readOnly v.name)) mirrored;

  small = { cpu = "100m"; request = "256Mi"; limit = "512Mi"; };
  python = script: [ "python" "-m" "cli" script ];

  workloads = {
    sources = {
      kind = "StatefulSet";
      command = python "sources-record" ++ [ "data/sources_live" ];
      volumes = [ (mount "sources" false) ];
      size = small;
      grace = 300;
    };
    datalayer = {
      kind = "StatefulSet";
      command = python "datalayer-record" ++ [ "data/datalayer" ];
      volumes = [ (mount "datalayer" false) ];
      size = small;
      grace = 300;
      keys = true;
    };
    ws = {
      kind = "StatefulSet";
      command = [ "mmrec" "run" "data/ws" ];
      volumes = [ (mount "ws" false) ];
      size = { cpu = "250m"; request = "512Mi"; limit = "1Gi"; };
      grace = 30;
    };
    vault = {
      kind = "CronJob";
      command = [ "mmvault" "run" "data/ws" "--user" "0x53375ca9a649f337d83d0834fec0db97640a2a06" ];
      volumes = [ (mount "ws" false) ];
      size = small;
      grace = 30;
      schedule = "7 * * * *";
    };
    mirror = {
      kind = "CronJob";
      command = [ "python" "ops/live.py" "mirror" ];
      volumes = allMirrored (v: !(builtins.elem v ledgers)) ++ [ (mount "mirror" false) ];
      size = { cpu = "200m"; request = "256Mi"; limit = "512Mi"; };
      grace = 600;
      schedule = "*/10 * * * *";
    };
    mirror-verify = {
      kind = "CronJob";
      command = [ "python" "ops/live.py" "verify" ];
      volumes = allMirrored (_: true) ++ [ (mount "mirror" true) ];
      size = { cpu = "200m"; request = "256Mi"; limit = "512Mi"; };
      grace = 600;
      schedule = "41 3 * * *";
    };
  };

  podSpec = name: w:
    let
      mountPath = v: if v.name == "mirror" then "/mirror" else "${appDir}/${claimPath.${v.name}}";
      keysMount = { name = "keys"; mountPath = "${appDir}/.keys.env"; subPath = ".keys.env"; readOnly = true; };
      scratch = [ "tmp" "scratch" ];
    in
    {
      serviceAccountName = "live";
      automountServiceAccountToken = false;
      enableServiceLinks = false;
      priorityClassName = namespace;
      nodeSelector."kubernetes.io/hostname" = node;
      terminationGracePeriodSeconds = w.grace;
      securityContext = {
        runAsUser = 1000;
        runAsGroup = 100;
        fsGroup = 100;
        runAsNonRoot = true;
        seccompProfile.type = "RuntimeDefault";
        appArmorProfile.type = "RuntimeDefault";
      };
      containers = [{
        inherit name;
        image = "${registry}@${placeholder}";
        workingDir = appDir;
        command = w.command;
        resources = {
          requests = { cpu = w.size.cpu; memory = w.size.request; };
          limits.memory = w.size.limit;
        };
        securityContext = {
          allowPrivilegeEscalation = false;
          readOnlyRootFilesystem = true;
          capabilities.drop = [ "ALL" ];
        };
        volumeMounts =
          map (n: { name = n; mountPath = "/${n}"; }) scratch
          ++ map (v: { inherit (v) name readOnly; mountPath = mountPath v; }) w.volumes
          ++ lib.optional (w.keys or false) keysMount;
      }];
      volumes =
        map (n: { name = n; emptyDir.sizeLimit = "2Gi"; }) scratch
        ++ map (v: { name = v.name; persistentVolumeClaim.claimName = v.name; }) w.volumes
        ++ lib.optional (w.keys or false) { name = "keys"; secret.secretName = "datalayer-keys"; };
    };

  manifest = name: w:
    let
      labels = { app = name; };
      template = pod: { metadata.labels = labels; spec = pod; };
    in
    if w.kind == "StatefulSet" then {
      apiVersion = "apps/v1";
      kind = w.kind;
      metadata = { inherit name labels; };
      spec = {
        replicas = 1;
        serviceName = name;
        selector.matchLabels = labels;
        template = template (podSpec name w);
      };
    } else {
      apiVersion = "batch/v1";
      kind = w.kind;
      metadata = { inherit name labels; };
      spec = {
        schedule = w.schedule;
        concurrencyPolicy = "Forbid";
        successfulJobsHistoryLimit = 1;
        jobTemplate.spec = {
          backoffLimit = 0;
          template = template (podSpec name w // { restartPolicy = "Never"; });
        };
      };
    };
in
{
  inherit mirrored registry;
  manifests = lib.mapAttrs manifest workloads;
}
