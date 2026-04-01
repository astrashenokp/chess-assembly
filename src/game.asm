.MODEL small

INCLUDE shared.inc
 
.DATA

; Board representation
; index = row * 8 + col
 
PUBLIC board
PUBLIC move_list
PUBLIC move_count
board DB 64 DUP(?)

 
; Global state
PUBLIC current_turn
current_turn    DB 0      ; 0 = white, 1 = black
selected_color DB 0       ; color of the selected piece
PUBLIC waiting_for_promotion
waiting_for_promotion DB 0
PUBLIC last_move_was_capture, last_captured_piece, last_mover_color
last_move_was_capture DB 0
last_captured_piece   DB 0
last_mover_color      DB 0
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
PUBLIC captured_by_white, captured_by_black, cap_w_count, cap_b_count
captured_by_white DB 16 DUP(0)
captured_by_black DB 16 DUP(0)
cap_w_count DW 0
cap_b_count DW 0
test_saved_from DB 0
test_saved_to DB 0
test_saved_white_king_pos DB 0
test_saved_black_king_pos DB 0
test_saved_ep_piece DB 0
test_saved_ep_index DB 0
test_ep_active DB 0

 
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
EMPTY  EQU 0
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
PUBLIC is_stalemate
PUBLIC get_move_capture_info
PUBLIC make_test_move 
PUBLIC undo_test_move


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
    mov last_move_was_capture, 0
    mov last_captured_piece, 0
    mov last_mover_color, 0
    mov en_passant_available, 0
    mov white_king_pos, 60
    mov black_king_pos, 4
    
    mov cap_w_count, 0
    mov cap_b_count, 0
    
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
    jmp filter_generated

call_king:
    push bx
    push col
    push row
    call generate_king_moves
    pop bx
    jmp filter_generated

call_bishop:
    push bx
    push 4
    push offset bishop_dirs
    push row
    push col
    call generate_sliding_moves
    pop bx
    jmp filter_generated

call_rook:
    push bx
    push 4
    push offset rook_dirs
    push row
    push col
    call generate_sliding_moves
    pop bx
    jmp filter_generated

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
    jmp filter_generated
    
call_pawn:
    push bx
    push col
    push row
    call generate_pawn_moves
    pop bx
    jmp filter_generated

filter_generated:
    call filter_legal_moves
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

    mov al, bl
    and al, COLOR_MASK
    shr al, 3
    mov last_mover_color, al
    mov last_move_was_capture, 0
    mov last_captured_piece, 0

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
    cmp ah, EMPTY
    je skip_rec
    mov last_move_was_capture, 1
    mov last_captured_piece, ah
    call record_capture

skip_rec:

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
    push di
    mov di, ax
    mov ah, board[di] 
    mov last_move_was_capture, 1
    mov last_captured_piece, ah
    call record_capture
    mov board[di], 0
    pop di

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


record_capture PROC
    push ax
    push bx
    push di

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, WHITE
    je cap_by_black

    mov di, cap_w_count
    mov captured_by_white[di], ah
    inc cap_w_count
    jmp cap_done

cap_by_black:
    mov di, cap_b_count
    mov captured_by_black[di], ah
    inc cap_b_count

cap_done:
    pop di
    pop bx
    pop ax
    ret
record_capture ENDP


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


; make_test_move PROC
; input: 
; [bp+4] = from_row
; [bp+6] = from_col
; [bp+8] = to_row
; [bp+10] = to_col
make_test_move PROC
    push bp
    mov bp, sp
    push ax
    push bx
    push dx
    push si
    push di

