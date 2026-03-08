.MODEL small
.STACK 256

INCLUDE shared.inc

.DATA
 
; Board representation
; index = row * 8 + col
 

board DB 64 DUP(?)

 
; Global state
current_turn    DB 0      ; 0 = white, 1 = black
white_king_pos  DB ?
black_king_pos  DB ?

 
; Move buffer
; format: from_row, from_col, to_row, to_col
move_list   DB 256 DUP(?)
move_count  DB 0
    
.CODE

start:
    mov ax, @data
    mov ds, ax

    call init_video_mode
    call draw_board

exit_program:
    mov ah, 4Ch
    int 21h

INCLUDE display.asm
INCLUDE game.asm  

END start