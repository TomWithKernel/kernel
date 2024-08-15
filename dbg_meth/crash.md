title: crash

date: 2024-05-10 10:09:00

tags:

categories: dbg_meth

---

# Crash

一个用于分析 Linux 内核转储文件的工具。它提供了一个交互式的环境，让用户能够检查内核转储文件中的信息，包括进程栈、内核数据结构等

### 进入crash环境

```bash
sudo -s
crash /lib/debug/vmlinux
```

### bt

backtrace打印内核栈回溯信息，bt pid 打印指定进程栈信息

```bash
crash> bt 1942
PID: 1942   TASK: ffff88068c957300  CPU: 2   COMMAND: "bash"
 #0 [ffff88062b8f7b48] machine_kexec at ffffffff81051e9b
 #1 [ffff88062b8f7ba8] crash_kexec at ffffffff810f27e2
 #2 [ffff88062b8f7c78] oops_end at ffffffff81689948
 #3 [ffff88062b8f7ca0] no_context at ffffffff816793f1
 #4 [ffff88062b8f7cf0] __bad_area_nosemaphore at ffffffff81679487
 #5 [ffff88062b8f7d38] bad_area_nosemaphore at ffffffff816795f1
 #6 [ffff88062b8f7d48] __do_page_fault at ffffffff8168c6ce
 #7 [ffff88062b8f7da8] do_page_fault at ffffffff8168c863
 #8 [ffff88062b8f7dd0] page_fault at ffffffff81688b48
    [exception RIP: sysrq_handle_crash+22]
    RIP: ffffffff813baf16  RSP: ffff88062b8f7e80  RFLAGS: 00010046
    RAX: 000000000000000f  RBX: ffffffff81a7b180  RCX: 0000000000000000
    RDX: 0000000000000000  RSI: ffff88086ec8f6c8  RDI: 0000000000000063
    RBP: ffff88062b8f7e80   R8: 0000000000000092   R9: 0000000000000e37
    R10: 0000000000000e36  R11: 0000000000000003  R12: 0000000000000063
    R13: 0000000000000246  R14: 0000000000000004  R15: 0000000000000000
    ORIG_RAX: ffffffffffffffff  CS: 0010  SS: 0018
 #9 [ffff88062b8f7e88] __handle_sysrq at ffffffff813bb6d2
#10 [ffff88062b8f7ec0] write_sysrq_trigger at ffffffff813bbbaf
#11 [ffff88062b8f7ed8] proc_reg_write at ffffffff812494bd
#12 [ffff88062b8f7ef8] vfs_write at ffffffff811dee9d
#13 [ffff88062b8f7f38] sys_write at ffffffff811df93f
#14 [ffff88062b8f7f80] system_call_fastpath at ffffffff81691049
    RIP: 00007fb320bcb500  RSP: 00007ffde533c198  RFLAGS: 00000246
    RAX: 0000000000000001  RBX: ffffffff81691049  RCX: ffffffffffffffff
    RDX: 0000000000000002  RSI: 00007fb3214eb000  RDI: 0000000000000001
    RBP: 00007fb3214eb000   R8: 000000000000000a   R9: 00007fb3214d5740
    R10: 0000000000000001  R11: 0000000000000246  R12: 0000000000000001
    R13: 0000000000000002  R14: 00007fb320e9f400  R15: 0000000000000002
    ORIG_RAX: 0000000000000001  CS: 0033  SS: 002b
```

解析：

可以看到最后几步触发了缺页异常，进入crash_kexec的流程，最后调用 machine_kexec()。这通常是一个硬件相关的函数。它会引导启动捕获内核，从而完成 kdump 的过程。
代码就是走到了sysrq_handle_crash函数首地址+0x22这段命令的时候，触发的缺页异常。

注意：

这里，对应x86-64汇编，应用层下来的系统调用对应的6个参数存放的寄存器依次对应：rdi、rsi、rdx、rcx、r8、r9。对于多于6个参数的，仍存储在栈上。

### log

打印vmcore所在的系统内核dmesg日志信息

