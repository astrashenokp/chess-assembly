.MODEL small
INCLUDE shared.inc

.DATA
    EXTRN board:BYTE

    ; Table of piece characters
    piece_chars DB ' ', 1, 2, 3, 4, 5, 6

    INCLUDE sprites.inc

.CODE
; make procs public for main.asm
PUBLIC init_video_mode
PUBLIC draw_board
PUBLIC draw_piece
PUBLIC draw_cursor
PUBLIC highlight_moves
PUBLIC draw_status

; skelet of procs (mocks)
init_video_mode PROC
    mov ax, 0003h
    int 10h

    push bp
    push es

    mov ax, ds
    mov es, ax

    mov ax, 1100h           
    mov bh, 16              
    mov bl, 0                
    mov cx, 6               
    mov dx, 1               
    mov bp, OFFSET font_data 
    int 10h  

    pop es                
    pop bp

    mov ax, 0B800h
    mov es, ax
    ret
init_video_mode ENDP

draw_board PROC
    push ax
    push bx
    push cx
    push dx
    push di

    mov ch, 0
r_loop:
    mov cl, 0
c_loop:
    ; Cell color logic
    mov al, ch
    add al, cl
    test al, 1
    jz light_c
    mov dh, COLOR_DARK
    jmp draw_c
light_c:
    mov dh, COLOR_LIGHT

draw_c:
    push dx

    ; Offset calculation
    mov al, ch
    mov ah, CELL_HEIGHT
    mul ah
    add ax, BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax

    mov al, cl
    mov ah, CELL_WIDTH
    mul ah
    add ax, BOARD_LEFT
    shl ax, 1
    add di, ax

    pop dx

    ; Draw 4x2 cell
    mov ah, dh
    mov al, ' '
    mov es:[di], ax
    mov es:[di+2], ax
    mov es:[di+4], ax
    mov es:[di+6], ax
    mov es:[di+160], ax
    mov es:[di+162], ax
    mov es:[di+164], ax
    mov es:[di+166], ax

    ; Draw piece inside cell
    call draw_piece

    inc cl
    cmp cl, 8
    jl c_loop
    inc ch
    cmp ch, 8
    jl r_loop

    ; Labels 1-8 (Left)
    mov ch, 0
lbl_r:
    mov al, ch
    mov ah, 2
    mul ah
    add ax, BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax
    mov ax, BOARD_LEFT
    sub ax, 2
    shl ax, 1
    add di, ax
    mov al, '8'
    sub al, ch
    mov ah, 07h
    mov es:[di], ax
    inc ch
    cmp ch, 8
    jl lbl_r

    ; Labels a-h (Bottom)
    mov cl, 0
lbl_c:
    mov ax, BOARD_TOP
    add ax, 16
    mov bx, 160
    mul bx
    mov di, ax
    mov al, cl
    mov ah, 4
    mul ah
    add ax, BOARD_LEFT
    inc ax
    shl ax, 1
    add di, ax
    mov al, 'a'
    add al, cl
    mov ah, 07h
    mov es:[di], ax
    inc cl
    cmp cl, 8
    jl lbl_c

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_board ENDP

draw_piece PROC
    push ax
    push bx
    push di

    ; Index = row * 8 + col
    mov al, ch
    mov ah, 8
    mul ah
    add al, cl
    mov bx, ax
    xor bh, bh
    mov dl, board[bx]

    mov al, dl
    and al, TYPE_MASK
    jz dp_end

    mov bl, al
    xor bh, bh
    mov al, piece_chars[bx]

    ; Colors
    mov dh, ch
    add dh, cl
    test dh, 1
    jz p_light
    mov dh, COLOR_DARK
    jmp p_color
p_light:
    mov dh, COLOR_LIGHT
p_color:
    test dl, COLOR_MASK
    jz p_white
    and dh, 0F0h       ; Black piece
    jmp p_draw
p_white:
    and dh, 0F0h
    or dh, 0Fh         ; White piece

p_draw:
    push dx
    push ax
    mov al, ch
    mov ah, CELL_HEIGHT
    mul ah
    add ax, BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax
    mov al, cl
    mov ah, CELL_WIDTH
    mul ah
    add ax, BOARD_LEFT
    inc ax
    shl ax, 1
    add di, ax
    pop ax
    pop dx

    mov ah, dh
    mov es:[di], ax

dp_end:
    pop di
    pop bx
    pop ax
    ret
draw_piece ENDP

draw_cursor PROC
    push ax
    push bx
    push cx
    push dx
    push di

    mov al, ch
    mov ah, CELL_HEIGHT
    mul ah
    add ax, BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax
    mov al, cl
    mov ah, CELL_WIDTH
    mul ah
    add ax, BOARD_LEFT
    shl ax, 1
    add di, ax

    mov ah, 20h         ; Green highlight attribute
    mov al, es:[di]
    mov es:[di], ax
    mov al, es:[di+2]
    mov es:[di+2], ax
    mov al, es:[di+4]
    mov es:[di+4], ax
    mov al, es:[di+6]
    mov es:[di+6], ax
    mov al, es:[di+160]
    mov es:[di+160], ax
    mov al, es:[di+162]
    mov es:[di+162], ax
    mov al, es:[di+164]
    mov es:[di+164], ax
    mov al, es:[di+166]
    mov es:[di+166], ax

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_cursor ENDP

highlight_moves PROC
    ret
highlight_moves ENDP

draw_status PROC
    ret
draw_status ENDP

END