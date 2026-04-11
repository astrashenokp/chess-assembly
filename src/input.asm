.MODEL small
INCLUDE shared.inc

.DATA
    EXTRN game_state:BYTE
    EXTRN cursor_row:WORD, cursor_col:WORD
    EXTRN is_selected:BYTE
    EXTRN from_row:WORD, from_col:WORD
    EXTRN need_redraw:BYTE
    EXTRN prev_mouse_btn:BYTE
    EXTRN move_count:WORD
    EXTRN move_list:BYTE
    EXTRN waiting_for_promotion:BYTE

.CODE
    EXTRN execute_move:PROC
    EXTRN draw_board:PROC
    EXTRN draw_cursor:PROC
    EXTRN handle_promotion:PROC
    EXTRN clear_promotion_prompt:PROC
    EXTRN update_game_state:PROC
    EXTRN get_legal_moves:PROC
    EXTRN play_move_sound:PROC ; Импортируем звук

PUBLIC handle_input

handle_input PROC
    cmp game_state, 0
    je check_kbd

    mov ah, 01h
    int 16h
    jz ignore_go_key
    mov ah, 00h
    int 16h
    cmp al, 'r'
    je do_restart
    cmp al, 'R'
    je do_restart
    cmp ah, 01h
    je do_exit
ignore_go_key:
    xor al, al      
    ret

do_restart:
    mov al, 1    
    ret

do_exit:
    mov al, 2      
    ret

check_kbd:
    mov ah, 01h
    int 16h
    jnz has_key
    jmp check_mouse

has_key:
    mov ah, 00h
    int 16h
    
    mov need_redraw, 1  

    cmp ah, 48h
    jne not_up
    jmp move_up
not_up:
    cmp ah, 50h
    jne not_down
    jmp move_down
not_down:
    cmp ah, 4Bh
    jne not_left
    jmp move_left
not_left:
    cmp ah, 4Dh
    jne not_right
    jmp move_right
not_right:
    cmp al, 0Dh
    jne not_enter
    jmp select_cell
not_enter:
    cmp ah, 01h
    jne ignore_key
    jmp check_esc

ignore_key:
    xor al, al
    ret

check_esc:
    cmp is_selected, 1
    je esc_cancel_selection
    mov al, 2      
    ret

esc_cancel_selection:
    mov is_selected, 0
    xor al, al
    ret

check_mouse:
    mov ax, 0003h       
    int 33h
    test bx, 1          
    jnz mouse_pressed  
    
    mov prev_mouse_btn, 0
    xor al, al
    ret

mouse_pressed:
    cmp prev_mouse_btn, 1
    je ignore_mouse     
    mov prev_mouse_btn, 1 
    
    shr cx, 1
    shr cx, 1
    shr cx, 1           

    shr dx, 1
    shr dx, 1
    shr dx, 1           

    sub dx, 2
    jl ignore_mouse
    shr dx, 1
    cmp dx, 7
    jg ignore_mouse

    sub cx, 5
    jl ignore_mouse
    shr cx, 1
    shr cx, 1
    cmp cx, 7
    jg ignore_mouse

    mov cursor_row, dx
    mov cursor_col, cx
    mov need_redraw, 1  
    jmp select_cell     

ignore_mouse:
    xor al, al
    ret

move_up:
    cmp cursor_row, 0
    je end_move_up
    dec cursor_row
end_move_up:
    xor al, al
    ret

move_down:
    cmp cursor_row, 7
    je end_move_down
    inc cursor_row
end_move_down:
    xor al, al
    ret

move_left:
    cmp cursor_col, 0
    je end_move_left
    dec cursor_col
end_move_left:
    xor al, al
    ret

move_right:
    cmp cursor_col, 7
    je end_move_right
    inc cursor_col
end_move_right:
    xor al, al
    ret

select_cell:
    cmp is_selected, 0
    jne check_same_cell
    jmp pickup_piece    

check_same_cell:
    mov ax, cursor_row
    cmp ax, from_row
    jne validate_move
    mov ax, cursor_col
    cmp ax, from_col
    jne validate_move
    
    mov is_selected, 0  
    xor al, al
    ret

validate_move:
    mov cx, move_count
    cmp cx, 0
    je invalid_move
    mov si, offset move_list

val_loop:
    mov ax, cursor_row
    cmp al, [si+2]
    jne val_next
    mov ax, cursor_col
    cmp al, [si+3]
    je do_move         

val_next:
    add si, 4
    dec cx
    jnz val_loop

invalid_move:
    mov is_selected, 0
    xor al, al
    ret

do_move:
    push cursor_col     
    push cursor_row     
    push from_col       
    push from_row       
    call execute_move
    call play_move_sound   ; Воспроизводим звук при ходе игрока

    cmp waiting_for_promotion, 0
    je move_done_label

    mov ax, 0002h
    int 33h
    call draw_board
    call draw_cursor
    call handle_promotion
    call clear_promotion_prompt
    mov ax, 0001h
    int 33h

move_done_label:
    call update_game_state
    mov need_redraw, 1
    mov is_selected, 0
    xor al, al
    ret

pickup_piece:
    mov ax, cursor_row
    mov from_row, ax
    mov ax, cursor_col
    mov from_col, ax
    
    push cursor_col
    push cursor_row
    call get_legal_moves

    cmp move_count, 0
    je cancel_selection

    mov is_selected, 1  
    xor al, al
    ret

cancel_selection:
    mov is_selected, 0
    xor al, al
    ret

handle_input ENDP
END