```bash
crash> log
[    0.000000] Linux version 4.19.0-amd64-desktop (uos@x86-compile-PC) (gcc version 8.3.0 (Uos 8.3.0.5-1+dde)) (c42ec32bb9fc) #6300 SMP Fri Dec 15 13:53:22 CST 2023
[    0.000000] Command line: BOOT_IMAGE=/vmlinuz-4.19.0-amd64-desktop root=UUID=826567d9-9352-4ab2-a268-e23345c606df ro video=efifb:nobgrt splash quiet DEEPIN_GFXMODE= ima_appraise=off libahci.ignore_sss=1
[    0.000000] KERNEL supported cpus:
[    0.000000]   Intel GenuineIntel
[    0.000000]   AMD AuthenticAMD
[    0.000000]   Hygon HygonGenuine
[    0.000000]   Centaur CentaurHauls
[    0.000000]   zhaoxin   Shanghai  
[    0.000000] x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
[    0.000000] x86/fpu: Supporting XSAVE feature 0x002: 'SSE registers'
[    0.000000] x86/fpu: Supporting XSAVE feature 0x004: 'AVX registers'
[    0.000000] x86/fpu: xstate_offset[2]:  576, xstate_sizes[2]:  256
[    0.000000] x86/fpu: Enabled xstate features 0x7, context size is 832 bytes, using 'compacted' format.
[    0.000000] BIOS-provided physical RAM map:
[    0.000000] BIOS-e820: [mem 0x0000000000000000-0x0000000000086fff] usable
[    0.000000] BIOS-e820: [mem 0x0000000000087000-0x0000000000087fff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000000088000-0x000000000009ffff] usable
[    0.000000] BIOS-e820: [mem 0x00000000000a0000-0x00000000000bffff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000000100000-0x0000000009afffff] usable
[    0.000000] BIOS-e820: [mem 0x0000000009b00000-0x0000000009dfffff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000009e00000-0x0000000009efffff] usable
[    0.000000] BIOS-e820: [mem 0x0000000009f00000-0x0000000009f0afff] ACPI NVS
[    0.000000] BIOS-e820: [mem 0x0000000009f0b000-0x00000000970f8fff] usable
[    0.000000] BIOS-e820: [mem 0x00000000970f9000-0x0000000097af8fff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000097af9000-0x00000000add0efff] usable
[    0.000000] BIOS-e820: [mem 0x00000000add0f000-0x00000000aee8efff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000aee8f000-0x00000000af77efff] ACPI NVS
[    0.000000] BIOS-e820: [mem 0x00000000af77f000-0x00000000af7fefff] ACPI data
[    0.000000] BIOS-e820: [mem 0x00000000af7ff000-0x00000000af7fffff] usable
[    0.000000] BIOS-e820: [mem 0x00000000af800000-0x00000000afffffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000f8000000-0x00000000fbffffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fdc00000-0x00000000fec00fff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fec10000-0x00000000fec10fff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fed80000-0x00000000fed80fff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fee00000-0x00000000fee00fff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000ff800000-0x00000000fff3ffff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000100000000-0x000000040effffff] usable
[    0.000000] BIOS-e820: [mem 0x000000040f000000-0x000000044effffff] reserved
[    0.000000] NX (Execute Disable) protection: active
[    0.000000] e820: update [mem 0x94db8018-0x94dc5457] usable ==> usable
[    0.000000] e820: update [mem 0x94db8018-0x94dc5457] usable ==> usable
[    0.000000] extended physical RAM map:
```

### dis

`dis -l (function+offset) 10` 反汇编出指令所在代码，10代表打印该指定位置开始的10行信息

```bash
crash> dis -l do_sys_poll 10
/home/uos/code/workspace/kernel/gerrit-V20-kernel-pipeline/x86-kernel/fs/select.c: 928
0xffffffff8f681540 <do_sys_poll>:       nopl   0x0(%rax,%rax,1) [FTRACE NOP]
0xffffffff8f681545 <do_sys_poll+5>:     push   %rbp
0xffffffff8f681546 <do_sys_poll+6>:     mov    %rsp,%rbp
0xffffffff8f681549 <do_sys_poll+9>:     push   %r15
0xffffffff8f68154b <do_sys_poll+11>:    push   %r14
0xffffffff8f68154d <do_sys_poll+13>:    push   %r13
0xffffffff8f68154f <do_sys_poll+15>:    mov    %esi,%r13d
0xffffffff8f681552 <do_sys_poll+18>:    push   %r12
0xffffffff8f681554 <do_sys_poll+20>:    push   %rbx
0xffffffff8f681555 <do_sys_poll+21>:    and    $0xfffffffffffffff0,%rsp
```

