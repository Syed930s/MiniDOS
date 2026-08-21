format binary as "bin"
org 0x7C00

; ==========================================
; 1. Jump Instruction & NOP (Offset 0x00 - 0x02)
; ==========================================
jmp short start
nop

; ==========================================
; 2. BIOS Parameter Block (BPB) (Offset 0x03 - 0x3D)
; ==========================================
bpb_oem_name        db "MiniDOS "
bpb_byts_per_sec    dw 512
bpb_sec_per_clus    db 1
bpb_resvd_sec_cnt   dw 1
bpb_num_fats        db 2
bpb_root_ent_cnt    dw 224
bpb_tot_sec16       dw 2880
bpb_media           db 0xF0
bpb_fat_sz16        dw 9
bpb_sec_per_trk     dw 18
bpb_num_heads       dw 2
bpb_hidd_sec        dd 0
bpb_tot_sec32       dd 0

bpb_drv_num         db 0
bpb_reserved1       db 0
bpb_boot_sig        db 0x29
bpb_vol_id          dd 0x12345678
bpb_vol_label       db "MINIDOS    "
bpb_fil_sys_type    db "FAT12   "

; ==========================================
; 3. Bootloader Code (Offset 0x3E onwards)
; ==========================================
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld

    mov si, boot_msg
    call print_string

    ; Dynamic FAT12 Geometry Calculation
    mov ax, word [bpb_root_ent_cnt]
    mov cl, 5
    shl ax, cl
    add ax, word [bpb_byts_per_sec]
    dec ax
    xor dx, dx
    div word [bpb_byts_per_sec]
    mov word [root_dir_sectors], ax

    xor ax, ax
    mov al, byte [bpb_num_fats]
    mul word [bpb_fat_sz16]
    add ax, word [bpb_resvd_sec_cnt]
    mov word [first_root_dir_sec], ax

    add ax, word [root_dir_sectors]
    mov word [first_data_sec], ax

    ; Search Root Directory for Kernel
    mov ax, word [first_root_dir_sec]
    mov bx, 0x0500
    mov es, bx
    xor bx, bx

search_root_dir:
    mov cx, ax
    push ax
    call read_sector
    pop ax

    mov cx, 16
    mov di, bx
search_entry:
    mov si, kernel_name
    push di
    push cx
    mov cx, 11
    repe cmpsb
    pop cx
    je found_kernel
    pop di
    add di, 32
    loop search_entry

    inc ax
    dec word [root_dir_sectors]
    jnz search_root_dir

    mov si, err_msg
    call print_string
    jmp hang

found_kernel:
    pop di
    mov ax, word [es:di + 26]
    mov word [current_cluster], ax

    mov bx, 0x2000
    mov es, bx
    xor bp, bp                  ; BP = load offset

load_file_loop:
    mov ax, word [current_cluster]
    cmp ax, 0xFF8
    jae load_done

    sub ax, 2
    xor dx, dx
    mov dl, byte [bpb_sec_per_clus]
    mul dx
    add ax, word [first_data_sec]
    mov cx, ax

    xor dx, dx
    mov dl, byte [bpb_sec_per_clus]

.read_cluster_sectors:
    mov bx, bp
    push cx
    push dx
    call read_sector
    pop dx
    pop cx

    add bp, 512
    jnc .no_carry
    push cx
    mov cx, es
    add cx, 0x1000
    mov es, cx
    pop cx
.no_carry:
    inc cx
    dec dx
    jnz .read_cluster_sectors

    ; Get Next Cluster from FAT
    mov ax, word [current_cluster]
    mov bx, ax
    shr bx, 1
    add bx, ax

    mov cx, bx
    shr cx, 9
    add cx, word [bpb_resvd_sec_cnt]

    push es
    push bx
    push ax
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    call read_sector
    pop ax
    pop bx
    and bx, 0x1FF
    mov dx, word [es:bx]
    pop es

    test ax, 1
    jz .even_cluster
    mov cl, 4
    shr dx, cl
    jmp .store_cluster
.even_cluster:
    and dx, 0x0FFF
.store_cluster:
    mov word [current_cluster], dx
    jmp load_file_loop

load_done:
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    jmp 0x2000:0x0000

print_string:
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .loop
.done:
    pop si
    ret

read_sector:
    push ax
    push cx
    push dx
    push es
    mov word [sector_tmp], cx

.calc_chs:
    xor dx, dx
    mov ax, word [sector_tmp]
    div word [bpb_sec_per_trk]
    inc dl
    mov cl, dl
    xor dx, dx
    div word [bpb_num_heads]
    mov ch, al
    mov dh, dl
    mov dl, 0
    mov ah, 0x02
    mov al, 1
    int 0x13
    jnc .ok
    push ax
    xor ah, ah
    mov dl, 0
    int 0x13
    pop ax
    jmp .calc_chs
.ok:
    pop es
    pop dx
    pop cx
    pop ax
    ret

hang:
    cli
    hlt
    jmp hang

boot_msg db "Starting MiniDOS...", 13, 10, 0
err_msg db "MINIDOS.SYS not found!", 0
kernel_name db "MINIDOS SYS"

root_dir_sectors dw 0
first_root_dir_sec dw 0
first_data_sec dw 0
current_cluster dw 0
sector_tmp dw 0

times 510-($-$$) db 0
dw 0xAA55
