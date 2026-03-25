.MODEL small
INCLUDE shared.inc

.DATA
    EXTRN board:BYTE
    EXTRN move_list:BYTE
    EXTRN move_count:WORD
    EXTRN current_turn:BYTE

    EXTRN captured_by_white:BYTE, captured_by_black:BYTE
    EXTRN cap_w_count:WORD, cap_b_count:WORD

    ; Table of piece characters
    piece_chars DB ' ', 1, 2, 3, 4, 5, 6

    str_white DB 'TURN: WHITE', 0
    str_black DB 'TURN: BLACK', 0
    str_cap_title DB 'CAPTURED:', 0
    str_cap_w     DB 'by White: ', 0
    str_cap_b     DB 'by Black: ', 0

    INCLUDE sprites.inc

.CODE
LOCAL_BOARD_LEFT EQU 5 
LOCAL_BOARD_TOP EQU 2   

PUBLIC init_video_mode
PUBLIC draw_board
PUBLIC draw_piece
PUBLIC draw_cursor
PUBLIC highlight_moves
PUBLIC draw_status

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
    add ax, LOCAL_BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax

    mov al, cl
    mov ah, CELL_WIDTH
    mul ah
    add ax, LOCAL_BOARD_LEFT
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
    jge r_loop_check 
    jmp c_loop

r_loop_check:
    inc ch
    cmp ch, 8
    jge labels_draw   
    jmp r_loop

labels_draw:
    ; Labels 1-8 (Left)
    mov ch, 0
lbl_r:
    mov al, ch
    mov ah, 2
    mul ah
    add ax, LOCAL_BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax
    mov ax, LOCAL_BOARD_LEFT
    sub ax, 2
    shl ax, 1
    add di, ax
    mov al, '8'
    sub al, ch
    mov ah, 07h
    mov es:[di], ax
    inc ch
    cmp ch, 8
    jge lbl_c_start  
    jmp lbl_r

lbl_c_start:
    ; Labels a-h (Bottom)
    mov cl, 0
lbl_c:
    mov ax, LOCAL_BOARD_TOP
    add ax, 16
    mov bx, 160
    mul bx
    mov di, ax
    mov al, cl
    mov ah, 4
    mul ah
    add ax, LOCAL_BOARD_LEFT
    inc ax
    shl ax, 1
    add di, ax
    mov al, 'a'
    add al, cl
    mov ah, 07h
    mov es:[di], ax
    inc cl
    cmp cl, 8
    jge board_end
    jmp lbl_c

board_end:
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
    and dh, 0F0h       
    jmp p_draw
p_white:
    and dh, 0F0h
    or dh, 0Fh         

p_draw:
    push dx
    push ax
    mov al, ch
    mov ah, CELL_HEIGHT
    mul ah
    add ax, LOCAL_BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax
    mov al, cl
    mov ah, CELL_WIDTH
    mul ah
    add ax, LOCAL_BOARD_LEFT
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
    add ax, LOCAL_BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax
    mov al, cl
    mov ah, CELL_WIDTH
    mul ah
    add ax, LOCAL_BOARD_LEFT
    shl ax, 1
    add di, ax

    mov al, es:[di+1]   
    and al, 0Fh         
    or al, 10h          
    mov es:[di+1], al   
    mov al, es:[di+3]
    and al, 0Fh
    or al, 10h
    mov es:[di+3], al
    mov al, es:[di+5]
    and al, 0Fh
    or al, 10h
    mov es:[di+5], al
    mov al, es:[di+7]
    and al, 0Fh
    or al, 10h
    mov es:[di+7], al
    mov al, es:[di+161]
    and al, 0Fh
    or al, 10h
    mov es:[di+161], al
    mov al, es:[di+163]
    and al, 0Fh
    or al, 10h
    mov es:[di+163], al
    mov al, es:[di+165]
    and al, 0Fh
    or al, 10h
    mov es:[di+165], al
    mov al, es:[di+167]
    and al, 0Fh
    or al, 10h
    mov es:[di+167], al

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_cursor ENDP

highlight_moves PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    mov cx, move_count
    cmp cx, 0
    jne hm_start
    jmp hm_end
hm_start:
    mov si, offset move_list

