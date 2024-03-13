# gdb

**编译程序加参数时生成调试信息**

g 和 -ggdb 都是令 gcc 生成调试信息，但是它们也是有区别的

| 选项 | 解析 |
| --- | --- |
| g | 该选项可以利用操作系统的“原生格式（native format）”生成调试信息。GDB 可以直接利用这个信息，其它调试器也可以使用这个调试信息 |
| ggdb | 使 GCC为GDB 生成专用的更为丰富的调试信息，但是，此时就不能用其他的调试器来进行调试了 (如 ddx) |

g也是分级别的

| 选项 | 解析 |
| --- | --- |
| g1 | 级别1（-g1）不包含局部变量和与行号有关的调试信息，因此只能够用于回溯跟踪和堆栈转储之用。回溯跟踪指的是监视程序在运行过程中的函数调用历史，堆栈转储则是一种以原始的十六进制格式保存程序执行环境的方法，两者都是经常用到的调试手段 |
| g2 | 这是默认的级别，此时产生的调试信息包括扩展的符号表、行号、局部或外部变量信息 |
| g3 | 包含级别2中的所有调试信息，以及源代码中定义的宏 |

## **gdb调试常用命令解析**

### b

break 断点

```bash
break 函数名
break 行号
break 文件名：行号
break 文件名：函数名
break +偏移量
break -偏移量
break *地址
```

```bash
(gdb)b iseq_compile            在函数处加断点
(gdb)b compile.c:516           在文件名和行号处加断点
(gdb)b +3                      设置偏移量
(gdb)b *0x88116fd6             在某地址处加断点
(gdb)b                         如果不指定位置，就是在下一行代码上设置断点
```

设置好的断点可以通过 info break 查看

```bash
(gdb) info break
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x00007febd6225bd9 ../sysdeps/unix/sysv/linux/poll.c:29
```

### disable | enable

临时禁用和启用断点

```bash
(gdb) info b
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x00007f218fcb1bd9 ../sysdeps/unix/sysv/linux/poll.c:29
(gdb) disa
disable      disassemble  
(gdb) disable 1
(gdb) enable 1
```

### r

run 开始运行

### bt

backtrace 命令可以在遇到断点而停止执行时显示栈帧

`bt N`只显示开头N个栈帧

`bt -N`只显示最后N个栈帧

```bash
(gdb) bt
#0  0x00007f218fcb1bd9 in __GI___poll (fds=0x7f218400a060, nfds=2, timeout=-1) at ../sysdeps/unix/sysv/linux/poll.c:29
#1  0x00007f218ff851f6 in ?? () from /lib/x86_64-linux-gnu/libglib-2.0.so.0
#2  0x00007f218ff85582 in g_main_loop_run () from /lib/x86_64-linux-gnu/libglib-2.0.so.0
#3  0x0000563b79c85395 in ?? ()
#4  0x00007f218fbe71fb in __libc_start_main (main=0x563b79c84640, argc=1, argv=0x7ffff90918c8, init=<optimized out>, fini=<optimized out>, rtld_fini=<optimized out>, 
    stack_end=0x7ffff90918b8) at ../csu/libc-start.c:308
#5  0x0000563b79c85ffa in ?? ()
```

`bt full` 不仅显示backtrace，还显示局部变量

```bash
(gdb) bt full
#0  0x00007f218fcb1bd9 in __GI___poll (fds=0x7f218400a060, nfds=2, timeout=-1) at ../sysdeps/unix/sysv/linux/poll.c:29
        resultvar = 18446744073709551100
        sc_cancel_oldtype = 0
        sc_ret = <optimized out>
#1  0x00007f218ff851f6 in ?? () from /lib/x86_64-linux-gnu/libglib-2.0.so.0
No symbol table info available.
#2  0x00007f218ff85582 in g_main_loop_run () from /lib/x86_64-linux-gnu/libglib-2.0.so.0
No symbol table info available.
#3  0x0000563b79c85395 in ?? ()
No symbol table info available.
#4  0x00007f218fbe71fb in __libc_start_main (main=0x563b79c84640, argc=1, argv=0x7ffff90918c8, init=<optimized out>, fini=<optimized out>, rtld_fini=<optimized out>, 
    stack_end=0x7ffff90918b8) at ../csu/libc-start.c:308
        self = <optimized out>
        result = <optimized out>
        unwind_buf = {cancel_jmp_buf = {{jmp_buf = {0, 3044201088132136217, 94813446234064, 140737371510976, 0, 0, 8770247100387114265, 8649937328162159897}, 
              mask_was_saved = 0}}, priv = {pad = {0x0, 0x0, 0x7ffff90918d8, 0x7f21902b2190}, data = {prev = 0x0, cleanup = 0x0, canceltype = -116844328}}}
        not_first_call = <optimized out>
#5  0x0000563b79c85ffa in ?? ()
```

### p

print显示变量

```bash
(gdb) p result
$1 = '\000' <repeats 113 times>
```

