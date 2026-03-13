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
move_list   DB 512 DUP(?)
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

; Pieces
EMPTY    EQU 0
PAWN   EQU 1
KNIGHT EQU 2
BISHOP EQU 3
ROOK   EQU 4
QUEEN  EQU 5
KING   EQU 6
BLACK_BIT EQU 08h 

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
; make procs public for main.asm
PUBLIC init_board
PUBLIC get_legal_moves
PUBLIC execute_move
PUBLIC is_in_check
PUBLIC is_square_attacked
PUBLIC is_checkmate


; init_board
; sets initial chess position
init_board PROC
    ; copy 64 bytes from start_position to board
    mov si, offset start_position
    mov di, offset board
    mov cx, 64

copy_loop:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    loop copy_loop

    mov current_turn, 0
    mov white_king_pos, 60
    mov black_king_pos, 4
    ret
init_board ENDP


; get_legal_moves
; input: row,col
; output: move_list filled
get_legal_moves PROC
    push bp
    mov bp, sp

; row = [bp+4]
; col = [bp+6]
row EQU [bp+4]
col EQU [bp+6]

    mov move_count, 0

    ; index = row*8 + col
    mov al, row
    mov bl, col

    mov dl, al
    shl dl, 3
    add dl, bl

    mov al, board[dl]

    ; save the piece color
    mov ah, al
    and ah, COLOR_MASK
    mov bh, ah          ; BH stores the color

    ; check piece type  
    and al, TYPE_MASK

    cmp al, KNIGHT
    je knight_moves

    cmp al, KING
    je king_moves

    jmp done


; KNIGHT
knight_moves:

    mov si, offset knight_offsets
    mov cx, 8

knight_loop:

    mov al, row
    add al, [si]

    mov bl, col
    add bl, [si+1]

    ; check the edges
    cmp al, 0
    jl knight_next
    cmp al, 7
    jg knight_next

    cmp bl, 0
    jl knight_next
    cmp bl, 7
    jg knight_next

    add dl, bl

    ; ah =  piece on the board cell
    mov ah, board[dl]

    ; check if square contains same color piece
    mov al, ah
    and al, COLOR_MASK                   

    cmp al, bh
    je knight_next

    ; add the move to move_list
    mov di, move_count
    shl di, 2
    add di, offset move_list

    ; from_row
    mov al, row
    mov [dx], al

    ; from_col
    mov al, col
    mov [dx+1], al

    ; to_row
    mov al, row
    add al, [si]
    mov [dx+2], al

    ; to_col
    mov al, col
    add al, [si+1]
    mov [dx+3], al

    inc move_count

knight_next:
    add si, 2
    loop knight_loop

    jmp done


; KING
king_moves:

    mov si, offset king_dirs
    mov cx, 8

king_loop:

    mov al, row
    add al, [si]        ; new_row

    mov bl, col
    add bl, [si+1]      ; new_col

    ; check the edges
    cmp al, 0
    jl king_next
    cmp al, 7
    jg king_next

    cmp bl, 0
    jl king_next
    cmp bl, 7
    jg king_next

    ; index = new_row*8 + new_col
    mov dl, al
    shl dl, 3
    add dl, bl

     mov ah, board[dl]

    ; check if square contains same color piece
    mov al, ah
    and al, COLOR_MASK
    cmp al, bh
    je king_next

    ; add move to move_list
    mov di, move_count
    shl di, 2
    add di, offset move_list

    ; from_row
    mov al, row
    mov [di], al

    ; from_col
    mov al, col
    mov [di+1], al

    ; to_row
    mov al, row
    add al, [si]
    mov [di+2], al

    ; to_col
    mov al, col
    add al, [si+1]
    mov [di+3], al

    inc move_count

king_next:

    add si, 2
    loop king_loop


done:

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
    mov bp, sp

from_row EQU [bp+4]
from_col EQU [bp+6]
to_row   EQU [bp+8]
to_col   EQU [bp+10]

    ; from_index = from_row*8 + from_col
    mov al, from_row
    shl al, 3
    add al, from_col
    mov si, ax

    ; piece = board[from]
    mov bl, board[si]

    ; to_index = to_row*8 + to_col
    mov al, to_row
    shl al, 3
    add al, to_col
    mov di, ax

    ; captured piece in AH
    mov ah, board[di]

    ; move piece
    mov board[di], bl

    ; clear source square
    mov board[si], 0

    pop bp
    ret 8
execute_move ENDP

 
; is_in_check
; input: [bp+4] = color
; output: AL = 1 if in check
is_in_check PROC
    push bp
    mov bp, sp

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
     mov bp, sp

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
    mov bp, sp

color EQU [bp+4]

    pop bp
    ret 2
is_checkmate ENDP

END