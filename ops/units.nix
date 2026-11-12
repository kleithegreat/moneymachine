# The user timers that guard the recordings, as a home-manager module (CLAUDE.md, Running things; CLUSTER.md §5). The
# dotfiles import it as `homeManagerModules.default` of this flake. Each unit runs an app of this flake in the main
# checkout, so a guard changes by merging into that checkout, as before.
{ diskguard, ociPull }:
{ config, lib, ... }:
let
  checkout = config.services.moneymachine.checkout;
  timer = description: onCalendar: {
    Unit.Description = description;
    Timer = { OnCalendar = onCalendar; Persistent = true; };
    Install.WantedBy = [ "timers.target" ];
  };
  service = description: app: {
    Unit.Description = description;
    Service = { Type = "oneshot"; WorkingDirectory = checkout; ExecStart = lib.getExe app; };
  };
in
{
  options.services.moneymachine.checkout = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/repos/moneymachine";
    description = "The main checkout, whose data/ the timers read and write.";
  };
  config.systemd.user = {
    services.mm-diskguard = service "moneymachine disk-space guard" diskguard;
    timers.mm-diskguard = timer "moneymachine disk-space guard, hourly" "hourly";
    services.mm-oci-pull = service "Pull the cloud HL recorder's files (moneymachine)" ociPull;
    timers.mm-oci-pull = timer "Pull the cloud HL recorder's files every 10 minutes" "*:0/10";
  };
}