from_row EQU [bp+4]
from_col EQU [bp+6]
to_row   EQU [bp+8]
to_col   EQU [bp+10]

    ; clear temporary en passant state for this tested move
    mov test_ep_active, 0

    ; save king positions so undo can restore them
    mov al, white_king_pos
    mov test_saved_white_king_pos, al
    mov al, black_king_pos
    mov test_saved_black_king_pos, al

    mov al, from_row
    shl al, 3
    add al, from_col
    xor ah, ah
    mov si, ax

    mov al, to_row
    shl al, 3
    add al, to_col
    xor ah, ah
    mov di, ax

    mov bl, board[si]
    mov test_saved_from, bl

    mov al, board[di]
    mov test_saved_to, al

    ; make the move only on board state
    mov board[di], bl
    mov board[si], EMPTY

    ; if a king moved, update its temporary position
    mov al, bl
    and al, TYPE_MASK
    cmp al, KING
    jne test_pawn_move

    mov al, bl
    and al, COLOR_MASK
    shr al, 3
    cmp al, WHITE
    jne test_black_king_move

    mov al, to_row
    shl al, 3
    add al, to_col
    mov white_king_pos, al
    jmp test_move_done

test_black_king_move:
    mov al, to_row
    shl al, 3
    add al, to_col
    mov black_king_pos, al
    jmp test_move_done

test_pawn_move:
    ; temporary en passant capture
    mov al, bl
    and al, TYPE_MASK
    cmp al, PAWN
    jne test_move_done

    mov al, test_saved_to
    cmp al, EMPTY
    jne test_move_done

    mov al, from_col
    cmp al, to_col
    je test_move_done

    cmp en_passant_available, 1
    jne test_move_done

    mov al, to_row
    cmp al, en_passant_row
    jne test_move_done

    mov al, to_col
    cmp al, en_passant_col
    jne test_move_done

    mov al, en_passant_capture_row
    shl al, 3
    add al, en_passant_capture_col
    mov test_saved_ep_index, al

    xor ah, ah
    mov di, ax
    mov al, board[di]
    mov test_saved_ep_piece, al
    mov board[di], EMPTY
    mov test_ep_active, 1

test_move_done:
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    pop bp
    ret 8
make_test_move ENDP


undo_test_move PROC
    push bp
    mov bp, sp
    push ax
    push si
    push di

from_row EQU [bp+4]
from_col EQU [bp+6]
to_row   EQU [bp+8]
to_col   EQU [bp+10]

    ; restore both board squares
    mov al, from_row
    shl al, 3
    add al, from_col
    xor ah, ah
    mov si, ax

    mov al, to_row
    shl al, 3
    add al, to_col
    xor ah, ah
    mov di, ax

    mov al, test_saved_from
    mov board[si], al

    mov al, test_saved_to
    mov board[di], al

    ; restore king positions
    mov al, test_saved_white_king_pos
    mov white_king_pos, al
    mov al, test_saved_black_king_pos
    mov black_king_pos, al

    ; restore captured pawn if the tested move was en passant
    cmp test_ep_active, 1
    jne undo_test_done

    mov al, test_saved_ep_index
    xor ah, ah
    mov di, ax
    mov al, test_saved_ep_piece
    mov board[di], al
    mov test_ep_active, 0

undo_test_done:
    pop di
    pop si
    pop ax
    pop bp
    ret 8
undo_test_move ENDP


filter_legal_moves PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, offset move_list
    mov di, offset move_list
    mov cx, move_count
    xor dx, dx

    cmp cx, 0
    jne filter_loop
    jmp filter_done

filter_loop:
    ; make-check-undo
    xor ax, ax
    mov al, [si+3]
    push ax

    xor ax, ax
    mov al, [si+2]
    push ax

    xor ax, ax
    mov al, [si+1]
    push ax

    xor ax, ax
    mov al, [si]
    push ax
    call make_test_move

    xor ax, ax
    mov al, selected_color
    push ax
    call is_in_check
    mov bl, al

    ; restore board state
    xor ax, ax
    mov al, [si+3]
    push ax

    xor ax, ax
    mov al, [si+2]
    push ax

    xor ax, ax
    mov al, [si+1]
    push ax

    xor ax, ax
    mov al, [si]
    push ax
    call undo_test_move

    ; keep only moves that do not leave own king in check
    cmp bl, 0
    jne skip_legal_move

    mov al, [si]
    mov [di], al
    mov al, [si+1]
    mov [di+1], al
    mov al, [si+2]
    mov [di+2], al
    mov al, [si+3]
    mov [di+3], al

    add di, 4
    inc dx

