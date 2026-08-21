; =====================================================================
; MiniDOS Kernel
; Format: Binary (SYS)
; =====================================================================
format binary as "sys"
org 0x0000

FT_USED         equ 0
FT_START_CL     equ 1
FT_CURRENT_CL   equ 3
FT_SECTORS_IN_CL equ 5
FT_SIZE_LOW     equ 7
FT_SIZE_HIGH    equ 9
FT_POS_LOW      equ 11
FT_POS_HIGH     equ 13
FT_DIR_PTR      equ 15
FT_DIR_SEC      equ 17
CONSOLE         equ 0FFFFh
MAX_HANDLES     equ 20

start:
    cli
    cld
    push cs
    pop ds
    push cs
    pop es
    push cs
    pop ss
    mov sp, 0xFFFE
    sti

    mov ax, cs
    mov es, ax
    mov bx, bpb_buffer
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 1
    mov dh, 0
    mov dl, 0
    int 0x13
    jc hang

    xor ax, ax
    mov al, byte [bpb_buffer + 0x0D]
    mov word [sec_per_clus], ax
    mov ax, word [bpb_buffer + 0x0E]
    mov word [resvd_sec_cnt], ax
    mov ax, word [bpb_buffer + 0x18]
    mov word [sec_per_trk], ax
    mov ax, word [bpb_buffer + 0x1A]
    mov word [num_heads], ax

    mov ax, word [bpb_buffer + 0x11]
    mov cl, 5
    shl ax, cl
    add ax, word [bpb_buffer + 0x0B]
    dec ax
    xor dx, dx
    div word [bpb_buffer + 0x0B]
    mov word [root_dir_sectors], ax

    xor ax, ax
    mov al, byte [bpb_buffer + 0x10]
    mul word [bpb_buffer + 0x16]
    add ax, word [bpb_buffer + 0x0E]
    mov word [first_root_dir_sec], ax
    add ax, word [root_dir_sectors]
    mov word [first_data_sec], ax

    xor ax, ax
    mov ds, ax
    mov word [0x20*4], terminate_process
    mov word [0x21*4], int21_handler
    mov ax, cs
    mov word [0x20*4+2], ax
    mov word [0x21*4+2], ax
    push cs
    pop ds

    mov cx, 3
    xor bx, bx
.ci_loop:
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov di, ax
    mov word [di+FT_USED], 1
    mov word [di+FT_DIR_PTR], CONSOLE
    inc bx
    cmp bx, cx
    jb .ci_loop

    call load_and_exec

hang:
    hlt
    jmp hang

command_name db "COMMAND.COM", 0
command_load_name db 'C','O','M','M','A','N','D',' ','C','O','M'
current_dir db "\", 0
dta_ptr dw 0x0080, 0x2000
user_seg dw 0
file_table rb MAX_HANDLES * 32
search_name db 13 dup(0)
search_dir_idx dw 0
buffer_name db 11 dup(' ')
old_name_buf db 11 dup(' ')
new_name_buf db 11 dup(' ')
create_attribs dw 0
lae_sector dw 0
lae_remaining dw 0
kbuf db 0

bpb_buffer rb 512
root_dir_sectors dw 0
first_root_dir_sec dw 0
first_data_sec dw 0
sec_per_clus dw 0
resvd_sec_cnt dw 0
sec_per_trk dw 0
num_heads dw 0
rfb_cluster dw 0
search_sec_current dw 0
search_sec_remaining dw 0
bytes_read dw 0
bytes_written dw 0
req_bytes dw 0
sector_tmp dw 0

terminate_process:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    push ax
    mov ax, 0x0100
    push ax
    retf

int21_handler:
    cld
    mov word [cs:user_seg], ds
    push ds
    push es
    push bx
    push cs
    pop ds
    mov bx, word [user_seg]
    mov es, bx

    cmp ah, 0x01
    je .get_char_echo
    cmp ah, 0x02
    je .print_char
    cmp ah, 0x06
    je .direct_console
    cmp ah, 0x08
    je .get_char
    cmp ah, 0x09
    je .print_string
    cmp ah, 0x0A
    je .buffered_input
    cmp ah, 0x19
    je .get_drive
    cmp ah, 0x1A
    je .set_dta
    cmp ah, 0x25
    je .set_vector
    cmp ah, 0x2A
    je .get_date
    cmp ah, 0x2C
    je .get_time
    cmp ah, 0x30
    je .get_version
    cmp ah, 0x35
    je .get_vector
    cmp ah, 0x36
    je .get_free_space
    cmp ah, 0x39
    je .make_dir
    cmp ah, 0x3A
    je .remove_dir
    cmp ah, 0x3B
    je .change_dir
    cmp ah, 0x3C
    je .create_file
    cmp ah, 0x3D
    je .open_file
    cmp ah, 0x3E
    je .close_file
    cmp ah, 0x3F
    je .read_file
    cmp ah, 0x40
    je .write_file
    cmp ah, 0x41
    je .delete_file
    cmp ah, 0x42
    je .lseek
    cmp ah, 0x45
    je .dup
    cmp ah, 0x46
    je .dup2
    cmp ah, 0x47
    je .get_current_dir
    cmp ah, 0x4C
    je terminate_process
    cmp ah, 0x4E
    je .find_first
    cmp ah, 0x4F
    je .find_next
    cmp ah, 0x56
    je .rename_file

    mov ax, 0x0001
    stc
    jmp .exit

