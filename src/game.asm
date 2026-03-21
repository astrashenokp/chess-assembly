.MODEL small

INCLUDE shared.inc
 
.DATA

; Board representation
; index = row * 8 + col
 
PUBLIC board
board DB 64 DUP(?)

 
; Global state
PUBLIC current_turn
current_turn    DB 0      ; 0 = white, 1 = black
selected_color DB 0       ; color of the selected piece
PUBLIC waiting_for_promotion
waiting_for_promotion DB 0
en_passant_available DB 0
en_passant_row DB ?
en_passant_col DB ?
en_passant_capture_row DB ?
en_passant_capture_col DB ?
promotion_row DB ?
promotion_col DB ?
promotion_color DB ?
white_king_pos  DB ?
black_king_pos  DB ?

 
; Move buffer
; format: from_row, from_col, to_row, to_col
PUBLIC move_list
PUBLIC move_count
move_list   DB 512 DUP(?)
move_count  DW 0

; Direction tables
rook_dirs DB  0,-1
        DB  0, 1
        DB -1, 0
        DB  1, 0

bishop_dirs DB -1,-1
        DB -1, 1
        DB  1,-1
        DB  1, 1

knight_offsets DB -2,-1
        DB -2, 1
        DB -1,-2
        DB -1, 2
        DB  1,-2
        DB  1, 2
        DB  2,-1
        DB  2, 1

king_dirs DB -1,-1
        DB -1,0
        DB -1,1
        DB 0,-1
        DB 0,1
        DB 1,-1
        DB 1,0
        DB 1,1

; Pieces
EMPTY    EQU 0
PAWN   EQU 1
KNIGHT EQU 2
BISHOP EQU 3
ROOK   EQU 4
QUEEN  EQU 5
KING   EQU 6
BLACK_BIT EQU 08h 

start_position DB 12,10,11,13,14,11,10,12
               DB 9,9,9,9,9,9,9,9
               DB 0,0,0,0,0,0,0,0
               DB 0,0,0,0,0,0,0,0
               DB 0,0,0,0,0,0,0,0
               DB 0,0,0,0,0,0,0,0
               DB 1,1,1,1,1,1,1,1
               DB 4,2,3,5,6,3,2,4


; Game Logic

.CODE 
; make procs public for main.asm
PUBLIC init_board
PUBLIC get_legal_moves
PUBLIC execute_move
PUBLIC finalize_promotion
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
    mov waiting_for_promotion, 0
    mov en_passant_available, 0
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

    ; clear move_list
    mov di, offset move_list
    mov cx, 512
    xor al, al

    clear_moves:
        mov [di], al
        inc di
        loop clear_moves
    mov move_count, 0

    ; index = row*8 + col
    mov al, row
    mov bl, col

    mov dl, al
    shl dl, 3
    add dl, bl

    xor dh, dh
    mov si, dx
    mov al, board[si]

    ; check if the square is empty
    cmp al, EMPTY
    jne piece_found
    jmp done

piece_found:

    ; save the piece color
    mov ah, al
    and ah, COLOR_MASK
    shr ah, 3
    mov selected_color, ah

    ; if current_turn = white
    cmp current_turn, 0
    je check_white

    ; current_turn = black
    cmp selected_color, BLACK
    je color_ok
    jmp done

    check_white:
    cmp selected_color, WHITE
    je color_ok
    jmp done

color_ok:

    ; check piece type  
    and al, TYPE_MASK

    cmp al, KNIGHT
    je call_knight

    cmp al, KING
    je call_king

    cmp al, BISHOP
    je call_bishop

    cmp al, ROOK
    je call_rook

    cmp al, QUEEN
    je call_queen
    
    cmp al, PAWN
    je piece_is_pawn
    jmp done

piece_is_pawn:
    jmp call_pawn

    jmp done

call_knight:
    push bx
    push col
    push row
    call generate_knight_moves
    pop bx
    jmp done

call_king:
    push bx
    push col
    push row
    call generate_king_moves
    pop bx
    jmp done

call_bishop:
    push bx
    push 4
    push offset bishop_dirs
    push row
    push col
    call generate_sliding_moves
    pop bx
    jmp done

call_rook:
    push bx
    push 4
    push offset rook_dirs
    push row
    push col
    call generate_sliding_moves
    pop bx
    jmp done

call_queen:
    push bx

    push 4
    push offset rook_dirs
    push row
    push col
    call generate_sliding_moves

    push 4
    push offset bishop_dirs
    push row
    push col
    call generate_sliding_moves

    pop bx
    jmp done
    
