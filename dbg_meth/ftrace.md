---
title: ftrace
date: 2024-08-22 10:33:06
tags: dbg_meth
categories: dbg_meth

---

### 什么是ftrace

​	ftrace是 Linux 内核中一个功能强大的跟踪框架，用于跟踪和分析内核及其模块的执行情况。它提供了一系列工具和功能，帮助开发者调试内核、分析性能瓶颈、查看系统调用、函数调用、上下文切换等信息。

​	`ftrace` 的主要功能：

1. **函数跟踪** (`function tracing`):
   - 可以跟踪内核中每个函数的调用情况，包括函数进入、退出的时间和执行时间。
   - 例如，可以跟踪某个特定函数的调用频率及其调用者。
2. **函数调用图** (`function graph tracing`):
   - 记录函数调用的完整调用栈。与简单的函数跟踪不同，函数调用图会显示函数的调用关系以及调用链中的每个函数的执行时间。
3. **系统调用跟踪**:
   - 可以跟踪所有的系统调用或特定的系统调用，从而了解用户空间程序如何与内核交互。
4. **调度器跟踪**:
   - `ftrace` 可以记录和分析调度器行为，比如任务切换、任务调度延迟等，帮助分析多任务系统中的调度性能。
5. **事件跟踪**:
   - `ftrace` 支持各种内核事件的跟踪（例如，IRQ 处理、中断、软中断等），并允许用户定义和过滤感兴趣的事件。

传统的ftrace操作较为繁琐，需要向多个文件写入信息，当前我们紧介绍ftrace前端工具：trace-cmd

### trace-cmd

- trace-cmd record：记录实时跟踪数据并将其写入trace.dat 文件

- trace-cmd report：读取 trace.dat 文件并将二进制数据转换为可读的 ASCII 文本格式。

- trace-cmd start：开始跟踪但不记录到 trace.dat 文件。

- trace-cmd stop：停止跟踪。

- trace-cmd extract：从内核缓冲区提取数据并创建 trace.dat 文件。

- trace-cmd reset：禁用所有跟踪并恢复系统性能。



- 查看可用追踪器

```shell
sudo trace-cmd list -t
hwlat blk mmiotrace function_graph wakeup_dl wakeup_rt wakeup function nop
```

- 查看可跟踪的函数

```shell
uos@uos-PC [~/tom-blog] ➜  sudo trace-cmd list -f | grep mmap

xen_hvm_exit_mmap
xen_dup_mmap
xen_exit_mmap
ldt_arch_exit_mmap
__ia32_compat_sys_ia32_mmap
...
```

- 查看可跟踪的事件

```shell
uos@uos-PC [~/tom-blog] ➜  sudo trace-cmd list -e | grep snd

asoc:snd_soc_bias_level_start
asoc:snd_soc_bias_level_done
asoc:snd_soc_dapm_start
asoc:snd_soc_dapm_done
...
```

- 查看函数调用栈

```shell
sudo trace-cmd record -p function -l do_mmap --func-stack

#使用 ctrl-c 退出trace-cmd时，会在当前目录生成 trace.dat文件,使用report读取trace.dat
uos@uos-PC [~] ➜  trace-cmd report | head -20

CPU 0 is empty
cpus=16
    explorer.exe-14504 [008] 1274475.231218: function:             do_mmap
    explorer.exe-14504 [008] 1274475.231223: kernel_stack:         <stack trace>
=> ftrace_trampoline (ffffffffc0d6106a)
=> do_mmap (ffffffff94891c45)
=> vm_mmap_pgoff (ffffffff94869ee4)
=> ksys_mmap_pgoff (ffffffff9488f472)
=> do_syscall_64 (ffffffff951e9690)
=> entry_SYSCALL_64_after_hwframe (ffffffff952000ea)
    explorer.exe-14504 [008] 1274475.231269: function:             do_mmap
    explorer.exe-14504 [008] 1274475.231271: kernel_stack:         <stack trace>
=> ftrace_trampoline (ffffffffc0d6106a)
=> do_mmap (ffffffff94891c45)
=> vm_mmap_pgoff (ffffffff94869ee4)
=> ksys_mmap_pgoff (ffffffff9488f472)
=> do_syscall_64 (ffffffff951e9690)
=> entry_SYSCALL_64_after_hwframe (ffffffff952000ea)
    explorer.exe-14504 [008] 1274475.231285: function:             do_mmap
    explorer.exe-14504 [008] 1274475.231286: kernel_stack:         <stack trace>

```

命令解释：

- `-p`：指定当前的 tracer，类似 `echo function > current_tracer`，可以是支持的 tracer 中的任意一个
- `-l`：指定跟踪的函数，可以设置多个，类似 `echo function_name > set_ftrace_filter`
- `--func-stack`：记录被跟踪函数的调用栈

- -n 指定不跟踪的函数
  - 比如：`trace-cmd record -p function -l 'dev*' -n dev_attr_show`
  - 设置跟踪所有 dev 开头的函数，但是不跟踪 `dev_attr_show`

- `-g`：指定 function_graph tracer 跟踪的 函数，类似 `echo function_name > set_graph_function`
- `-O`：设置 options，比如设置 `options/func_stack_trace` 可以用 `-O func_stack_trace`，在 optoin 名称前加上 `no` 就是将 option 清 0
- `-P`：设置跟踪的进程

注意，function_graph tracer 同时支持 `-l/-g` 参数，但是两者是有区别的，他们区别的本质还是 `set_ftrace_filter` 与 `set_graph_function` 的区别。

- `-l` 表示被跟踪的函数是叶子函数，不会跟踪其内部的调用子函数。
- `-g` 会跟踪函数内部调用的子函数。

​	默认情况下，`trace-cmd` 的 `function_graph` 会记录所有嵌套的函数调用。可以通过设置 `--max-graph-depth` 来限制跟踪深度。例如要将深度设置为 2，可以使用以下命令：

```shell
sudo trace-cmd record -p function_graph --max-graph-depth 2 -P 1656
```