.set_vector:
    push es
    push bx
    xor bx, bx
    mov es, bx
    mov bl, al
    shl bx, 2
    mov word [es:bx], dx
    mov word [es:bx+2], ds
    pop bx
    pop es
    clc
    jmp .exit

.get_vector:
    push ds
    push si
    xor si, si
    mov ds, si
    mov si, ax
    and si, 0xFF
    shl si, 2
    mov bx, word [ds:si]
    mov es, word [ds:si+2]
    pop si
    pop ds
    clc
    jmp .exit

.get_char_echo:
    mov ah, 0x00
    int 0x16
    mov dl, al
    push ax
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop ax
    clc
    jmp .exit

.direct_console:
    cmp dl, 0xFF
    je .dc_input
.dc_output:
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    clc
    jmp .exit
.dc_input:
    mov ah, 0x01
    int 0x16
    jz .dc_no_char
    clc
    jmp .exit
.dc_no_char:
    stc
    jmp .exit

.get_drive:
    mov al, 0
    clc
    jmp .exit

.get_version:
    mov al, 7
    mov bx, 0
    mov cx, 0
    mov dx, 0
    clc
    jmp .exit

.get_free_space:
    push cx
    push dx
    push si
    mov cx, 2
    xor bx, bx
.fat_scan:
    mov ax, cx
    call get_fat_entry
    test ax, ax
    jnz .fat_used
    inc bx
.fat_used:
    inc cx
    cmp cx, 4085
    jb .fat_scan
    mov ax, word [sec_per_clus]
    mov cx, 512
    mov dx, 4085
    pop si
    pop dx
    pop cx
    clc
    jmp .exit

.print_char:
    cmp word [file_table+32+FT_DIR_PTR], CONSOLE
    jne .pc_file
    push bx
    mov al, dl
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    clc
    jmp .exit
.pc_file:
    mov byte [kbuf], dl
    push word [cs:user_seg]
    push cs
    pop word [cs:user_seg]
    mov bx, 1
    mov dx, kbuf
    mov cx, 1
    call do_write
    pop word [cs:user_seg]
    clc
    jmp .exit

.print_string:
    cmp word [file_table+32+FT_DIR_PTR], CONSOLE
    jne .ps_file
    push si
    mov si, dx
.ps_loop:
    mov al, byte [es:si]
    inc si
    cmp al, '$'
    je .ps_done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .ps_loop
.ps_done:
    pop si
    clc
    jmp .exit
.ps_file:
    push si
    push cx
    mov si, dx
    xor cx, cx
.ps_len:
    mov al, byte [es:si]
    cmp al, '$'
    je .ps_got
    inc si
    inc cx
    jmp .ps_len
.ps_got:
    push word [cs:user_seg]
    push cs
    pop word [cs:user_seg]
    mov bx, 1
    mov dx, si
    sub dx, cx
    push cx
    call do_write
    pop cx
    pop word [cs:user_seg]
    pop cx
    pop si
    clc
    jmp .exit

.get_char:
    cmp word [file_table+FT_DIR_PTR], CONSOLE
    jne .gc_file
    mov ah, 0x00
    int 0x16
    clc
    jmp .exit
.gc_file:
    push word [cs:user_seg]
    push cs
    pop word [cs:user_seg]
    mov bx, 0
    mov dx, kbuf
    mov cx, 1
    call do_read
    pop word [cs:user_seg]
    mov al, byte [kbuf]
    clc
    jmp .exit

.buffered_input:
    cmp word [file_table+FT_DIR_PTR], CONSOLE
    jne .bi_file
    push bx
    push cx
    push dx
    push si
    mov di, dx
    xor ch, ch
    mov cl, byte [es:di]
    mov si, 2
    add di, si
.bi_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .bi_done
    cmp al, 0x08
    je .bi_backspace
    cmp si, cx
    jae .bi_loop
    push ax
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop ax
    mov byte [es:di], al
    inc di
    inc si
    jmp .bi_loop
.bi_backspace:
    cmp si, 2
    jbe .bi_loop
    dec si
    dec di
    mov ah, 0x0E
    mov al, 0x08
    mov bx, 0x0007
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .bi_loop
.bi_done:
    mov ah, 0x0E
    mov al, 0x0D
    mov bx, 0x0007
    int 0x10
    mov al, 0x0A
    int 0x10
    mov ax, si
    sub ax, 2
    mov bx, dx
    mov byte [es:bx+1], al
    pop si
    pop dx
    pop cx
    pop bx
    clc
    jmp .exit
