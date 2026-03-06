# R07 – Chess (TASM / DOSBox)
## Architecture & Integration Contract

Цей документ фіксує архітектурні рішення для початку паралельної роботи
Студента A (UI) та Студента B (Game Logic).

---

# 1. Board Representation

Дошка зберігається як:

    board DB 64 DUP(?)

Індексація:

    index = row * 8 + col

де:
    row = 0..7 (0 = верхній ряд, 7 = нижній)
    col = 0..7 (0 = ліва колонка, 7 = права)

Відповідність індексів:

    board[0]  = a8
    board[7]  = h8
    board[56] = a1
    board[63] = h1

Білі фігури розташовані внизу (ряди 6–7),
чорні – вгорі (ряди 0–1).

---

# 2. Piece Encoding (1 byte per square)

Бітова структура:

    біт 0–2  : тип фігури
    біт 3    : колір (0 = white, 1 = black)

Типи:

    000 = empty
    001 = pawn
    010 = knight
    011 = bishop
    100 = rook
    101 = queen
    110 = king

Приклади:

    white pawn  = 0001b = 1
    black pawn  = 1001b = 9
    white king  = 0110b = 6
    black king  = 1110b = 14

Спільні константи (shared.inc):

    TYPE_MASK  EQU 00000111b
    COLOR_MASK EQU 00001000b

    WHITE      EQU 0
    BLACK      EQU 1

---

# 3. Global State

У game.asm:

    board           DB 64 DUP(?)
    current_turn    DB 0      ; 0=white, 1=black
    white_king_pos  DB ?
    black_king_pos  DB ?

Move buffer:

    move_list       DB 256 DUP(?) ; достатньо для max ходів

Формат одного ходу (4 байти):

    from_row
    from_col
    to_row
    to_col

---

# 4. Direction Tables

rook_dirs:
    DB  0,-1
    DB  0,1
    DB -1,0
    DB  1,0

bishop_dirs:
    DB -1,-1
    DB -1,1
    DB  1,-1
    DB  1,1

knight_offsets:
    DB -2,-1
    DB -2,1
    DB -1,-2
    DB -1,2
    DB  1,-2
    DB  1,2
    DB  2,-1
    DB  2,1

---

# 5. Module Responsibility

Student A:
    display.asm
    input.asm
    - draw_board
    - draw_piece
    - draw_cursor
    - highlight_moves
    - draw_status
    - keyboard handling
    - B800h video memory

Student B:
    game.asm
    ai.asm
    - get_legal_moves
    - execute_move
    - is_square_attacked
    - is_in_check
    - is_checkmate
    - ai_turn

---

# 6. File Structure

main.asm
display.asm
input.asm
game.asm
ai.asm
shared.inc

---

## display.asm

draw_board PROC
    ret
draw_board ENDP

draw_piece PROC
    ret
draw_piece ENDP

draw_cursor PROC
    ret
draw_cursor ENDP

highlight_moves PROC
    ret
highlight_moves ENDP

draw_status PROC
    ret
draw_status ENDP

---

## input.asm

handle_input PROC
    ret
handle_input ENDP

---

## game.asm

init_board PROC
    ret
init_board ENDP

get_legal_moves PROC
    push bp
    mov bp, sp
    xor ax, ax
    pop bp
    ret 2
get_legal_moves ENDP

execute_move PROC
    push bp
    mov bp, sp
    xor ax, ax
    pop bp
    ret 4
execute_move ENDP

is_square_attacked PROC
    push bp
    mov bp, sp
    xor ax, ax
    pop bp
    ret 4
is_square_attacked ENDP

is_in_check PROC
    push bp
    mov bp, sp
    xor ax, ax
    pop bp
    ret 2
is_in_check ENDP

---

## ai.asm

ai_turn PROC
    ret
ai_turn ENDP


