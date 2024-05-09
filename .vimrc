"" Overview of which map command works in which mode.
""      COMMANDS                    MODES ~
"" :map   :noremap  :unmap     Normal, Visual, Select, Operator-pending
"" :nmap  :nnoremap :nunmap    Normal
"" :vmap  :vnoremap :vunmap    Visual and Select
"" :smap  :snoremap :sunmap    Select
"" :xmap  :xnoremap :xunmap    Visual
"" :omap  :onoremap :ounmap    Operator-pending
"" :map!  :noremap! :unmap!    Insert and Command-line
"" :imap  :inoremap :iunmap    Insert
"" :lmap  :lnoremap :lunmap    Insert, Command-line, Lang-Arg
"" :cmap  :cnoremap :cunmap    Command-line

"""""" Leader Key
let mapleader=" "

"""""" Esc and Space
map <C-c> <Esc>
noremap <Space> <Nop>

"""""" Spaces & Tabs
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smartindent

"""""" Line Numbers
set number " show line numbers
set relativenumber " relative line numbers

set scrolloff=8 " minimum 8 lines on top or bottom
set signcolumn="yes" " show sign column

"""""" UI Config
set termguicolors
set updatetime=250

" don't wrap lines
set nowrap

" show command in bottom bar
set showcmd

" visual autocomplete for command menu
set wildmenu

" highlight matching [{()}]
set showmatch

"""""" Searching
" search as characters are entered
set incsearch

" highlight matches
set nohlsearch

" ignore case in search patterns
set ignorecase

" override the 'ignorecase' option if the search pattern contains upper case characters
set smartcase

"""""" Backups & Undo
set history=1000

set noswapfile
set nobackup
set undodir="~/.vim/undodir"
set undofile

" create undo directory if it doesn't exist
if !isdirectory($HOME."/.vim")
    call mkdir($HOME."/.vim", "", 0770)
endif
if !isdirectory($HOME."/.vim/undo-dir")
    call mkdir($HOME."/.vim/undo-dir", "", 0700)
endif
set undodir=~/.vim/undo-dir
set undofile

"""""" Modified Commands
" keep cursor position when appending lines
nnoremap J mzJ`z

" keep cursor centered when half-page jumping
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" keep cursor centered when jumping to searched term
nnoremap n nzzzv
nnoremap N Nzzzv

" make Y like D and C
nnoremap Y y$

"""""" Yank, Paste, Delete
" yank to system clipboard
xnoremap <leader>y "+y
nnoremap <leader>y "+y
nnoremap <leader>Y "+Y

" paste and keep buffer
xnoremap <leader>p "_dP
" paste from system clipboard
nnoremap <leader>p "+p

" delete to void register
xnoremap <leader>d "_d
nnoremap <leader>d "_d

" GoLang return err snippet
nnoremap <leader>ee oif err != nil {<CR>}<Esc>Oreturn err<Esc>

"""""" Movement
" use J and K to move blocks of code up and down in visual mode
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" stay in visual mode after shifting
vnoremap < <gv
vnoremap > >gv

nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k

"""""" Useful Commands
" highlight last inserted text
nnoremap gV `[v`]