.bi_file:
    push bx
    push cx
    push dx
    push si
    push bp
    mov bp, dx
    xor ch, ch
    mov cl, byte [es:bp]
    lea di, [bp+2]
    xor si, si
.bif_loop:
    cmp si, cx
    jae .bif_done
    push word [cs:user_seg]
    push cs
    pop word [cs:user_seg]
    mov bx, 0
    mov dx, kbuf
    mov cx, 1
    call do_read
    pop word [cs:user_seg]
    test ax, ax
    jz .bif_eof
    mov al, byte [kbuf]
    cmp al, 0x0D
    je .bif_done
    mov byte [es:di], al
    inc di
    inc si
    jmp .bif_loop
.bif_eof:
    call .reset_console0
.bif_done:
    mov ax, si
    mov byte [es:bp+1], al
    pop bp
    pop si
    pop dx
    pop cx
    pop bx
    clc
    jmp .exit

.reset_console0:
    mov di, file_table
    mov word [di+FT_USED], 1
    mov word [di+FT_DIR_PTR], CONSOLE
    ret

.set_dta:
    mov word [dta_ptr], dx
    mov word [dta_ptr+2], es
    clc
    jmp .exit

.get_date:
    mov ah, 0x04
    int 0x1A
    clc
    jmp .exit

.get_time:
    mov ah, 0x02
    int 0x1A
    mov dl, 0
    clc
    jmp .exit

.make_dir:
.remove_dir:
    mov ax, 0x0003
    stc
    jmp .exit

.change_dir:
    push si
    mov si, dx
    cmp byte [es:si], '\'
    je .cd_ok
    cmp byte [es:si], '/'
    je .cd_ok
    cmp byte [es:si], 0
    je .cd_ok
    mov ax, 0x0003
    stc
    pop si
    jmp .exit
.cd_ok:
    mov word [current_dir], '\'
    mov byte [current_dir+1], 0
    pop si
    clc
    jmp .exit

.get_current_dir:
    push si
    push di
    mov di, si
    mov si, current_dir
    cmp byte [si], '\'
    jne .gc_copy
    inc si
.gc_copy:
    lodsb
    stosb
    test al, al
    jnz .gc_copy
    pop di
    pop si
    clc
    jmp .exit

.lseek:
    cmp bx, MAX_HANDLES
    jae .ls_fail
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov bp, ax
    cmp word [bp+FT_USED], 0
    je .ls_fail
    mov word [bp+FT_POS_LOW], dx
    mov word [bp+FT_POS_HIGH], cx
    mov ax, dx
    mov dx, cx
    clc
    jmp .exit
.ls_fail:
    mov ax, 0x0006
    stc
    jmp .exit

.dup:
    call alloc_file_handle
    jc .exit
    push ax
    shl ax, 5
    add ax, file_table
    mov di, ax
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov si, ax
    mov cx, 10
    rep movsw
    pop ax
    clc
    jmp .exit

.dup2:
    push bx
    push cx
    mov ax, cx
    shl ax, 5
    add ax, file_table
    mov si, ax
    cmp word [si+FT_USED], 0
    je .d2_copy
    mov word [si+FT_USED], 0
.d2_copy:
    mov ax, cx
    shl ax, 5
    add ax, file_table
    mov di, ax
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov si, ax
    mov cx, 10
    rep movsw
    pop cx
    pop bx
    clc
    jmp .exit

.open_file:
    call parse_filename
    jc .of_fail
    call search_root_dir
    jc .of_fail
    call alloc_file_handle
    jc .of_fail
    mov dx, ax
    shl ax, 5
    add ax, file_table
    mov bx, ax
    mov word [bx + FT_USED], 1
    mov ax, word [es:di + 26]
    mov word [bx + FT_START_CL], ax
    mov word [bx + FT_CURRENT_CL], ax
    mov word [bx + FT_SECTORS_IN_CL], 0
    mov ax, word [es:di + 28]
    mov word [bx + FT_SIZE_LOW], ax
    mov ax, word [es:di + 30]
    mov word [bx + FT_SIZE_HIGH], ax
    mov word [bx + FT_POS_LOW], 0
    mov word [bx + FT_POS_HIGH], 0
    mov word [bx + FT_DIR_PTR], di
    mov cx, word [search_sec_current]
    mov word [bx + FT_DIR_SEC], cx
    mov ax, dx
    clc
    jmp .exit
.of_fail:
    mov ax, 0x0002
    stc
    jmp .exit

.close_file:
    cmp bx, MAX_HANDLES
    jae .cf_fail
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov si, ax
    cmp word [si + FT_USED], 0
    je .cf_fail
    mov word [si + FT_USED], 0
    clc
    jmp .exit