skip_legal_move:
    add si, 4
    dec cx
    jz filter_done
    jmp filter_loop

filter_done:
    mov move_count, dx

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
filter_legal_moves ENDP

 
; is_in_check
; input: [bp+4] = color
; output: AL = 1 if in check
is_in_check PROC
    push bp
    mov bp, sp
    push bx
    push dx

color EQU [bp+4]

    mov al, color
    cmp al, WHITE
    jne load_black_king_pos

    mov al, white_king_pos
    jmp king_pos_loaded

load_black_king_pos:
    mov al, black_king_pos

king_pos_loaded:
    ; board index into row / col 
    mov dl, al
    and dl, 7
    shr al, 3

    xor bh, bh
    mov bl, color
    xor bl, 1

    xor dh, dh
    xor ah, ah

    push bx
    push dx
    push ax
    call is_square_attacked

    pop dx
    pop bx
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
    push si
    push di
    push bx
    push cx
    push dx

row   EQU [bp+4]
col   EQU [bp+6]
color EQU [bp+8]

    mov bl, color

    ; rook / queen attacks on straight lines
    mov si, offset rook_dirs
    mov cx, 4

rook_dir_loop:
    mov dh, row
    mov dl, col

rook_step_loop:
    add dh, [si]
    add dl, [si+1]

    cmp dh, 0
    jl rook_next_dir
    cmp dh, 7
    jg rook_next_dir

    cmp dl, 0
    jl rook_next_dir
    cmp dl, 7
    jg rook_next_dir

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dl
    xor ah, ah
    add di, ax

    mov ah, board[di]
    cmp ah, EMPTY
    je rook_step_loop

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, bl
    jne rook_next_dir

    mov al, ah
    and al, TYPE_MASK
    cmp al, ROOK
    jne rook_check_queen
    jmp attacked_done

rook_check_queen:
    cmp al, QUEEN
    jne rook_next_dir
    jmp attacked_done

rook_next_dir:
    add si, 2
    dec cx
    jz rook_done
    jmp rook_dir_loop

rook_done:
    ; bishop / queen attacks on diagonals
    mov si, offset bishop_dirs
    mov cx, 4

bishop_dir_loop:
    mov dh, row
    mov dl, col

bishop_step_loop:
    add dh, [si]
    add dl, [si+1]

    cmp dh, 0
    jl bishop_next_dir
    cmp dh, 7
    jg bishop_next_dir

    cmp dl, 0
    jl bishop_next_dir
    cmp dl, 7
    jg bishop_next_dir

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dl
    xor ah, ah
    add di, ax

    mov ah, board[di]
    cmp ah, EMPTY
    je bishop_step_loop

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, bl
    jne bishop_next_dir

    mov al, ah
    and al, TYPE_MASK
    cmp al, BISHOP
    jne bishop_check_queen
    jmp attacked_done

bishop_check_queen:
    cmp al, QUEEN
    jne bishop_next_dir
    jmp attacked_done

bishop_next_dir:
    add si, 2
    dec cx
    jz bishop_done
    jmp bishop_dir_loop

bishop_done:
    ; knight attacks
    mov si, offset knight_offsets
    mov cx, 8

knight_loop_check:
    mov dh, row
    add dh, [si]

    mov dl, col
    add dl, [si+1]

    cmp dh, 0
    jl knight_check_next
    cmp dh, 7
    jg knight_check_next

    cmp dl, 0
    jl knight_check_next
    cmp dl, 7
    jg knight_check_next

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dl
    xor ah, ah
    add di, ax

    mov ah, board[di]
    cmp ah, EMPTY
    je knight_check_next

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, bl
    jne knight_check_next

    mov al, ah
    and al, TYPE_MASK
    cmp al, KNIGHT
    jne knight_check_next
    jmp attacked_done

