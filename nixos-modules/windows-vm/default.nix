{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dcaroncfg.windowsVm;

  usbDeviceType = lib.types.submodule {
    options = {
      vendor = lib.mkOption {
        type = lib.types.str;
        description = "USB vendor ID (hex, e.g. 0c72).";
      };
      product = lib.mkOption {
        type = lib.types.str;
        description = "USB product ID (hex, e.g. 0012).";
      };
    };
  };

  vmXml = pkgs.writeText "${cfg.vmName}.xml" ''
    <domain type='kvm'>
      <name>${cfg.vmName}</name>
      <memory unit='MiB'>${toString cfg.memoryMB}</memory>
      <vcpu placement='static'>${toString cfg.vcpus}</vcpu>
      <os firmware='efi'>
        <type arch='x86_64' machine='q35'>hvm</type>
        <boot dev='hd'/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
        </hyperv>
      </features>
      <cpu mode='host-passthrough' check='none' migratable='on'/>
      <clock offset='localtime'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
        <timer name='hypervclock' present='yes'/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <devices>
        <emulator>${pkgs.qemu}/bin/qemu-system-x86_64</emulator>
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap'/>
          <source file='${cfg.diskPath}'/>
          <target dev='vda' bus='virtio'/>
        </disk>
        <interface type='network'>
          <source network='default'/>
          <model type='virtio'/>
        </interface>
        <tpm model='tpm-crb'>
          <backend type='emulator' version='2.0'/>
        </tpm>
        <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'/>
        <video>
          <model type='qxl' ram='65536' vram='65536'/>
        </video>
        <channel type='spicevmc'>
          <target type='virtio' name='com.redhat.spice.0'/>
        </channel>
      </devices>
    </domain>
  '';

  mkUsbAttachXml =
    dev:
    pkgs.writeText "usb-${dev.vendor}-${dev.product}.xml" ''
      <hostdev mode='subsystem' type='usb' managed='yes'>
        <source>
          <vendor id='0x${dev.vendor}'/>
          <product id='0x${dev.product}'/>
        </source>
      </hostdev>
    '';

  sshOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR";
  virsh = "${pkgs.libvirt}/bin/virsh -c qemu:///system";

  ciVmStart = pkgs.writeShellScriptBin "ci-vm-start" ''
    set -euo pipefail
    echo "Starting Windows VM '${cfg.vmName}'..."
    ${virsh} start "${cfg.vmName}" 2>/dev/null || {
      echo "VM already running or failed to start"
      ${virsh} domstate "${cfg.vmName}"
    }
  '';

  ciVmWaitSsh = pkgs.writeShellScriptBin "ci-vm-wait-ssh" ''
    set -euo pipefail
    echo "Waiting for SSH on ${cfg.vmAddress}..."
    timeout=120
    elapsed=0
    while ! ${pkgs.openssh}/bin/ssh ${sshOpts} \
      -i "${cfg.sshKeyFile}" \
      ${cfg.vmUser}@${cfg.vmAddress} "echo ready" &>/dev/null; do
      if [ "$elapsed" -ge "$timeout" ]; then
        echo "ERROR: SSH timeout after ''${timeout}s"
        exit 1
      fi
      sleep 2
      elapsed=$((elapsed + 2))
      echo "  ...waiting (''${elapsed}s)"
    done
    echo "SSH is ready."
  '';

  ciUsbToVm = pkgs.writeShellScriptBin "ci-usb-to-vm" ''
    set -euo pipefail
    echo "Attaching USB devices to VM..."
    ${lib.concatMapStrings (dev: ''
      echo "  Attaching ${dev.vendor}:${dev.product}..."
      ${virsh} attach-device "${cfg.vmName}" "${mkUsbAttachXml dev}" --live || \
        echo "  Warning: could not attach ${dev.vendor}:${dev.product} (may already be attached)"
    '') cfg.usbDevices}
    echo "USB devices attached."
  '';

  ciRunWindowsTests = pkgs.writeShellScriptBin "ci-run-windows-tests" ''
    set -euo pipefail
    crate="''${1:?Usage: ci-run-windows-tests <crate-name>}"
    echo "Running Windows tests for $crate..."
    ${pkgs.openssh}/bin/ssh ${sshOpts} \
      -i "${cfg.sshKeyFile}" \
      ${cfg.vmUser}@${cfg.vmAddress} \
      "cd can-hal-rs && cargo test -p $crate"
  '';

  ciUsbToHost = pkgs.writeShellScriptBin "ci-usb-to-host" ''
    set -euo pipefail
    echo "Detaching USB devices from VM..."
    ${lib.concatMapStrings (dev: ''
      echo "  Detaching ${dev.vendor}:${dev.product}..."
      ${virsh} detach-device "${cfg.vmName}" "${mkUsbAttachXml dev}" --live || \
        echo "  Warning: could not detach ${dev.vendor}:${dev.product} (may already be detached)"
    '') cfg.usbDevices}
    echo "USB devices returned to host."
  '';

  ciVmStop = pkgs.writeShellScriptBin "ci-vm-stop" ''
    set -euo pipefail
    echo "Stopping Windows VM '${cfg.vmName}'..."
    ${virsh} shutdown "${cfg.vmName}" 2>/dev/null || true

    # Wait for graceful shutdown.
    timeout=60
    elapsed=0
    while [ "$(${virsh} domstate "${cfg.vmName}" 2>/dev/null)" = "running" ]; do
      if [ "$elapsed" -ge "$timeout" ]; then
        echo "Graceful shutdown timed out, forcing destroy..."
        ${virsh} destroy "${cfg.vmName}" 2>/dev/null || true
        break
      fi
      sleep 2
      elapsed=$((elapsed + 2))
    done
    echo "VM stopped."
  '';
in

{
  options.dcaroncfg.windowsVm = {
    enable = lib.mkEnableOption "Windows VM for CI testing";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "win-test";
      description = "Libvirt domain name for the Windows VM.";
    };

    memoryMB = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Memory allocated to the VM in MiB.";
    };

    vcpus = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of virtual CPUs for the VM.";
    };

    diskPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/libvirt/images/win-test.qcow2";
      description = "Path to the Windows VM qcow2 disk image.";
    };

    sshKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/github-runner/win-test-ssh-key";
      description = "Path to SSH private key for accessing the Windows VM.";
    };

    vmAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.122.10";
      description = "Static IP address of the Windows VM on the libvirt default network.";
    };

    vmUser = lib.mkOption {
      type = lib.types.str;
      default = "ci";
      description = "SSH user on the Windows VM.";
    };

    usbDevices = lib.mkOption {
      type = lib.types.listOf usbDeviceType;
      default = [ ];
      description = "USB devices available for passthrough to the VM.";
    };

    ciPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      default = [
        ciVmStart
        ciVmWaitSsh
        ciUsbToVm
        ciRunWindowsTests
        ciUsbToHost
        ciVmStop
      ];
      description = "CI helper script packages for use in runner extraPackages.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    virtualisation.spiceUSBRedirection.enable = true;

    # Define the VM on system activation.
    system.activationScripts.defineWindowsVm = lib.stringAfter [ "var" ] ''
      if [ -S /var/run/libvirt/libvirt-sock ]; then
        ${virsh} define ${vmXml} 2>/dev/null || true
      fi
    '';

    environment.systemPackages = [
      ciVmStart
      ciVmWaitSsh
      ciUsbToVm
      ciRunWindowsTests
      ciUsbToHost
      ciVmStop
    ];
  };
}
