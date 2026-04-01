INCLUDE shared.inc

.MODEL small

.DATA
EXTRN ai_difficulty:BYTE
EXTRN board:BYTE
EXTRN current_turn:BYTE
EXTRN move_list:BYTE
EXTRN move_count:WORD
EXTRN waiting_for_promotion:BYTE

ai_move_buffer DB 1024 DUP(?)
ai_total_moves DW 0
capture_index_buffer DW 256 DUP(?)
capture_count DW 0
best_index_buffer DW 256 DUP(?)
best_count DW 0
selected_from_row DB ?
selected_from_col DB ?
selected_to_row DB ?
selected_to_col DB ?
ai_side DB ?
opponent_side DB ?
current_piece_type DB ?
current_source_attacked DB ?
current_move_index DW ?
current_score DW ?
best_score DW ?
seed DW 0
rng_ready DB 0

.CODE

EMPTY EQU 0
PAWN EQU 1
KNIGHT EQU 2
BISHOP EQU 3
ROOK EQU 4
QUEEN EQU 5
KING EQU 6

PUBLIC ai_turn
EXTRN get_legal_moves:PROC
EXTRN execute_move:PROC
EXTRN finalize_promotion:PROC
EXTRN get_move_capture_info:PROC
EXTRN make_test_move:PROC
EXTRN undo_test_move:PROC
EXTRN is_in_check:PROC
EXTRN is_square_attacked:PROC

ai_turn PROC
    call collect_all_legal_moves

    cmp ai_total_moves, 0
    je ai_done

    cmp ai_difficulty, 0
    je ai_easy

    cmp ai_difficulty, 1
    je ai_medium

; hard mode
ai_hard:
    call choose_hard_move
    jmp ai_execute

; medium mode
ai_medium:
    call choose_medium_move
    jmp ai_execute

; easy mode
ai_easy:
    call choose_easy_move
    
ai_execute:
    call execute_selected_move

    cmp waiting_for_promotion, 0
    je ai_done

    push 5
    call finalize_promotion

ai_done:
    ret
ai_turn ENDP


choose_hard_move PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov al, current_turn
    mov ai_side, al
    mov opponent_side, al
    xor opponent_side, 1

    mov best_score, 8000h
    call reset_best_list

    mov cx, ai_total_moves
    xor dx, dx

hard_loop:
    cmp cx, 0
    jne hard_eval
    jmp hard_pick

hard_eval:
    mov current_move_index, dx

    mov bx, dx
    call load_move_by_index
    call get_selected_piece_type
    mov current_piece_type, al
    cmp al, KING
    je hard_source_attack_done

    call check_selected_source_square_attacked
    mov current_source_attacked, al
    jmp hard_make_move

hard_source_attack_done:
    mov current_source_attacked, 0

hard_make_move:
    call make_selected_test_move

    call evaluate_material
    push dx
    mov bx, 100
    imul bx
    mov current_score, ax
    pop dx

    call check_opponent_in_check
    cmp al, 1
    jne hard_check_done

    mov ax, current_score
    add ax, 40
    mov current_score, ax

hard_check_done:
    mov al, current_piece_type
    cmp al, KING
    je hard_score_ready

    call check_selected_square_attacked
    cmp current_source_attacked, 1
    jne hard_dest_penalty_check
    cmp al, 0
    jne hard_dest_penalty_check

    mov al, current_piece_type
    call piece_value
    push dx
    mov bx, 100
    imul bx
    mov bx, ax
    pop dx

    mov ax, current_score
    add ax, bx
    mov current_score, ax

hard_dest_penalty_check:
    cmp al, 1
    jne hard_score_ready

    mov al, current_piece_type
    call piece_value
    push dx
    mov bx, 100
    imul bx
    mov bx, ax
    pop dx

    mov ax, current_score
    sub ax, bx
    mov current_score, ax

hard_score_ready:
    call undo_selected_test_move

    mov ax, current_score
    cmp ax, best_score
    jg hard_new_best
    je hard_same_best
    jmp hard_next

hard_new_best:
    mov best_score, ax
    call reset_best_list
    mov bx, current_move_index
    call record_best_index
    jmp hard_next

hard_same_best:
    mov bx, current_move_index
    call record_best_index

hard_next:
    inc dx
    dec cx
    jmp hard_loop

hard_pick:
    mov bx, best_count
    call random_range
    shl ax, 1
    mov di, ax
    mov bx, best_index_buffer[di]
    call load_move_by_index

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
choose_hard_move ENDP