.cf_fail:
    mov ax, 0x0006
    stc
    jmp .exit

.read_file:
    cmp bx, MAX_HANDLES
    jae .rf_fail
    call do_read
    clc
    jmp .exit
.rf_fail:
    mov ax, 0x0006
    stc
    jmp .exit

.write_file:
    cmp bx, MAX_HANDLES
    jae .wf_fail
    call do_write
    clc
    jmp .exit
.wf_fail:
    mov ax, 0x0006
    stc
    jmp .exit

.create_file:
    mov word [create_attribs], cx
    call parse_filename
    jc .cre_fail
    call search_root_dir
    jnc .cre_fail_exists
    call find_empty_dir_entry
    jc .cre_fail_full

    mov bx, 0x3000
    mov es, bx
    push di
    mov cx, 32
    xor al, al
    rep stosb
    pop di

    push di
    push cs
    pop ds
    mov si, buffer_name
    mov cx, 11
    rep movsb
    pop di
    push cs
    pop ds

    mov cx, word [create_attribs]
    mov byte [es:di + 0Bh], cl
    mov word [es:di + 1Ah], 0
    mov word [es:di + 1Ch], 0
    mov word [es:di + 20h], 0
    mov word [es:di + 22h], 0
    mov word [es:di + 26], 0

    mov cx, word [search_sec_current]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call write_sector_int13
    jc .cre_fail_io

    call alloc_file_handle
    jc .cre_fail_handles

    mov dx, ax
    shl ax, 5
    add ax, file_table
    mov bx, ax
    mov word [bx + FT_USED], 1
    mov word [bx + FT_START_CL], 0
    mov word [bx + FT_CURRENT_CL], 0
    mov word [bx + FT_SECTORS_IN_CL], 0
    mov word [bx + FT_SIZE_LOW], 0
    mov word [bx + FT_SIZE_HIGH], 0
    mov word [bx + FT_POS_LOW], 0
    mov word [bx + FT_POS_HIGH], 0
    mov word [bx + FT_DIR_PTR], di
    mov cx, word [search_sec_current]
    mov word [bx + FT_DIR_SEC], cx
    mov ax, dx
    clc
    jmp .exit
.cre_fail_exists:
    mov ax, 0x0005
    stc
    jmp .exit
.cre_fail_full:
    mov ax, 0x000B
    stc
    jmp .exit
.cre_fail_io:
    mov ax, 0x0013
    stc
    jmp .exit
.cre_fail_handles:
    mov ax, 0x0004
    stc
    jmp .exit
.cre_fail:
    mov ax, 0x0002
    stc
    jmp .exit

.delete_file:
    call parse_filename
    jc .del_fail
    call search_root_dir
    jc .del_fail
    mov bx, 0x3000
    mov ds, bx
    mov ax, word [di + 26]
    push ax
    push cs
    pop ds
    mov bx, 0x3000
    mov es, bx
    mov byte [es:di], 0xE5
    mov cx, word [search_sec_current]
    xor bx, bx
    call write_sector_int13
    pop ax
    call free_cluster_chain
    clc
    jmp .exit
.del_fail:
    mov ax, 0x0002
    stc
    jmp .exit

.rename_file:
    push di
    call parse_filename
    push es
    push di
    push cs
    pop es
    mov di, old_name_buf
    mov si, buffer_name
    mov cx, 11
    rep movsb
    pop di
    pop es

    mov dx, di
    call parse_filename

    push es
    push di
    push cs
    pop es
    mov di, new_name_buf
    mov si, buffer_name
    mov cx, 11
    rep movsb
    pop di
    pop es

    push es
    push di
    push cs
    pop es
    mov di, buffer_name
    mov si, new_name_buf
    mov cx, 11
    rep movsb
    pop di
    pop es

    call search_root_dir
    jnc .rename_fail_exists

    push es
    push di
    push cs
    pop es
    mov di, buffer_name
    mov si, old_name_buf
    mov cx, 11
    rep movsb
    pop di
    pop es

    call search_root_dir
    jc .rename_fail_not_found

    push es
    push di
    push cs
    pop ds
    mov si, new_name_buf
    pop di
    pop es
    mov cx, 11
    rep movsb

    mov cx, word [search_sec_current]
    xor bx, bx
    call write_sector_int13
    jc .rename_fail_io
    clc
    jmp .exit
.rename_fail_exists:
    mov ax, 0x0005
    stc
    jmp .exit
.rename_fail_not_found:
    mov ax, 0x0002
    stc
    jmp .exit
.rename_fail_io:
    mov ax, 0x0013
    stc
    jmp .exit

.find_first:
    mov word [search_dir_idx], 0
    mov si, dx
    mov di, search_name
    mov cx, 13
.ff_copy:
    mov al, byte [es:si]
    mov byte [di], al
    inc si
    inc di
    loop .ff_copy
    xor bx, bx
    jmp .do_find

