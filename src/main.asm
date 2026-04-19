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

    tm_title      DB 'CHOOSE TIME LIMIT (1v1):', 0
    tm_3m         DB '1. 3 Minutes', 0
    tm_5m         DB '2. 5 Minutes', 0
    tm_10m        DB '3. 10 Minutes', 0

    PUBLIC w_time_m, w_time_s, b_time_m, b_time_s, time_limit
    time_limit    DB 5
    w_time_m      DB 5
    w_time_s      DB 0
    b_time_m      DB 5
    b_time_s      DB 0
    last_tick     DW 0

    PUBLIC bg_data
    bg_data       DB 4000 DUP(0)

    EXTRN last_move_was_capture:BYTE
    EXTRN last_captured_piece:BYTE

    PUBLIC current_quote
    current_quote  DW offset q_empty
    q_empty        DB ' ', 0
    
    q_ai_cap_queen DB '"Ouch! Say goodbye to your Queen!"', 0
    q_ai_cap_rook  DB '"Nice Rook. I will take it."', 0
    q_ai_cap_minor DB '"Just a minor piece, but thanks!"', 0
    q_ai_cap_pawn  DB '"Yummy pawn! Om-nom-nom!"', 0
    q_ai_give_chk  DB '"Check! Your King is in danger!"', 0
    q_ai_rec_chk   DB '"Oh... you dare to attack my King?"', 0
    q_ai_default   DB '"Hmm... Your move, human."', 0

    bg0_arr LABEL BYTE
    INCLUDE bg0.inc
    bg1_arr LABEL BYTE
    INCLUDE bg1.inc
    bg2_arr LABEL BYTE
    INCLUDE bg2.inc

.CODE

EMPTY  EQU 0
PAWN   EQU 1
KNIGHT EQU 2
BISHOP EQU 3
ROOK   EQU 4
QUEEN  EQU 5
KING   EQU 6

PROMOTE_KNIGHT EQU 2
PROMOTE_BISHOP EQU 3
PROMOTE_ROOK   EQU 4
PROMOTE_QUEEN  EQU 5
PROMOTION_ROW  EQU 20
PROMOTION_COL  EQU 5  
PROMOTION_LEN  EQU 24

EXTRN init_video_mode:PROC
EXTRN draw_background:PROC   
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
PUBLIC update_game_state, handle_promotion, clear_promotion_prompt, load_background, play_move_sound

start:
    mov ax, @data
    mov ds, ax

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
    mov ai_mode, 0
    jmp menu_time    
mm_check_2:         
    cmp al, '2'
    jne mm_ignore
    jmp menu_color
mm_ignore:
    jmp mm_wait_key

menu_time:
    call clear_screen
    mov ax, 0002h
    int 33h

    mov si, offset tm_title
    mov dh, 8
    mov dl, 28
    mov bl, 0Fh
    call draw_string

    mov si, offset tm_3m
    mov dh, 10
    mov dl, 32
    mov bl, 0Ah
    call draw_string

    mov si, offset tm_5m
    mov dh, 12
    mov dl, 32
    mov bl, 0Eh
    call draw_string

    mov si, offset tm_10m
    mov dh, 14
    mov dl, 32
    mov bl, 0Bh
    call draw_string

    mov ax, 0001h
    int 33h

mt_wait_key:
    mov ah, 00h
    int 16h
    cmp al, '1'
    jne mt_check_2
    mov time_limit, 3
    jmp start_game
mt_check_2:
    cmp al, '2'
    jne mt_check_3
    mov time_limit, 5
    jmp start_game
mt_check_3:
    cmp al, '3'
    jne mt_wait_key
    mov time_limit, 10
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
    
    ; Порожня цитата на старті гри!
    mov ax, offset q_empty
    mov current_quote, ax

    ; Ініціалізація таймера
    mov al, time_limit
    mov w_time_m, al
    mov b_time_m, al
    mov w_time_s, 0
    mov b_time_s, 0
    
    mov ah, 00h
    int 1ah
    mov last_tick, dx

    push ax
    push cx
    push di
    push es
    mov ax, ds
    mov es, ax
    mov cx, 2000
    mov di, offset bg_data
    mov ax, 0020h 
    cld
    rep stosw
    pop es
    pop di
    pop cx
    pop ax

    cmp ai_mode, 1
    jne skip_bg_load
    call load_background
