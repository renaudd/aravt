from PIL import Image
import sys
import os

def remove_white_background(input_path, output_path):
    print(f"Processing {input_path}...")
    img = Image.open(input_path)
    img = img.convert("RGBA")
    
    datas = img.getdata()
    
    new_data = []
    # Threshold for what we consider "white"
    threshold = 240
    
    for item in datas:
        # If pixel is very bright (near white), make it transparent
        if item[0] > threshold and item[1] > threshold and item[2] > threshold:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Saved to {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 remove_background.py <file1> <file2> ...")
        sys.exit(1)
        
    for file_path in sys.argv[1:]:
        if os.path.exists(file_path):
            remove_white_background(file_path, file_path)
        else:
            print(f"File not found: {file_path}")
