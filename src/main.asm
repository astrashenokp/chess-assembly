.MODEL small
.STACK 256

INCLUDE shared.inc

.DATA
    ; Current cursor coordinates
    cursor_row DW 6
    cursor_col DW 4

    is_selected DB 0    ; 0 = no piece selected, 1 = piece selected
    from_row    DW 0
    from_col    DW 0
    promotion_msg DB 'Promote: 1-Q 2-R 3-B 4-N',0

    need_redraw DB 1

    EXTRN move_list:BYTE
    EXTRN move_count:WORD

.CODE

PROMOTE_KNIGHT EQU 2
PROMOTE_BISHOP EQU 3
PROMOTE_ROOK   EQU 4
PROMOTE_QUEEN  EQU 5
PROMOTION_ROW  EQU 20
PROMOTION_COL  EQU 5  
PROMOTION_LEN  EQU 24

EXTRN init_video_mode:PROC
EXTRN draw_board:PROC
EXTRN draw_cursor:PROC
EXTRN init_board:PROC
EXTRN execute_move:PROC
EXTRN finalize_promotion:PROC
EXTRN get_legal_moves:PROC
EXTRN is_in_check:PROC
EXTRN is_square_attacked:PROC
EXTRN is_checkmate:PROC
EXTRN highlight_moves:PROC
EXTRN draw_status:PROC
EXTRN waiting_for_promotion:BYTE

start:
    mov ax, @data
    mov ds, ax

    call init_board
    call init_video_mode

    mov ax, 0000h       
    int 33h
    mov ax, 0001h       
    int 33h

game_loop:
    cmp need_redraw, 1
    jne check_input     

    mov ax, 0002h
    int 33h

    call draw_board
    call draw_status      
    
    cmp is_selected, 1
    jne skip_highlights
    call highlight_moves  

skip_highlights:
    mov ax, cursor_row
    mov ch, al
    mov ax, cursor_col
    mov cl, al
    call draw_cursor

    mov ax, 0001h
    int 33h

    mov need_redraw, 0

check_input:
    mov ah, 01h         
    int 16h
    jnz has_key         ; Трамплін для клавіатури
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
    
    cmp is_selected, 1
    je esc_cancel_selection
    jmp exit_program

esc_cancel_selection:
    mov is_selected, 0
    jmp game_loop

ignore_key:
    jmp game_loop   


check_mouse:
    mov ax, 0003h       
    int 33h

    test bx, 1          
    jnz wait_mouse_release  ; Трамплін для мишки
    jmp game_loop

wait_mouse_release:
    mov ax, 0003h
    int 33h
    test bx, 1
    jnz wait_mouse_release

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
    jmp game_loop


move_up:
    cmp cursor_row, 0
    je end_move_up
    dec cursor_row
end_move_up:
    jmp game_loop

move_down:
    cmp cursor_row, 7
    je end_move_down
    inc cursor_row
end_move_down:
    jmp game_loop

move_left:
    cmp cursor_col, 0
    je end_move_left
    dec cursor_col
end_move_left:
    jmp game_loop

move_right:
    cmp cursor_col, 7
    je end_move_right
    inc cursor_col
end_move_right:
    jmp game_loop

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
    jmp game_loop

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
    jmp game_loop

do_move:
    push cursor_col     
    push cursor_row     
    push from_col       
    push from_row       
    call execute_move

    cmp waiting_for_promotion, 0
    je move_done

    mov need_redraw, 1
    call draw_board
    mov ax, cursor_row
    mov ch, al
    mov ax, cursor_col
    mov cl, al
    call draw_cursor

    call handle_promotion
    call clear_promotion_prompt

    mov need_redraw, 1
    call draw_board
    
    mov ax, cursor_row
    mov ch, al
    mov ax, cursor_col
    mov cl, al
    call draw_cursor

move_done:
    mov is_selected, 0
    jmp game_loop

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
    jmp game_loop

cancel_selection:
    mov is_selected, 0
    jmp game_loop


handle_promotion PROC
    mov ax, 0002h
    int 33h
    call draw_promotion_prompt

promotion_key_loop:
    mov ah, 00h
    int 16h

    cmp al, '1'
    je choose_queen

    cmp al, '2'
    je choose_rook

    cmp al, '3'
    je choose_bishop

    cmp al, '4'
    je choose_knight

    jmp promotion_key_loop

choose_queen:
    push PROMOTE_QUEEN
    call finalize_promotion
    mov ax, 0001h
    int 33h
    ret

choose_rook:
    push PROMOTE_ROOK
    call finalize_promotion
    mov ax, 0001h
    int 33h
    ret

choose_bishop:
    push PROMOTE_BISHOP
    call finalize_promotion
    mov ax, 0001h
    int 33h
    ret

choose_knight:
    push PROMOTE_KNIGHT
    call finalize_promotion
    mov ax, 0001h
    int 33h
    ret
handle_promotion ENDP

draw_promotion_prompt PROC
    push ax
    push bx
    push dx
    push si
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    mov ax, PROMOTION_ROW
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, PROMOTION_COL
    shl ax, 1
    add di, ax

    mov si, offset promotion_msg

draw_promotion_char:
    mov al, [si]
    cmp al, 0
    je draw_promotion_done

    mov ah, 07h
    mov es:[di], ax
    inc si
    add di, 2
    jmp draw_promotion_char

draw_promotion_done:
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret
draw_promotion_prompt ENDP

clear_promotion_prompt PROC
    push ax
    push bx
    push dx
    push di
    push es

    mov ax, 0B800h
    mov es, ax

    mov ax, PROMOTION_ROW
    mov bx, 160
    mul bx
    mov di, ax

    mov ax, PROMOTION_COL
    shl ax, 1
    add di, ax

    mov dx, PROMOTION_LEN

clear_promotion_char:
    mov ax, 0720h
    mov es:[di], ax
    add di, 2
    dec dx
    jnz clear_promotion_char

    pop es
    pop di
    pop dx
    pop bx
    pop ax
    ret
clear_promotion_prompt ENDP

exit_program:
    mov ax, 0003h
    int 10h

    mov ah, 4Ch
    int 21h

END start