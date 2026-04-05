from PIL import Image, ImageOps

INPUT_FILE = "original_judy.jpg" 
OUTPUT_FILE = "bg.bin"

# Exact DOS palette (16 colors supported by text mode)
pal = [
    (0,0,0), (0,0,170), (0,170,0), (0,170,170),        # Black, Blue, Green, Cyan
    (170,0,0), (170,0,170), (170,85,0), (170,170,170), # Red, Magenta, Brown, Light Gray
    (85,85,85), (85,85,255), (85,255,85), (85,255,255),# Dark Gray, Light Blue, Light Green, Light Cyan
    (255,85,85), (255,85,255), (255,255,85), (255,255,255) # Light Red, Pink, Yellow, White
]

# Function that finds the closest matching color out of the 16 available
def get_nearest_color(rgb):
    # Get the red (r), green (g), and blue (b) channels of the current pixel
    r, g, b = rgb[:3]
    
    # Find the difference between the brightest and darkest channel of the pixel
    diff = max(r, g, b) - min(r, g, b)
    
   # If the difference is less than 25, the color is almost tintless (gray)
    if diff < 25: 
        # Prevent the script from making gray fur pink! Allow only these 4 colors:
        allowed_greys = [0, 7, 8, 15] # Black (0), Light Gray (7), Dark Gray (8), White (15)
        # Find the closest color ONLY among these grays and return its index
        return min(allowed_greys, key=lambda i: (r-pal[i][0])**2 + (g-pal[i][1])**2 + (b-pal[i][2])**2)

    # Variables for finding the best color (if it's not gray)
    best_i = 0
    min_dist = float('inf') # Initial "distance" is infinity
    
    # Iterate through all 16 colors in our DOS palette
    for i, (pr, pg, pb) in enumerate(pal):
        # Weighted distance: the human eye sees green better, blue worse.
        dist = (r-pr)**2 * 0.3 + (g-pg)**2 * 0.59 + (b-pb)**2 * 0.11
        
        # If the found color is closer (more similar) to the original than the previous one
        if dist < min_dist:
            min_dist = dist # Update the minimum distance
            best_i = i      # Remember the index of this color (from 0 to 15)
            
    # Return the index of the best found color
    return best_i

img = Image.open(INPUT_FILE).convert("RGB")
from PIL import ImageEnhance
img = ImageEnhance.Contrast(img).enhance(1.3)
img = img.resize((80, 50), Image.Resampling.LANCZOS)
pixels = img.load()
out_data = bytearray()

# Iterate through each of the 25 rows of the DOS text screen
for y in range(25):
    # Iterate through each of the 80 columns of the screen
    for x in range(80):
        # Get the DOS color for the TOP half of the cell
        top = get_nearest_color(pixels[x, y*2])
        
        # Get the DOS color for the BOTTOM half of the cell
        bot = get_nearest_color(pixels[x, y*2+1])
        
        # Write the character code 0xDF (this is the ▀ symbol - upper half-block)
        out_data.append(0xDF) 
        
        # Format the DOS color: shift the bottom color left and merge it with the top color
        # This is the standard attribute byte (Background | Text) in B800h video memory
        out_data.append((bot << 4) | top) 

# Open the bg.bin file for writing in binary mode ("wb")
with open(OUTPUT_FILE, "wb") as f: 
    f.write(out_data)

print("Done!")