### info reg

显示寄存器

```bash
(gdb) info reg
rax            0xfffffffffffffdfc  -516
rbx            0x7f218400a060      139781925281888
rcx            0x7f218fcb1bd9      139782123101145
rdx            0xffffffff          4294967295
rsi            0x2                 2
rdi            0x7f218400a060      139781925281888
rbp            0x2                 0x2
rsp            0x7ffff90913e0      0x7ffff90913e0
r8             0x0                 0
r9             0x1                 1
```

在寄存器之前添加 $，即可以显示各个寄存器的内容

```bash
(gdb) p $rip
$2 = (void (*)()) 0x7f218fcb1bd9 <__GI___poll+73>
```

### x

查看内存地址保存的值

`(gdb) x/nfu addr`

n 是一个正整数，表示显示内存的长度，也就是说从当前地址向后显示几个地址的内容。
f 表示显示的格式，参见上面。如果地址所指的是字符串，那么格式可以是s，如果地十是
指令地址，那么格式可以是i。
u 表示从当前地址往后请求的字节数，如果不指定的话，GDB默认是4个bytes。u参数可
以用下面的字符来代替，b表示单字节，h表示双字节，w表示四字节，g表示八字节。当
我们指定了字节长度后，GDB会从指内存定的内存地址开始，读写指定字节，并把其当作
一个值取出来。

```bash
(gdb) x/3uh 0x54320 //从内存地址0x54320读取内容，h表示以双字节为一个单位，3表示三个单位，u表示按十六进制显示。
```

`x/i $rip`   显示汇编指令

```bash
(gdb) x/i $rip
=> 0x7f218fcb1bd9 <__GI___poll+73>:     cmp    $0xfffffffffffff000,%rax
```

显示寄存器可以使用的格式：
格式                说明
x                   显示为十六进制数
d                   显示为十进制数
u                   显示为无符号十进制数
o                   显示为八进制数
t                   显示为二进制数，t的由来是two
a                   地址
c                   显示为字符(ASCII)
f                   浮点小数
s                   显示为字符串
i                   显示为机器语言(仅在显示内存的X命令中可以使用)

### n

执行下一行语句

### s

单步进入，遇到函数的话就会进入函数的内部，再一行一行的执行。执行完当前函数返回到调用它的函数

### c

continue，继续执行，程序会在遇到断点后再次暂停运行，如果没有遇到断点就会一直运行到结束

continue 次数
指定次数可以忽略断点，例如，continue 5则5次遇断点不停止，第六次遇到断点才停止执行

### finish

跳出当前函数，这里，运行程序，直到当前函数运行完毕返回再停止。例如进入的单步执行如果已经进入了某函数，可以退出该函数返回到它的调用函数中

### forward-search  |  reverse-search

```bash
(gdb) forward-search     //向前面搜索。 
(gdb) reverse-search    //从当前行的开始向后搜索
```

### watch

<表达式>  发生变化时暂停运行

### awatch

<表达式>  被访问，改变时暂停运行

### rwatch

<表达式>  被访问时暂停运行

### info locals

打印出当前函数中所有局部变量以及值

```bash
(gdb) info locals
resultvar = 18446744073709551100
sc_cancel_oldtype = 0
sc_ret = <optimized out>
```

### d

delete 删除断点和监视点

```bash
(gdb) info b
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x0000000000400450 in main at watch.c:10
	breakpoint already hit 1 time
4       breakpoint     keep y   0x0000000000400450 in main at watch.c:10
	breakpoint already hit 1 time

-->删除1号断点
(gdb) d 1
(gdb) info b
Num     Type           Disp Enb Address            What
4       breakpoint     keep y   0x0000000000400450 in main at watch.c:10
	breakpoint already hit 1 time
```

### set variable <变量> = <表达式>

```bash
(gdb)p options
$7 =1
(gdb)set varaable options = 0
(gdb)p options 
$8 = 0
```

### disassemble

用于反汇编函数或指定地址范围的代码，以显示对应的汇编指令

```bash
<address> <+offset>:  <assembly_instruction>  <operands>

<address>：指令的地址
<+offset>：相对于函数或代码块开始处的偏移量
<assembly_instruction>：汇编指令的助记符
<operands>：汇编指令的操作数
在输出中，箭头 => 表示当前执行的指令
```

```bash
disassemble ：默认情况下，会反汇编当前执行点所在的函数或指定地址处的代码。
disassemble function_name ：反汇编指定函数的代码。
disassemble /m address ：从指定地址开始反汇编代码，/m 选项可用于指定反汇编的长度
```