skip_bg_load:

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
    cmp ai_mode, 0
    jne gl_timer_done
    cmp game_state, 0
    jne gl_timer_done

    mov ah, 00h
    int 1ah
    mov ax, dx
    sub ax, last_tick
    cmp ax, 18
    jl gl_timer_done

    mov last_tick, dx
    mov need_redraw, 1

    cmp current_turn, 0
    je gl_w_tick
    ; Black tick
    cmp b_time_s, 0
    jne gl_b_sec
    cmp b_time_m, 0
    je gl_b_timeout
    dec b_time_m
    mov b_time_s, 59
    jmp gl_timer_done
gl_b_sec:
    dec b_time_s
    jmp gl_timer_done
gl_b_timeout:
    mov game_state, 1 ; White wins
    jmp gl_timer_done

gl_w_tick:
    cmp w_time_s, 0
    jne gl_w_sec
    cmp w_time_m, 0
    je gl_w_timeout
    dec w_time_m
    mov w_time_s, 59
    jmp gl_timer_done
gl_w_sec:
    dec w_time_s
    jmp gl_timer_done
gl_w_timeout:
    mov game_state, 2 ; Black wins

gl_timer_done:
    cmp need_redraw, 1
    jne check_ai_turn     

    mov ax, 0002h
    int 33h

    call draw_background  
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
    call play_move_sound
    call update_game_state
    call update_ai_quote
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

update_ai_quote PROC
    push ax

    
    mov ax, offset q_empty
    mov current_quote, ax

    cmp check_status, 1
    je uaq_rec_chk  
    cmp check_status, 2
    je uaq_give_chk 
    cmp last_move_was_capture, 1
    jne uaq_def

    mov al, last_captured_piece
    and al, TYPE_MASK

    cmp al, QUEEN
    jne uaq_chk_rook
    mov ax, offset q_ai_cap_queen
    mov current_quote, ax
    jmp uaq_end

uaq_chk_rook:
    cmp al, ROOK
    jne uaq_chk_minor
    mov ax, offset q_ai_cap_rook
    mov current_quote, ax
    jmp uaq_end

uaq_chk_minor:
    cmp al, BISHOP
    je uaq_is_minor
    cmp al, KNIGHT
    jne uaq_chk_pawn
uaq_is_minor:
    mov ax, offset q_ai_cap_minor
    mov current_quote, ax
    jmp uaq_end

uaq_chk_pawn:
    cmp al, PAWN
    jne uaq_def
    mov ax, offset q_ai_cap_pawn
    mov current_quote, ax
    jmp uaq_end

uaq_rec_chk:
    mov ax, offset q_ai_rec_chk
    mov current_quote, ax
    jmp uaq_end

uaq_give_chk:
    mov ax, offset q_ai_give_chk
    mov current_quote, ax
    jmp uaq_end

uaq_def:
    mov ax, offset q_ai_default
    mov current_quote, ax

uaq_end:
    pop ax
    ret
update_ai_quote ENDP

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

play_move_sound PROC
    push ax
    push cx
    push dx
    
    in al, 61h
    or al, 3
    out 61h, al

    mov al, 0B6h
    out 43h, al
    mov al, 0E9h   
    out 42h, al
    mov al, 04h    
    out 42h, al

    mov ah, 86h
    mov cx, 0
    mov dx, 30000  
    int 15h

    in al, 61h
    and al, 0FCh
    out 61h, al

    cmp check_status, 0
    je snd_end

    in al, 61h
    or al, 3
    out 61h, al
    mov al, 0B6h
    out 43h, al
    mov al, 090h 
    out 42h, al
    mov al, 02h    
    out 42h, al
    mov ah, 86h
    mov cx, 0
    mov dx, 50000 
    int 15h
    in al, 61h
    and al, 0FCh
    out 61h, al

snd_end:
    pop dx
    pop cx
    pop ax
    ret
play_move_sound ENDP

load_background PROC
    push ax
    push cx
    push si
    push di
    push es

    mov ax, ds
    mov es, ax
    mov cx, 2000
    mov di, offset bg_data
    
    cmp ai_difficulty, 0
    je load_bg0
    cmp ai_difficulty, 1
    je load_bg1
    mov si, offset bg2_arr
    jmp do_copy
load_bg0:
    mov si, offset bg0_arr
    jmp do_copy
load_bg1:
    mov si, offset bg1_arr
do_copy:
    cld
    rep movsw

    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret
load_background ENDP

exit_program:
    mov ax, 0003h
    int 10h
    mov ah, 4Ch
    int 21h

END start