choose_medium_move PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov al, current_turn
    mov ai_side, al
    mov opponent_side, al
    xor opponent_side, 1

    mov best_score, 8000h
    call reset_best_list

    mov cx, ai_total_moves
    xor dx, dx

medium_loop:
    cmp cx, 0
    jne medium_eval
    jmp medium_pick

medium_eval:
    mov current_move_index, dx

    mov bx, dx
    call load_move_by_index
    call make_selected_test_move
    call evaluate_material
    push dx
    mov bx, 100
    imul bx
    mov current_score, ax
    pop dx
    call undo_selected_test_move

    mov ax, current_score
    cmp ax, best_score
    jg medium_new_best
    je medium_same_best
    jmp medium_next

medium_new_best:
    mov best_score, ax
    call reset_best_list
    mov bx, current_move_index
    call record_best_index
    jmp medium_next

medium_same_best:
    mov bx, current_move_index
    call record_best_index

medium_next:
    inc dx
    dec cx
    jmp medium_loop

medium_pick:
    mov bx, best_count
    call random_range
    shl ax, 1
    mov di, ax
    mov bx, best_index_buffer[di]
    call load_move_by_index

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
choose_medium_move ENDP

choose_easy_move PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Build a list of capture moves first.
    mov capture_count, 0
    mov cx, ai_total_moves
    mov si, offset ai_move_buffer
    xor bx, bx

scan_moves:
    cmp cx, 0
    jne scan_current
    jmp choose_phase

scan_current:
    call is_move_capture
    cmp al, 1
    jne next_scan_move

    mov di, capture_count
    shl di, 1
    mov capture_index_buffer[di], bx
    inc capture_count

next_scan_move:
    add si, 4
    inc bx
    dec cx
    jmp scan_moves

choose_phase:
    mov ax, capture_count
    cmp ax, 0
    jne choose_capture

    mov bx, ai_total_moves
    call random_range
    mov bx, ax
    jmp load_selected_move

choose_capture:
    mov bx, capture_count
    call random_range

    shl ax, 1
    mov di, ax
    mov bx, capture_index_buffer[di]

load_selected_move:
    mov di, bx
    shl di, 2
    mov si, di
    add si, offset ai_move_buffer

    mov al, [si]
    mov selected_from_row, al

    mov al, [si+1]
    mov selected_from_col, al

    mov al, [si+2]
    mov selected_to_row, al

    mov al, [si+3]
    mov selected_to_col, al

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
choose_easy_move ENDP

reset_best_list PROC
    mov best_count, 0
    ret
reset_best_list ENDP

record_best_index PROC
    push di

    mov di, best_count
    shl di, 1
    mov best_index_buffer[di], bx
    inc best_count

    pop di
    ret
record_best_index ENDP

load_move_by_index PROC
    push si
    push di

    mov di, bx
    shl di, 2
    mov si, di
    add si, offset ai_move_buffer

    mov al, [si]
    mov selected_from_row, al

    mov al, [si+1]
    mov selected_from_col, al

    mov al, [si+2]
    mov selected_to_row, al

    mov al, [si+3]
    mov selected_to_col, al

    pop di
    pop si
    ret
load_move_by_index ENDP

get_selected_piece_type PROC
    push bx

    mov al, selected_from_row
    shl al, 3
    add al, selected_from_col

    xor ah, ah
    mov bx, ax

    mov al, board[bx]
    and al, TYPE_MASK

    pop bx
    ret
get_selected_piece_type ENDP

make_selected_test_move PROC
    xor ax, ax
    mov al, selected_to_col
    push ax

    xor ax, ax
    mov al, selected_to_row
    push ax

    xor ax, ax
    mov al, selected_from_col
    push ax

    xor ax, ax
    mov al, selected_from_row
    push ax
    call make_test_move
    ret
make_selected_test_move ENDP

undo_selected_test_move PROC
    xor ax, ax
    mov al, selected_to_col
    push ax

    xor ax, ax
    mov al, selected_to_row
    push ax

    xor ax, ax
    mov al, selected_from_col
    push ax

    xor ax, ax
    mov al, selected_from_row
    push ax
    call undo_test_move
    ret
undo_selected_test_move ENDP

piece_value PROC
    cmp al, PAWN
    je piece_is_pawn

    cmp al, KNIGHT
    je piece_is_knight

    cmp al, BISHOP
    je piece_is_bishop

    cmp al, ROOK
    je piece_is_rook

    cmp al, QUEEN
    je piece_is_queen

    xor ax, ax
    ret

piece_is_pawn:
    mov ax, 1
    ret