```bash
(gdb) disassemble 
Dump of assembler code for function __GI___poll:
   0x00007f218fcb1b90 <+0>:     lea    0xc6b59(%rip),%rax        # 0x7f218fd786f0 <__libc_multiple_threads>
   0x00007f218fcb1b97 <+7>:     mov    (%rax),%eax
   0x00007f218fcb1b99 <+9>:     test   %eax,%eax
   0x00007f218fcb1b9b <+11>:    jne    0x7f218fcb1bb0 <__GI___poll+32>
   0x00007f218fcb1b9d <+13>:    mov    $0x7,%eax
   0x00007f218fcb1ba2 <+18>:    syscall 
   0x00007f218fcb1ba4 <+20>:    cmp    $0xfffffffffffff000,%rax
   0x00007f218fcb1baa <+26>:    ja     0x7f218fcb1c00 <__GI___poll+112>
   0x00007f218fcb1bac <+28>:    retq   
   0x00007f218fcb1bad <+29>:    nopl   (%rax)
   0x00007f218fcb1bb0 <+32>:    push   %r12
   0x00007f218fcb1bb2 <+34>:    mov    %edx,%r12d
   0x00007f218fcb1bb5 <+37>:    push   %rbp
   0x00007f218fcb1bb6 <+38>:    mov    %rsi,%rbp
   0x00007f218fcb1bb9 <+41>:    push   %rbx
   0x00007f218fcb1bba <+42>:    mov    %rdi,%rbx
   0x00007f218fcb1bbd <+45>:    sub    $0x10,%rsp
   0x00007f218fcb1bc1 <+49>:    callq  0x7f218fcc9a60 <__libc_enable_asynccancel>
   0x00007f218fcb1bc6 <+54>:    mov    %r12d,%edx
   0x00007f218fcb1bc9 <+57>:    mov    %rbp,%rsi
   0x00007f218fcb1bcc <+60>:    mov    %rbx,%rdi
   0x00007f218fcb1bcf <+63>:    mov    %eax,%r8d
   0x00007f218fcb1bd2 <+66>:    mov    $0x7,%eax
   0x00007f218fcb1bd7 <+71>:    syscall 
=> 0x00007f218fcb1bd9 <+73>:    cmp    $0xfffffffffffff000,%rax
   0x00007f218fcb1bdf <+79>:    ja     0x7f218fcb1c12 <__GI___poll+130>
   0x00007f218fcb1be1 <+81>:    mov    %r8d,%edi
   0x00007f218fcb1be4 <+84>:    mov    %eax,0xc(%rsp)
   0x00007f218fcb1be8 <+88>:    callq  0x7f218fcc9ac0 <__libc_disable_asynccancel>
   0x00007f218fcb1bed <+93>:    mov    0xc(%rsp),%eax
   0x00007f218fcb1bf1 <+97>:    add    $0x10,%rsp
   0x00007f218fcb1bf5 <+101>:   pop    %rbx
   0x00007f218fcb1bf6 <+102>:   pop    %rbp
   0x00007f218fcb1bf7 <+103>:   pop    %r12
   0x00007f218fcb1bf9 <+105>:   retq   
   0x00007f218fcb1bfa <+106>:   nopw   0x0(%rax,%rax,1)
   0x00007f218fcb1c00 <+112>:   mov    0xc1269(%rip),%rdx        # 0x7f218fd72e70
   0x00007f218fcb1c07 <+119>:   neg    %eax
   0x00007f218fcb1c09 <+121>:   mov    %eax,%fs:(%rdx)
   0x00007f218fcb1c0c <+124>:   mov    $0xffffffff,%eax
   0x00007f218fcb1c11 <+129>:   retq   
   0x00007f218fcb1c12 <+130>:   mov    0xc1257(%rip),%rdx        # 0x7f218fd72e70
   0x00007f218fcb1c19 <+137>:   neg    %eax
   0x00007f218fcb1c1b <+139>:   mov    %eax,%fs:(%rdx)
   0x00007f218fcb1c1e <+142>:   mov    $0xffffffff,%eax
   0x00007f218fcb1c23 <+147>:   jmp    0x7f218fcb1be1 <__GI___poll+81>
End of assembler dump.
```

### commands

可以定义在断点中断后执行的命令

```bash
commands 断点编号
	命令
	...
	end
```

```bash
(gdb) info b
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x00007f218fcb1bd9 ../sysdeps/unix/sysv/linux/poll.c:29
(gdb) command 1 
Type commands for breakpoint(s) 1, one per line.
End with a line saying just "end".
>p $rip
>end
```

### list

命令用于显示源代码，当没有参数时，它会显示当前执行代码的周围区域

```bash
list：显示当前执行点周围的源代码。
list function_name：显示特定函数的源代码。
list filename:linenum：显示特定文件中特定行号的源代码。
list start, end：显示指定范围内的源代码行
```

```bash
(gdb) list
24      in ../sysdeps/unix/sysv/linux/poll.c
```

### display

用于设置要在每次程序停止时自动显示的表达式的值，持续监视特定变量或表达式的值

```bash
(gdb) display x
1: x = 5
(gdb) display *ptr
2: *ptr = 0x7fff5fbff7f
(gdb) display result
3: result = 42
(gdb) display a > b
4: a > b = true
```

用undisplay取消

### until

进行指定位置跳转，执行完区间代码