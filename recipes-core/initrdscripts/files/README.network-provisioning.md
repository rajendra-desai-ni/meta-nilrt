# Networked provisioning bootstrap for NILRT recovery

This document explains the minimal flow required to run the recovery provisioning tool from DHCP-connected network media instead of a local USB recovery stick.

## Environment variables

Use the following variables when booting or invoking the recovery environment over the network:

- `NETWORK_BOOTSTRAP_ENABLED=1`
- `PROVISIONING_BUNDLE_URL=http://<server>/ni_provisioning.tar.gz`
- `PROVISION_ANSWERS_URL=http://<server>/ni_provisioning.answers`
- `PAYLOAD_BASE=/netprov/payload`
- `restore=provision-network`

## Minimal remote workflow

1. Boot a minimal initramfs or recovery image on the target.
2. The initramfs runs DHCP on all active NICs.
3. `sshd` or `dropbear` starts so the target can be reached over SSH.
4. The target fetches the provisioning bundle from `PROVISIONING_BUNDLE_URL`.
5. The target fetches answers from `PROVISION_ANSWERS_URL`.
6. The provisioning tool runs with `restore=provision-network`.
7. The existing disk partitioning and RAUC logic completes the install.

## Example answer file

```bash
#NI_PROVISIONING_ANSWERS_V1
PROVISION_TARGET_DISK=/dev/sda
PROVISION_REPARTITION_TARGET=y
PROVISION_REBOOT_METHOD=reboot
restore=provision-network
FORCE_PROVISIONING=0
```

## Example remote invocation

```bash
ssh root@<target-ip>
export NETWORK_BOOTSTRAP_ENABLED=1
export PROVISIONING_BUNDLE_URL=http://10.0.0.10/ni_provisioning.tar.gz
export PROVISION_ANSWERS_URL=http://10.0.0.10/ni_provisioning.answers
export PAYLOAD_BASE=/netprov/payload
export restore=provision-network
/ni_provisioning
```

## Notes

- Local USB recovery remains supported.
- The network path is an addition, not a rewrite of the provisioning engine.
- The real provisioning logic still lives in `ni_provisioning.common` and is left intact.
