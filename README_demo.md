# Hypervisorless virtio binary demo (openamp/demo-lite)

A binary-only version of the hypervisorless virtio setup can be used in a containerized deployment based on the openamp/demo-lite image from Docker Hub.

```
you@your-machine:~$ docker run -it openamp/demo-lite
dev@openamp-demo:~$ qemu-zcu102 ./demo4
```

Let U-boot autoboot, don’t stop it. U-boot will tftp load uEnv.txt which will tftp load the kernel, dtb, and cpio. Use root as user to login to the A53 terminal.

You can run ```./demo4``` or ```cat demo4``` and follow the commands.

When the Physical Machine Monitor starts, you will see an output similar to
```
/hvl/lkvm run --debug --vxworks --rsld --pmm --debug-nohostfs --transport mmio --shmem-addr 0x37000000 --shmem-size 0x1000000 --cpus 1 --mem 128 --no-dtb --debug --rng --network mode=tap,tapif=tap0,trans=mmio --vproxy
  Info: (virtio/mmio.c) virtio_mmio_init:620: virtio-mmio.devices=0x200@0x37000000 [0x4d564b4c:0x4]
[   48.008155] IPv6: ADDRCONF(NETDEV_CHANGE): tap0: link becomes ready
  Info: (virtio/mmio.c) virtio_mmio_init:620: virtio-mmio.devices=0x200@0x37000200 [0x4d564b4c:0x1]
```


You can see the results of the entropy test in the Zephyr console in the 2nd UART and interact with the system using shell commands.

E.g. Show the network interface configuration on Zephyr and ping the back-end (PetaLinux) runtime.
```
uart:~$ device list
devices:
- sys_clock (READY)
- UART_1 (READY)
- rpu_0_ipi (READY)
- virtio1 (READY)
- virtio0 (READY)
- virt-rng (READY)
  requires: virtio0
- virt-net (READY)
  requires: virtio1
uart:~$ net iface

Interface 0x78109a70 (Ethernet) [1]
===================================
Link addr : 00:00:00:00:00:00
MTU       : 1500
Flags     : AUTO_START,IPv4
Ethernet capabilities supported:
IPv4 unicast addresses (max 1):
        192.168.200.2 manual preferred infinite
IPv4 multicast addresses (max 1):
        <none>
IPv4 gateway : 0.0.0.0
IPv4 netmask : 255.255.255.0
DHCPv4 lease time : 0
DHCPv4 renew time : 0
DHCPv4 server     : 0.0.0.0
DHCPv4 requested  : 0.0.0.0
DHCPv4 state      : disabled
DHCPv4 attempts   : 0

uart:~$ net ping -c 10 192.168.200.254
PING 192.168.200.254
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=0 ttl=64 time=291 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=1 ttl=64 time=149 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=2 ttl=64 time=180 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=3 ttl=64 time=243 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=4 ttl=64 time=241 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=5 ttl=64 time=240 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=6 ttl=64 time=167 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=7 ttl=64 time=168 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=8 ttl=64 time=272 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=9 ttl=64 time=157 ms
```

When you are ready to stop, from the QEMU pane input Ctrl-A x and the QEMU instance will terminate.

Refer to [https://github.com/danmilea/hypervisorless_virtio_zcu102/blob/main/README.md](https://github.com/danmilea/hypervisorless_virtio_zcu102/blob/main/README.md) for information on creating a hypervisorless virtio build environment.