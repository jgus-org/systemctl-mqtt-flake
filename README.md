# systemctl-mqtt-flake

A Nix flake that builds [systemctl-mqtt](https://github.com/fphammerle/systemctl-mqtt), an MQTT client that reports systemd state and carries out power and unit actions, with one addition: a `--mqtt-retain` option that publishes the topics it reports on with MQTT's retain flag.

## Outputs

| Attribute                        | What you get                                     |
| -------------------------------- | ------------------------------------------------ |
| `packages.default`               | The package; `bin/systemctl-mqtt` is the client. |
| `packages.systemctl-mqtt`        | The same package under its own name.             |
| `formatter`, `checks.formatting` | This flake's own files.                          |

`packages.<system>.update-version` and `packages.<system>.update-branches` move the pin; neither is needed to consume the flake.

```nix
inputs.systemctl-mqtt = {
  url = "github:jgus-org/systemctl-mqtt-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};

# then
inputs.systemctl-mqtt.packages.${system}.default
```

## What you get

**Retained topics.** Upstream publishes its availability topic and its last will retained, but reports `preparing-for-shutdown`, each monitored unit's `active-state`, and its Home Assistant device discovery config without the retain flag, so a client that subscribes after the last publish sees nothing until the next state change. `--mqtt-retain` sets the flag on those publishes too; without it the published messages are exactly as upstream has them. Inbound retained messages are ignored by upstream either way, so retaining reports does not replay actions.

**Runtime.** The client needs the system D-Bus socket and a systemd that exposes `org.freedesktop.systemd1`; it is a system or user service on a systemd-based Linux host, and Linux is the only platform family its package claims. Actions on units are allowed only where the host's D-Bus policy permits them, so a consumer running it unprivileged still cannot start or stop units the host would not let it touch.

**Home Assistant.** Device discovery uses `default_entity_id`, which needs Home Assistant 2025.10 or newer.

See [LICENSE.md](LICENSE.md) for licensing and copyright, and [NOTICE.md](NOTICE.md) for the terms of upstream and distributed artifacts.
