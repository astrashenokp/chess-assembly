.MODEL small
.STACK 4096

INCLUDE shared.inc

.DATA
    PUBLIC game_state, check_status
    game_state    DB 0
    check_status  DB 0

    PUBLIC cursor_row, cursor_col, is_selected, from_row, from_col, need_redraw, prev_mouse_btn
    
    ; Cursor coords
    cursor_row DW 6
    cursor_col DW 4

    ; Selection flag
    is_selected DB 0
    from_row    DW 0
    from_col    DW 0
    promotion_msg DB 'Promote: 1-Q 2-R 3-B 4-N',0

    need_redraw DB 1
    prev_mouse_btn DB 0

    EXTRN move_list:BYTE
    EXTRN move_count:WORD
    EXTRN board:BYTE

    PUBLIC ai_mode, ai_color, ai_difficulty
    ai_mode       DB 0
    ai_color      DB 0
    ai_difficulty DB 0

    title_msg     DB '=== CHESS ENGINE ===', 0
    
    icon_1v1_1    DB '   _O_  _O_   ', 0
    icon_1v1_2    DB '    | vs |    ', 0
    icon_1v1_3    DB '   / \  / \   ', 0
    text_1v1      DB '  1. 1 vs 1   ', 0

    icon_ai_1     DB '    [0_0]     ', 0
    icon_ai_2     DB '   --[_]--    ', 0
    icon_ai_3     DB '    /   \     ', 0
    text_ai       DB '  2. vs AI    ', 0

    col_title     DB 'CHOOSE YOUR COLOR:', 0
    col_w         DB '1. WHITE', 0
    col_b         DB '2. BLACK', 0
    msg_enter     DB '(Press ENTER to confirm)', 0

    dif_title     DB 'CHOOSE AI DIFFICULTY:', 0
    dif_easy      DB '1. EASY   (Bober z Ushuaia)', 0
    dif_med       DB '2. MEDIUM (Zaychyk Judy Hopps)', 0
    dif_hard      DB '3. HARD   (Pes Patron)', 0

    ; Background data
    PUBLIC bg_data
    bg_filename DB 'bg.bin', 0
    bg_data     DB 4000 DUP(0)

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
EXTRN ai_turn:PROC
EXTRN highlight_moves:PROC
EXTRN draw_status:PROC
EXTRN is_in_check:PROC
EXTRN is_checkmate:PROC
EXTRN is_stalemate:PROC
EXTRN is_fifty_move_draw:PROC
EXTRN current_turn:BYTE
EXTRN waiting_for_promotion:BYTE

EXTRN handle_input:PROC
PUBLIC update_game_state, handle_promotion, clear_promotion_prompt, load_background

start:
    mov ax, @data
    mov ds, ax

    ; Load BG file
    call load_background 

    call init_video_mode
    mov ax, 0000h       
    int 33h
    mov ax, 0001h       
    int 33h

main_menu:
    call clear_screen
    mov ax, 0002h
    int 33h

    mov si, offset title_msg
    mov dh, 3
    mov dl, 30
    mov bl, 0Fh
    call draw_string

    mov si, offset icon_1v1_1
    mov dh, 8
    mov dl, 20
    mov bl, 0Bh
    call draw_string
    mov si, offset icon_1v1_2
    mov dh, 9
    mov dl, 20
    mov bl, 0Bh
    call draw_string
    mov si, offset icon_1v1_3
    mov dh, 10
    mov dl, 20
    mov bl, 0Bh
    call draw_string
    mov si, offset text_1v1
    mov dh, 12
    mov dl, 20
    mov bl, 0Fh
    call draw_string

    mov si, offset icon_ai_1
    mov dh, 8
    mov dl, 45
    mov bl, 0Ch
    call draw_string
    mov si, offset icon_ai_2
    mov dh, 9
    mov dl, 45
    mov bl, 0Ch
    call draw_string
    mov si, offset icon_ai_3
    mov dh, 10
    mov dl, 45
    mov bl, 0Ch
    call draw_string
    mov si, offset text_ai
    mov dh, 12
    mov dl, 45
    mov bl, 0Fh
    call draw_string

    mov ax, 0001h
    int 33h

mm_wait_key:
    mov ah, 00h
    int 16h
    cmp al, '1'
    jne mm_check_2
    jmp start_1v1
mm_check_2:
    cmp al, '2'
    jne mm_ignore
    jmp menu_color
mm_ignore:
    jmp mm_wait_key

start_1v1:
    mov ai_mode, 0
    jmp start_game

menu_color:
    mov ai_mode, 1
mc_draw:
    call clear_screen
    mov ax, 0002h
    int 33h

    mov si, offset col_title
    mov dh, 8
    mov dl, 30
    mov bl, 0Fh
    call draw_string

    mov si, offset col_w
    mov dh, 10
    mov dl, 35
    mov bl, 07h
    cmp ai_color, 0
    jne mc_draw_w
    mov bl, 0Ah
mc_draw_w:
    call draw_string

    mov si, offset col_b
    mov dh, 12
    mov dl, 35
    mov bl, 07h
    cmp ai_color, 1
    jne mc_draw_b
    mov bl, 0Ah
mc_draw_b:
    call draw_string

    mov si, offset msg_enter
    mov dh, 16
    mov dl, 28
    mov bl, 08h
    call draw_string

    mov ax, 0001h
    int 33h

mc_wait_key:
    mov ah, 00h
    int 16h
    cmp al, '1'
    jne mc_check_2
    mov ai_color, 0
    jmp mc_draw
mc_check_2:
    cmp al, '2'
    jne mc_check_enter
    mov ai_color, 1
    jmp mc_draw
