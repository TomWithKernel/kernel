title: ctags

date: 2024-01-26 10:09:00

tags:

categories: commands

---

# ctags

**生成索引文件  `ctags –R .`**

```c
Ctrl + ]     跳到光标所在变量的定义处
Ctrl + t     返回查找或跳转，从哪里跳过来的跳回哪里，即使用了很多次 Ctrl+]，该命令也会回到最初一次的位置
vi –t tag   找到名为 tag 的变量的定义处
g + ]          列出变量的所有引用供用户选择
:ts         tagslist  同 g + ]
:tp         tagspreview 上一个tag标记文件
:tn         tagsnext  下一个tag标记文件
```