hm_loop:
    push cx  

    mov ch, [si+2] 
    mov cl, [si+3] 

    mov al, ch
    mov ah, 8
    mul ah
    add al, cl
    mov bx, ax
    xor bh, bh
    mov dl, board[bx]

    mov al, dl
    and al, TYPE_MASK
    cmp al, 0
    jne hm_red

    push bx
    mov al, [si]
    mov ah, 8
    mul ah
    add al, [si+1]
    mov bx, ax
    xor bh, bh
    mov al, board[bx]
    pop bx

    and al, TYPE_MASK
    cmp al, 1
    jne hm_green

    mov al, [si+1]
    cmp al, [si+3]
    je hm_green

hm_red:
    mov ah, 40h
    jmp hm_apply

hm_green:
    mov ah, 20h

hm_apply:
    push ax

    mov al, ch
    push cx
    mov cl, CELL_HEIGHT
    mul cl
    add ax, LOCAL_BOARD_TOP
    mov bx, 160
    mul bx
    mov di, ax

    pop cx
    mov al, cl
    push cx
    mov cl, CELL_WIDTH
    mul cl
    add ax, LOCAL_BOARD_LEFT
    shl ax, 1
    add di, ax
    pop cx

    pop ax 

    push di
    add di, 1
    call paint_8attrs
    pop di

    push di
    add di, 161
    call paint_8attrs
    pop di

    pop cx  

    add si, 4
    dec cx
    jz hm_end
    jmp hm_loop

hm_end:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
highlight_moves ENDP

paint_8attrs PROC
    mov al, es:[di]
    and al, 0Fh
    or al, ah
    mov es:[di], al

    mov al, es:[di+2]
    and al, 0Fh
    or al, ah
    mov es:[di+2], al

    mov al, es:[di+4]
    and al, 0Fh
    or al, ah
    mov es:[di+4], al

    mov al, es:[di+6]
    and al, 0Fh
    or al, ah
    mov es:[di+6], al
    ret
paint_8attrs ENDP

draw_status PROC
    push ax
    push bx
    push cx
    push di
    push si
    push es

    mov ax, 0B800h
    mov es, ax

    cmp current_turn, 0
    je stat_w
    mov si, offset str_black
    jmp stat_draw
stat_w:
    mov si, offset str_white
stat_draw:
    mov di, 160 * 4 + 100 
    mov ah, 07h
stat_loop1:
    mov al, [si]
    cmp al, 0
    je stat_cap
    mov es:[di], ax
    add di, 2
    inc si
    jmp stat_loop1

stat_cap:
    mov si, offset str_cap_title
    mov di, 160 * 6 + 100 
stat_loop2:
    mov al, [si]
    cmp al, 0
    je stat_cap_w
    mov es:[di], ax
    add di, 2
    inc si
    jmp stat_loop2

stat_cap_w:
    mov si, offset str_cap_w
    mov di, 160 * 8 + 100
stat_loop3:
    mov al, [si]
    cmp al, 0
    je stat_cw_pieces
    mov es:[di], ax
    add di, 2
    inc si
    jmp stat_loop3

stat_cw_pieces:
    mov cx, cap_w_count
    cmp cx, 0
    je stat_cap_b
    mov si, offset captured_by_white
stat_cw_ploop:
    mov al, [si]
    and al, TYPE_MASK
    xor bx, bx
    mov bl, al
    mov al, piece_chars[bx]
    mov ah, 08h     
    mov es:[di], ax
    add di, 2
    inc si
    dec cx
    jnz stat_cw_ploop

stat_cap_b:
    mov si, offset str_cap_b
    mov di, 160 * 10 + 100
stat_loop4:
    mov al, [si]
    cmp al, 0
    je stat_cb_pieces
    mov es:[di], ax
    add di, 2
    inc si
    jmp stat_loop4

stat_cb_pieces:
    mov cx, cap_b_count
    cmp cx, 0
    je stat_end
    mov si, offset captured_by_black
stat_cb_ploop:
    mov al, [si]
    and al, TYPE_MASK
    xor bx, bx
    mov bl, al
    mov al, piece_chars[bx]
    mov ah, 0Fh     
    mov es:[di], ax
    add di, 2
    inc si
    dec cx
    jnz stat_cb_ploop

stat_end:
    pop es
    pop si
    pop di
    pop cx    
    pop bx
    pop ax
    ret
draw_status ENDP

END