.find_next:
    mov bx, word [search_dir_idx]
    jmp .do_find

.do_find:
    push es
    push di
    push cs
    pop es
    mov di, buffer_name
    mov cx, 11
    mov al, ' '
    rep stosb
    mov si, search_name
    mov di, buffer_name
    mov cx, 8
.dp_name:
    mov al, [si]
    inc si
    cmp al, 0
    je .dp_ext_done
    cmp al, '.'
    je .dp_ext
    stosb
    loop .dp_name
    cmp byte [si], '.'
    je .dp_ext
    jmp .dp_ext_done
.dp_ext:
    mov di, buffer_name + 8
    mov cx, 3
.dp_extl:
    mov al, [si]
    inc si
    cmp al, 0
    je .dp_ext_done
    stosb
    loop .dp_extl
.dp_ext_done:
    pop di
    pop es

    mov ax, word [root_dir_sectors]
    mov cl, 4
    shl ax, cl
    mov bp, ax
    cmp bx, bp
    jae .ff_fail

    mov cx, bx
    shr cx, 4
    add cx, word [first_root_dir_sec]
    mov dx, bx
    and dx, 15
    mov di, dx
    shl di, 5

    push bx
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop bx

.ff_search:
    mov al, byte [es:di]
    cmp al, 0x00
    je .ff_fail
    cmp al, 0xE5
    je .ff_advance
    mov al, byte [es:di + 11]
    test al, 0x18
    jnz .ff_advance
    call match_entry
    jnc .ff_found
.ff_advance:
    add di, 32
    inc bx
    cmp bx, bp
    jae .ff_fail
    mov dx, bx
    and dx, 15
    jnz .ff_search
    inc cx
    push bx
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop bx
    xor di, di
    jmp .ff_search

.ff_found:
    mov word [search_dir_idx], bx
    inc word [search_dir_idx]

    push di
    mov ax, [dta_ptr+2]
    mov es, ax
    mov di, [dta_ptr]
    push cx
    mov cx, 44
    xor al, al
    rep stosb
    pop cx
    mov di, [dta_ptr]
    pop si
    push es
    mov ax, 0x3000
    mov ds, ax

    mov al, [si+0Bh]
    mov [es:di+15h], al
    mov ax, [si+16h]
    mov [es:di+16h], ax
    mov ax, [si+18h]
    mov [es:di+18h], ax
    mov ax, [si+1Ch]
    mov [es:di+1Ah], ax
    mov ax, [si+1Eh]
    mov [es:di+1Ch], ax

    add di, 1Eh
    mov cx, 8
.name_loop:
    mov al, [si]
    cmp al, ' '
    je .name_skip
    mov [es:di], al
    inc di
.name_skip:
    inc si
    loop .name_loop
    mov byte [es:di], '.'
    inc di
    mov cx, 3
.ext_loop:
    mov al, [si]
    cmp al, ' '
    je .ext_skip
    mov [es:di], al
    inc di
.ext_skip:
    inc si
    loop .ext_loop
    mov byte [es:di], 0
    push cs
    pop ds
    pop es
    clc
    jmp .exit
.ff_fail:
    mov ax, 0x0012
    stc
    jmp .exit

.exit:
    pop bx
    pop es
    pop ds
    iret

do_read:
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov bp, ax
    cmp word [bp + FT_USED], 0
    je .dr_zero

    push bx
    push cx
    push dx
    push es
    push bp
    mov word [bytes_read], 0
    mov word [req_bytes], cx

.dr_loop:
    mov ax, word [bytes_read]
    cmp ax, word [req_bytes]
    jge .dr_done
    mov ax, word [bp+FT_POS_LOW]
    cmp ax, word [bp+FT_SIZE_LOW]
    jb .dr_ok
    mov ax, word [bp+FT_POS_HIGH]
    cmp ax, word [bp+FT_SIZE_HIGH]
    jb .dr_ok
    jmp .dr_done
.dr_ok:
    mov ax, word [bp + FT_CURRENT_CL]
    sub ax, 2
    xor dx, dx
    mov bx, word [sec_per_clus]
    mul bx
    add ax, word [first_data_sec]
    add ax, word [bp + FT_SECTORS_IN_CL]
    mov cx, ax

    push cx
    push dx
    push bp
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop bp
    pop dx
    pop cx

    mov ax, word [bp + FT_POS_LOW]
    and ax, 511
    mov bx, 512
    sub bx, ax
    mov ax, word [req_bytes]
    sub ax, word [bytes_read]
    cmp ax, bx
    jbe .dr_copy
