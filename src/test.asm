.MODEL small
.STACK 256

INCLUDE shared.inc

.DATA
EXTRN board:BYTE
EXTRN move_list:BYTE
EXTRN move_count:WORD

.CODE

EXTRN init_board:PROC
EXTRN get_legal_moves:PROC

start:

    mov ax, @data
    mov ds, ax

    ; initialize chess position
    call init_board

    ; test knight at (7,1)
    ; push 1
    ; push 7

    ; clear board
    mov di, offset board
    mov cx, 64
    xor al, al

clear_board:
    mov [di], al
    inc di
    loop clear_board

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

    ; test queen sliding moves from (4,3)
    push 3
    push 4
    call get_legal_moves

    mov cx, [move_count]
    mov si, offset move_list

print_loop:

    cmp cx, 0
    je done

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

done:

    mov ax, 4C00h
    int 21h

END start
