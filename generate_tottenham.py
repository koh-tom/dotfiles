import urllib.request
from PIL import Image
import os

def download_and_convert_logo(url, target_height=26, char_aspect=2.0):
    # Download the logo
    print(f"Downloading from {url}...")
    temp_img_path = "spurs_logo.png"
    
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response, open(temp_img_path, 'wb') as out_file:
        out_file.write(response.read())
        
    print("Download completed. Converting to ASCII art...")
    
    # Open image
    img = Image.open(temp_img_path)
    
    # Extract alpha channel to use as a mask
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
        
    # Get transparency mask or calculate brightness
    width, height = img.size
    
    # Calculate target width
    aspect_ratio = width / height
    target_width = int(target_height * aspect_ratio * char_aspect)
    
    # Resize image
    img_resized = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
    
    # ASCII characters from high density to empty
    # We use a custom, sharp set of characters
    ascii_chars = "$@B%8&WM#*oahkbdpqzoQLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. "
    num_chars = len(ascii_chars)
    
    ascii_art_lines = []
    
    for y in range(target_height):
        line = ""
        for x in range(target_width):
            r, g, b, a = img_resized.getpixel((x, y))
            
            # Since the Tottenham logo is navy blue on transparent background,
            # we want the transparent parts (a < 50) to be completely empty.
            # And we want the navy blue parts to have solid/semi-solid characters.
            if a < 50:
                line += " "
            else:
                # Inside the logo shape, map the brightness to ASCII
                # Since the logo is dark blue, we can invert the mapping so dark colors look solid
                brightness = int(0.299 * r + 0.587 * g + 0.114 * b)
                # Invert: dark is solid, light is empty
                char_idx = int((brightness / 255.0) * (num_chars - 1))
                # Alternatively, just use solid blocks or high-density characters
                # To make it look extremely clean, let's use a solid-to-gradient character mapping
                line += ascii_chars[char_idx]
        
        # Trim trailing whitespace to keep the output file clean
        ascii_art_lines.append(line.rstrip())
        
    # Remove temp image
    if os.path.exists(temp_img_path):
        os.remove(temp_img_path)
        
    return ascii_art_lines

# The image should be already downloaded as 'spurs_logo.png'
try:
    # Generate a version with height 26 lines
    # We define a wrapper that just skips download
    def convert_local_logo(img_path, target_height=26, char_aspect=2.1):
        print("Converting local image to ASCII art...")
        img = Image.open(img_path)
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        width, height = img.size
        aspect_ratio = width / height
        target_width = int(target_height * aspect_ratio * char_aspect)
        img_resized = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
        ascii_chars = "$@B%8&WM#*oahkbdpqzoQLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. "
        num_chars = len(ascii_chars)
        ascii_art_lines = []
        for y in range(target_height):
            line = ""
            for x in range(target_width):
                r, g, b, a = img_resized.getpixel((x, y))
                if a < 50:
                    line += " "
                else:
                    brightness = int(0.299 * r + 0.587 * g + 0.114 * b)
                    char_idx = int((brightness / 255.0) * (num_chars - 1))
                    line += ascii_chars[char_idx]
            ascii_art_lines.append(line.rstrip())
        return ascii_art_lines

    lines = convert_local_logo("spurs_logo.png", target_height=26, char_aspect=2.1)
    
    output_path = "/home/koh/dotfiles/logo.txt"
    with open(output_path, "w") as f:
        f.write("\n".join(lines) + "\n")
        
    print(f"ASCII art successfully written to {output_path}!")
    print(f"Dimensions: {len(lines)} lines high, {max(len(l) for l in lines)} columns wide.")
    
    # Print preview
    print("\nPreview:")
    for line in lines:
        print(line)
        
except Exception as e:
    print(f"Error occurred: {e}")
