; Standard FASM COM file format
org 100h

start:
    cld
    jmp main

prompt_str db 13,10,"C:\> $"
cmd_buf db 128, 0, 128 dup(0)
cmd_upper db 128 dup(0)

str_dir db "DIR",0
str_cls db "CLS",0
str_ver db "VER",0
str_echo db "ECHO",0
str_cd db "CD",0
str_md db "MD",0
str_rd db "RD",0
str_del db "DEL",0
str_erase db "ERASE",0
str_ren db "REN",0
str_rename db "RENAME",0
str_type db "TYPE",0
str_copy db "COPY",0
str_pause db "PAUSE",0
str_date db "DATE",0
str_time db "TIME",0

msg_badcmd db 13,10,"Bad command or file name",13,10,"$"
msg_copied db " File(s) copied",13,10,"$"
msg_notfound db "File not found",13,10,"$"
msg_presskey db "Press any key to continue . . .$"
msg_dirmes db " File(s)",13,10,"$"
msg_crlf db 13,10,"$"
msg_ver db 13,10,"MiniDOS v2.1",13,10,"$"
msg_echo_on db "ECHO is on",13,10,"$"
msg_echo_off db "ECHO is off",13,10,"$"
msg_created db "Directory created",13,10,"$"
msg_removed db "Directory removed",13,10,"$"
msg_chgd db "Directory changed",13,10,"$"
msg_cwd db "Current directory is $"

dta_buf rb 44
find_name db 64 dup(0)
file_cnt dw 0
prev_name rb 16
prev_size dw 0

copy_buf rb 4096
src_handle dw 0
dst_handle dw 0
arg_ptr dw 0

pipe_file db "PIPE.TMP",0
bat_handle dw 0
bat_mode db 0

main:
    push cs
    pop ds
    push cs
    pop es

main_loop:
    push cs
    pop ds
    push cs
    pop es

    mov dx, prompt_str
    call print_str

    mov dx, cmd_buf
    mov ah, 0Ah
    int 21h
    call crlf

    xor cx, cx
    mov cl, byte [cmd_buf+1]
    mov bx, cx
    mov byte [cmd_buf+2+bx], 0

    call parse_cmd
    cmp byte [cmd_upper], 0
    je main_loop

    call pre_process_io
    call dispatch
    call post_process_io
    jmp main_loop

parse_cmd:
    mov si, cmd_buf+2
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .empty
    cmp al, 13
    je .empty

    mov di, cmd_upper
    dec si
.copy_loop:
    lodsb
    call toupper
    stosb
    cmp al, 0
    je .done_copy
    cmp al, ' '
    je .done_copy
    cmp al, 13
    je .done_copy
    jmp .copy_loop
.done_copy:
    dec di
    mov byte [di], 0

.skip_arg_spaces:
    cmp byte [si], ' '
    jne .check_end
    inc si
    jmp .skip_arg_spaces
.check_end:
    cmp byte [si], 13
    jne .clean_trailing
    mov byte [si], 0

.clean_trailing:
    mov di, si
.replace_cr:
    cmp byte [di], 0
    je .find_end2
    cmp byte [di], 13
    jne .next_char
    mov byte [di], 0
.next_char:
    inc di
    jmp .replace_cr

.find_end2:
    cmp byte [di], 0
    je .found_end2
    inc di
    jmp .find_end2
.found_end2:
    dec di
.strip_spaces:
    cmp di, si
    jl .args_ready
    cmp byte [di], ' '
    jne .args_ready
    mov byte [di], 0
    dec di
    jmp .strip_spaces

.args_ready:
    mov word [arg_ptr], si
    ret
.empty:
    mov byte [cmd_upper], 0
    ret

pre_process_io:
    ; Simple redirection and pipe handling
    ; Scans for >, <, | and sets up handles
    mov si, cmd_buf+2
.scan:
    lodsb
    test al, al
    jz .done_io
    cmp al, '>'
    je .handle_out
    cmp al, '<'
    je .handle_in
    cmp al, '|'
    je .handle_pipe
    jmp .scan
.handle_out:
    ; Basic > implementation (overwrite)
    dec si
    mov byte [si], 0
    inc si
    call skip_spaces_si
    mov dx, si
    mov cx, 0
    mov ah, 3Ch
    int 21h
    jc .done_io
    mov bx, ax
    push bx
    mov bx, 1
    mov ah, 45h
    int 21h
    mov word [saved_stdout], ax
    pop bx
    mov cx, 1
    mov ah, 46h
    int 21h
    jmp .done_io