### mod

mod 查看当时内核加载的所有内核模块信息

```bash
crash> mod
     MODULE       NAME                 SIZE    OBJECT        FILE
ffffffffc01ee200  button               20480   (not loaded)  [CONFIG_KALLSYMS]
ffffffffc0211f00  hid                  139264  (not loaded)  [CONFIG_KALLSYMS]
ffffffffc021a0c0  ecb                  16384   (not loaded)  [CONFIG_KALLSYMS]
```

### sym

`sym 00007fb320bcb500 (内存地址)`   转换指定符号为其虚拟地址，显示系统中对应的符号表信息，并且具体到源代码的那一行

```bash
crash> sym ffffffffc07c5024
ffffffffc07c5024 (t) my_openat+36 [my_test_lkm] /mnt/hgfs/test_ko/lkm-test05/my_lkm.c: 25
```

### ps

ps 打印内核崩溃时，正常的进程信息

带 > 标识代表是活跃的进程，ps pid打印某指定进程的状态信息：

```bash
crash> ps 27005
   PID    PPID  CPU       TASK        ST  %MEM     VSZ    RSS  COMM
> 27005   7783   1  ffff997b388ae180  RU   0.2   91732   4124  pickup
> 
查看指定进程的进程树，显示进程父子关系（ps -p pid） 
crash> ps -p 85151
PID: 0      TASK: ffffffff818b6420  CPU: 0   COMMAND: "swapper/0"
 PID: 1      TASK: ffff881f91dae040  CPU: 28  COMMAND: "init"
  PID: 14544  TASK: ffff881f8d7b05c0  CPU: 11  COMMAND: "init.tfa"
   PID: 85138  TASK: ffff880bab01a400  CPU: 8   COMMAND: "tfactl"
    PID: 85151  TASK: ffff880b7a728380  CPU: 17  COMMAND: "perl"
ps -t [pid]: 显示进程运行时间
```

### files

files pid 打印指定进程所打开的文件信息

```bash
crash> files 1106
PID: 1106   TASK: ffff8bac7d2c0f40  CPU: 0   COMMAND: "lightdm"
ROOT: /    CWD: /
 FD       FILE            DENTRY           INODE       TYPE PATH
  0 ffff8bac747f8900 ffff8bac7f00a000 ffff8bac7d02bad0 CHR  /dev/null
  1 ffff8bac747f9e00 ffff8bac7a23cd80 ffff8bac7abb5570 SOCK UNIX
  2 ffff8bac747f9e00 ffff8bac7a23cd80 ffff8bac7abb5570 SOCK UNIX
  3 ffff8bac794fdc00 ffff8bac7a0fd980 ffff8bac7ca64000 UNKN [eventfd]
  4 ffff8bac794fd700 ffff8bac7a0fc780 ffff8bac7a1771e0 FIFO 
  5 ffff8bac794fde00 ffff8bac7a0fc780 ffff8bac7a1771e0 FIFO 
  6 ffff8bac794fd400 ffff8bac66e9ecc0 ffff8bac7a1ec928 REG  /var/var/log/lightdm/lightdm.log
  7 ffff8bac794fc700 ffff8bac66e9e000 ffff8bac7ca64000 UNKN [eventfd]
  8 ffff8bac74d4d300 ffff8bac7a3ad680 ffff8bac7988d1a8 DIR  /var/var/lib/lightdm/data
  9 ffff8bac78f1d700 ffff8bac7a08cb40 ffff8bac7a090b30 SOCK UNIX
 10 ffff8bac73e40500 ffff8bac7985aa80 ffff8bac7ca64000 UNKN [eventfd]
 11 ffff8bac731c6b00 ffff8bac775a8000 ffff8bac7abfee30 SOCK UNIX
 15 ffff8bac74670900 ffff8bac7772e000 ffff8bac7aa704c0 FIFO 
 16 ffff8bac74670e00 ffff8bac7772ef00 ffff8bac7aa72860 FIFO 
 22 ffff8bac69130900 ffff8bac7772f500 ffff8bac7aa710a0 FIFO
```