mc_check_enter:
    cmp al, 0Dh
    je go_menu_diff
    cmp al, ' '
    je go_menu_diff
    jmp mc_wait_key
go_menu_diff:
    jmp menu_diff

menu_diff:
md_draw:
    call clear_screen
    mov ax, 0002h
    int 33h

    mov si, offset dif_title
    mov dh, 6
    mov dl, 28
    mov bl, 0Fh
    call draw_string

    mov si, offset dif_easy
    mov dh, 9
    mov dl, 22
    mov bl, 07h
    cmp ai_difficulty, 0
    jne md_draw_e
    mov bl, 0Ah
md_draw_e:
    call draw_string

    mov si, offset dif_med
    mov dh, 11
    mov dl, 22
    mov bl, 07h
    cmp ai_difficulty, 1
    jne md_draw_m
    mov bl, 0Eh
md_draw_m:
    call draw_string

    mov si, offset dif_hard
    mov dh, 13
    mov dl, 22
    mov bl, 07h
    cmp ai_difficulty, 2
    jne md_draw_h
    mov bl, 0Ch
md_draw_h:
    call draw_string

    mov si, offset msg_enter
    mov dh, 17
    mov dl, 28
    mov bl, 08h
    call draw_string

    mov ax, 0001h
    int 33h

md_wait_key:
    mov ah, 00h
    int 16h
    cmp al, '1'
    jne md_check_2
    mov ai_difficulty, 0
    jmp md_draw
md_check_2:
    cmp al, '2'
    jne md_check_3
    mov ai_difficulty, 1
    jmp md_draw
md_check_3:
    cmp al, '3'
    jne md_check_enter
    mov ai_difficulty, 2
    jmp md_draw
md_check_enter:
    cmp al, 0Dh
    je go_start_game
    cmp al, ' '
    je go_start_game
    jmp md_wait_key
go_start_game:
    jmp start_game

clear_screen PROC
    push ax
    push bx
    push cx
    push dx
    mov ax, 0600h
    mov bh, 00h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clear_screen ENDP

draw_string PROC
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0B800h
    mov es, ax
    
    mov al, 80
    mul dh
    mov dh, 0
    add ax, dx
    shl ax, 1
    mov di, ax

ds_loop:
    mov al, [si]
    cmp al, 0
    je ds_done
    mov es:[di], al
    mov es:[di+1], bl
    inc si
    add di, 2
    jmp ds_loop
ds_done:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_string ENDP

start_game:
    call clear_screen
    call init_board
    call init_video_mode

    mov game_state, 0
    mov check_status, 0 
    mov is_selected, 0 
    mov prev_mouse_btn, 0
    
    mov ax, 0001h
    int 33h
    mov need_redraw, 1

flush_kbd:
    mov ah, 01h
    int 16h
    jz flush_done
    mov ah, 00h
    int 16h
    jmp flush_kbd
flush_done:

game_loop:
    cmp need_redraw, 1
    jne check_ai_turn     

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

check_ai_turn:
    cmp game_state, 0
    jne check_input

    cmp ai_mode, 1
    jne check_input

    mov al, current_turn
    cmp al, ai_color
    je check_input

    call ai_turn
    call update_game_state
    mov is_selected, 0
    mov need_redraw, 1
    jmp game_loop

check_input:
    call handle_input
    
    cmp al, 1
    je restart_game_tr
    cmp al, 2
    je exit_game_tr
    jmp game_loop

restart_game_tr:
    jmp start_game

exit_game_tr:
    jmp exit_program

update_game_state PROC
    push ax
    
    xor ax, ax
    mov al, current_turn
    push ax
    call is_checkmate
    cmp al, 1
    jne ugs_stalemate
    
    mov al, current_turn
    xor al, 1
    inc al
    mov game_state, al
    jmp ugs_check_status

ugs_stalemate:
    xor ax, ax
    mov al, current_turn
    push ax
    call is_stalemate
    cmp al, 1
    jne ugs_fifty_move
    mov game_state, 3
    jmp ugs_check_status

ugs_fifty_move:
    call is_fifty_move_draw
    cmp al, 1
    jne ugs_active
    mov game_state, 3
    jmp ugs_check_status

ugs_active:
    mov game_state, 0

ugs_check_status:
    xor ax, ax
    push ax
    call is_in_check
    cmp al, 1
    jne ugs_chk_b
    mov check_status, 1
    jmp ugs_done

ugs_chk_b:
    mov ax, 1
    push ax
    call is_in_check
    cmp al, 1
    jne ugs_no_chk
    mov check_status, 2
    jmp ugs_done

ugs_no_chk:
    mov check_status, 0

ugs_done:
    pop ax
    ret
update_game_state ENDP

handle_promotion PROC
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
    mov ax, PROMOTE_QUEEN
    push ax
    call finalize_promotion
    ret

choose_rook:
    mov ax, PROMOTE_ROOK
    push ax
    call finalize_promotion
    ret

choose_bishop:
    mov ax, PROMOTE_BISHOP
    push ax
    call finalize_promotion
    ret

choose_knight:
    mov ax, PROMOTE_KNIGHT
    push ax
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

; Read BG.BIN
load_background PROC
    push ax
    push bx
    push cx
    push dx

    ; Open file
    mov ah, 3Dh
    mov al, 0           
    mov dx, offset bg_filename
    int 21h
    jc lb_end           
    mov bx, ax          

    ; Read 4000 bytes
    mov ah, 3Fh
    mov cx, 4000
    mov dx, offset bg_data
    int 21h

    ; Close file
    mov ah, 3Eh
    int 21h

lb_end:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
load_background ENDP

END start