.handle_in:
    dec si
    mov byte [si], 0
    inc si
    call skip_spaces_si
    mov dx, si
    mov ax, 3D00h
    int 21h
    jc .done_io
    mov bx, ax
    push bx
    mov bx, 0
    mov ah, 45h
    int 21h
    mov word [saved_stdin], ax
    pop bx
    mov cx, 0
    mov ah, 46h
    int 21h
    jmp .done_io
.handle_pipe:
    ; Pipe: run left > PIPE.TMP, then right < PIPE.TMP
    dec si
    mov byte [si], 0
    mov byte [pipe_active], 1
    inc si
    mov word [pipe_right], si
    mov dx, pipe_file
    mov cx, 0
    mov ah, 3CH
    int 21H
    jc .done_io
    mov bx, ax
    push bx
    mov bx, 1
    mov ah, 45H
    int 21H
    mov word [saved_stdout], ax
    pop bx
    mov cx, 1
    mov ah, 46H
    int 21H
.done_io:
    ret

post_process_io:
    cmp byte [pipe_active], 1
    je .do_pipe
    cmp word [saved_stdout], 0
    je .check_in
    mov bx, word [saved_stdout]
    mov cx, 1
    mov ah, 46h
    int 21h
    mov bx, word [saved_stdout]
    mov ah, 3Eh
    int 21h
    mov word [saved_stdout], 0
.check_in:
    cmp word [saved_stdin], 0
    je .done_post
    mov bx, word [saved_stdin]
    mov cx, 0
    mov ah, 46h
    int 21h
    mov bx, word [saved_stdin]
    mov ah, 3Eh
    int 21h
    mov word [saved_stdin], 0
.done_post:
    ret
.do_pipe:
    mov byte [pipe_active], 0
    mov bx, word [saved_stdout]
    mov cx, 1
    mov ah, 46h
    int 21h
    mov bx, word [saved_stdout]
    mov ah, 3Eh
    int 21h
    mov word [saved_stdout], 0

    mov dx, pipe_file
    mov ax, 3D00h
    int 21h
    jc .pipe_end
    mov bx, ax
    push bx
    mov bx, 0
    mov ah, 45h
    int 21h
    mov word [saved_stdin], ax
    pop bx
    mov cx, 0
    mov ah, 46h
    int 21h

    mov si, word [pipe_right]
    mov di, cmd_buf+2
.copy_right:
    lodsb
    stosb
    test al, al
    jnz .copy_right

    mov byte [cmd_buf+1], 0
    call parse_cmd
    call dispatch

    mov bx, word [saved_stdin]
    mov cx, 0
    mov ah, 46h
    int 21h
    mov bx, word [saved_stdin]
    mov ah, 3Eh
    int 21h
    mov word [saved_stdin], 0
.pipe_end:
    mov dx, pipe_file
    mov ah, 41h
    int 21h
    ret

skip_spaces_si:
    cmp byte [si], ' '
    jne .done_skip
    inc si
    jmp skip_spaces_si
.done_skip:
    ret

saved_stdout dw 0
saved_stdin dw 0
pipe_active db 0
pipe_right dw 0

dispatch:
    mov si, cmd_upper

    mov di, str_dir
    call strcmp
    je .do_dir
    mov di, str_cls
    call strcmp
    je .do_cls
    mov di, str_ver
    call strcmp
    je .do_ver
    mov di, str_echo
    call strcmp
    je .do_echo
    mov di, str_cd
    call strcmp
    je .do_cd
    mov di, str_md
    call strcmp
    je .do_md
    mov di, str_rd
    call strcmp
    je .do_rd
    mov di, str_del
    call strcmp
    je .do_del
    mov di, str_erase
    call strcmp
    je .do_del
    mov di, str_ren
    call strcmp
    je .do_ren
    mov di, str_rename
    call strcmp
    je .do_ren
    mov di, str_type
    call strcmp
    je .do_type
    mov di, str_copy
    call strcmp
    je .do_copy
    mov di, str_pause
    call strcmp
    je .do_pause
    mov di, str_date
    call strcmp
    je .do_date
    mov di, str_time
    call strcmp
    je .do_time

    jmp .do_exec

.do_dir: jmp cmd_dir
.do_cls: jmp cmd_cls
.do_ver: jmp cmd_ver
.do_echo: jmp cmd_echo
.do_cd: jmp cmd_cd
.do_md: jmp cmd_md
.do_rd: jmp cmd_rd
.do_del: jmp cmd_del
.do_ren: jmp cmd_ren
.do_type: jmp cmd_type
.do_copy: jmp cmd_copy
.do_pause: jmp cmd_pause
.do_date: jmp cmd_date
.do_time: jmp cmd_time
.do_exec: jmp cmd_exec

strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.equal:
    pop di
    pop si
    xor al, al
    ret
.not_equal:
    pop di
    pop si
    or al, 1
    ret

print_str:
    push ax
    mov ah, 09h
    int 21h
    pop ax
    ret

print_char:
    push ax
    push dx
    mov ah, 02h
    mov dl, al
    int 21h
    pop dx
    pop ax
    ret

crlf:
    push ax
    push dx
    mov dx, msg_crlf
    mov ah, 09h
    int 21h
    pop dx
    pop ax
    ret

toupper:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 20h
.done:
    ret

print_num8:
    push ax
    push bx
    push cx
    push dx

    xor ah, ah
    mov bl, 10
    div bl
    push ax

    mov dl, al
    add dl, 30h
    mov ah, 02h
    int 21h

    pop ax
    mov dl, ah
    add dl, 30h
    mov ah, 02h
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_num16:
    push ax
    push bx
    push cx
    push dx

    mov cx, 0
    mov bx, 10
.loop1:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .loop1
.loop2:
    pop dx
    add dl, 30h
    mov ah, 02h
    int 21h
    loop .loop2

    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_str_dos:
    push ax
    push dx
    push si
    mov si, dx
.loop:
    lodsb
    test al, al
    jz .done
    mov dl, al
    mov ah, 02h
    int 21h
    jmp .loop
.done:
    pop si
    pop dx
    pop ax
    ret

fix_filespec:
    push di
    mov cx, 64
    mov al, '.'
    repne scasb
    pop di
    jne .no_dot
    ret
.no_dot:
    push di
    mov cx, 64
    mov al, '*'
    repne scasb
    pop di
    jne .no_star
    ret
.no_star:
    push di
    mov cx, 64
    mov al, '?'
    repne scasb
    pop di
    jne .no_qmark
    ret
.no_qmark:
    mov cx, 64
    mov al, 0
    repne scasb
    dec di
    mov byte [di], '.'
    inc di
    mov byte [di], '*'
    inc di
    mov byte [di], 0
    ret

cmd_cls:
    mov ax, 0003h
    int 10h
    ret

cmd_ver:
    mov dx, msg_ver
    call print_str
    ret

cmd_echo:
    mov si, word [arg_ptr]
    cmp byte [si], 0
    je .show_status
    mov dx, si
    call print_str_dos
    call crlf
    ret
.show_status:
    mov dx, msg_echo_on
    call print_str
    ret

cmd_cd:
    mov si, word [arg_ptr]
    cmp byte [si], 0
    je .show_cd
    mov dx, si
    mov ah, 3Bh
    int 21h
    jnc .ok
    mov dx, msg_notfound
    call print_str
    ret
.ok:
    mov dx, msg_chgd
    call print_str
    ret
.show_cd:
    mov dx, msg_cwd
    call print_str
    mov dx, cmd_buf+2
    mov ah, 47h
    mov dl, 0
    int 21h
    jnc .print_cwd
    mov dx, msg_notfound
    call print_str
    ret
.print_cwd:
    mov dx, cmd_buf+2
    call print_str_dos
    call crlf
    ret

cmd_md:
    mov si, word [arg_ptr]
    cmp byte [si], 0
    je .err
    mov dx, si
    mov ah, 39h
    int 21h
    jnc .ok
.err:
    mov dx, msg_notfound
    call print_str
    ret
.ok:
    mov dx, msg_created
    call print_str
    ret

cmd_rd:
    mov si, word [arg_ptr]
    cmp byte [si], 0
    je .err
    mov dx, si
    mov ah, 3Ah
    int 21h
    jnc .ok
.err:
    mov dx, msg_notfound
    call print_str
    ret
.ok:
    mov dx, msg_removed
    call print_str
    ret

cmd_pause:
    mov dx, msg_presskey
    call print_str
    mov ah, 08h
    int 21h
    call crlf
    ret

cmd_date:
    mov ah, 2Ah
    int 21h
    push cx
    push dx
    mov al, dh
    call print_num8
    mov al, '-'
    call print_char
    pop dx
    push dx
    mov al, dl
    call print_num8
    mov al, '-'
    call print_char
    pop dx
    pop cx
    mov ax, cx
    call print_num16
    call crlf
    ret