### vm

vm pid 打印某指定进程当时虚拟内存基本信息

```bash
crash> vm 1106
PID: 1106   TASK: ffff8bac7d2c0f40  CPU: 0   COMMAND: "lightdm"
       MM               PGD          RSS    TOTAL_VM
ffff8bac695bf700  ffff8bac6ce42000  9504k   309268k 
      VMA           START       END     FLAGS FILE
ffff8bac71486a90 563c12926000 563c1292d000 8000871 /usr/sbin/lightdm
ffff8bac714872b0 563c1292d000 563c12957000 8000875 /usr/sbin/lightdm
ffff8bac71486750 563c12957000 563c1296a000 8000871 /usr/sbin/lightdm
ffff8bac71487110 563c1296b000 563c1296c000 8100871 /usr/sbin/lightdm
ffff8bac713be340 563c1296c000 563c1296d000 8100873 /usr/sbin/lightdm
ffff8bac713be5b0 563c13820000 563c138ae000 8100073 
ffff8bac6ce94270 7fa728000000 7fa72802d000 8200073
```

### task

task 查看当前进程或指定进程task_struct和thread_info的信息

```bash
crash> task 1106
PID: 1106   TASK: ffff8bac7d2c0f40  CPU: 0   COMMAND: "lightdm"
struct task_struct {
  thread_info = {
    flags = 0, 
    status = 0
  }, 
  state = 1, 
  stack = 0xffffa530038c4000, 
  usage = {
    counter = 2
  }, 
  flags = 4194560, 
  ptrace = 0, 
  wake_entry = {
    next = 0x0
  }, 
  on_cpu = 0, 
  cpu = 0, 
  wakee_flips = 16, 
  wakee_flip_decay_ts = 4295264801, 
  last_wakee = 0xffff8bac7d2c1e80, 
	.................
```

### kmem

`kmem -i` 查看内存整体使用情况

`kmem -s`  查看slab使用情况

`kmem [addr]` 搜索地址所属的内存结构

```bash
crash> kmem -i
                 PAGES        TOTAL      PERCENTAGE
    TOTAL MEM  3847813      14.7 GB         ----
         FREE  2437856       9.3 GB   63% of TOTAL MEM
         USED  1409957       5.4 GB   36% of TOTAL MEM
       SHARED   197787     772.6 MB    5% of TOTAL MEM
      BUFFERS    43217     168.8 MB    1% of TOTAL MEM
       CACHED   984251       3.8 GB   25% of TOTAL MEM
         SLAB    73599     287.5 MB    1% of TOTAL MEM

   TOTAL HUGE        0            0         ----
    HUGE FREE        0            0    0% of TOTAL HUGE

   TOTAL SWAP  3971839      15.2 GB         ----
    SWAP USED        0            0    0% of TOTAL SWAP
    SWAP FREE  3971839      15.2 GB  100% of TOTAL SWAP

 COMMIT LIMIT  5895745      22.5 GB         ----
    COMMITTED  1660064       6.3 GB   28% of TOTAL LIMIT
```

### struct

```bash
struct [struct]              //查看结构体成员变量
struct -o [struct]           //显示结构体中成员的偏移
struct [struct] [address]    //显示对应地址结构体的值
[struct] [address]           //简化形式显示对应地址结构体的值
[struct] [address] -xo       //打印结构体定义和大小
[struct].member[address]     //显示某个成员的值
```

```bash
crash> struct dentry
struct dentry {
    unsigned int d_flags;
    seqcount_t d_seq;
    struct hlist_bl_node d_hash;
    struct dentry *d_parent;
    struct qstr d_name;
    struct inode *d_inode;
    unsigned char d_iname[32];
    struct lockref d_lockref;
    const struct dentry_operations *d_op;
    struct super_block *d_sb;
    unsigned long d_time;
    void *d_fsdata;
    union {
        struct list_head d_lru;
        wait_queue_head_t *d_wait;
    };
    struct list_head d_child;
    struct list_head d_subdirs;
    union {
        struct hlist_node d_alias;
        struct hlist_bl_node d_in_lookup_hash;
        struct callback_head d_rcu;
    } d_u;
}
SIZE: 192
```

