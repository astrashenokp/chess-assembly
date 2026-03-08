INCLUDE shared.inc
 
; Direction tables
rook_dirs:
    DB  0,-1
    DB  0, 1
    DB -1, 0
    DB  1, 0

bishop_dirs:
    DB -1,-1
    DB -1, 1
    DB  1,-1
    DB  1, 1

knight_offsets:
    DB -2,-1
    DB -2, 1
    DB -1,-2
    DB -1, 2
    DB  1,-2
    DB  1, 2
    DB  2,-1
    DB  2, 1


; Game Logic

.CODE 
; init_board
; sets initial chess position
init_board PROC
    ret
init_board ENDP

 
; get_legal_moves
; input: row,col
; output: move_list filled
get_legal_moves PROC
    push bp
    mov bp,sp

    ; row = [bp+4]
    ; col = [bp+5]

    ; index = row*8 + col

    pop bp
    ret
get_legal_moves ENDP

 
; execute_move
; input: from_row,from_col,to_row,to_col
execute_move PROC
    push bp
    mov bp,sp

    pop bp
    ret
execute_move ENDP

 
; is_in_check
; input: color
; output: AL = 1 if in check
is_in_check PROC
    push bp
    mov bp,sp

    pop bp
    ret 
is_in_check ENDP

END