call_pawn:
    push bx
    push col
    push row
    call generate_pawn_moves
    pop bx
    jmp done

done:

    pop bp
    ret 4
get_legal_moves ENDP


; KNIGHT
generate_knight_moves PROC
    push bp
    mov bp, sp

row EQU [bp+4]
col EQU [bp+6]
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

    ; index = new_row*8 + new_col
    mov ah, 0
    mov di, ax
    shl di, 3
    xor bh, bh
    add di, bx

    mov ah, board[di]

    ; if square is empty - knight_add_move
    cmp ah, EMPTY
    je knight_add_move

    ; check if square contains same color piece
    mov al, ah
    and al, COLOR_MASK  
    shr al, 3                 

    cmp al, selected_color
    je knight_next

knight_add_move:
    ; add the move to move_list
    mov di, [move_count]
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
    mov bl, col
    add bl, [si+1]
    mov [di+3], bl

    inc move_count

knight_next:
    add si, 2
    loop knight_loop
    pop bp
    ret 4 
generate_knight_moves ENDP


; KING
generate_king_moves PROC
    push bp
    mov bp, sp

row EQU [bp+4]
col EQU [bp+6]
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

    mov ah, 0
    mov di, ax
    shl di, 3
    xor bh, bh
    add di, bx

    mov ah, board[di]

    ; if square is empty - king_add_move
    cmp ah, EMPTY
    je king_add_move

    ; check if square contains same color piece
    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, selected_color
    je king_next

king_add_move:
    ; add move to move_list
    mov di, [move_count]
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
    mov bl, col
    add bl, [si+1]
    mov [di+3], bl

    inc move_count

king_next:

    add si, 2
    loop king_loop
    pop bp
    ret 4
generate_king_moves ENDP


; SLIDING PIECES
; input:
;   [bp+4]  = col
;   [bp+6]  = row
;   [bp+8]  = offset dir_table
;   [bp+10] = num_dirs
generate_sliding_moves PROC
    push bp
    mov bp, sp

col       EQU [bp+4]
row       EQU [bp+6]
dir_table EQU [bp+8]
num_dirs  EQU [bp+10]

    mov si, dir_table
    mov cx, num_dirs

dir_loop:
    ; nr = row + dr
    mov al, row
    add al, [si]
    mov dl, al          ; DL = nr

    ; nc = col + dc
    mov al, col
    add al, [si+1]
    mov dh, al          ; DH = nc

slide_loop:
    ; check board edges
    cmp dl, 0
    jge row_low_ok
    jmp next_dir

row_low_ok:
    cmp dl, 7
    jle row_high_ok
    jmp next_dir

row_high_ok:
    cmp dh, 0
    jge col_low_ok
    jmp next_dir

col_low_ok:
    cmp dh, 7
    jle col_high_ok
    jmp next_dir

col_high_ok:

    ; index = nr * 8 + nc
    mov al, dl
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dh
    xor ah, ah
    add di, ax

    ; piece = board[index]
    mov al, board[di]

    ; check if the square is empty
    cmp al, EMPTY
    je sliding_add_empty

    ; check piece color
    and al, COLOR_MASK
    shr al, 3
    cmp al, selected_color
    jne enemy_piece
    jmp next_dir             ; if the square contains the same color piece - stop direction

enemy_piece:

    ; if enemy piece - add capture and stop direction
    jmp sliding_add_capture

sliding_add_empty:
    mov di, [move_count]
    shl di, 2
    add di, offset move_list

    mov al, row
    mov [di], al

    mov al, col
    mov [di+1], al

    mov al, dl
    mov [di+2], al

    mov al, dh
    mov [di+3], al

    inc move_count

    ; nr += dr
    mov al, dl
    add al, [si]
    mov dl, al

    ; nc += dc
    mov al, dh
    add al, [si+1]
    mov dh, al

    jmp slide_loop

sliding_add_capture:
    mov di, [move_count]
    shl di, 2
    add di, offset move_list

    mov al, row
    mov [di], al

    mov al, col
    mov [di+1], al

    mov al, dl
    mov [di+2], al

    mov al, dh
    mov [di+3], al

    inc move_count
    jmp next_dir

next_dir:
    add si, 2
    dec cx
    jz dir_loop_done
    jmp dir_loop

dir_loop_done:

    pop bp
    ret 8
generate_sliding_moves ENDP


; PAWN
generate_pawn_moves PROC
    push bp
    mov bp, sp

