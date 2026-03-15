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
    push 1
    push 7
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