let b:gNumOfParns = 0
highlight link myMatch Error

function GetNumOfParns(line)
    let l:iNumOfParns = 0
    for i in range(len(a:line))
        if a:line[i] =~ '('
            let l:iNumOfParns = l:iNumOfParns + 1
        endif
    endfor
    return l:iNumOfParns
endfunction

function FeedRoundParn()
    let l:line = getline('.') . '('
    let l:iNumOfParns = GetNumOfParns(l:line)
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
    return '('
endfunction
