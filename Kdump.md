# Kdump

kdump是在系统崩溃、死锁、或者死机的时候用来转储内存为vmcore保存到磁盘的一个工具和服务

### 相关配置

```c
CONFIG_KEXEC=y
CONFIG_KEXEC_FILE=y   
//两者选其一，或者都选也可以，对应两个版本的kexec接口

CONFIG_CRASH_DUMP=y   
//内核支持系统崩溃转储功能，即能够生成 vmcore 文件以便进行故障诊断和调试
CONFIG_PROC_VMCORE=y
//内核支持在 /proc 文件系统中生成 vmcore 文件以供调试和分析系统崩溃时的信息
CONFIG_RELOCATABLE=y
//内核能够在运行时进行地址重定位，从而使内核能够在不同的物理内存地址上加载和运行
CONFIG_SYSFS=y
CONFIG_DEBUG_INFO=y
//编译过程中会生成额外的调试信息，包括函数符号，代码注释，宏定义等
```

### 安装用户态工具包

```bash
sudo apt install kdump-tools
sudo apt install makedumpfile
```

### 配置预留内存

配置第一内核启动参数（/etc/default/grub.d/kdump-tools.cfg）：

```bash
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT crashkernel=512M"
```

完整的格式可以是：crashkernel=1G-:512M@3G，其含义是：

- 当内存大于1Ｇ时，预留512Ｍ
- 预留位置在3Ｇ
- 如果“@offset”部分留空的话，内核会自动寻找合适的位置。（一般都不需要指定）
- 在x86虚拟机环境里，直接用crashkernel=512M就能正常运行，但某些架构不行，所以推荐用这个格式：crashkernel=1G-:512M。
- 预留内存大小默认是128Ｍ，一般而言都太小了，建议使用512Ｍ

注意：

- sw内核的crashkernel代码不完整，没有实现自动寻找的功能，所以不指定offset时会默认为offset=0，与第一内核发生冲突而导致系统起不来，此时应该用完整的格式，比如1G-:512M@3G。

配置完成后需要重启系统生效

有两种方式可以确认内核是否正确完成了内存预留：

```bash
sudo dmesg | grep -i crashkernel

[0.008200] Reserving 512MB of memory at 1520MB for crashkernel (System RAM: 4095MB)
```

```bash
sudo cat /proc/iomem

00100000-7ffdbfff : System RAM
01000000-02002287 : Kernel code
02200000-02cb1fff : Kernel rodata
02e00000-0311473f : Kernel data
03449000-039fffff : Kernel bss
5f000000-7effffff : Crash kernel
```

### 触发Kdump

- 手动触发
    - 开启sysrq   `sysctl kernel.sysrq=1`
    - 触发panic   `echo c > /proc/sysrq-trigger`
- oops
- oom
- softlockup/hardlockup
- rcu-stall