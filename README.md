# kernel

Some learning methods about the linux kernel

## How to debug kernel

- [crash](./dbg_meth/crash.md)

crash can help you analyze kernel dump files, you can know the status of the kernel when the system crashes, including running processes, CPU register content, stack information, and so on

- [gdb](./dbg_meth/gdb.md)

gdb can help you execute code line by line during program execution, set breakpoints, view the value of variables, and check the function call stack, including dynamically allocated memory and stack memory

- [kdump](./dbg_meth/kdump.md)

When the system crashes, kdump collects core dump information and saves it to the disk. When a critical error occurs or the system crashes, kdump automatically collects core dump information, including key information about the system status, such as memory image, CPU register status, and process information

## some config

- [you can refer here](./config)	These configurations will help you get started quickly./config)

## Some tools commands

- [vim](./commands/vim_command.md)	[ctags](./commands/ctags.md)