knight_check_next:
    add si, 2
    dec cx
    jz check_pawns
    jmp knight_loop_check

check_pawns:
    ; pawn attacks
    cmp bl, WHITE
    jne check_black_pawn_attack

check_white_pawn_attack:
    mov bh, 1
    jmp pawn_attack_row_ready

check_black_pawn_attack:
    mov bh, -1

pawn_attack_row_ready:
    mov dh, row
    add dh, bh

    cmp dh, 0
    jge check_next_bound
    jmp check_king
    
check_next_bound: 
    cmp dh, 7
    jg check_king

check_pawn_left:
    mov dl, col
    dec dl

    cmp dl, 0
    jl check_pawn_right

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dl
    xor ah, ah
    add di, ax

    mov ah, board[di]
    cmp ah, EMPTY
    je check_pawn_right

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, bl
    jne check_pawn_right

    mov al, ah
    and al, TYPE_MASK
    cmp al, PAWN
    jne check_pawn_right
    jmp attacked_done

check_pawn_right:
    mov dl, col
    inc dl

    cmp dl, 7
    jg check_king

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dl
    xor ah, ah
    add di, ax

    mov ah, board[di]
    cmp ah, EMPTY
    je check_king

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, bl
    jne check_king

    mov al, ah
    and al, TYPE_MASK
    cmp al, PAWN
    jne check_king
    jmp attacked_done

check_king:
    mov si, offset king_dirs
    mov cx, 8

king_loop_check:
    mov dh, row
    add dh, [si]

    mov dl, col
    add dl, [si+1]

    cmp dh, 0
    jl king_check_next
    cmp dh, 7
    jg king_check_next

    cmp dl, 0
    jl king_check_next
    cmp dl, 7
    jg king_check_next

    mov al, dh
    xor ah, ah
    mov di, ax
    shl di, 3

    mov al, dl
    xor ah, ah
    add di, ax

    mov ah, board[di]
    cmp ah, EMPTY
    je king_check_next

    mov al, ah
    and al, COLOR_MASK
    shr al, 3
    cmp al, bl
    jne king_check_next

    mov al, ah
    and al, TYPE_MASK
    cmp al, KING
    jne king_check_next
    jmp attacked_done

king_check_next:
    add si, 2
    dec cx
    jz not_attacked
    jmp king_loop_check

attacked_done:
    mov al, 1
    jmp is_square_attacked_exit

not_attacked:
    xor al, al

is_square_attacked_exit:
    pop dx
    pop cx
    pop bx
    pop di
    pop si
    pop bp
    ret 6
is_square_attacked ENDP


has_any_legal_move PROC
    push bp
    mov bp, sp
    push bx
    push dx
    push si

color EQU [bp+4]

    mov bl, current_turn
    mov bh, color
    mov current_turn, bh

    xor dh, dh

scan_row_loop:
    cmp dh, 8
    je no_legal_moves

    xor dl, dl

scan_col_loop:
    cmp dl, 8
    je next_scan_row

    mov al, dh
    xor ah, ah
    mov si, ax
    shl si, 3

    mov al, dl
    xor ah, ah
    add si, ax

    mov al, board[si]
    cmp al, EMPTY
    je next_scan_col

    mov ah, al
    and ah, COLOR_MASK
    shr ah, 3
    cmp ah, bh
    jne next_scan_col

    push bx
    push dx

    xor ax, ax
    mov al, dl
    push ax

    xor ax, ax
    mov al, dh
    push ax
    call get_legal_moves

    pop dx
    pop bx

    mov ax, move_count
    cmp ax, 0
    jne legal_move_found

