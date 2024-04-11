# OpenAMP virtio - quick reference

The OpenAMP library includes experimental support for VIRTIO MMIO drivers in its [virtio-exp](https://github.com/OpenAMP/open-amp/tree/virtio-exp) branch. Virtio device drivers for network, console and entropy can be easily created using the API provided by lib OpenAMP, with minimal glue code provided by the target operating system.

Zephyr is our runtime of choice for demonstrating **virtio** and we have samples demonstrating standard virtio with QEMU ARM as virtual machine monitor on a **qemu_cortex_a53** target.

**qemu_cortex_r5** is the target for **[hypervirorless virtio](https://github.com/danmilea/hypervisorless_virtio_zcu102/blob/main/README_hypervisorless_virtio.md)**, in a configuration based on the Xilinx ZCU 102 platform. In this case, the virtio back-ends are implemented in a [fork of the kvmtool VMM](https://github.com/OpenAMP/kvmtool-openamp-staging/tree/hvl-integration), which is available in the OpenAMP System Reference repository on GitHub.

The Zephyr-specific implementation can be examined here:
- Virtio MMIO: https://github.com/OpenAMP/openamp-zephyr-staging/tree/virtio-exp/drivers/virtio
- Zephyr Virtio samples:
  - network: https://github.com/OpenAMP/zephyr-openamp-staging/tree/virtio-exp/samples/virtio/net/dhcp
  - console: https://github.com/OpenAMP/zephyr-openamp-staging/tree/virtio-exp/samples/virtio/serial/shell_poll
  - entropy: https://github.com/OpenAMP/zephyr-openamp-staging/tree/virtio-exp/samples/virtio/entropy
  - hypervisorless virtio (network and entropy): https://github.com/OpenAMP/zephyr-openamp-staging/tree/virtio-exp/samples/virtio/hvl_net_rng_reloc

Each of the samples includes a README file with usage instructions.