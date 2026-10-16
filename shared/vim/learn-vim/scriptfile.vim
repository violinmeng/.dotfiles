function! ToggleSyntax()
	if exists("g:syntax_on")
		syntax off
	else
		syntax enable
	endif
endfunction

nmap <silent> ;y :call ToggleSyntax()<CR>

function! CapitalizeCenterAndMoveDown()
	s/\<./\u&/g   "Built‑in substitution capitalizes each word
	center        "Built‑in center command centers entire line
	+1            "Built‑in relative motion (+1 line down)
endfunction

nmap <silent>  \C  :call CapitalizeCenterAndMoveDown()<CR>

imap <silent> <C-C> <C-R>=string(eval(input("Calculate: ")))<CR>

"Locate and return character "above" current cursor position...
function! LookUpwards()
    "Locate current column and preceding line from which to copy...
    let column_num      = virtcol('.')
    let target_pattern  = '\%' . column_num . 'v.'
    let target_line_num = search(target_pattern . '*\S', 'bnW')

    "If target line found, return vertically copied character...
    if !target_line_num
        return ""
    else
        return matchstr(getline(target_line_num), target_pattern)
    endif
endfunction

imap <silent> <C-Y> <C-R><C-R>=LookUpwards()<CR>

