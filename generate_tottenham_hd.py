import urllib.request
from PIL import Image
import os

url = "https://upload.wikimedia.org/wikipedia/en/thumb/b/b4/Tottenham_Hotspur.svg/960px-Tottenham_Hotspur.svg.png"
print(f"Downloading {url}...")

req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response, open('spurs.png', 'wb') as out_file:
    out_file.write(response.read())

print("Processing image with Unicode half-blocks...")
img = Image.open('spurs.png').convert('RGBA')
orig_width, orig_height = img.size

# We want the output to be exactly 26 lines high to match the info boxes
target_char_height = 26
pixel_height = target_char_height * 2

# Crop the bottom 18% of the image which contains the text "TOTTENHAM HOTSPUR"
img = img.crop((0, 0, orig_width, int(orig_height * 0.82)))
orig_width, orig_height = img.size

# Calculate pixel width maintaining original aspect ratio
# Using half-blocks, each "pixel" is perfectly square in the terminal!
pixel_width = int(pixel_height * (orig_width / orig_height) * 1.05) # Add a tiny 5% stretch for aesthetics

img = img.resize((pixel_width, pixel_height), Image.Resampling.LANCZOS)

ascii_lines = []
for cy in range(target_char_height):
    line = ""
    for cx in range(pixel_width):
        # Get upper pixel
        y_up = cy * 2
        r_u, g_u, b_u, a_u = img.getpixel((cx, y_up))
        # Get lower pixel
        y_dn = cy * 2 + 1
        r_d, g_d, b_d, a_d = img.getpixel((cx, y_dn))
        
        up_filled = a_u > 127
        dn_filled = a_d > 127
        
        if up_filled and dn_filled:
            line += "█"
        elif up_filled and not dn_filled:
            line += "▀"
        elif not up_filled and dn_filled:
            line += "▄"
        else:
            line += " "
            
    ascii_lines.append(line.rstrip())

with open('/home/koh/dotfiles/logo.txt', 'w') as f:
    f.write('\n'.join(ascii_lines) + '\n')

print("Successfully generated ultra-high-res ASCII logo!")
for line in ascii_lines:
    print(line)
