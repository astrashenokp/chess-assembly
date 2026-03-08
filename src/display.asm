.MODEL small
INCLUDE shared.inc

.DATA
    ; Table of piece characters
    ; 0=empty, 1=pawn, 2=knight, 3=bishop, 4=rook, 5=queen, 6=king
    piece_chars DB ' ', 'P', 'N', 'B', 'R', 'Q', 'K'

.CODE
; make procs public for main.asm
PUBLIC init_video_mode
PUBLIC draw_board
PUBLIC draw_piece
PUBLIC draw_cursor
PUBLIC highlight_moves
PUBLIC draw_status

; skelet of procs (mocks)
init_video_mode PROC
    
    mov ax, 0B800h
    mov es, ax
    ret
init_video_mode ENDP

draw_board PROC
    ret
draw_board ENDP

draw_piece PROC
    ret
draw_piece ENDP

draw_cursor PROC
    ret
draw_cursor ENDP

highlight_moves PROC
    ret
highlight_moves ENDP

draw_status PROC
    ret
draw_status ENDP

END