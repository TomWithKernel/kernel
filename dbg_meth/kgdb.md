---
title: kgdb
date: 2024-09-05 10:44:35
tags: dbg_meth
categories: dbg_meth

---

## KGDB

kgdb是Linux内核提供的用于调试内核的源码级调试工具，支持断点设置，单步调试等源码调试常用功能，类似于在用户空间用gdb调试应用程序。kgdb从形式上来说类似于gdb server，你需要两台设备，一台主机，用于运行普通的gdb程序，一台被调试设备，需要安装所需调试的内核或者驱动，同时运行kgdb。kgdb与主机通过串口通讯，所以要在内核的启动参数里指定kgdb所需使用的串口设备号。

### 配置内核

| 配置名称                   | 作用                                             |
| -------------------------- | ------------------------------------------------ |
| CONFIG_KGDB_SERIAL_CONSOLE | 使KGDB通过串口与主机通信(使用串口KGDB时必须打开) |
| CONFIG_KGDB_KDB            | 打开KGDB调试+KDB支持                             |
| CONFIG_DEBUG_INFO          | 使内核包含基本调试信息                           |
| CONFIG_DEBUG_KERNEL        | 包含驱动调试信息                                 |
| CONFIG_GDB_SCRIPTS         | 用于支持vmlinux-gdb.py扩展                       |

### 设置kgdboc参数

`kgdboc` 是kgdb over consle的缩写，用来指定内核调试信息从哪里输出，这里我们使用了ttyUSB0串口输出，未来gdb便需要连接到对应串口来接收调试数据。

`kgdbwait` 该参数可以让内核启动时准备好数据后等待gdb接入再继续启动内核。

#### 方法1：

主要用于调试内核初始化，在kernel的启动参数上添加`kgdboc=ttyXXX,115200 kgdbwait`，前者设置测试机使用的串口，后者数字设置波特率。

{% note warning %} 

​	kgdbwait这个字符串的作用就是让内核停在刚启动的地方。

{% endnote %}

{% asset_img grub.png grub %}

#### 方法2：

​	在系统启动后，设置进入kgdb模式

```shell
# 设置调试串口
echo "kgdboc=ttyXXX,115200" > /sys/module/kgdboc/parameters/kgdboc

# 设置魔术键，g就是进行KGDB模式
echo g > /proc/sysrq-trigger
```

{% note warning %} 

​	这里设置魔术键执行完后，测试机进入kgdb模块，这时测试机按任何键都不会有任何反应，内核等待接受gdb调试请求

{% endnote %}

### 设置主机串口

```shell
sudo apt install minicom
sudo minicom -s
```

### 开始调试

首先，在主机上安装gdb-multiarch

```shell
sudo apt-get install gdb-multiarch
```

进入到内核源码根目录，执行

```shell
sudo gdb-multiarch vmlinux
```

我们需要设置目标平台，串口波特率，并且通过串口连接到开发板上的kgdb上

```shell
# 设备目标平台
set architecture aarch64
# 设置串口波特率
set serial baud 115200
# 主机通过串口连接到开发板上的kgdb
target remote /dev/ttyUSB0
```

设置成功后会有如下提示：

```shell
(gdb) set architecture aarch64
The target architecture is assumed to be aarch64
(gdb) set serial baud 115200
(gdb) target remote /dev/ttyUSB0
Remote debugging using /dev/ttyUSB0
arch_kgdb_breakpoint () at ./arch/arm64/include/asm/kgdb.h:21
21		asm ("brk %0" : : "I" (KGDB_COMPILED_DBG_BRK_IMM));
```

###  agent-proxy

kgdb目前有一个问题，它和测试机的Linux终端共用一个串口，所以在进行信息输出的时候无法使用kgdb，因为kgdb还等着使用该串口，一般测试机只有一个串口，这就给调试带来了很大的麻烦，因为一般驱动是要应用程序调用的，也就是说我在调试时可能需要不停的在kgdb和终端之间来回切换，因为经常需要运行程序，停下程序，甚至输入一些参数。而且在实际的过程当中，切换也会有问题。

官网解释：

{% asset_img kgdb_bug.png kgdb %}

也就是说官网目前已知该问题

这时我们需要一个工具agent-proxy

源码地址：https://git.kernel.org/pub/scm/utils/kernel/kgdb/agent-proxy.git/

```shell
git clone https://git.kernel.org/cgit/utils/kernel/kgdb/agent-proxy.git/
```

下载源码后。在源码目录下直接`make`即可，然后创建软连接到/bin目录下

```shell
sudo ln -s /media/uos/work_kernel/agent-proxy-1.97/agent-proxy /usr/bin/agent-proxy
```

#### 启动调试

启动代理，将串口映射成两个本地网络端口

```shell
agent-proxy 5550^5551 0 /dev/ttyUSB0,115200
```

telnet登录一个端口，充当控制台

```shell
telnet localhost 5550
```

gdb连接另一个端口，充当调试通道

```shell
target remote localhost:5551
```

#### 驱动调试

如果调试某个驱动我们需要打开驱动文件所在rootfs文件夹，使用`insmod`安装.ko驱动，然后输入如下命令：

