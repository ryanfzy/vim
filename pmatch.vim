let b:gNumOfParns = 0
highlight link myMatch Error

"TODO: implement
"   ( => [0]
"   () => [1]
"   (() => [0,1]
"   (()() => [0,1,1]
"   ((()()) => [0,[1,1]]
"   ((( => [0,0,0]
"   (()((()) => [0,1,0,[1]]
function GetPatParns(line)
    let l:listPatParns = []
    let l:listParns = []
    let l:bEscaped = g:FALSE
    let l:bFoundString = g:FALSE
    for i in range(len(a:line))
       let l:ch = a:line[i] 
       if !l:bFoundString
           if l:ch =~ '"' || l:ch =~ "'"
               let l:bFoundString = g:TRUE
           elseif l:ch =~ '('
               let l:listParns = add(l:listParns, 0)
           elseif l:ch =~ ')'
               let l:listParns = add(l:listParns, 1)
           endif
       else
           if l:ch =~ '\'
               let l:bEscaped = g:TRUE
           elseif l:ch =~ '"' || l:ch =~ "'"
               if l:bEscaped
                   let l:bEscaped = g:FALSE
               else
                   let l:bFoundString = g:FALSE
               endif
           endif
       endif
    endfor

    echom "list:".string(l:listParns)
    for i in range(len(l:listParns))
        let l:iParn = l:listParns[i]
        if l:iParn == 0
            let l:listPatParns = add(l:listPatParns, 0)
        elseif l:iParn == 1
            let l:lenPatParns = len(l:listPatParns)
            if type(l:listPatParns[l:lenParns-1]) != type([]) && l:listPatParns[l:lenPatParn-1] == 0
                let l:listPatParns[l:lenPatParns-1] = 1
            else
                let l:idx = 0
                for j in range(l:lenPatParns-1, 0, -1)
                    if type(l:listPatParns[j]) != type([]) && l:listPatParns[j] == 0
                        let l:idx = j
                        break
                    endif
                endfor
                let l:lst = []
                for k in range(l:idx)
                    let l:lst = add(l:lst, l:listPatParns[k])
                endfor
                let l:lst2 = []
                "echom "l:idx:".l:idx
                "echom "len(listPatParns:".len(l:listPatParns)
                for m in range(l:idx+1, l:lenPatParns-1)
                    let l:lst2 = add(l:lst2, l:listPatParns[m])
                endfor
                "echom "l:lst:".string(l:lst)
                "echom "l:lst2:".string(l:lst2)
                let l:listPatParns = add(l:lst, l:lst2)
            endif
        endif
    endfor
    return l:listPatParns
endfunction

function GetNumOfParns(line)
    let l:iNumOfParns = 0
    for i in range(len(a:line))
        if a:line[i] =~ '('
            let l:iNumOfParns = l:iNumOfParns + 1
        endif
    endfor
    return l:iNumOfParns
endfunction

function FeedRoundParn(ch)
    let l:line = getline('.') . a:ch
    let l:iNumOfParns = GetNumOfParns(l:line)
    let l:listPatParns = GetPatParns(l:line)
    echom string(l:listPatParns)
    if l:iNumOfParns > b:gNumOfParns
        let b:gNumOfParns = l:iNumOfParns
        let l:pat = ''
        if b:gNumOfParns < 2
            let l:pat = '/([^)]*$\&./'
        else
            let l:patParn = '([^)]*)'
            let l:patNestedParn = '([^)]*%s[^)]*%s'
            let l:pat = l:patParn
            for i in range(b:gNumOfParns-1)
                if i < b:gNumOfParns - 2
                    let l:pat = printf(l:patNestedParn, l:pat, ')')
                else
                    let l:pat = printf(l:patNestedParn, l:pat, '')
                endif
            endfor
            let l:pat = '/' . l:pat . '\($\|\([^(]*(\)\)\&./'
        endif
        let l:syn = 'syntax match myMatch ' . l:pat
        "echom l:syn
        execute l:syn
    endif
    return a:ch
endfunction