```bash
crash> struct -o dentry
struct dentry {
    [0] unsigned int d_flags;
    [4] seqcount_t d_seq;
    [8] struct hlist_bl_node d_hash;
   [24] struct dentry *d_parent;
   [32] struct qstr d_name;
   [48] struct inode *d_inode;
   [56] unsigned char d_iname[32];
   [88] struct lockref d_lockref;
   [96] const struct dentry_operations *d_op;
  [104] struct super_block *d_sb;
  [112] unsigned long d_time;
  [120] void *d_fsdata;
        union {
  [128]     struct list_head d_lru;
  [128]     wait_queue_head_t *d_wait;
        };
  [144] struct list_head d_child;
  [160] struct list_head d_subdirs;
        union {
            struct hlist_node d_alias;
            struct hlist_bl_node d_in_lookup_hash;
            struct callback_head d_rcu;
  [176] } d_u;
}
SIZE: 192
```

```bash
crash> struct  dentry.d_name
struct dentry {
   [32] struct qstr d_name;
}
```

```bash
crash> struct dentry ffffffff8fbed352
struct dentry {
  d_flags = 3905390920, 
  d_seq = {
    sequence = 4287371206
  }, 
  d_hash = {
    next = 0x9d8bf8349c78949, 
    pprev = 0x450850f000000
  }, 
  d_parent = 0x334865d0458b4800, 
  d_name = {
    {
      {
        hash = 2630916, 
        len = 2232352768
      }, 
      hash_len = 9587882131697706244
    }, 
    name = 0x30c4834800000562 <Address 0x30c4834800000562 out of bounds>
  }, 
  d_inode = 0x415e415d415c415b,
```

如果要查看二阶指针的值，可以通过rd命令需要先获取一级指针的值，然后再用struct 结构体名 + addr获取具体的值

### rd

读取内存内容

`rd [addr] [len]`                    //查看指定地址，长度为len的内存
`rd -S [addr][len]`                //尝试将地址转换为对应的符号
`rd [addr] -e [addr]`            //查看指定内存区域内容

```bash
crash> rd ffffffff8fbed352 32
ffffffff8fbed352:  ff8c17c6e8c78948 09d8bf8349c78949   H.......I..I....
ffffffff8fbed362:  000450850f000000 334865d0458b4800   .....P...H.E.eH3
ffffffff8fbed372:  850f000000282504 30c4834800000562   .%(.....b...H..0
ffffffff8fbed382:  415e415d415c415b 2140c0c748c35d5f   [A\A]A^A_].H..@!
ffffffff8fbed392:  1e3c050348650002 00000b8c80837042   ..eH..<.Bp......
ffffffff8fbed3a2:  f641fffffd88e901 0f01000007412484   ......A..$A.....
ffffffff8fbed3b2:  0009bafffffdf785 df8948e6894c0000   ..........L..H..
ffffffff8fbed3c2:  44c741ff8c49f9e8 f641000000006c24   ..I..A.D$l....A.
ffffffff8fbed3d2:  0f02000004c82484 44f6410000032785   .$.......'...A.D
ffffffff8fbed3e2:  fffdcc840f202424 8b495de8e7894cff   $$ ......L...]I.
ffffffff8fbed3f2:  0fc08548c68949ff 3c408bfffffdb884   .I..H.........@<
ffffffff8fbed402:  4c00022140c5c749 4890509720c52c03   I..@!..L.,. .P.H
ffffffff8fbed412:  486500022140c0c7 394970421db80503   ..@!..eH....BpI9
ffffffff8fbed422:  6500000456850fc5 00015cc025048b48   ...V...eH..%.\..
ffffffff8fbed432:  00044b840fc63949 0000079c868d4900   I9...K...I......
ffffffff8fbed442:  e8b8458948c78948 3475c08500005b12   H..H.E...[....u4
```

### p

p命令可以用来打印出表达式或者变量的值

```bash
crash> p __schedule
__schedule = $1 = 
 {void (bool)} 0xffffffff8fbed0b0
```