cmd_time:
    mov ah, 2Ch
    int 21h
    push cx
    push dx
    mov al, ch
    call print_num8
    mov al, ':'
    call print_char
    pop dx
    push dx
    mov al, cl
    call print_num8
    mov al, ':'
    call print_char
    pop dx
    mov al, dh
    call print_num8
    call crlf
    ret

cmd_dir:
    mov si, word [arg_ptr]
    mov ah, 1Ah
    mov dx, dta_buf
    int 21h

    mov di, find_name
    cmp byte [si], 0
    jne .has_args
    mov al, '*'
    stosb
    mov al, '.'
    stosb
    mov al, '*'
    stosb
    mov al, 0
    stosb
    jmp .search

.has_args:
.copy_args:
    lodsb
    cmp al, 0
    je .done_args
    cmp al, ' '
    je .done_args
    cmp al, 13
    je .done_args
    stosb
    jmp .copy_args
.done_args:
    mov byte [di], 0
    call fix_filespec

.search:
    mov dx, find_name
    mov cx, 3Fh
    mov ah, 4Eh
    int 21h
    jc .not_found

    mov word [file_cnt], 0
    mov byte [prev_name], 0

.loop:
    cmp word [file_cnt], 0
    je .not_dup
    mov si, dta_buf + 1Eh
    mov di, prev_name
    mov cx, 13
    repe cmpsb
    jne .not_dup
    mov ax, word [dta_buf + 1Ah]
    cmp ax, word [prev_size]
    jne .not_dup
    jmp .summary
.not_dup:
    mov si, dta_buf + 1Eh
    mov di, prev_name
    mov cx, 13
    rep movsb
    mov ax, word [dta_buf + 1Ah]
    mov word [prev_size], ax

    mov byte [dta_buf + 1Eh + 13], 0
    mov dx, dta_buf + 1Eh
    call print_str_dos

    mov al, ' '
    call print_char
    mov al, ' '
    call print_char

    mov ax, word [dta_buf + 1Ah]
    call print_num16

    call crlf

    inc word [file_cnt]

    mov ah, 4Fh
    int 21h
    jnc .loop

.summary:
    mov ax, [file_cnt]
    call print_num16
    mov dx, msg_dirmes
    call print_str
    ret

.not_found:
    mov dx, msg_notfound
    call print_str
    ret

cmd_del:
    mov si, word [arg_ptr]
    cmp byte [si], 0
    je .err

    mov ah, 1Ah
    mov dx, dta_buf
    int 21h

    mov di, find_name
.copy_args:
    lodsb
    cmp al, 0
    je .done_args
    cmp al, ' '
    je .done_args
    cmp al, 13
    je .done_args
    stosb
    jmp .copy_args
.done_args:
    mov byte [di], 0
    call fix_filespec

    mov dx, find_name
    mov cx, 3Fh
    mov ah, 4Eh
    int 21h
    jc .err

.loop:
    mov byte [dta_buf + 1Eh + 13], 0
    mov dx, dta_buf + 1Eh
    mov ah, 41h
    int 21h

    mov ah, 4Fh
    int 21h
    jnc .loop

    ret
.err:
    mov dx, msg_notfound
    call print_str
    ret

cmd_ren:
    mov si, word [arg_ptr]
    mov di, si
.find_space:
    cmp byte [di], ' '
    je .found_space
    cmp byte [di], 0
    je .err
    inc di
    jmp .find_space
.found_space:
    mov byte [di], 0
    inc di
.skip:
    cmp byte [di], ' '
    jne .got_dst
    inc di
    jmp .skip
.got_dst:
    mov dx, si
    push ds
    pop es
    mov ah, 56h
    int 21h
    jnc .ok
.err:
    mov dx, msg_notfound
    call print_str
    ret
.ok:
    ret

cmd_type:
    mov si, word [arg_ptr]
    cmp byte [si], 0
    je .err
    mov dx, si
    mov ax, 3D00h
    int 21h
    jc .err

    mov bx, ax
.read_loop:
    mov cx, 4096
    mov dx, copy_buf
    mov ah, 3Fh
    int 21h
    jc .close
    test ax, ax
    jz .close

    mov cx, ax
    mov si, copy_buf
.print_loop:
    lodsb
    call print_char
    loop .print_loop
    jmp .read_loop

.close:
    mov ah, 3Eh
    int 21h
    ret
.err:
    mov dx, msg_notfound
    call print_str
    ret

cmd_copy:
    mov si, word [arg_ptr]
    mov di, si
