.MODEL small
.STACK 256

INCLUDE shared.inc

.DATA
EXTRN board:BYTE
EXTRN move_list:BYTE
EXTRN move_count:WORD
EXTRN current_turn:BYTE

queen_msg DB 'QUEEN MOVES',13,10,'$'
pawn_msg  DB 13,10,'PAWN MOVES',13,10,'$'
black_pawn_msg DB 13,10,'BLACK PAWN MOVES',13,10,'$'
white_ep_msg DB 13,10,'WHITE EN PASSANT',13,10,'$'
black_ep_msg DB 13,10,'BLACK EN PASSANT',13,10,'$'

.CODE

EXTRN init_board:PROC
EXTRN get_legal_moves:PROC
EXTRN execute_move:PROC

start:

    mov ax, @data
    mov ds, ax

    ; initialize chess position
    call init_board

    ; queen sliding-move test
    call clear_test_board

    ; white queen at (4,3)
    mov board[35], 5

    mov board[33], 9     ; black pawn at (4,1)
    mov board[37], 1     ; white pawn at (4,5)

    mov board[19], 2     ; white knight at (2,3)
    mov board[51], 11    ; black bishop at (6,3)

    mov board[17], 9     ; black pawn at (2,1)
    mov board[21], 1     ; white pawn at (2,5)
    mov board[53], 12    ; black rook at (6,5)
    mov board[49], 3     ; white bishop at (6,1)

;       0 1 2 3 4 5 6 7
; row 0 . . . . . . . .
; row 1 . . . . . . . .
; row 2 . p . N . P . .
; row 3 . . . . . . . .
; row 4 . p . Q . P . .
; row 5 . . . . . . . .
; row 6 . B . b . r . .
; row 7 . . . . . . . .

    mov dx, offset queen_msg
    mov ah, 09h
    int 21h

    ; test queen sliding moves from (4,3)
    push 3
    push 4
    call get_legal_moves

    call print_moves

    ; pawn move test
    call clear_test_board

    ; white pawn at (6,3)
    mov board[51], 1
    mov board[42], 9     ; black pawn at (5,2)
    mov board[44], 11    ; black bishop at (5,4)

    ;       0 1 2 3 4 5 6 7
    ; row 0 . . . . . . . .
    ; row 1 . . . . . . . .
    ; row 2 . . . . . . . .
    ; row 3 . . . . . . . .
    ; row 4 . . . . . . . .
    ; row 5 . . p . b . . .
    ; row 6 . . . P . . . .
    ; row 7 . . . . . . . .

    mov dx, offset pawn_msg
    mov ah, 09h
    int 21h

    ; test pawn moves from (6,3)
    push 3
    push 6
    call get_legal_moves

    call print_moves

    ; black pawn move test
    call clear_test_board
    mov current_turn, 1

    ; black pawn at (1,3)
    mov board[11], 9
    mov board[18], 2     ; white knight at (2,2)
    mov board[20], 3     ; white bishop at (2,4)

    ;       0 1 2 3 4 5 6 7
    ; row 0 . . . . . . . .
    ; row 1 . . . p . . . .
    ; row 2 . . N . B . . .
    ; row 3 . . . . . . . .
    ; row 4 . . . . . . . .
    ; row 5 . . . . . . . .
    ; row 6 . . . . . . . .
    ; row 7 . . . . . . . .

    mov dx, offset black_pawn_msg
    mov ah, 09h
    int 21h

    ; test black pawn moves from (1,3)
    push 3
    push 1
    call get_legal_moves

    call print_moves

    ; white en passant test
    call clear_test_board
    mov current_turn, 1

    ; black pawn at (1,4), white pawn at (3,3)
    mov board[12], 9
    mov board[27], 1

    mov dx, offset white_ep_msg
    mov ah, 09h
    int 21h

    ; black double step from (1,4) to (3,4)
    push 4
    push 3
    push 4
    push 1
    call execute_move

    ; test white pawn moves from (3,3)
    push 3
    push 3
    call get_legal_moves

    call print_moves

    ; black en passant test
    call clear_test_board
    mov current_turn, 0

    ; white pawn at (6,3), black pawn at (4,4)
    mov board[51], 1
    mov board[36], 9

    mov dx, offset black_ep_msg
    mov ah, 09h
    int 21h

    ; white double step from (6,3) to (4,3)
    push 3
    push 4
    push 3
    push 6
    call execute_move

    ; test black pawn moves from (4,4)
    push 4
    push 4
    call get_legal_moves

    call print_moves

done:

    mov ax, 4C00h
    int 21h


clear_test_board PROC
    mov di, offset board
    mov cx, 64
    xor al, al

clear_board_loop:
    mov [di], al
    inc di
    loop clear_board_loop
    ret
clear_test_board ENDP


print_moves PROC
    mov cx, [move_count]
    mov si, offset move_list

print_loop:
    cmp cx, 0
    je print_done

    ; from_row
    mov dl, [si]
    add dl, '0'
    mov ah, 02h
    int 21h

    mov dl, ' '
    int 21h

    ; from_col
    mov dl, [si+1]
    add dl, '0'
    mov ah, 02h
    int 21h

    mov dl, ' '
    int 21h

    ; to_row
    mov dl, [si+2]
    add dl, '0'
    mov ah, 02h
    int 21h

    mov dl, ' '
    int 21h

    ; to_col
    mov dl, [si+3]
    add dl, '0'
    mov ah, 02h
    int 21h

    ; newline
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    add si, 4
    dec cx
    jmp print_loop

print_done:
    ret
print_moves ENDP

END start
