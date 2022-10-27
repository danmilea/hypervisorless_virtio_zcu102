# Hypervisorless virtio - quick reference

The goal of the "Hypervisorless virtio" initiative is to prototype and define a framework for using virtio as a communication infrastructure between runtimes deployed on heterogeneous CPU clusters (e.g.Cortex A53 <-> Cortex R5).

At its core, virtio makes a set of assumptions which are typically fulfilled by a virtual machine monitor which has complete access to the guest memory space. Removing the hypervisor means:

- Hardware notifications are used instead of VM-exits
- Feature negotiation is replaced by predefined feature lists (optional).
- Virtio can be used without virtualization hardware or virtualization enabled.
- The term virtual machine monitor (VMM) is a misnomer when there is no virtualization so PMM (Physical Machine Monitor) is used instead. The PMM implements the VIRTIO device back-ends.
- A pre-shared memory region is defined by the physical machine monitor (PMM).

## Zephyr-based hypervisorless virtio reference implementation

A set of tools for building a reference deployment of hypervisorless virtio is available here:

https://github.com/danmilea/hypervisorless_virtio_zcu102/

This repository includes the infrastructure required to build and deploy a hypervisorless virtio environment on Xilinx ZCU102 (QEMU) with PetaLinux running on Cortex A53 and Zephyr running on Cortex R5.

The physical machine monitor (PMM) which includes the virtio back-ends runs on PetaLinux and communicates with the Zephyr auxiliary runtime over shared memory.


## Implementation notes

OS-specific API is implemented as weak functions in the OpenAMP library which provides support for hypervisorless virtio.

The runtime (e.g. Zephyr) is responsible for providing the following functionality:

```
/**
 * @brief VIRTIO MMIO shared memory pool initialization routine.
 *
 * @param[in] mem Pointer to memory.
 * @param[in] size Size of memory region in bytes.
 *
 * @return N/A.
 */

void virtio_mmio_shm_pool_init(void *mem, size_t size);

/**
 * @brief VIRTIO MMIO shared memory pool buffer allocation routine.
 *
 * @param[in] size Number of bytes requested.
 *
 * @return pointer to allocated memory space in shared memory region.
 */

void *virtio_mmio_shm_pool_alloc(size_t size);

/**
 * @brief VIRTIO MMIO shared memory pool buffer deallocation routine.
 *
 * @param[in] ptr Pointer to memory space to free.
 *
 * @return N/A.
 */

void virtio_mmio_shm_pool_free(void *ptr);

/**
 * @brief VIRTIO MMIO (hypervisorless mode) inter-processor notification routine.
 *
 * @return N/A.
 */

void virtio_mmio_hvl_ipi(void);

/**
 * @brief VIRTIO MMIO (hypervisorless mode) wait routine.
 *
 * @param[in] usec Number of microseconds to wait.
 *
 * @return N/A.
 */

void virtio_mmio_hvl_wait(uint32_t usec);
```
In order to operate in hypervisorless mode, the VIRTIO MMIO framework in OpenAMP:
- uses the runtime-specific IPI implementation to signal the PMM in situations when a VM-exit would have been triggerred.
- uses the shared memory allocation routines to allocate bounce buffers in the preshared memory area; the API can also be used directly in the virtio device front-end, and in this case the copy is not performed. The virtqueue descriptors are updated transparently in the vqueue add / get code paths, so the virtio device drivers do not need any changes to operate in hypervisorless mode.
- uses the wait routine to implement conditional wait for VIRTIO MMIO configuration items which share the same configuration register (e.g. QPFN)

The Zephyr-specific implementation can be examined here:
- VIRTIO MMIO: https://github.com/OpenAMP/openamp-zephyr-staging/tree/virtio-exp/drivers/virtio
- hypervisorless virtio sample with network and entropy devices: https://github.com/OpenAMP/openamp-zephyr-staging/tree/virtio-exp/samples/virtio/hvl_net_rng

In the Zephyr implementation, the vrings are allocated in the preshared memory area by moving them to their own binary sections which are then moved to the shared memory area using a custom link script (e.g. https://github.com/OpenAMP/openamp-zephyr-staging/blob/virtio-exp/samples/virtio/hvl_net_rng/linker_r5_hvl.ld).


