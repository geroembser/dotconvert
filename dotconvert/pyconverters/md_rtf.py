import re
import os
import sys

def markdown_to_rtf(text):
    # Replace headers with different font sizes
    text = re.sub(r'^(#{6}) (.*)', r'\\b\\fs24 \2\\par ', text, flags=re.MULTILINE)
    text = re.sub(r'^(#{5}) (.*)', r'\\b\\fs28 \2\\par ', text, flags=re.MULTILINE)
    text = re.sub(r'^(#{4}) (.*)', r'\\b\\fs32 \2\\par ', text, flags=re.MULTILINE)
    text = re.sub(r'^(#{3}) (.*)', r'\\b\\fs36 \2\\par ', text, flags=re.MULTILINE)
    text = re.sub(r'^(#{2}) (.*)', r'\\b\\fs40 \2\\par ', text, flags=re.MULTILINE)
    text = re.sub(r'^(#{1}) (.*)', r'\\b\\fs44 \2\\par ', text, flags=re.MULTILINE)

    # Replace bold text **text** or __text__
    text = re.sub(r'\*\*(.*?)\*\*', r'\\b \1\\b0 ', text)
    text = re.sub(r'__(.*?)__', r'\\b \1\\b0 ', text)

    # Replace italic text *text* or _text_
    text = re.sub(r'\*(.*?)\*', r'\\i \1\\i0 ', text)
    text = re.sub(r'_(.*?)_', r'\\i \1\\i0 ', text)

    # Replace unordered lists
    text = re.sub(r'^\* (.*)', r'• \1\\par ', text, flags=re.MULTILINE)
    text = re.sub(r'^- (.*)', r'• \1\\par ', text, flags=re.MULTILINE)

    # Replace ordered lists
    text = re.sub(r'^\d+\. (.*)', r'\\tab \1\\par ', text, flags=re.MULTILINE)

    # Convert new lines to RTF paragraph breaks
    text = text.replace('\n', '\\par ')

    # Wrap with RTF header and footer
    rtf_text = r"{\rtf1\ansi " + text + "}"

    return rtf_text

def convert_markdown_file_to_rtf(input_file, output_file):
    # Read the Markdown file content
    with open(input_file, 'r', encoding='utf-8') as f:
        markdown_content = f.read()

    # Convert Markdown to RTF format
    rtf_content = markdown_to_rtf(markdown_content)

    # Write the RTF content to the output file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(rtf_content)

    print(f"Conversion complete. The RTF file is saved as: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_markdown_file> <output_rtf_file>")
    else:
        input_file = sys.argv[1]
        output_file = sys.argv[2]
        convert_markdown_file_to_rtf(input_file, output_file)
