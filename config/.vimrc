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
let g:tagbar_autofocus = 1	" 打开Tagbar时自动聚焦窗口
let g:tagbar_sort = 0		" 不对符号排序，保持源代码顺序


Plug 'morhetz/gruvbox'
autocmd vimenter * colorscheme gruvbox
set bg=dark

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
let g:airline_theme='minimalist'

call plug#end()

set mouse=a
set backspace=indent,eol,start
set cursorline
set autoindent    " 在输入文本时自动缩进
set smartindent   " 根据上一行的缩进进行智能缩进
set hlsearch
set number
