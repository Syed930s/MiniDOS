; MEM.COM - Memory usage reporter for MiniDOS
org 100h

start:
    push cs
    pop ds
    push cs
    pop es

    ; Get extended memory (above 1MB) in KB
    mov ah, 88h
    int 15h
    mov word [ext_mem], ax

    ; Print header
    mov dx, header
    mov ah, 09h
    int 21h

    ; Print conventional memory info
    mov dx, conv_msg
    call print_str
    mov ax, 640
    call print_num16
    mov dx, kb_msg
    call print_str

    ; Print extended memory info
    mov dx, ext_msg
    call print_str
    mov ax, word [ext_mem]
    call print_num16
    mov dx, kb_msg
    call print_str

    ; Calculate and print OS usage estimate
    ; Kernel at 2000:0000 (approx 8KB)
    ; Shell at 1000:0100 (approx 6KB)
    ; Buffers/misc (approx 2KB)
    ; Total OS usage: ~16KB
    mov dx, os_msg
    call print_str
    mov ax, 16
    call print_num16
    mov dx, kb_msg
    call print_str

    ; Print free conventional memory
    mov dx, free_msg
    call print_str
    mov ax, 640 - 16
    call print_num16
    mov dx, kb_msg
    call print_str

    ; Print total system memory
    mov dx, total_msg
    call print_str
    mov ax, 640
    add ax, word [ext_mem]
    call print_num16
    mov dx, kb_msg
    call print_str

    mov dx, crlf
    call print_str

    ; Exit
    mov ax, 4C00h
    int 21h

print_str:
    push ax
    mov ah, 09h
    int 21h
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

ext_mem dw 0
header db 13,10,"MiniDOS Memory Report",13,10
       db "=====================",13,10,"$"
conv_msg db "Conventional Memory: $"
ext_msg db "Extended Memory:     $"
os_msg db "OS Memory Usage:     $"
free_msg db "Free Memory:         $"
total_msg db "Total System Memory: $"
kb_msg db " KB",13,10,"$"
crlf db 13,10,"$"
