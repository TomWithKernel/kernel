# tmux

插件，`tmux-continuum`  `plugins`放入~/.tmux文件夹

~/.tmux.conf

```bash
# 设置Prefix为Ctrl+x
set-option -g prefix C-x
unbind C-b
bind C-x send-prefix
 
# 开始鼠标模式
##  tmux v2.1及上 
set-option -g mouse on
set-window-option -g mode-mouse on # (setw其实是set-window-option的别名)
setw -g mouse-resize-pane on # 开启用鼠标拖动调节pane的大小（拖动位置是pane之间的分隔线
setw -g mouse-select-pane on # 开启用鼠标点击pane来激活该pane
setw -g mouse-select-window on # 开启用鼠标点击来切换活动window（点击位置是状态栏的窗口名称）
setw -g mode-mouse on # 开启window/pane里面的鼠标支持（也即可以用鼠标滚轮回滚显示窗口内容，此时还可以用鼠标选取文本）

set -g history-limit 100000

# 开启复制模式
setw -g mode-keys vi
set-window-option -g mode-keys vi
 
# 使用快捷键r重新读取配置文件
bind r source-file ~/.tmux.conf\; display "Reloaded!"
 
# 设置Window和Pane开始编号为1
set-option -g base-index 1
set-window-option -g pane-base-index 1
 
bind-key k select-pane -U # up
bind-key j select-pane -D # down 
bind-key h select-pane -L # left
bind-key l select-pane -R # right

# 设置Ctrl+j为横向分屏
bind-key -n C-j split-window -h

# 设置Ctrl+h为竖向分屏
bind-key -n C-h split-window -v

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

set -g @plugin 'dracula/tmux'
set -g @dracula-plugins "ssh-session cpu-usage ram-usage time"  #状态栏显示的内容
set -g @dracula-show-flags true 
set -g @dracula-show-left-icon session  # 最左侧的图标显示当前tmux session名称
set -g @dracula-show-powerline true # 显示powerline,更美观
set -g @dracula-time-format "%F %R" # 时间格式 

#ls颜色
#set -g default-terminal "tmux-256color"
#set-option -a terminal-overrides ",*256col*:RGB"

run '~/.tmux/plugins/tpm/tpm'
run-shell ~/.tmux/tmux-continuum/continuum.tmux
set -g @continuum-save-interval '60'
```

`tmux source-file ~/.tmux.conf`