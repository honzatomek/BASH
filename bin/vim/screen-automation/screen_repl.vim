" set of screen automation scripts for VIM
" by: Jan Tomek (11.4.2021)
if exists('g:screen_repl')
  finish
endif

" global variables
if !exists('g:screen_repl_vars')
  let g:screen_repl_vars = {'session': '',
                         \  'chdir': 1,
                         \  'init': ['/home/pi/bin/repl', 'repl'],
                         \  'comment': '#',
                         \  'cell': ['{{{', '}}}'],
                         \  'use_paste_mode': 1,
                         \  'strip_comments': 1,
                         \  'strip_empty_lines': 1,
                         \  'commands': {'cancel': '^C',
                                       \ 'reset': '^D',
                                       \ 'paste': ['^E', '^D'],
                                       \ 'enter': '^M'},
                         \  'delay': 200,
                         \  'debug': 0}
endif

if has('terminal')
  let g:screen_repl_buffer = 0
  let g:screen_repl_visible = 0

  function! s:ToggleTerminal()
    call <SID>PrintMsg('function! s:ToggleTerminal()')
    if g:screen_repl_visible > 0
      call <SID>HideTerminal()
    else
      call <SID>ViewTerminal()
    endif
  endfunction

  function! s:ViewTerminal()
    call <SID>PrintMsg('function! s:ViewTerminal()')
    let l:initial_buffer = bufnr(bufname("%"))
    let l:initial_window = winnr()
    if or(g:screen_repl_buffer == 0, bufname(g:screen_repl_buffer) == "")
      call <SID>CreateTerminal()
    else
      vsplit
      exec 'buffer ' . g:screen_repl_buffer
    endif
    let g:screen_repl_visible = winnr()
    exec l:initial_window . 'wincmd w'
  endfunction

  function! s:HideTerminal()
    call <SID>PrintMsg('function! s:HideTerminal()')
    exec g:screen_repl_visible . 'wincmd c'
    let g:screen_repl_visible = 0
  endfunction

  function! s:CloseTerminal()
    call <SID>PrintMsg('function! s:CloseTerminal()')
    silent call term_sendkeys(g:screen_repl_buffer, "\<c-a>d")
    silent call term_wait(g:screen_repl_buffer, g:screen_repl_vars['delay'])
    silent call term_sendkeys(g:screen_repl_buffer, "\<c-d>")
  endfunction

  function! s:CreateTerminal()
    call <SID>PrintMsg('function! s:CreateTerminal()')
    let l:initial_buffer = bufnr(bufname("%"))
    let l:initial_window = winnr()
    vert term
    let l:terminal_window = winnr()
    let g:screen_repl_buffer = bufnr(bufname("%"))

    call <SID>ScreenAttach()

    au! * <buffer>
    au! BufDelete <buffer> :call <SID>TerminalDeleted()
    au! BufWinEnter <buffer> :call <SID>TerminalVisible()
    au! BufHidden <buffer> :call <SID>TerminalHidden()
  endfunction

  function! s:TerminalVisible()
    call <SID>PrintMsg('function! s:TerminalVisible()')
    let g:screen_repl_visible = winnr()

    call <SID>PrintMsg('terminal open')
  endfunction

  function! s:TerminalHidden()
    call <SID>PrintMsg('function! s:TerminalHidden()')
    let g:screen_repl_visible = 0

    call <SID>PrintMsg('terminal closed')
  endfunction

  function! s:TerminalDeleted()
    call <SID>PrintMsg('function! s:TerminalDeleted()')
    let g:screen_repl_visible = 0
    let g:screen_repl_buffer = 0

    call <SID>PrintMsg('terminal deleted')
  endfunction

  function! s:ScreenAttach()
    call <SID>PrintMsg('function! s:ScreenAttach()')
    if g:screen_repl_vars['session'] == ''
      let l:screen = <SID>ScreenSelect()
      let g:screen_repl_vars['session'] = l:screen
    else
      let l:screen = g:screen_repl_vars['session']
    endif
    call term_sendkeys(g:screen_repl_buffer, 'screen -x ' . l:screen . "\<cr>")

    call <SID>PrintMsg('attached to screen ' . l:screen)
  endfunction

  function! s:ScreenDetach()
    call <SID>PrintMsg('function! s:ScreenDetach()')
    let l:screen = g:screen_repl_vars['session']
    call term_sendkeys(g:screen_repl_buffer, "\<c-a>d")
    let g:screen_repl_vars['session'] = ''

    call <SID>PrintMsg('detached from screen ' . l:screen)
  endfunction