.dr_copy:
    push ds
    push es
    push si
    push di
    push cx
    mov cx, bx
    mov ax, word [bp + FT_POS_LOW]
    and ax, 511
    mov si, ax
    mov ax, 0x3000
    mov ds, ax
    mov ax, word [user_seg]
    mov es, ax
    mov di, dx
    rep movsb
    pop cx
    pop di
    pop si
    pop es
    pop ds
    push cs
    pop ds

    add word [bytes_read], bx
    add dx, bx
    add word [bp + FT_POS_LOW], bx
    adc word [bp + FT_POS_HIGH], 0

    inc word [bp + FT_SECTORS_IN_CL]
    mov ax, word [bp + FT_SECTORS_IN_CL]
    cmp ax, word [sec_per_clus]
    jb .dr_loop

    mov word [bp + FT_SECTORS_IN_CL], 0
    mov ax, word [bp + FT_CURRENT_CL]
    call get_fat_entry
    mov word [bp + FT_CURRENT_CL], ax
    jmp .dr_loop

.dr_done:
    mov ax, word [bytes_read]
    pop bp
    pop es
    pop dx
    pop cx
    pop bx
    ret
.dr_zero:
    xor ax, ax
    ret

do_write:
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov bp, ax
    cmp word [bp + FT_USED], 0
    je .dw_zero

    push bx
    push cx
    push dx
    push es
    push bp
    mov word [bytes_written], 0
    mov word [req_bytes], cx

.dw_loop:
    mov ax, word [bytes_written]
    cmp ax, word [req_bytes]
    jge .dw_done

    mov ax, word [bp + FT_CURRENT_CL]
    test ax, ax
    jnz .dw_has
    call find_free_cluster
    test ax, ax
    jz .dw_ioerr
    mov word [bp + FT_START_CL], ax
    mov word [bp + FT_CURRENT_CL], ax
    mov dx, 0xFFF
    call set_fat_entry

.dw_has:
    mov ax, word [bp + FT_CURRENT_CL]
    sub ax, 2
    xor dx, dx
    mov bx, word [sec_per_clus]
    mul bx
    add ax, word [first_data_sec]
    add ax, word [bp + FT_SECTORS_IN_CL]
    mov cx, ax

    mov ax, word [bp + FT_POS_LOW]
    and ax, 511
    mov bx, 512
    sub bx, ax
    mov ax, word [req_bytes]
    sub ax, word [bytes_written]
    cmp ax, bx
    jbe .dw_copy
.dw_copy:
    push cx
    push bx
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop bx
    pop cx

    push ds
    push es
    push si
    push di
    push cx
    mov ax, word [bp + FT_POS_LOW]
    and ax, 511
    mov di, ax
    mov ax, 0x3000
    mov es, ax
    mov ax, word [user_seg]
    mov ds, ax
    mov si, dx
    mov cx, bx
    rep movsb
    pop cx
    pop di
    pop si
    pop es
    pop ds
    push cs
    pop ds

    push cx
    push bx
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call write_sector_int13
    pop bx
    pop cx

    add word [bytes_written], bx
    add dx, bx
    add word [bp + FT_POS_LOW], bx
    adc word [bp + FT_POS_HIGH], 0

    inc word [bp + FT_SECTORS_IN_CL]
    mov ax, word [bp + FT_SECTORS_IN_CL]
    cmp ax, word [sec_per_clus]
    jb .dw_loop

    mov word [bp + FT_SECTORS_IN_CL], 0
    mov ax, word [bp + FT_CURRENT_CL]
    call get_fat_entry
    cmp ax, 0xFF8
    jb .dw_next

    call find_free_cluster
    test ax, ax
    jz .dw_ioerr
    push ax
    mov dx, ax
    mov ax, word [bp + FT_CURRENT_CL]
    call set_fat_entry
    pop ax
    mov dx, 0xFFF
    call set_fat_entry

.dw_next:
    mov word [bp + FT_CURRENT_CL], ax
    jmp .dw_loop

.dw_done:
    mov ax, word [bp + FT_POS_LOW]
    mov dx, word [bp + FT_POS_HIGH]
    cmp dx, word [bp + FT_SIZE_HIGH]
    ja .dw_up
    jb .dw_skip
    cmp ax, word [bp + FT_SIZE_LOW]
    jbe .dw_skip
.dw_up:
    mov word [bp + FT_SIZE_LOW], ax
    mov word [bp + FT_SIZE_HIGH], dx

    mov cx, word [bp + FT_DIR_SEC]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13

    mov di, word [bp + FT_DIR_PTR]
    mov ax, word [bp + FT_SIZE_LOW]
    mov word [es:di + 20h], ax
    mov ax, word [bp + FT_SIZE_HIGH]
    mov word [es:di + 22h], ax

    mov cx, word [bp + FT_DIR_SEC]
    xor bx, bx
    call write_sector_int13

.dw_skip:
    mov ax, word [bytes_written]
    pop bp
    pop es
    pop dx
    pop cx
    pop bx
    ret
.dw_ioerr:
    pop bp
    pop es
    pop dx
    pop cx
    pop bx
    mov ax, 0
    ret
