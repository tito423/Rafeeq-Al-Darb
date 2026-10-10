"""Run the actual Android 15+ timeout regression, restoring system settings."""
import argparse
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    args = parser.parse_args()
    prefix = [args.adb, '-s', args.serial]

    def adb(*command, check=True):
        result = subprocess.run(prefix + list(command), capture_output=True,
                                text=True, errors='replace', timeout=180)
        if check and result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout.strip()

    if int(adb('shell', 'getprop', 'ro.build.version.sdk')) < 35:
        raise RuntimeError('Use an Android 15+ emulator for this suite')
    setting = 'data_sync_fgs_timeout_duration'
    original = adb('shell', 'device_config', 'get', 'activity_manager', setting)
    try:
        adb('shell', 'device_config', 'put', 'activity_manager', setting, '3000')
        output = adb('shell', 'am', 'instrument', '-w', '-e', 'suite', 'timeout',
                     'com.tito.rafeeq_aldarb.test/'
                     'com.tito.rafeeq_aldarb.DownloadNotificationRegression')
        print(output)
        if 'PASS:' not in output or 'timeout cleanup and foreground restart' not in output:
            raise AssertionError('Native timeout regression failed')
    finally:
        if original == 'null':
            adb('shell', 'device_config', 'delete', 'activity_manager', setting)
        else:
            adb('shell', 'device_config', 'put', 'activity_manager', setting, original)
        adb('shell', 'am', 'stopservice', '-n',
            'com.tito.rafeeq_aldarb/.DownloadForegroundService', check=False)
        # Instrumentation stops the target process; re-arm its saved reminders.
        adb('shell', 'monkey', '-p', 'com.tito.rafeeq_aldarb', '1', check=False)
        restored = adb('shell', 'device_config', 'get', 'activity_manager', setting)
        if restored != original:
            raise AssertionError('System timeout setting was not restored')


if __name__ == '__main__':
    main()