row EQU [bp+4]
col EQU [bp+6]

    cmp selected_color, WHITE
    jne pawn_black

    mov dl, -1
    mov cl, 6
    jmp pawn_forward

pawn_black:
    mov dl, 1
    mov cl, 1

pawn_forward:
    ; nr = row + dir
    mov al, row
    add al, dl

    ; check the edges
    cmp al, 0
    jge pawn_row_low_ok
    jmp pawn_done

pawn_row_low_ok:
    cmp al, 7
    jle pawn_row_high_ok
    jmp pawn_done

pawn_row_high_ok:

    mov dh, al          ; DH = nr

    ; index = nr * 8 + col
    xor ah, ah
    mov di, ax
    shl di, 3

    mov bl, col
    xor bh, bh
    add di, bx

    mov al, board[di]

    cmp al, EMPTY
    je pawn_forward_empty
    jmp pawn_captures

pawn_forward_empty:

    ; add 1-square move
    mov di, [move_count]
    shl di, 2
    add di, offset move_list

    mov al, row
    mov [di], al

    mov al, col
    mov [di+1], al

    mov al, dh
    mov [di+2], al

    mov al, col
    mov [di+3], al

    inc move_count

    ; double step from the starting row
    mov al, row
    cmp al, cl
    je pawn_start_row_ok
    jmp pawn_captures

pawn_start_row_ok:

    ; nr2 = row + 2 * dir
    mov al, row
    add al, dl
    add al, dl
    mov dh, al          ; DH = nr2

    xor ah, ah
    mov di, ax
    shl di, 3

    mov bl, col
    xor bh, bh
    add di, bx

    mov al, board[di]
    cmp al, EMPTY
    je pawn_double_empty
    jmp pawn_captures

pawn_double_empty:

    ; add 2-square move
    mov di, [move_count]
    shl di, 2
    add di, offset move_list

    mov al, row
    mov [di], al

    mov al, col
    mov [di+1], al

    mov al, dh
    mov [di+2], al

    mov al, col
    mov [di+3], al

    inc move_count

pawn_captures:
    ; capture row = row + dir
    mov al, row
    add al, dl
    mov dh, al          ; DH = capture row

    ; capture to the left
    mov al, col
    dec al
    cmp al, 0
    jge pawn_left_in_bounds
    jmp pawn_capture_right

pawn_left_in_bounds:

    mov bl, al          ; BL = target col

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3
    xor bh, bh
    add di, bx

    mov al, board[di]
    cmp al, EMPTY
    jne pawn_left_occupied
    cmp en_passant_available, 1
    je pawn_left_en_passant
    jmp pawn_capture_right

pawn_left_en_passant:
    mov al, dh
    cmp al, en_passant_row
    je pawn_left_ep_row_ok
    jmp pawn_capture_right

pawn_left_ep_row_ok:
    cmp bl, en_passant_col
    je pawn_left_enemy
    jmp pawn_capture_right

pawn_left_occupied:

    and al, COLOR_MASK
    shr al, 3
    cmp al, selected_color
    jne pawn_left_enemy
    jmp pawn_capture_right

pawn_left_enemy:

    mov di, [move_count]
    shl di, 2
    add di, offset move_list

    mov al, row
    mov [di], al

    mov al, col
    mov [di+1], al

    mov al, dh
    mov [di+2], al

    mov [di+3], bl

    inc move_count

pawn_capture_right:
    mov al, col
    inc al
    cmp al, 7
    jle pawn_right_in_bounds
    jmp pawn_done

pawn_right_in_bounds:

    mov bl, al          ; BL = target col

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3
    xor bh, bh
    add di, bx

    mov al, board[di]
    cmp al, EMPTY
    jne pawn_right_occupied
    cmp en_passant_available, 1
    je pawn_right_en_passant
    jmp pawn_done

pawn_right_en_passant:
    mov al, dh
    cmp al, en_passant_row
    je pawn_right_ep_row_ok
    jmp pawn_done

pawn_right_ep_row_ok:
    cmp bl, en_passant_col
    je pawn_right_enemy
    jmp pawn_done

pawn_right_occupied:

    and al, COLOR_MASK
    shr al, 3
    cmp al, selected_color
    jne pawn_right_enemy
    jmp pawn_done

pawn_right_enemy:

    mov di, [move_count]
    shl di, 2
    add di, offset move_list

    mov al, row
    mov [di], al

    mov al, col
    mov [di+1], al

    mov al, dh
    mov [di+2], al

    mov [di+3], bl

    inc move_count

pawn_done:
    pop bp
    ret 4