.dw_zero:
    xor ax, ax
    ret

match_entry:
    push si
    push di
    push cx
    mov si, buffer_name
    mov cx, 8
    call .field
    jc .me_no
    mov cx, 3
    call .field
.me_no:
    pop cx
    pop di
    pop si
    ret
.field:
.fl:
    mov al, [si]
    cmp al, '*'
    je .fok
    cmp al, '?'
    je .fx
    cmp al, byte [es:di]
    jne .fno
.fx:
    inc si
    inc di
    dec cx
    jnz .fl
.fok:
    clc
    ret
.fno:
    stc
    ret

parse_filename:
    push si
    push di
    mov si, dx
    mov di, buffer_name
    mov cx, 11
    mov al, ' '
    rep stosb
    pop di
    pop si
    mov cx, 8
.pf_name:
    mov al, byte [es:si]
    inc si
    cmp al, 0
    je .pf_done
    cmp al, '.'
    je .pf_ext
    cmp al, 'a'
    jb .pf_upper
    cmp al, 'z'
    ja .pf_upper
    sub al, 20h
.pf_upper:
    stosb
    loop .pf_name
    jmp .pf_ext_check
.pf_ext:
    mov di, buffer_name + 8
    mov cx, 3
.pf_ext_loop:
    mov al, byte [es:si]
    inc si
    cmp al, 0
    je .pf_done
    cmp al, 'a'
    jb .pf_eu
    cmp al, 'z'
    ja .pf_eu
    sub al, 20h
.pf_eu:
    stosb
    loop .pf_ext_loop
.pf_ext_check:
    cmp byte [es:si], '.'
    jne .pf_done
    inc si
    mov di, buffer_name + 8
    mov cx, 3
    jmp .pf_ext_loop
.pf_done:
    clc
    ret

search_root_dir:
    mov ax, word [first_root_dir_sec]
    mov word [search_sec_current], ax
    mov ax, word [root_dir_sectors]
    mov word [search_sec_remaining], ax
.search_loop:
    cmp word [search_sec_remaining], 0
    je .not_found
    mov cx, word [search_sec_current]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    mov cx, 16
    xor di, di
.search_entry:
    push cx
    mov cx, 11
    mov si, buffer_name
    push di
    repe cmpsb
    pop di
    pop cx
    je .found
    add di, 32
    loop .search_entry
    inc word [search_sec_current]
    dec word [search_sec_remaining]
    jmp .search_loop
.found:
    clc
    ret
.not_found:
    stc
    ret

find_empty_dir_entry:
    mov ax, word [first_root_dir_sec]
    mov word [search_sec_current], ax
    mov ax, word [root_dir_sectors]
    mov word [search_sec_remaining], ax
.fed_loop:
    cmp word [search_sec_remaining], 0
    je .fed_not_found
    mov cx, word [search_sec_current]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    mov cx, 16
    xor di, di
.fed_entry:
    mov al, byte [es:di]
    cmp al, 0x00
    je .fed_found
    cmp al, 0xE5
    je .fed_found
    add di, 32
    loop .fed_entry
    inc word [search_sec_current]
    dec word [search_sec_remaining]
    jmp .fed_loop
.fed_found:
    clc
    ret
.fed_not_found:
    stc
    ret

alloc_file_handle:
    mov cx, MAX_HANDLES
    xor bx, bx
.afh_loop:
    mov ax, bx
    shl ax, 5
    add ax, file_table
    mov si, ax
    cmp word [si + FT_USED], 0
    je .afh_found
    inc bx
    loop .afh_loop
    stc
    ret
.afh_found:
    mov ax, bx
    clc
    ret

get_fat_entry:
    push bx
    push cx
    push es
    mov bx, ax
    shr bx, 1
    add bx, ax
    mov cx, bx
    shr cx, 9
    add cx, word [resvd_sec_cnt]
    push bx
    push ax
    mov ax, cx
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop ax
    pop bx
    and bx, 0x1FF
    mov dx, word [es:bx]
    test ax, 1
    jz .gfe_even
    shr dx, 4
    jmp .gfe_done
.gfe_even:
    and dx, 0x0FFF
.gfe_done:
    mov ax, dx
    pop es
    pop cx
    pop bx
    ret

set_fat_entry:
    push bx
    push cx
    push es
    push si
    mov si, dx
    mov bx, ax
    shr bx, 1
    add bx, ax
    mov cx, bx
    shr cx, 9
    add cx, word [resvd_sec_cnt]
    push bx
    push ax
    push cx
    mov ax, cx
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop cx
    pop ax
    pop bx
    and bx, 0x1FF
    test ax, 1
    jz .sfe_even
    mov ax, word [es:bx]
    and ax, 0x000F
    shl si, 4
    or ax, si
    mov word [es:bx], ax
    jmp .sfe_write
.sfe_even:
    mov ax, word [es:bx]
    and ax, 0xF000
    and si, 0x0FFF
    or ax, si
    mov word [es:bx], ax
