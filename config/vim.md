title: vim

date: 2024-02-24 10:09:00

tags:

categories: config

---

# vim

### **安装Vim插件管理器 VimPlug**

```bash
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

### **配置 ~/.vimrc**

```bash
call plug#begin()

Plug 'scrooloose/nerdtree'
noremap <leader>t :NERDTreeToggle<CR>
autocmd VimEnter * wincmd p
autocmd BufEnter * if 0 == len(filter(range(1, winnr('$')), 'empty(getbufvar(winbufnr(v:val), "&bt"))')) | qa! | endif
let NERDTreeWinSize=25

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
nnoremap <c-p> :Files<CR>
nnoremap <c-g> :Ag<CR>

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'tracyone/fzf-funky',{'on': 'FzfFunky'}
nnoremap <Leader>f :FzfFunky<CR>

Plug 'majutsushi/tagbar'
nmap <Leader>b :TagbarToggle<CR>
let g:tagbar_width=30
autocmd BufReadPost *.cpp,*.c,*.h,*.hpp,*.cc,*.cxx call tagbar#autoopen()

call plug#end()

set mouse=a
set backspace=indent,eol,start
set cursorline
set autoindent    " 在输入文本时自动缩进
set smartindent   " 根据上一行的缩进进行智能缩进
```

### 把插件放到~/.vim文件夹中

autoload 和 plugged

执行`source ~/.vimrc`