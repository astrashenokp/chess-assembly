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

start_position DB
    12,10,11,13,14,11,10,12,   ; black pieces
    9,9,9,9,9,9,9,9,           ; black pawns
    0,0,0,0,0,0,0,0
    0,0,0,0,0,0,0,0
    0,0,0,0,0,0,0,0
    0,0,0,0,0,0,0,0
    1,1,1,1,1,1,1,1,           ; white pawns
    4,2,3,5,6,3,2,4            ; white pieces


; Game Logic

.CODE 
; init_board
; sets initial chess position
init_board PROC
    ; copy 64 bytes from start_position to board
    mov si, offset start_position
    mov di, offset board
    mov cx, 64

copy_loop:
    mov al,[si]
    mov [di],al
    inc si
    inc di
    loop copy_loop

    mov current_turn,0
    mov white_king_pos,60
    mov black_king_pos,4
    ret
init_board ENDP


; get_legal_moves
; input: row,col
; output: move_list filled
get_legal_moves PROC
    push bp
    mov bp,sp

    ; row = [bp+4]
    ; col = [bp+6]
row EQU [bp+4]
col EQU [bp+6]

    ; index = row*8 + col

    pop bp
    ret 4
get_legal_moves ENDP


; execute_move
; input:
;   [bp+4]  = from_row
;   [bp+6]  = from_col
;   [bp+8]  = to_row
;   [bp+10] = to_col
execute_move PROC
    push bp
    mov bp,sp

from_row EQU [bp+4]
from_col EQU [bp+6]
to_row   EQU [bp+8]
to_col   EQU [bp+10]

    pop bp
    ret 8
execute_move ENDP

 
; is_in_check
; input: [bp+4] = color
; output: AL = 1 if in check
is_in_check PROC
    push bp
    mov bp,sp

color EQU [bp+4]

    pop bp
    ret 2 
is_in_check ENDP

; is_square_attacked
; input:
;   [bp+4] = row
;   [bp+6] = col
;   [bp+8] = attacker_color
; output: AL = 1 if square attacked
is_square_attacked PROC
    push bp
    mov bp,sp

row   EQU [bp+4]
col   EQU [bp+6]
color EQU [bp+8]

    pop bp
    ret 6
is_square_attacked ENDP

; is_checkmate
; input: [bp+4] = color
; output: AL = 1 if in checkmate
is_checkmate PROC
    push bp
    mov bp,sp

color EQU [bp+4]

    pop bp
    ret 2
is_checkmate ENDP

END