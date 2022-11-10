/*
 * Copyright (c) Carlo Caione <ccaione@baylibre.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <autoconf.h>
#include <zephyr/linker/sections.h>
#include <zephyr/devicetree.h>

#include <zephyr/linker/linker-defs.h>
#include <zephyr/linker/linker-tool.h>

#define SHMEM_START_ADDR 0x37000000
#define SRAM2_ADDR       0x38000000
#define SRAM2_SIZE       0x00100000

#define SHMEM_RESERVED_HEADERS 4K
#define SHMEM_RESERVED_SIZE (16384 * 1K)

MEMORY
{
    shmem0 (rw) : ORIGIN = (SHMEM_START_ADDR + SHMEM_RESERVED_HEADERS), LENGTH = (SHMEM_RESERVED_SIZE - SHMEM_RESERVED_HEADERS)
    SRAM2                  (wx) : ORIGIN = (SRAM2_ADDR), LENGTH = SRAM2_SIZE
}

SECTIONS
{
    shmem0 (NOLOAD): {
        __shmem0_start = .;
        KEEP(*(.shared.vring.*));
        __shmem0_pool_start = .;
        __shmem0_end = __shmem0_start + (SHMEM_RESERVED_SIZE - SHMEM_RESERVED_HEADERS);
    } > shmem0
    text :
    {
        . = ALIGN(_region_min_align);
        __text_region_start = .;
        z_mapped_start = .;
        *(.text)
        *(".text.*")
        *(.gnu.linkonce.t.*)
        *(.glue_7t) *(.glue_7) *(.vfp11_veneer) *(.v4_bx)
        __text_region_end = .;
        . = ALIGN(_region_min_align);
    } > SRAM2
#if 0
    bss (NOLOAD) : ALIGN(_region_min_align)
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss)
        *(".bss.*")
        *(COMMON)
        *(".kernel_bss.*")
        __bss_end = ALIGN(4);
    } > SRAM2
    noinit (NOLOAD) :
    {
            *(.noinit)
            *(".noinit.*")
    } > SRAM2
#endif
}

#include <zephyr/arch/arm/aarch32/cortex_r/scripts/linker.ld>
