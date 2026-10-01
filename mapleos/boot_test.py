#!/usr/bin/env python3
"""Boot the actual ISO through BIOS and UEFI; capture serial evidence and screenshots."""
from __future__ import annotations
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time


def qmp_command(stream, name, arguments=None):
    stream.write((json.dumps({'execute': name, **({'arguments': arguments} if arguments else {})})+'\n').encode())
    stream.flush()
    while True:
        response = json.loads(stream.readline())
        if 'return' in response: return response['return']
        if 'error' in response: raise RuntimeError(response['error'])


def run_test(iso: Path, output: Path, firmware: str) -> dict:
    serial = output / f'{firmware}-serial.log'
    stderr = output / f'{firmware}-qemu.log'
    result = {'firmware': firmware, 'booted_from_iso': True, 'passed': False}
    with tempfile.TemporaryDirectory(prefix='maple-qemu-') as temp:
        temp = Path(temp)
        qmp = temp / 'monitor.sock'
        args = ['qemu-system-x86_64', '-machine', 'q35', '-m', '4096', '-smp', '2',
                '-cdrom', str(iso), '-boot', 'order=d', '-display', 'none', '-vga', 'virtio',
                '-netdev', 'user,id=net0', '-device', 'virtio-net-pci,netdev=net0',
                '-serial', 'file:'+str(serial), '-qmp', 'unix:'+str(qmp)+',server=on,wait=off', '-no-reboot']
        if Path('/dev/kvm').exists() and os.access('/dev/kvm', os.R_OK | os.W_OK):
            args += ['-enable-kvm', '-cpu', 'host']
            result['accelerator'] = 'kvm'
        else:
            args += ['-accel', 'tcg', '-cpu', 'max']
            result['accelerator'] = 'tcg'
        if firmware == 'uefi':
            code = Path('/usr/share/OVMF/OVMF_CODE_4M.fd')
            variables = Path('/usr/share/OVMF/OVMF_VARS_4M.fd')
            if not code.exists():
                code = Path('/usr/share/OVMF/OVMF_CODE.fd')
                variables = Path('/usr/share/OVMF/OVMF_VARS.fd')
            if not code.exists() or not variables.exists(): raise RuntimeError('OVMF firmware missing')
            shutil.copyfile(variables, temp / 'vars.fd')
            args += ['-drive', f'if=pflash,format=raw,readonly=on,file={code}', '-drive', f'if=pflash,format=raw,file={temp / "vars.fd"}']
        started = time.monotonic()
        with stderr.open('wb') as errors:
            proc = subprocess.Popen(args, stdout=errors, stderr=subprocess.STDOUT)
            try:
                deadline = started + 300
                while time.monotonic() < deadline:
                    text = serial.read_text(errors='replace') if serial.exists() else ''
                    if 'MAPLEOS_DESKTOP_OK' in text:
                        result['passed'] = 'MAPLEOS_LIVE_OK' in text
                        break
                    if 'MAPLEOS_BOOT_FAILED' in text or 'MAPLEOS_DESKTOP_TIMEOUT' in text:
                        break
                    if proc.poll() is not None:
                        result['qemu_exit'] = proc.returncode
                        break
                    time.sleep(2)
                if qmp.exists() and proc.poll() is None:
                    try:
                        with socket.socket(socket.AF_UNIX) as sock:
                            sock.settimeout(10)
                            sock.connect(str(qmp))
                            with sock.makefile('rwb') as stream:
                                json.loads(stream.readline())
                                qmp_command(stream, 'qmp_capabilities')
                                ppm = output / f'{firmware}-desktop.ppm'
                                qmp_command(stream, 'screendump', {'filename': str(ppm)})
                        from PIL import Image
                        with Image.open(ppm) as image: image.save(output / f'{firmware}-desktop.png')
                        ppm.unlink()
                    except Exception as exc:
                        result['screenshot_error'] = str(exc)
            finally:
                proc.terminate()
                try: proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
        result['seconds'] = round(time.monotonic() - started, 1)
        print(json.dumps(result), flush=True)
        if not result['passed']:
            print(serial.read_text(errors='replace')[-18000:] if serial.exists() else stderr.read_text(errors='replace'))
    return result


def main() -> int:
    output = Path(sys.argv[1]).resolve()
    iso, = output.glob('*.iso')
    tests = []
    for firmware in ('bios', 'uefi'):
        tests.append(run_test(iso, output, firmware))
        (output/'boot-tests.json').write_text(json.dumps({'tests': tests, 'scope': 'Actual ISO boot, Maple live identity, non-root sandbox self-test, SSH inactive, Hyprland startup and zero reported config errors. Disk installation and physical hardware are NOT validated by these tests.'}, indent=2)+'\n')
    return 0 if all(t['passed'] for t in tests) else 1

if __name__ == '__main__': raise SystemExit(main())
