# Project Name
Chess

Topic: [R07](https://github.com/ukma-fin-csa-2026/projects/issues/38)

## Team

- Abdurakhimova Rinata — r.abdurakhimova@ukma.edu.ua
- Astrashenok Polina — p.astrashenok@ukma.edu.ua

## Project Objective

The objective of this project is to create a chess game in Assembly language for the DOS environment. The project includes displaying the chessboard in the text mode of video memory, allowing the user to make moves and verifying their correctness, as well as implementing gameplay against an artificial intelligence. 

## Implementation Plan

The work on the project is divided between Rinata and Polina into two main parts:

- **Student A (Polina)** — rendering and user interface
- **Student B (Rinata)** — game logic and artificial intelligence

To avoid incompatibilities between parts of the project, shared data structures, the board representation format, and procedure calling interfaces are defined at the beginning (`architecture.md` file).

### Student A - Polina (rendering and interface)

- Implementation of basic procedures for working with B800h video memory and setting up the video mode (B800h video memory)
- Creation of the start menu: mode selection and handling interactive selection zones (draw_status, handle_input)
- Chessboard rendering: displaying cells of different colors and outputting coordinates (draw_board)
- Drawing (rendering) pieces using pseudo-graphics instead of standard letters (draw_piece)
- Building the game interface: status panel with an avatar, name, turn indicator, and a list of captured pieces (draw_status)
- Navigating the board using arrow keys and the ability to click/press to select (draw_cursor, handle_input)
- Color highlighting of possible moves: green - free square, red - capture (highlight_moves)
- Move confirmation logic and creation of a piece selection menu for pawn promotion (handle_input, draw_status)
- Dynamic UI changes during Check: shifting the captured pieces block, "CHECK" text, and playing a sound (draw_status)
- Implementation of the final victory screen: repainting the board, audio, displaying a quote, and a "Quit" button (draw_status, handle_input)
- Main files: display.asm, input.asm

### Student B - Rinata (game logic)

- Designing the data structure to represent the board (implementation of the `board[64]` array)
- Initialization of the starting position (piece placement)
- Definition of bitwise piece encoding (bit 3 = color, bits 0-2 = type)
- Implementation of movement rules for each piece type (`get_legal_moves` procedure, generating possible moves)
- Board boundary checking (index control, preventing out-of-bounds array access)
- Clear path checking for sliding pieces (bishop, rook, queen)
- Implementation of move execution (`execute_move` procedure, updating `board`)
- Checking attacked squares (`is_square_attacked` procedure)
- Implementation of check detection (`is_in_check` procedure)
- Preventing moves that leave the king in check (move filtering)
- Checkmate detection (absence of legal moves during check)
- Stalemate detection (absence of legal moves without check)
- Pawn promotion logic (reaching the last rank, choosing a new piece)
- Implementation of basic artificial intelligence (`ai_turn` procedure, generating all moves)
- Move selection for AI (priority on capturing pieces, random selection)
- Turn queue management (changing sides after a move)
- Main files: game.asm, ai.asm.

### Shared (Architecture and Synchronization)

- main.asm file with initialization and the main game loop.
- shared.inc file with shared constants (in particular TYPE_MASK, COLOR_MASK).
- Shared data segment: 64-byte board array (board), counters, turn queue variable (current_turn), king positions (white_king_pos, black_king_pos), and move buffer (move_list for 256 bytes).
- Coordinated board representation: indexing by the formula index = row * 8 + col (white pieces are placed at the bottom, black pieces at the top).
- Single move saving format (4 bytes): from_row, from_col, to_row, to_col.
- Coordinated square encoding (1 byte): 0 = empty, bit 3 - color (0=white, 1=black), bits 0-2 - piece type (1=pawn, 2=knight, 3=bishop, 4=rook, 5=queen, 6=king).
- Architectural contract (API): parameters are passed to procedures via the stack, results are returned via AX or global buffers; UI never changes the board directly, logic never renders.

## Final Report 

### Student A's Contribution - Polina: architecture, interface, infrastructure, and UX

Polina's work in the project consisted of creating a graphical text interface, handling input for the main game loop, and providing the overall project infrastructure, including visuals and audio playback.

It was decided to write the graphics output directly to video memory (0B800h), rather than using BIOS interrupts for every character. Thanks to this, the screen updates instantly - without flickering when redrawing the board or moving the cursor. All pieces were meticulously drawn using custom 8-bit fonts (sprites.inc) loaded into VGA memory, giving the game a retro style.

For the backgrounds, a Python script (make_bg.py) was written, which converts images to the DOS 16-color palette using weighted RGB distance and generates .inc files with byte arrays. They are immediately included during TASM assembly. No delays on startup, smaller size.

Regarding user experience (UX) and atmosphere:
- Input (input.asm) - supports both keyboard (int 16h) and mouse (int 33h). This ensures convenience in the DOS environment.
- Timer for 1v1 - implemented via the BIOS system timer (int 1Ah); before the game, you can choose 3, 5, or 10 minutes.
- AI Quotes - the computer reacts to events: comments on a check, says something when you take a queen or a rook. Playing against the AI has become much more fun.
- Sound - written directly to the PC speaker ports. There is a move sound and a separate signal for check.

What else could be added?
- Move the game to graphical VGA mode 13h (320x200 pixels, 256 colors). We could then abandon pseudo-graphics (sprites.inc) in favor of proper pixel-art sprites and make the interface more modern.
- Add different audio tracks upon AI agent victory. 
- Move history panel, i.e., create a side window that would record all moves in real time. This would only require writing an algorithm to convert board coordinates to text.
- Ability to undo a move. This would require allocating a memory segment where the entire board array would be fully copied after each move. Pressing Ctrl+Z would trigger such a function.


### Student B's Contribution - Rinata: game logic and AI

Rinata's work in the project consisted of the game logic and artificial intelligence - the part that determines the correctness of moves, chooses the computer's move, and detects checkmate or stalemate.

For sliding pieces, I decided to use **Approach A**, resulting in a single shared loop for move generation. As a result, I could use one procedure `generate_sliding_moves` for the bishop, rook, and queen. And this turned out to be very convenient, because this loop is universal: when I needed to call the procedure for a rook or a bishop, I simply passed the corresponding piece movement table (rook_dirs or bishop_dirs) as a parameter via the stack, and for the queen, it was enough to call the procedure twice for both tables, because the queen is a combination of rook and bishop moves, so she doesn't need a separate direction table. In my opinion, this solution is more efficient and requires fewer instructions than Approach B.

For checking checks and attacked squares, I also decided to choose **Approach A**: checking if a specific square is attacked. I implemented the `is_square_attacked` procedure so that it could move from the selected square along all direction tables (for a pawn, we check if it attacks the square diagonally), and check if any enemy piece is attacking this square. For Approach B (checking if a piece is pinned), I would have needed to do preliminary calculations, so the first option seemed simpler to execute.

Before implementing my AI file, I thought that playing only against a basic level of artificial intelligence would not be very interesting, so I decided to make three difficulty levels, and thus managed to combine not one, but exactly three approaches in `ai.asm`:

- `easy` - AI chooses a random capture, and if there is none, makes a random legal move.
- `medium` - AI can make a material evaluation of the position and based on this makes the best move.
- `hard` - AI not only makes a material evaluation, but also knows how to play more carefully and smartly: a bonus is added to the overall move evaluation if the AI can deliver a check or defend its attacked piece; and conversely, receives penalties if it exposes its piece to an attack.

Thanks to this, I managed to create not only a basic level, but a truly worthy opponent for our future user.

I implemented all the recommended extensions for game logic and AI:
- en passant: capturing a pawn in passing after the opponent moves a pawn two squares forward, with tracking of the availability of this move in `en_passant_available`.
- castling: implemented short and long castling, checking that the king and the corresponding rook have not moved yet, there are no pieces between them, the king is not in check, and will not pass through attacked squares.
- Three AI levels (easy, medium, hard).

What I would really like to improve later:
- make the AI even smarter: add logic to analyze not only its move, but also the opponent's next move; 
- add special logic for openings and endgames;
- implement legal move hints for the player;
- add logic to check for threefold repetition of a position with an automatic declaration of a draw;
- implement move undo and redo.

### Integration of our work
The biggest challenge was probably combining the individual pieces of work we created over the week. Usually, our sequence of actions was as follows: Rinata worked on the game logic, tested the procedures in test.asm before integration to immediately see if there would be any errors; Polina added and improved our visuals so that the user would feel comfortable and interested in playing; and then we combined all this in main.asm. This was a truly valuable experience, and I'm sure it will help us in future projects!

# Result

As a result of the project, a program was created that implements a chess game in Assembly language with a text interface, basic chess logic, and a computer opponent.

# Memory Organization Scheme
We chose the .MODEL small memory model, so the program is divided into 64 KB segments. The scheme looks like this:

![Project Memory Organization Scheme](memory_diagrama.png)

- CS (code itself): here are all the compiled modules - main.obj, display.obj, game.obj, input.obj, ai.obj.
- DS (data): global variables and game state. Main ones:
    - board DB 64 DUP(?) - 8x8 chessboard 1D array, square - row * 8 + col
    - move_list DB 512 DUP(?) - all legal moves, 4 bytes per move (from_row, from_col, to_row, to_col)
    - ai_move_buffer DB 1024 DUP(?) - a separate buffer for AI calculations
    - direction tables (rook_dirs, bishop_dirs, knight_offsets, king_dirs)
    - bg_data DB 4000 DUP(0) - buffer for the background image (characters + color attributes)
- SS (stack): 4096 bytes allocated - for return addresses and local parameters. Piece coordinates are passed via bp in the logic module.
- ES (video memory): hardcoded to 0B800h. Written directly - without interrupts, the screen updates instantly.


## Project Structure

```text
project-assembly-divers/
├── src/
│   ├── main.asm         
│   ├── display.asm     
│   ├── game.asm        
│   ├── input.asm        
│   ├── ai.asm           
│   ├── shared.inc       
│   ├── sprites.inc     
│   ├── bg0.inc          
│   ├── bg1.inc          
│   ├── bg2.inc          
│   └── make_bg.py       
│        
├── .gitignore          
├── README.md
├── architecture.md
├── ASSESSMENT.md
├── checkpoints.md
├── memory_diagrama.png
└── video_presentation.txt
```

## Launch Instructions

### 1. Prepare DOSBox

- Windows:

1. Make sure you have DOSBox installed.

### 2. Mount the repository in DOSBox

1. Open the file `C:\DosBox\dosbox-csa.conf`.
2. Find the line:

```ini
mount d "C:\Users\YOUR_USERNAME\YOUR_REPO_FOLDER"
```

3. Replace it with the path to this repository:

```ini
mount d "C:\YOUR_FOLDER\REPO_FOLDER"
```

4. Save the file.

- macOS:

1. Make sure you have DOSBox installed.

### 2. Mount the repository in DOSBox

1. Open the file `~/DosBox/dosbox-csa.conf`.
2. Find the line:

```ini
mount d "~/YOUR_REPO_FOLDER"
```

3. Replace it with the path to this repository:

```ini
mount d "~/REPO_FOLDER"
```

4. Save the file.

> The path to the repository must not contain Cyrillic characters, otherwise DOSBox/TASM may not work correctly.

### 3. Run DOSBox

Run:

- Windows:

```bat
C:\DosBox\START-DOSBOX.bat
```

- macOS:

```zsh
zsh ~/DosBox/start-dosbox.sh
```

After launching, navigate to the source code folder:

```dos
d:
cd src
dir
```

### 4. Build and run the game

In `src` execute:

```dos
tasm /zi main.asm
tasm /zi display.asm
tasm /zi game.asm
tasm /zi ai.asm
tasm /zi input.asm
tlink /v main.obj display.obj game.obj ai.obj input.obj
main.exe
```
