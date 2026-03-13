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

    ; Initialize board array with starting position
    call init_board

    ; Set video mode and render the board
    call init_video_mode
    call draw_board

    ; Test get_legal_moves 
    push 6      
    push 4      
    call get_legal_moves

    ; Test execute_move
    push 6      
    push 4      
    push 4      
    push 4      
    call execute_move

    ; Test is_in_check 
    push 0     
    call is_in_check

    ; Test is_square_attacked 
    push 4      
    push 4      
    push 1      
    call is_square_attacked

    ; Test is_checkmate 
    push 0      
    call is_checkmate

    ; Test ai_turn 
    call ai_turn

exit_program:
    ; Wait for any keypress to keep the screen open
    mov ah, 00h
    int 16h

    mov ax, 0003h
    int 10h

    mov ah, 4Ch
    int 21h

END start