.sfe_write:
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call write_sector_int13
    pop si
    pop es
    pop cx
    pop bx
    ret

find_free_cluster:
    push bx
    push cx
    push dx
    mov cx, 2
.ffc_loop:
    mov ax, cx
    call get_fat_entry
    test ax, ax
    jz .ffc_found
    inc cx
    cmp cx, 4085
    jb .ffc_loop
    xor ax, ax
    jmp .ffc_done
.ffc_found:
    mov ax, cx
.ffc_done:
    pop dx
    pop cx
    pop bx
    ret

free_cluster_chain:
    push bx
    push cx
    push dx
.fcc_loop:
    test ax, ax
    jz .fcc_done
    cmp ax, 0xFF8
    jae .fcc_done
    mov cx, ax
    call get_fat_entry
    push ax
    mov ax, cx
    xor dx, dx
    call set_fat_entry
    pop ax
    jmp .fcc_loop
.fcc_done:
    pop dx
    pop cx
    pop bx
    ret

read_sector_int13:
    push ax
    push cx
    push dx
    push es
    mov word [sector_tmp], cx
.rsi_chs:
    xor dx, dx
    mov ax, word [sector_tmp]
    div word [sec_per_trk]
    inc dl
    mov cl, dl
    xor dx, dx
    div word [num_heads]
    mov ch, al
    mov dh, dl
    mov dl, 0
    mov ah, 0x02
    mov al, 1
    int 0x13
    jnc .rsi_ok
    push ax
    xor ah, ah
    mov dl, 0
    int 0x13
    pop ax
    jmp .rsi_chs
.rsi_ok:
    pop es
    pop dx
    pop cx
    pop ax
    ret

write_sector_int13:
    push ax
    push cx
    push dx
    push es
    mov word [sector_tmp], cx
.wsi_chs:
    xor dx, dx
    mov ax, word [sector_tmp]
    div word [sec_per_trk]
    inc dl
    mov cl, dl
    xor dx, dx
    div word [num_heads]
    mov ch, al
    mov dh, dl
    mov dl, 0
    mov ah, 0x03
    mov al, 1
    int 0x13
    jnc .wsi_ok
    push ax
    xor ah, ah
    mov dl, 0
    int 0x13
    pop ax
    jmp .wsi_chs
.wsi_ok:
    pop es
    pop dx
    pop cx
    pop ax
    ret

load_and_exec:
    cld
    mov ax, word [first_root_dir_sec]
    mov word [lae_sector], ax
    mov ax, word [root_dir_sectors]
    mov word [lae_remaining], ax

.lae_next_sec:
    cmp word [lae_remaining], 0
    je hang
    mov cx, word [lae_sector]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13

    mov cx, 16
    xor di, di
.lae_entry:
    mov al, byte [es:di]
    cmp al, 0xE5
    je .lae_skip
    cmp al, 0x00
    je .lae_skip
    mov si, command_load_name
    push di
    push cx
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    je .lae_found
.lae_skip:
    add di, 32
    loop .lae_entry

    inc word [lae_sector]
    dec word [lae_remaining]
    jmp .lae_next_sec

.lae_found:
    mov ax, word [es:di + 26]
    mov word [rfb_cluster], ax

    mov bx, 0x1000
    mov es, bx
    mov bp, 0x0100

.lae_load_loop:
    mov ax, word [rfb_cluster]
    cmp ax, 0xFF8
    jae .lae_exec

    sub ax, 2
    xor dx, dx
    mov dl, byte [sec_per_clus]
    mul dx
    add ax, word [first_data_sec]
    mov cx, ax

    xor dx, dx
    mov dl, byte [sec_per_clus]

.lae_read_sec:
    mov bx, bp
    push cx
    push dx
    call read_sector_int13
    pop dx
    pop cx

    add bp, 512
    jnc .lae_no_carry
    push cx
    mov cx, es
    add cx, 0x1000
    mov es, cx
    pop cx
.lae_no_carry:
    inc cx
    dec dx
    jnz .lae_read_sec

    mov ax, word [rfb_cluster]
    mov bx, ax
    shr bx, 1
    add bx, ax
    mov cx, bx
    shr cx, 9
    add cx, word [resvd_sec_cnt]

    push es
    push bx
    push ax
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    call read_sector_int13
    pop ax
    pop bx
    and bx, 0x1FF
    mov dx, word [es:bx]
    pop es

    test ax, 1
    jz .lae_even
    mov cl, 4
    shr dx, cl
    jmp .lae_store
.lae_even:
    and dx, 0x0FFF
.lae_store:
    mov word [rfb_cluster], dx
    jmp .lae_load_loop

.lae_exec:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    mov byte [es:0x0080], 0
    mov byte [es:0x0081], 0x0D
    push ax
    mov ax, 0x0100
    push ax
    retf
