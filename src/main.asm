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
    promotion_msg DB 'Promote to: Q R B N',0

    EXTRN move_list:BYTE
    EXTRN move_count:WORD

.CODE

PROMOTE_KNIGHT EQU 2
PROMOTE_BISHOP EQU 3
PROMOTE_ROOK   EQU 4
PROMOTE_QUEEN  EQU 5
PROMOTION_ROW  EQU 20
PROMOTION_COL  EQU 5  
PROMOTION_LEN  EQU 19

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
EXTRN ai_turn:PROC
EXTRN highlight_moves:PROC
EXTRN draw_status:PROC
EXTRN waiting_for_promotion:BYTE

start:
    mov ax, @data
    mov ds, ax

    call init_board
    call init_video_mode

game_loop:
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

    mov ah, 00h
    int 16h

    cmp ah, 48h     
    je move_up
    cmp ah, 50h     
    je move_down
    cmp ah, 4Bh    
    je move_left
    cmp ah, 4Dh     
    je move_right
    
    cmp al, 0Dh     
    jne check_esc
    jmp select_cell

check_esc:
    cmp ah, 01h     
    jne ignore_key
    jmp exit_program

ignore_key:
    jmp game_loop   

move_up:
    cmp cursor_row, 0
    je game_loop
    dec cursor_row
    jmp game_loop

move_down:
    cmp cursor_row, 7
    je game_loop
    inc cursor_row
    jmp game_loop

move_left:
    cmp cursor_col, 0
    je game_loop
    dec cursor_col
    jmp game_loop

move_right:
    cmp cursor_col, 7
    je game_loop
    inc cursor_col
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

    call draw_board
    mov ax, cursor_row
    mov ch, al
    mov ax, cursor_col
    mov cl, al
    call draw_cursor

    call handle_promotion
    call clear_promotion_prompt
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
    mov is_selected, 1  

    push cursor_col
    push cursor_row
    call get_legal_moves

    jmp game_loop


handle_promotion PROC
    call draw_promotion_prompt

promotion_key_loop:
    mov ah, 00h
    int 16h

    cmp al, 'Q'
    je choose_queen
    cmp al, 'q'
    je choose_queen

    cmp al, 'R'
    je choose_rook
    cmp al, 'r'
    je choose_rook

    cmp al, 'B'
    je choose_bishop
    cmp al, 'b'
    je choose_bishop

    cmp al, 'N'
    je choose_knight
    cmp al, 'n'
    je choose_knight

    jmp promotion_key_loop

choose_queen:
    push PROMOTE_QUEEN
    call finalize_promotion
    ret

choose_rook:
    push PROMOTE_ROOK
    call finalize_promotion
    ret

choose_bishop:
    push PROMOTE_BISHOP
    call finalize_promotion
    ret

choose_knight:
    push PROMOTE_KNIGHT
    call finalize_promotion
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