endif

function! s:ScreenSelect()
  call <SID>PrintMsg('function! s:ScreenSelect()')
  let l:screens = system('screen -ls')

  " No screens are available
  if l:screens =~? "No Sockets found"
    return <SID>ScreenCreate()
  endif

  " display screen choices for selection
  let l:screens = split(l:screens, '\n', 0)[1:-2]
  let l:choices = ['0 - create new']

  if len(l:screens) > 0
    for l:i in range(len(l:screens))
      let l:screens[l:i] = split(l:screens[l:i], '\t', 0)[0]
      let l:choices += [ l:i + 1 . ' - ' . l:screens[l:i] ]
    endfor
  endif

  " select screen
  let l:choice = inputlist(l:choices)

  if l:choice == 0
    return <SID>ScreenCreate()
  endif

  call <SID>PrintMsg(l:screens[l:choice - 1])

  let g:screen_repl_vars['session'] = l:screens[l:choice - 1]

  return l:screens[l:choice - 1]
endfunction

function! s:ScreenCreate()
  call <SID>PrintMsg('function! s:ScreenCreate()')
  call inputsave()
  let l:screen = input("\nInput new GNU Screen name:\n", "upy")
  call inputrestore()

  if l:screen == ""
    exit
  endif

  call system('screen -d -m -S ' . l:screen)
  if type(g:screen_repl_vars['chdir']) == 0
    call system('screen -S ' . l:screen . ' -X stuff "cd ' . getcwd() . '^M"')
  elseif type(g:screen_repl_vars['chdir']) == 1
    if g:screen_repl_vars['chdir'] != ''
      call system('screen -S ' . l:screen . ' -X stuff "cd ' . g:screen_repl_vars['chdir'] . '^M"')
    endif
  endif
  if type(g:screen_repl_vars['init']) == 3
    for l:command in g:screen_repl_vars['init']
      call system('screen -S ' . l:screen . ' -X stuff "' . l:command . '^M"')
    endfor
  else
    call system('screen -S ' . l:screen . ' -X stuff "' . g:screen_repl_vars['init'] . '^M"')
  endif

  let g:screen_repl_vars['session'] = l:screen
  return l:screen
endfunction

function! s:SendText(text)
  call <SID>PrintMsg('function! s:SendText(text)')
  silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "' . a:text . '"')
endfunction

function! s:SendEnter()
  call <SID>PrintMsg('function! s:SendEnter()')
  silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "' . g:screen_repl_vars['commands']['enter'] . '"')
endfunction

function! s:SendStartPaste()
  call <SID>PrintMsg('function! s:SendStartPaste()')
  silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "' . g:screen_repl_vars['commands']['paste'][0] . '"')
  "silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "^E"')
endfunction

function! s:SendEndPaste()
  call <SID>PrintMsg('function! s:SendEndPaste()')
  silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "' . g:screen_repl_vars['commands']['paste'][1] . '"')
  "silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "^D"')
endfunction

function! s:SendReset()
  call <SID>PrintMsg('function! s:SendReset()')
  silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "' . g:screen_repl_vars['commands']['reset'] . '"')
  "silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "^D"')
endfunction

function! s:SendCancel()
  call <SID>PrintMsg('function! s:SendCancel()')
  silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "' . g:screen_repl_vars['commands']['cancel'] . '"')
  " silent call system('screen -S ' . g:screen_repl_vars['session'] . ' -X stuff "^C"')
endfunction

