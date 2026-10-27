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
    flake-lib.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        pin = import ./pin.nix;
        orgFormatting = flake-lib.lib.mkFormatting {
          inherit self system;
        };
        source = {
          owner = "fphammerle";
          repo = "systemctl-mqtt";
          type = "github";
        };
      in
      {
        checks.formatting = orgFormatting.check;
        formatter = orgFormatting.formatter;
        packages = rec {
          default = systemctl-mqtt;
          systemctl-mqtt = pkgs.python3Packages.buildPythonApplication {
            inherit (pin) version;
            build-system = with pkgs.python3Packages; [
              setuptools
              setuptools-scm
              wheel
            ];
            dependencies = with pkgs.python3Packages; [
              aiomqtt
              jeepney
            ];
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
            meta = {
              description = "MQTT client triggering & reporting shutdown on systemd-based systems";
              homepage = "https://github.com/fphammerle/systemctl-mqtt";
              license = pkgs.lib.licenses.gpl3Plus;
              mainProgram = "systemctl-mqtt";
              platforms = pkgs.lib.platforms.linux;
            };
            nativeCheckInputs = [
              pkgs.dbus
            ]
            ++ (with pkgs.python3Packages; [
              pytestCheckHook
              pytest-asyncio
            ]);
            patches = [ ./patches/0001-add-mqtt-retain-option.patch ];
            pname = "systemctl-mqtt";
            postPatch = ''
              cp ${./tests/test_mqtt_retain.py} tests/test_mqtt_retain.py
            '';
            # Upstream's tests read whether a unit action is allowed from the system bus, which a build sandbox has no reason to run.
            preCheck = ''
              export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$TMPDIR/system-bus-socket"
              ${pkgs.lib.getExe' pkgs.dbus "dbus-daemon"} --config-file=${pkgs.dbus}/share/dbus-1/session.conf --fork --print-address --address="$DBUS_SYSTEM_BUS_ADDRESS"
            '';
            pyproject = true;
            src = pkgs.fetchFromGitHub {
              inherit (source) owner repo;
              hash = pin.sourceHash;
              rev = pin.sourceRev;
            };
          };
          update-branches = flake-lib.lib.mkUpdateBranches {
            inherit pkgs source;
            # Home Assistant device discovery needs 2025.10+, which only 3.0.0 and later emit.
            minimumTrackingVersion = "3.0.0";
            pinSchema = "github";
          };
          update-version = flake-lib.lib.mkUpdateVersion {
            inherit pkgs source;
          };
        };
      }
    );
}