```shell
sudo cat /sys/module/usbhid/sections/.text

0xffffffffc014d000
```

为什么要获取这个.text信息：

直接用.ko文件调试，可能无法设置断点，在内核模块的调试中，GDB 需要知道模块代码在内存中的实际位置，以便正确设置断点。如果内核启用了 `CONFIG_RANDOMIZE_BASE`（即启用地址随机化），模块的加载地址可能会发生变化，通过获取模块的 `.text` 段的实际地址，调试工具可以根据这些信息来调整断点的位置。	

解决地址随机化问题：

在内核中启用了地址随机化（KASLR，Kernel Address Space Layout Randomization）时，内核模块的加载地址会被随机化，这使得直接在源代码中设置断点变得困难。获取模块的 `.text` 段信息有助于了解实际的加载地址，从而在调试时提供正确的断点信息。

也可以在启动参数添加`nokaslr kgdboc=ttyUSB0,115200 kgdbwait`

接着输入：

```shell
echo g > /proc/sysrq-trigger
```

这个指令是触发kgdb运行的，输入该指令后，内核就会停下，等待远端gdb连接。

然后在主机打开新的终端，进入驱动源码所在目录，输入如下指令：

```shell
sudo gdb-multiarch
(gdb) set architecture aarch64
The target architecture is assumed to be aarch64
(gdb) set serial baud 115200
#将这个地址信息告知 GDB，以便它可以正确地设置断点
(gdb) add-symbol-file /path/to/usbhid.ko 0xffffffffc014d000
# 主机通过串口连接到测试机上的kgdb
(gdb) target remote localhost:5551
```

#### add-symbol-file

```shell
(gdb) add-symbol-file {filename} {addr}
```

`{filename}` 是你要加载的符号文件的路径，通常是一个带有调试符号的可执行文件或库文件。

`{addr}` 是该符号文件在内存中的基地址（装载地址），告诉 GDB 这个文件的代码段被加载到哪个内存地址上。

`add-symbol-file` 命令在 GDB 中用于动态加载调试符号文件，并指定该文件的装载地址。它的作用是告诉 GDB 某个特定的二进制文件在内存中的加载位置，以便调试。

如果你的系统有很多ko，这将是很麻烦的事情，所以我们进行替代使用`lx-symbols`命令，可以自动查找所有ko文件并加载符号。

首先执行以下命令：

```shell
(gdb) add-auto-load-safe-path ./	#指定./路径为可信的路径，便于gdb执行启动的python脚本
(gdb) file vmlinux					#指定符号文件
(gdb) source vmlinux-gdb.py			#执行./vmlinux-gdb.py添加环境用于kgdb的命令扩展
(gdb) target remote localhost:5551
```

### kgdb扩展命令

```shell
(gdb) lx-
lx-clk-summary        lx-device-list-class  lx-iomem              lx-ps
lx-cmdline            lx-device-list-tree   lx-ioports            lx-symbols
lx-configdump         lx-dmesg              lx-list-check         lx-timerlist
lx-cpus               lx-fdtdump            lx-lsmod              lx-version
lx-device-list-bus    lx-genpd-summary      lx-mounts  
```

对于`(gdb) lx-symbols`时出现：

```shell
Python Exception <class 'gdb.MemoryError'> Cannot access memory at address
```

修改`scripts/gdb/linux/symbols.py`中`_section_arguments`函数

```python
    def _section_arguments(self, module):
        try:
            sect_attrs = module['sect_attrs'].dereference()
            attrs = sect_attrs['attrs']
            section_name_to_address = {
                attrs[n]['battr']['attr']['name'].string(): attrs[n]['address']
                for n in range(int(sect_attrs['nsections']))}
        except gdb.error:
            return ""
        args = []
        for section_name in [".data", ".data..read_mostly", ".rodata", ".bss",
                            ".text", ".text.hot", ".text.unlikely"]:
            address = section_name_to_address.get(section_name)
            if address:
                args.append(" -s {name} {addr}".format(
                    name=section_name, addr=str(address)))
        return "".join(args)
```

### 注意事项

在用gdb来调试内核的时候，由于内核在初始化的时候，会创建很多子线程。而默认gdb会接管所有的线程，如果你从一个线程切换到另外一个线程，gdb会马上把原先的线程暂停。但是这样很容易导致kernel死掉，所以需要设置一下gdb。 
一般用gdb进行多线程调试，需要注意两个参数：`follow-fork-mode`和`detach-on-fork`

`detach-on-fork`：

- `on`：在 `fork` 之后，GDB 会断开对子进程的调试，仅继续调试父进程。
- `off`：GDB 将继续调试父进程和子进程。需要注意，这可能会导致调试会话变得非常复杂，因为 GDB 会同时控制多个进程。

```shell
(gdb) set detach-on-fork on
```

`follow-fork-mode`：

- `parent`：在 `fork` 之后，GDB 继续调试父进程，而子进程将处于暂停状态。
- `child`：在 `fork` 之后，GDB 继续调试子进程，而父进程将处于暂停状态。

```shell
(gdb) set follow-fork-mode child
```

