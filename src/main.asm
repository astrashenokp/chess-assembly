.MODEL small
.STACK 256

INCLUDE shared.inc
    
.CODE

EXTRN init_video_mode:PROC
EXTRN draw_board:PROC
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

    call init_video_mode
    call draw_board
    call init_board
    call get_legal_moves
    call execute_move
    call is_in_check
    call is_square_attacked
    call is_checkmate
    call ai_turn

exit_program:
    mov ah, 4Ch
    int 21h

END start