piece_is_knight:
    mov ax, 3
    ret

piece_is_bishop:
    mov ax, 3
    ret

piece_is_rook:
    mov ax, 5
    ret

piece_is_queen:
    mov ax, 9
    ret
piece_value ENDP

evaluate_material PROC
    push bx
    push cx
    push dx
    push si

    xor dx, dx
    mov cx, 64
    mov si, offset board

eval_loop:
    mov al, [si]
    cmp al, EMPTY
    jne eval_piece_found
    jmp eval_next

eval_piece_found:
    mov bl, al
    and bl, COLOR_MASK
    shr bl, 3

    and al, TYPE_MASK
    call piece_value

    cmp bl, ai_side
    je eval_add_value
    sub dx, ax
    jmp eval_next

eval_add_value:
    add dx, ax

eval_next:
    inc si
    loop eval_loop

    mov ax, dx

    pop si
    pop dx
    pop cx
    pop bx
    ret
evaluate_material ENDP

check_opponent_in_check PROC
    push bx
    push cx
    push dx
    push si
    push di

    xor ax, ax
    mov al, opponent_side
    push ax
    call is_in_check

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
check_opponent_in_check ENDP

check_selected_square_attacked PROC
    push bx
    push cx
    push dx
    push si
    push di

    xor ax, ax
    mov al, opponent_side
    push ax

    xor ax, ax
    mov al, selected_to_col
    push ax

    xor ax, ax
    mov al, selected_to_row
    push ax
    call is_square_attacked

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
check_selected_square_attacked ENDP

check_selected_source_square_attacked PROC
    push bx
    push cx
    push dx
    push si
    push di

    xor ax, ax
    mov al, opponent_side
    push ax

    xor ax, ax
    mov al, selected_from_col
    push ax

    xor ax, ax
    mov al, selected_from_row
    push ax
    call is_square_attacked

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
check_selected_source_square_attacked ENDP

init_rng_if_needed PROC
    ; Seed the generator once from the BIOS timer
    cmp rng_ready, 1
    je rng_ready_done

    mov ah, 00h
    int 1Ah
    mov seed, dx
    mov rng_ready, 1

rng_ready_done:
    ret
init_rng_if_needed ENDP

random_range PROC
    ; BX = N, AX returns a value in [0, N)
    push dx
    push cx

    call init_rng_if_needed
    ; seed = (seed * 25173 + 13849)

    mov ax, seed
    mov cx, 25173
    mul cx
    add ax, 13849
    mov seed, ax

    xor dx, dx
    div bx
    mov ax, dx

    pop cx
    pop dx
    ret
random_range ENDP

is_move_capture PROC
    ; SI points to one move in ai_move_buffer
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

    call get_move_capture_info
    ret
is_move_capture ENDP

execute_selected_move PROC
    ; Execute the chosen move
    push ax

    xor ax, ax
    mov al, selected_to_col
    push ax

    xor ax, ax
    mov al, selected_to_row
    push ax

    xor ax, ax
    mov al, selected_from_col
    push ax

    xor ax, ax
    mov al, selected_from_row
    push ax

    call execute_move

    pop ax
    ret
execute_selected_move ENDP

collect_all_legal_moves PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov ai_total_moves, 0

    mov dh, 0

row_loop:
    cmp dh, 8
    jl row_ok
    jmp collect_done

row_ok:
    mov dl, 0

col_loop:
    cmp dl, 8
    jl col_ok
    jmp next_row

col_ok:
    ; index = row*8 + col
    mov al, dh
    shl al, 3
    add al, dl

    xor ah, ah
    mov si, ax
    mov al, board[si]

    cmp al, EMPTY
    jne piece_found
    jmp next_col

piece_found:
    mov ah, al
    and ah, COLOR_MASK
    shr ah, 3

    cmp ah, current_turn
    je color_ok
    jmp next_col

color_ok:
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

    mov cx, move_count
    cmp cx, 0
    jne has_moves
    jmp next_col

has_moves:
    mov di, ai_total_moves
    shl di, 2
    add di, offset ai_move_buffer

    mov si, offset move_list

copy_loop:
    mov al, [si]
    mov [di], al

    mov al, [si+1]
    mov [di+1], al

    mov al, [si+2]
    mov [di+2], al

    mov al, [si+3]
    mov [di+3], al

    add si, 4
    add di, 4
    inc ai_total_moves

    loop copy_loop

next_col:
    inc dl
    jmp col_loop

next_row:
    inc dh
    jmp row_loop

collect_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
collect_all_legal_moves ENDP

END
