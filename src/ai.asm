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
selected_from_row DB ?
selected_from_col DB ?
selected_to_row DB ?
selected_to_col DB ?
seed DW 0
rng_ready DB 0

.CODE

EMPTY EQU 0

PUBLIC ai_turn
EXTRN get_legal_moves:PROC
EXTRN execute_move:PROC
EXTRN finalize_promotion:PROC

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
    ret
choose_hard_move ENDP

choose_medium_move PROC
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
    push bx

    mov al, [si+2]
    shl al, 3
    add al, [si+3]

    xor ah, ah
    mov bx, ax

    mov al, board[bx]
    cmp al, EMPTY
    jne move_is_capture

    xor al, al
    pop bx
    ret

move_is_capture:
    mov al, 1
    pop bx
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