.find_space:
    cmp byte [di], ' '
    je .found_space
    cmp byte [di], 0
    je .err
    inc di
    jmp .find_space
.found_space:
    mov byte [di], 0
    inc di
.skip:
    cmp byte [di], ' '
    jne .got_dst
    inc di
    jmp .skip
.got_dst:
    mov dx, si
    mov ax, 3D00h
    int 21h
    jc .err
    mov word [src_handle], ax

    mov dx, di
    mov cx, 0
    mov ah, 3Ch
    int 21h
    jc .close_src
    mov word [dst_handle], ax

.read_loop:
    mov cx, 4096
    mov dx, copy_buf
    mov bx, [src_handle]
    mov ah, 3Fh
    int 21h
    jc .close_both
    test ax, ax
    jz .close_both

    mov cx, ax
    mov dx, copy_buf
    mov bx, [dst_handle]
    mov ah, 40h
    int 21h
    jc .close_both
    jmp .read_loop

.close_both:
    mov bx, [dst_handle]
    mov ah, 3Eh
    int 21h
.close_src:
    mov bx, [src_handle]
    mov ah, 3Eh
    int 21h

    mov dx, msg_copied
    call print_str
    ret
.err:
    mov dx, msg_notfound
    call print_str
    ret

cmd_exec:
    push cs
    pop ds
    push cs
    pop es

    mov si, cmd_upper
    mov di, find_name
    mov cx, 8
.copy8:
    lodsb
    test al, al
    jz .pad
    stosb
    loop .copy8
    jmp .dot
.pad:
    mov al, ' '
    stosb
    loop .copy8
.dot:
    mov al, '.'
    stosb
    mov al, 'C'
    stosb
    mov al, 'O'
    stosb
    mov al, 'M'
    stosb
    mov byte [di], 0

    mov ah, 1Ah
    mov dx, dta_buf
    int 21h
    mov dx, find_name
    mov cx, 0
    mov ah, 4Eh
    int 21h
    jnc .found_com

    mov si, cmd_upper
    mov di, find_name
    mov cx, 8
.copy8_bat:
    lodsb
    test al, al
    jz .pad_bat
    stosb
    loop .copy8_bat
    jmp .dot_bat
.pad_bat:
    mov al, ' '
    stosb
    loop .copy8_bat
.dot_bat:
    mov al, '.'
    stosb
    mov al, 'B'
    stosb
    mov al, 'A'
    stosb
    mov al, 'T'
    stosb
    mov byte [di], 0
    mov dx, find_name
    mov ax, 3D00h
    int 21h
    jc .not_found_exec
    mov word [bat_handle], ax
    jmp .run_bat

.found_com:
    mov dx, find_name
    mov ax, 3D00h
    int 21h
    jc .not_found_exec
    mov bx, ax

    push bx
    mov ax, 3000h
    mov es, ax
    xor di, di
    xor ax, ax
    mov cx, 128
    rep stosw
    mov word [es:0000h], 20CDh
    mov word [es:0050h], 21CDh
    mov byte [es:0052h], 0CBh
    mov si, word [arg_ptr]
    mov di, 0081h
    xor cx, cx
.ce_args:
    lodsb
    test al, al
    jz .ce_args_done
    cmp al, 13
    je .ce_args_done
    stosb
    inc cl
    jmp .ce_args
.ce_args_done:
    mov byte [es:di], 0Dh
    mov byte [es:0080h], cl
    pop bx

    mov ax, 3000h
    mov ds, ax
    mov dx, 0100h
    mov cx, 0FF00h
    mov ah, 3Fh
    int 21h
    push ax

    mov ah, 3Eh
    int 21h

    pop cx
    push cs
    pop ds

    test cx, cx
    jz .not_found_exec

    mov ax, 3000h
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0FFFEh

    push ax
    mov ax, 0100h
    push ax

    mov ah, 1Ah
    mov dx, 0080h
    int 21h

    retf

.run_bat:
    mov bx, word [bat_handle]
.bat_loop:
    mov cx, 128
    mov dx, cmd_buf+2
    mov ah, 3Fh
    int 21h
    jc .bat_done
    test ax, ax
    jz .bat_done
    mov cx, ax
    mov byte [cmd_buf+2+cx], 0

    push bx
    call parse_cmd
    call dispatch
    pop bx
    jmp .bat_loop
.bat_done:
    mov bx, word [bat_handle]
    mov ah, 3Eh
    int 21h
    ret

.not_found_exec:
    mov dx, msg_badcmd
    call print_str
    ret