function! s:SendLine()
  call <SID>PrintMsg('function! s:SendLine()')
  let l:line = trim(getline('.'), " ")
  call <SID>SendText(l:line)
  call <SID>SendEnter()
  call <SID>PrintMsg('Sending: ' . l:line)
endfunction

function! s:SendSelected() range
  call <SID>PrintMsg('function! s:SendSelected()')
  if mode() == "v"
    let [l:line_start, l:column_start] = getpos("v")[1:2]
    let [l:line_end, l:column_end] = getpos(".")[1:2]
  else
    let [l:line_start, l:column_start] = getpos("'<")[1:2]
    let [l:line_end, l:column_end] = getpos("'>")[1:2]
  endif

  if l:line_start > l:line_end
    let [l:line_start, l:line_end] = [l:line_end, l:line_start]
  endif
  echom [l:line_start, l:line_end]

  let l:lines = getline(l:line_start, l:line_end)
  if len(l:lines) == 0
    return ''
  endif

  call <SID>PrintMsg(join(l:lines, "\n"))

  let l:text = <SID>StripComments(l:lines)
  call <SID>SendStartPaste()
  call <SID>SendText(l:text)
  " silent call term_wait(g:screen_repl_buffer, g:screen_repl_vars['delay'])
  exec 'sleep ' . g:screen_repl_buffer['delay']  . 'm'
  call <SID>SendEndPaste()

  call <SID>PrintMsg('Sending: ' . l:text)
endfunction

function! s:SendRange() range
  call <SID>PrintMsg('function! s:SendRange() range')
  let l:lines = getline(a:firstline, a:lastline)
  if len(l:lines) == 0
    return ''
  endif

  let l:text = <SID>StripComments(l:lines)
  call <SID>SendStartPaste()
  call <SID>SendText(l:text)
  " silent call term_wait(g:screen_repl_buffer, g:screen_repl_vars['delay'])
  exec 'sleep ' . g:screen_repl_vars['delay']  . 'm'
  call <SID>SendEndPaste()

  call <SID>PrintMsg('Sending: ' . l:text)
endfunction

function! s:SendCell()
  call <SID>PrintMsg('function! s:SendCell()')
  let l:line_start = search("^" . g:screen_repl_vars['comment'] . "\\s*" . g:screen_repl_vars['cell'][0] . ".*", 'bcnW')
  let l:line_end = search("^" . g:screen_repl_vars['comment'] . "\\s*" . g:screen_repl_vars['cell'][1] . ".*", 'cnW')
  " let l:line_end = search("^#{{{.*", 'bcnW')
  " let l:line_end = search("^#}}}.*", 'cnW')
  if or(l:line_start == 0, l:line_end == 0)
    echom 'No cell (block of code enclosed in ' . g:screen_repl_vars['comment'] . g:screen_repl_vars['cell'][0]
          \ g:screen_repl_vars['comment'] . g:screen_repl_vars['cell'][1] . ' comment lines) has been found.'
    return ''
  endif

  let l:lines = getline(l:line_start + 1, l:line_end - 1)
  if len(l:lines) == 0
    return ''
  endif

  let l:text = <SID>StripComments(l:lines)
  call <SID>SendStartPaste()
  call <SID>SendText(l:text)
  " silent call term_wait(g:screen_repl_buffer, g:screen_repl_vars['delay'])
  exec 'sleep ' . g:screen_repl_vars['delay']  . 'm'
  call <SID>SendEndPaste()

  call <SID>PrintMsg('Sending: ' . l:text)
endfunction

function! s:SendFile()
  call <SID>PrintMsg('function! s:SendFile()')
  let l:lines = getline('0', '$')

  let l:text = <SID>StripComments(l:lines)

  call <SID>SendStartPaste()
  call <SID>SendText(l:text)
  " silent call term_wait(g:screen_repl_buffer, g:screen_repl_vars['delay'])
  exec 'sleep ' . g:screen_repl_vars['delay']  . 'm'
  call <SID>SendEndPaste()

  call <SID>PrintMsg('Sending: ' . l:text)
