DC-Welcome Server Logo
======================

Place your server logo here as: ServerLogo.tga or ServerLogo.blp

The logo appears in two places:
1. Title bar (36x36) - small icon next to "Welcome to DarkChaos-255!"
2. Community tab (200x200) - larger display

WoW 3.3.5a Texture Requirements:
--------------------------------
- Format: TGA (32-bit, uncompressed) or BLP
- Dimensions: Power of 2 (e.g., 256x256, 512x512)
- Recommended size: 256x256 (scales nicely to both 36x36 and 200x200)

Converting from PNG:
--------------------
1. Using GIMP:
   - Open your PNG file
   - Image > Canvas Size > Resize to power of 2 (256x256 recommended)
   - Export as: ServerLogo.tga
   - Options: Uncompressed, Origin: Bottom-left

2. Using BLP Converter (BLP Lab):
   - Open your PNG file  
   - Save as: ServerLogo.blp
   - This gives better compression

3. Using ImageMagick (command line):
   convert input.png -resize 256x256 -define tga:compression=none ServerLogo.tga

4. Using Paint.NET:
   - Open PNG, resize to 256x256
   - File > Save As > TGA File
   - Select 32-bit (RGBA)

Original Source:
----------------
C:\Users\flori\Desktop\BCO.3a2b76bc-8aee-469b-bd22-1127f80d5d64.png

After conversion, place the file here as ServerLogo.tga or ServerLogo.blp
If no file is present, the addon will simply not show a logo (no errors).
