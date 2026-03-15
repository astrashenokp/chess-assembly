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

.CODE

EXTRN init_video_mode:PROC
EXTRN draw_board:PROC
EXTRN draw_cursor:PROC
EXTRN init_board:PROC
EXTRN execute_move:PROC
EXTRN get_legal_moves:PROC
EXTRN is_in_check:PROC
EXTRN is_square_attacked:PROC
EXTRN is_checkmate:PROC
EXTRN ai_turn:PROC

start:
    mov ax, @data
    mov ds, ax

    ; Initialize board array with starting position
    call init_board

    ; Set video mode and render the board
    call init_video_mode

game_loop:
    call draw_board

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

; Piece selection and movement logic
select_cell:
    cmp is_selected, 0
    jne check_same_cell
    jmp pickup_piece    

check_same_cell:
    mov ax, cursor_row
    cmp ax, from_row
    jne do_move
    mov ax, cursor_col
    cmp ax, from_col
    jne do_move
    
    mov is_selected, 0  
    jmp game_loop

do_move:
    push cursor_col     
    push cursor_row     
    push from_col       
    push from_row       
    call execute_move

    mov is_selected, 0
    jmp game_loop

pickup_piece:
    mov ax, cursor_row
    mov from_row, ax
    mov ax, cursor_col
    mov from_col, ax
    
    mov is_selected, 1  
    jmp game_loop

exit_program:
    mov ax, 0003h
    int 10h

    mov ah, 4Ch
    int 21h

END start