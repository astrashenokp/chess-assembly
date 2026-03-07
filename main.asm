.MODEL small
.STACK 256

INCLUDE shared.inc

.DATA
; main state
    board  DB 64 DUP(0)      ;playing board 8x8
    current_turn  DB 0       ; 0-white 1-black
    white_king_pos  DB ?    
    black_king_pos  DB ?
    move_list  DB 256 DUP(0) ;buffer for move
    
.CODE
; tell that procs exist in other files
EXTRN init_video_mode:PROC
EXTRN draw_board:PROC

start:
    mov ax, @data
    mov ds, ax

    call init_video_mode
    call draw_board

exit_program:
    mov ah, 4Ch
    int 21h

END start