next_scan_col:
    inc dl
    jmp scan_col_loop

next_scan_row:
    inc dh
    jmp scan_row_loop

legal_move_found:
    mov current_turn, bl
    mov al, 1
    jmp has_any_legal_move_done

no_legal_moves:
    mov current_turn, bl
    xor al, al

has_any_legal_move_done:
    pop si
    pop dx
    pop bx
    pop bp
    ret 2
has_any_legal_move ENDP

; is_checkmate
; input: [bp+4] = color
; output: AL = 1 if in checkmate
is_checkmate PROC
    push bp
    mov bp, sp

color EQU [bp+4]

    xor ax, ax
    mov al, color
    push ax
    call has_any_legal_move
    cmp al, 0
    je check_if_in_check
    jmp not_checkmate

check_if_in_check:
    xor ax, ax
    mov al, color
    push ax
    call is_in_check
    cmp al, 1
    je yes_checkmate
    jmp not_checkmate

yes_checkmate:
    mov al, 1
    jmp is_checkmate_done

not_checkmate:
    xor al, al

is_checkmate_done:
    pop bp
    ret 2
is_checkmate ENDP


; is_stalemate
; input: [bp+4] = color
; output: AL = 1 if in stalemate
is_stalemate PROC
    push bp
    mov bp, sp

color EQU [bp+4]

    xor ax, ax
    mov al, color
    push ax
    call has_any_legal_move
    cmp al, 0
    je check_if_not_in_check
    jmp not_stalemate

check_if_not_in_check:
    xor ax, ax
    mov al, color
    push ax
    call is_in_check
    cmp al, 0
    je yes_stalemate
    jmp not_stalemate

yes_stalemate:
    mov al, 1
    jmp is_stalemate_done

not_stalemate:
    xor al, al

is_stalemate_done:
    pop bp
    ret 2
is_stalemate ENDP


; get_move_capture_info
; input:  from_row, from_col, to_row, to_col
; output: AL = 1 if capture, 0 if not
;         AH = captured piece byte, or 0 if no capture
get_move_capture_info PROC
    push bp
    mov bp, sp
    push bx
    push dx
    push si
    push di

from_row EQU [bp+4]
from_col EQU [bp+6]
to_row   EQU [bp+8]
to_col   EQU [bp+10]

    ; from index
    mov al, from_row
    shl al, 3
    add al, from_col
    xor ah, ah
    mov si, ax

    ; moving piece
    mov bl, board[si]

    ; to index
    mov al, to_row
    shl al, 3
    add al, to_col
    xor ah, ah
    mov di, ax

    ; if capture: al = 1
    mov dl, board[di]
    cmp dl, EMPTY
    je gmci_check_en_passant

    mov al, bl
    and al, COLOR_MASK
    mov ah, dl
    and ah, COLOR_MASK
    cmp al, ah
    je gmci_no_capture

    mov ah, dl
    mov al, 1
    jmp gmci_done

gmci_check_en_passant:
    ; en passant: destination is empty, but captured pawn is behind it
    mov al, bl
    and al, TYPE_MASK
    cmp al, PAWN
    jne gmci_no_capture

    mov al, from_col
    cmp al, to_col
    je gmci_no_capture

    cmp en_passant_available, 1
    jne gmci_no_capture

    mov al, to_row
    cmp al, en_passant_row
    jne gmci_no_capture

    mov al, to_col
    cmp al, en_passant_col
    jne gmci_no_capture

    mov al, en_passant_capture_row
    shl al, 3
    add al, en_passant_capture_col
    xor ah, ah
    mov bx, ax

    mov dl, board[bx]
    cmp dl, EMPTY
    je gmci_no_capture

    mov ah, dl
    mov al, 1
    jmp gmci_done

gmci_no_capture:
    xor ax, ax

gmci_done:
    pop di
    pop si
    pop dx
    pop bx
    pop bp
    ret 8
get_move_capture_info ENDP

END
