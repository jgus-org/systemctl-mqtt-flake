{
  description = "systemctl-mqtt with an option to retain the topics it publishes (fphammerle/systemctl-mqtt)";

  inputs = {
    flake-lib.url = "github:jgus-org/flake-lib/v1";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      self,
      flake-lib,
      nixpkgs,
    }:
    let
      pin = import ./pin.nix;
    in
    flake-lib.lib.mkPythonFlake {
      inherit
        nixpkgs
        pin
        self
        ;
      package = {
        attr = "systemctl-mqtt";
        buildSystem =
          p: with p; [
            setuptools
            setuptools-scm
            wheel
          ];
        dependencies =
          p: with p; [
            aiomqtt
            jeepney
          ];
        description = "MQTT client triggering & reporting shutdown on systemd-based systems";
        extra = p: pkgs: {
          # These reach the host's own org.freedesktop.systemd1: they assert on a live login-manager proxy, and two of them take a real inhibitor lock through _run.
          disabledTests = [
            "test_get_login_manager_proxy"
            "test__run_authentication"
            "test__run_tls"
          ];
          # Upstream's suite is the guard that a bump did not move the publish sites the patch below edits.
          doCheck = true;
          # Upstream reads its version from git metadata, which a source archive does not carry.
          env.SETUPTOOLS_SCM_PRETEND_VERSION = pin.version;
          nativeCheckInputs = [
            pkgs.dbus
          ]
          ++ (with p; [
            pytestCheckHook
            pytest-asyncio
          ]);
          patches = [ ./patches/0001-add-mqtt-retain-option.patch ];
          postPatch = ''
            cp ${./tests/test_mqtt_retain.py} tests/test_mqtt_retain.py
          '';
          # Upstream's tests read whether a unit action is allowed from the system bus, which a build sandbox has no reason to run.
          preCheck = ''
            export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$TMPDIR/system-bus-socket"
            ${pkgs.lib.getExe' pkgs.dbus "dbus-daemon"} --config-file=${pkgs.dbus}/share/dbus-1/session.conf --fork --print-address --address="$DBUS_SYSTEM_BUS_ADDRESS"
          '';
        };
        kind = "pythonApplication";
        meta = {
          homepage = "https://github.com/fphammerle/systemctl-mqtt";
          license = nixpkgs.lib.licenses.gpl3Plus;
          mainProgram = "systemctl-mqtt";
          platforms = nixpkgs.lib.platforms.linux;
        };
      };
      source = {
        owner = "fphammerle";
        repo = "systemctl-mqtt";
        type = "github";
      };
      updateBranches.minimumTrackingVersion = "3.0.0";
    };

}
