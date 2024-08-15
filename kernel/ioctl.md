title: ioctl

date: 2024-07-10 10:09:00

tags:

categories: 

---

## ioctl

在驱动程序的ioctl函数体中，实现了一个switch-case结构，每一个case对应一个命令码，case内部是驱动程序实现该命令的相关操作。

ioctl的实现函数要传递给file_operations结构体中对应的函数指针，函数原型为

```c
#include <linux/ioctl.h>
long (*unlocked_ioctl) (struct file * fp, unsigned int request, unsigned long args);
long (*compat_ioctl) (struct file * fp, unsigned int request, unsigned long args);
```


unlocked_ioctl在无大内核锁（BKL）的情况下调用。64位用户程序运行在64位的kernel，或32位的用户程序运行在32位的kernel上，都是调用unlocked_ioctl函数。

compat_ioctl是64位系统提供32位ioctl的兼容方法，也在无大内核锁的情况下调用。即如果是32位的用户程序调用64位的kernel，则会调用compat_ioctl。如果驱动程序没有实现compat_ioctl，则用户程序在执行ioctl时会返回错误Not a typewriter。

另外，如果32位用户态和64位内核态发生交互时，第三个参数的长度需要保持一致，否则交互协议会出错。

```c
int (*ioctl) (struct inode *inode, struct file *fp, unsigned int request, unsigned long args);
```


在2.6.35.7及以前的内核版本中，file_operations还定义了ioctl()接口，与unlocked_ioctl是等价的。但是在2.6.36以后就不再支持这个接口，全部使用unlocked_ioctl了

以上函数参数的含义如下。
1）inode和fp用来确定被操作的设备。
2）request就是用户程序下发的命令。
3）args就是用户程序在必要时传递的参数。

返回值：可以在函数体中随意定义返回值，这个返回值也会被直接返回到用户程序中。通常使用非负数表示正确的返回，而返回一个负数系统会判定为ioctl调用失败。

三、用户与驱动之间的ioctl协议构成
也就是request或cmd，本质上就是一个32位数字，理论上可以是任何一个数，但为了保证命令码的唯一性，linux定义了一套严格的规定，通过计算得到这个命令吗数字。linux将32位划分为四段

![ioctl](./img/ioctl.png) 

- dir，即direction，表示ioctl命令的访问模式，分为无数据(_IO)、读数据(_IOR)、写数据(_IOW)、读写数据(_IOWR)四种模式。
- type，即device type，表示设备类型，也可翻译成“幻数”或“魔数”，可以是任意一个char型字符，如’a’、‘b’、‘c’等，其主要作用是使ioctl命令具有唯一的设备标识。不过在内核中’w’、‘y’、'z’三个字符已经被使用了。
- nr，即number，命令编号/序数，取值范围0~255，在定义了多个ioctl命令的时候，通常从0开始顺次往下编号。
- size，涉及到ioctl的参数arg，占据13bit或14bit，这个与体系有关，arm使用14bit。用来传递arg的数据类型的长度，比如如果arg是int型，我们就将这个参数填入int，系统会检查数据类型和长度的正确性。

在上面的四个参数都需要用户自己定义，linux系统提供了宏可以使程序员方便的定义ioctl命令码。

```c
include/uapi/asm-generic/ioctl.h
/* used to create numbers */
#define _IO(type,nr)        _IOC(_IOC_NONE,(type),(nr),0)
#define _IOR(type,nr,size)  _IOC(_IOC_READ,(type),(nr),(_IOC_TYPECHECK(size)))
#define _IOW(type,nr,size)  _IOC(_IOC_WRITE,(type),(nr),(_IOC_TYPECHECK(size)))
#define _IOWR(type,nr,size) _IOC(_IOC_READ|_IOC_WRITE,(type),(nr),(_IOC_TYPECHECK(size)))

分别对应了四个dir：
_IO(type, nr)：用来定义不带参数的ioctl命令。
_IOR(type,nr,size)：用来定义用户程序向驱动程序写参数的ioctl命令。
_IOW(type,nr,size)：用来定义用户程序从驱动程序读参数的ioctl命令。
_IOWR(type,nr,size)：用来定义带读写参数的驱动命令。
```

当然了，系统也定义反向解析ioctl命令的宏。

```c
include/uapi/asm-generic/ioctl.h
/* used to decode ioctl numbers */
#define _IOC_DIR(nr)        (((nr) >> _IOC_DIRSHIFT) & _IOC_DIRMASK)
#define _IOC_TYPE(nr)       (((nr) >> _IOC_TYPESHIFT) & _IOC_TYPEMASK)
#define _IOC_NR(nr)     (((nr) >> _IOC_NRSHIFT) & _IOC_NRMASK)
#define _IOC_SIZE(nr)       (((nr) >> _IOC_SIZESHIFT) & _IOC_SIZEMASK
```