endfunction

function! s:StripComments(text)
  call <SID>PrintMsg('function! s:StripComments(text)')
  if type(a:text) == 3
    let l:text = join(a:text, "\n")
  else
    let l:text = a:text
  endif

  " call <SID>PrintMsg(l:text)

  if g:screen_repl_vars['strip_comments']
    let l:text = substitute(l:text, "\\s*" . g:screen_repl_vars['comment'] . ".\\{-}\\ze\n", '', 'g')
    " call <SID>PrintMsg(l:text)
  endif
  if g:screen_repl_vars['strip_empty_lines']
    let l:text = substitute(l:text, "\n\\{2,}", "\n", 'g')
    " call <SID>PrintMsg(l:text)
  endif

  return l:text
endfunction

function! s:PrintMsg(message)
  if g:screen_repl_vars['debug'] == 1
    echom a:message
  endif
endfunction

function! s:SetEntryMapping(mode, name, function, keys)
  call <SID>PrintMsg('function! s:SetEntryMapping(mode, name, function, keys)')
  if a:mode == 'r'
    execute 'command! -range ' . a:name . ' <line1>,<line2>call ' . a:function
    return ''
  endif

  execute a:mode . 'noremap <silent> <plug>' . a:name . ' :call ' . a:function . '<cr>'
  call <SID>PrintMsg("(" . a:mode . ") " . a:function . " mapped to <plug>" . a:name)
  if a:keys != '' && !hasmapto('<plug>' . a:name, a:mode) && (mapcheck(a:keys, a:mode) == "")
    execute a:mode . 'map <silent> ' . a:keys . ' <plug>' . a:name
    call <SID>PrintMsg("(" . a:mode . ") <plug>" . a:name . " mapped to " . a:keys)
  endif
  execute 'command! ' . a:name . ' :call ' . a:function
endfunction

if has('terminal')
  call <SID>SetEntryMapping('n', 'ScreenReplToggleTerminal', '<SID>ToggleTerminal()', '<leader>rt')
  call <SID>SetEntryMapping('n', 'ScreenReplViewTerminal', '<SID>ViewTerminal()', '<leader>ro')
  call <SID>SetEntryMapping('n', 'ScreenReplHideTerminal', '<SID>HideTerminal()', '<leader>rh')
  call <SID>SetEntryMapping('n', 'ScreenReplCloseTerminal', '<SID>CloseTerminal()', '<leader>rc')
  call <SID>SetEntryMapping('n', 'ScreenReplScreenAttach', '<SID>ScreenAttach()', '<leader>ra')
  call <SID>SetEntryMapping('n', 'ScreenReplScreenDetach', '<SID>ScreenDetach()', '<leader>rd')
endif
call <SID>SetEntryMapping('n', 'ScreenReplScreenInit', '<SID>ScreenSelect()', '<leader>ri')
call <SID>SetEntryMapping('n', 'ScreenReplSendLine', '<SID>SendLine()', '<leader>rl')
call <SID>SetEntryMapping('n', 'ScreenReplSendCell', '<SID>SendCell()', '<leader>rc')
call <SID>SetEntryMapping('n', 'ScreenReplSendSelectedN', '<SID>SendSelected()', '<leader>rs')
call <SID>SetEntryMapping('x', 'ScreenReplSendSelected', '<SID>SendSelected()', '<leader>rs')
call <SID>SetEntryMapping('r', 'ScreenReplSendRange', '<SID>SendRange()', '')
call <SID>SetEntryMapping('n', 'ScreenReplSendFile', '<SID>SendFile()', '<leader>rf')
call <SID>SetEntryMapping('n', 'ScreenReplSendReset', '<SID>SendReset()', '<leader>rr')
call <SID>SetEntryMapping('n', 'ScreenReplSendEnter', '<SID>SendEnter()', '<leader>re')
call <SID>SetEntryMapping('n', 'ScreenReplSendCancel', '<SID>SendCancel()', '<leader>rx')

let g:screen_repl = 1
