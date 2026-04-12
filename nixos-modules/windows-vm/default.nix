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
    # Force a clean start — destroy any leftover state from previous runs.
    ${virsh} destroy "${cfg.vmName}" 2>/dev/null || true
    sleep 1
    ${virsh} start "${cfg.vmName}"
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

  # Find the sysfs USB device path for a given vendor:product pair.
  findUsbDev = pkgs.writeShellScript "find-usb-dev" ''
    vendor="$1"
    product="$2"
    for dev in /sys/bus/usb/devices/*/idVendor; do
      dir="$(dirname "$dev")"
      if [ "$(cat "$dir/idVendor" 2>/dev/null)" = "$vendor" ] && \
         [ "$(cat "$dir/idProduct" 2>/dev/null)" = "$product" ]; then
        basename "$dir"
        exit 0
      fi
    done
    exit 1
  '';

  ciUsbToVm = pkgs.writeShellScriptBin "ci-usb-to-vm" ''
    set -euo pipefail
    echo "Releasing USB devices and attaching to VM..."
    systemctl start ci-usb-to-vm.service
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
    echo "Returning USB devices to host..."
    systemctl start ci-usb-to-host.service
    echo "USB devices returned to host and bound."
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

    # Allow libvirtd group to manage VMs and github-runner to manage CI services.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id.indexOf("org.libvirt.unix.manage") === 0 &&
            subject.isInGroup("libvirtd")) {
          return polkit.Result.YES;
        }
        if (action.id === "org.freedesktop.systemd1.manage-units" &&
            subject.user === "github-runner") {
          var unit = action.lookup("unit");
          if (unit === "can-usb-bind.service" ||
              unit === "ci-usb-to-vm.service" ||
              unit === "ci-usb-to-host.service") {
            return polkit.Result.YES;
          }
        }
      });
    '';

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

    # Privileged systemd services for USB lifecycle (run as root).
    systemd.services.ci-usb-to-vm = {
      description = "Release CAN USB devices from host and attach to VM";
      wantedBy = [ ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.kmod ];
      script = ''
        # PCAN: remove_id keeps USB device alive (rmmod kills it).
        echo "0c72 0012" > /sys/bus/usb/drivers/pcan/remove_id 2>/dev/null || true
        # Kvaser: rmmod is safe.
        rmmod mhydra 2>/dev/null || true
        rmmod kvcommon 2>/dev/null || true
        sleep 2

        ${lib.concatMapStrings (dev: ''
          echo "Attaching ${dev.vendor}:${dev.product} to VM..."
          ${virsh} attach-device "${cfg.vmName}" "${mkUsbAttachXml dev}" --live || true
        '') cfg.usbDevices}

        # Kvaser detach/reattach for Windows driver detection.
        ${virsh} detach-device "${cfg.vmName}" "${mkUsbAttachXml (builtins.elemAt cfg.usbDevices 1)}" --live 2>/dev/null || true
        sleep 2
        ${virsh} attach-device "${cfg.vmName}" "${mkUsbAttachXml (builtins.elemAt cfg.usbDevices 1)}" --live 2>/dev/null || true
        sleep 3
      '';
    };

    systemd.services.ci-usb-to-host = {
      description = "Detach CAN USB devices from VM and rebind to host";
      wantedBy = [ ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.kmod pkgs.usbutils pkgs.pciutils ];
      script = ''
        # --- Step 1: Detach all USB devices from VM ---
        ${lib.concatMapStrings (dev: ''
          echo "Detaching ${dev.vendor}:${dev.product} from VM..."
          ${virsh} detach-device "${cfg.vmName}" "${mkUsbAttachXml dev}" --live 2>/dev/null || true
        '') cfg.usbDevices}
        sleep 3

        # --- Step 2: Reset Kvaser (usbreset works fine for it) ---
        echo "Resetting Kvaser USB device..."
        usbreset 0bfd:0111 2>/dev/null || true
        sleep 2

        # --- Step 3: Escalating PCAN reset ---
        # PCAN-USB FD firmware gets stuck after VM passthrough detach.
        # usbreset won't work (firmware can't respond). Try host-side resets.
        pcan_reset_ok=0

        # Helper: try to rebind PCAN driver and check /proc/pcan.
        try_pcan_rebind() {
          echo "0c72 0012" > /sys/bus/usb/drivers/pcan/new_id 2>/dev/null || true
          sleep 3
          if grep -q "usbfd" /proc/pcan 2>/dev/null; then
            return 0
          fi
          return 1
        }

        # Method 1: USB unbind/rebind (lightest — tears down USB connection at host level).
        PCAN_DEV=$(${findUsbDev} 0c72 0012) || true
        if [ -n "$PCAN_DEV" ]; then
          echo "PCAN reset: Method 1 — USB unbind/rebind ($PCAN_DEV)..."
          echo -n "$PCAN_DEV" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null || true
          sleep 2
          echo -n "$PCAN_DEV" > /sys/bus/usb/drivers/usb/bind 2>/dev/null || true
          sleep 2
          if try_pcan_rebind; then
            echo "PCAN recovered via Method 1 (unbind/rebind)."
            pcan_reset_ok=1
          fi
        else
          echo "PCAN reset: could not find USB device, skipping Method 1."
        fi

        # Method 2: Authorized toggle (different kernel code path — full re-enumeration).
        if [ "$pcan_reset_ok" -eq 0 ]; then
          PCAN_DEV=$(${findUsbDev} 0c72 0012) || true
          if [ -n "$PCAN_DEV" ]; then
            echo "PCAN reset: Method 2 — authorized toggle ($PCAN_DEV)..."
            echo 0 > /sys/bus/usb/devices/$PCAN_DEV/authorized 2>/dev/null || true
            sleep 2
            echo 1 > /sys/bus/usb/devices/$PCAN_DEV/authorized 2>/dev/null || true
            sleep 2
            if try_pcan_rebind; then
              echo "PCAN recovered via Method 2 (authorized toggle)."
              pcan_reset_ok=1
            fi
          else
            echo "PCAN reset: could not find USB device, skipping Method 2."
          fi
        fi

        # Method 3: xHCI controller reset (nuclear — resets entire host controller).
        # PCAN is on Bus 3 → xHCI controller 0000:04:00.4.
        # Kvaser is on Bus 1 → xHCI controller 0000:04:00.3 (safe, not touched).
        if [ "$pcan_reset_ok" -eq 0 ]; then
          echo "PCAN reset: Method 3 — xHCI controller reset (0000:04:00.4)..."
          echo -n "0000:04:00.4" > /sys/bus/pci/drivers/xhci_hcd/unbind 2>/dev/null || true
          sleep 3
          echo -n "0000:04:00.4" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
          sleep 3
          if try_pcan_rebind; then
            echo "PCAN recovered via Method 3 (xHCI controller reset)."
            pcan_reset_ok=1
          fi
        fi

        if [ "$pcan_reset_ok" -eq 0 ]; then
          echo "WARNING: All PCAN reset methods failed!"
        fi

        # --- Step 4: Reload Kvaser modules and rebind ---
        modprobe kvcommon 2>/dev/null || true
        modprobe mhydra 2>/dev/null || true
        sleep 1
        echo "0bfd 0111" > /sys/bus/usb/drivers/mhydra/new_id 2>/dev/null || true

        # --- Step 5: Final wait for PCAN readiness ---
        if [ "$pcan_reset_ok" -eq 0 ]; then
          echo "Polling /proc/pcan for late recovery..."
          for i in $(seq 1 30); do
            if grep -q "usbfd" /proc/pcan 2>/dev/null; then
              echo "PCAN ready after ''${i}s (late recovery)"
              pcan_reset_ok=1
              break
            fi
            sleep 1
          done
        fi

        if [ "$pcan_reset_ok" -eq 0 ]; then
          echo "ERROR: PCAN device not available in /proc/pcan after all reset attempts."
          exit 1
        fi

        echo "All CAN devices returned to host successfully."
        sleep 2
      '';
    };

  };
}
