import datetime
import unittest.mock

import pytest

import systemctl_mqtt

# pylint: disable=protected-access

RETAIN_CASES = [(False, False), (True, True)]


def _state(mqtt_retain: bool) -> systemctl_mqtt._State:
    login_manager_mock = unittest.mock.MagicMock()
    login_manager_mock.Get.return_value = (("b", False),)[:]
    with unittest.mock.patch(
        "systemctl_mqtt._dbus.login_manager.get_login_manager_proxy",
        return_value=login_manager_mock,
    ):
        return systemctl_mqtt._State(
            mqtt_topic_prefix="any",
            homeassistant_discovery_prefix="homeassistant",
            homeassistant_discovery_object_id="obj",
            poweroff_delay=datetime.timedelta(),
            monitored_system_unit_names=[],
            controlled_system_unit_names=[],
            mqtt_retain=mqtt_retain,
        )


@pytest.mark.asyncio
@pytest.mark.parametrize(("mqtt_retain", "expected_retain"), RETAIN_CASES)
async def test__publish_preparing_for_shutdown_retain(
    mqtt_retain: bool, expected_retain: bool
) -> None:
    state = _state(mqtt_retain)
    mqtt_client = unittest.mock.AsyncMock()
    await state.publish_preparing_for_shutdown(mqtt_client=mqtt_client)
    mqtt_client.publish.assert_awaited_once_with(
        topic="any/preparing-for-shutdown",
        payload="false",
        retain=expected_retain,
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(("mqtt_retain", "expected_retain"), RETAIN_CASES)
async def test__publish_homeassistant_device_config_retain(
    mqtt_retain: bool, expected_retain: bool
) -> None:
    state = _state(mqtt_retain)
    mqtt_client = unittest.mock.AsyncMock()
    with unittest.mock.patch(
        "systemctl_mqtt._utils.get_hostname", return_value="hostname"
    ):
        await state.publish_homeassistant_device_config(
            mqtt_client=mqtt_client
        )
    mqtt_client.publish.assert_called_once()
    _, publish_kwargs = mqtt_client.publish.call_args
    assert publish_kwargs["retain"] is expected_retain


@pytest.mark.parametrize(
    ("args", "expected_mqtt_retain"),
    [([], False), (["--mqtt-retain"], True)],
)
def test__main_mqtt_retain(
    args: list[str], expected_mqtt_retain: bool
) -> None:
    with (
        unittest.mock.patch("systemctl_mqtt._run") as run_mock,
        unittest.mock.patch(
            "sys.argv", ["", "--mqtt-host", "mqtt-broker.local", *args]
        ),
    ):
        systemctl_mqtt._main()
    assert run_mock.call_args[1]["mqtt_retain"] is expected_mqtt_retain