generate_pawn_moves ENDP


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
    xor ah, ah
    mov si, ax

    ; piece = board[from]
    mov bl, board[si]

    ; to_index = to_row*8 + to_col
    mov al, to_row
    shl al, 3
    add al, to_col
    xor ah, ah
    mov di, ax

    ; save low byte of to_index for king pos
    mov dl, al

    ; captured piece in AH
    mov ah, board[di]

    ; move piece
    mov board[di], bl

    mov al, bl
    and al, TYPE_MASK

    cmp al, KING
    je update_king_pos
    jmp check_pawn_promotion

update_king_pos:
    mov al, bl
    and al, COLOR_MASK

    cmp al, WHITE
    jne black_king_move

    mov white_king_pos, dl
    jmp check_pawn_promotion

black_king_move:
    mov black_king_pos, dl

check_pawn_promotion:
    mov al, bl
    and al, TYPE_MASK

    cmp al, PAWN
    je moved_pawn
    jmp clear_old_en_passant

moved_pawn:
    cmp ah, EMPTY
    jne pawn_en_passant_checked

    mov al, from_col
    cmp al, to_col
    je pawn_en_passant_checked

    cmp en_passant_available, 1
    je pawn_ep_available
    jmp pawn_en_passant_checked

pawn_ep_available:
    mov al, to_row
    cmp al, en_passant_row
    je pawn_ep_row_ok
    jmp pawn_en_passant_checked

pawn_ep_row_ok:
    mov al, to_col
    cmp al, en_passant_col
    je do_en_passant_capture
    jmp pawn_en_passant_checked

do_en_passant_capture:
    mov al, en_passant_capture_row
    shl al, 3
    add al, en_passant_capture_col
    xor ah, ah
    mov di, ax
    mov board[di], 0

pawn_en_passant_checked:
    mov en_passant_available, 0

    mov al, bl
    and al, COLOR_MASK
    shr al, 3

    cmp al, WHITE
    jne pawn_black_double_step

    mov al, from_row
    cmp al, 6
    je white_from_start
    jmp check_white_promotion

white_from_start:
    mov al, to_row
    cmp al, 4
    je set_white_en_passant
    jmp check_white_promotion

set_white_en_passant:
    mov en_passant_available, 1
    mov en_passant_row, 5
    mov al, from_col
    mov en_passant_col, al
    mov en_passant_capture_row, 4
    mov en_passant_capture_col, al
    jmp check_white_promotion

pawn_black_double_step:
    mov al, from_row
    cmp al, 1
    je black_from_start
    jmp moved_black_pawn

black_from_start:
    mov al, to_row
    cmp al, 3
    je set_black_en_passant
    jmp moved_black_pawn

set_black_en_passant:
    mov en_passant_available, 1
    mov en_passant_row, 2
    mov al, from_col
    mov en_passant_col, al
    mov en_passant_capture_row, 3
    mov en_passant_capture_col, al
    jmp moved_black_pawn

check_white_promotion:
    mov al, bl
    and al, COLOR_MASK
    shr al, 3

    cmp al, WHITE
    jne moved_black_pawn

    mov al, to_row
    cmp al, 0
    je start_promotion
    jmp finalize_move

moved_black_pawn:
    mov al, to_row
    cmp al, 7
    je start_promotion
    jmp finalize_move

start_promotion:
    mov waiting_for_promotion, 1

    mov al, to_row
    mov promotion_row, al

    mov al, to_col
    mov promotion_col, al

    mov al, bl
    and al, COLOR_MASK
    shr al, 3
    mov promotion_color, al

    jmp clear_source_only

clear_old_en_passant:
    mov en_passant_available, 0
    jmp finalize_move

finalize_move:
    xor current_turn, 1

clear_source_only:

    ; clear source square
    mov board[si], 0

    pop bp
    ret 8
execute_move ENDP


; finalize_promotion
; input: [bp+4] = chosen piece type
finalize_promotion PROC
    push bp
    mov bp, sp

piece_type EQU [bp+4]

    cmp waiting_for_promotion, 1
    je do_promotion
    jmp finalize_promotion_done

do_promotion:
    mov al, promotion_row
    shl al, 3
    add al, promotion_col
    xor ah, ah
    mov di, ax

    mov al, piece_type
    and al, TYPE_MASK

    mov ah, promotion_color
    shl ah, 3
    or al, ah

    mov board[di], al
    mov waiting_for_promotion, 0
    xor current_turn, 1

finalize_promotion_done:
    pop bp
    ret 2
finalize_promotion ENDP

 
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