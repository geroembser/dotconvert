import http.client
import mimetypes
import sys
import json
import os
from urllib.parse import urlencode

def transcribe_audio(input_path, output_path):
    # Set your OpenAI API key
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        print("API key not found. Please set it as an environment variable OPENAI_API_KEY.")
        return

    # Define the endpoint and host
    host = "api.openai.com"
    endpoint = "/v1/audio/transcriptions"

    # Prepare the file data for the request
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": f"multipart/form-data; boundary={boundary}"
    }

    # Read the MP3 file data
    with open(input_path, "rb") as audio_file:
        audio_data = audio_file.read()

    # make sure that input file name has mp3 extension
    if not input_path.endswith('.mp3'):
        # replace an existing extension with mp3 (or add it if there is none)
        input_path = os.path.splitext(input_path)[0] + '.mp3'

    # Construct the multipart body
    body = (
        f"--{boundary}\r\n"
        f"Content-Disposition: form-data; name=\"model\"\r\n\r\n"
        f"whisper-1\r\n"
        f"--{boundary}\r\n"
        f"Content-Disposition: form-data; name=\"file\"; filename=\"{input_path}\"\r\n"
        f"Content-Type: audio/mpeg\r\n\r\n"
    ).encode() + audio_data + f"\r\n--{boundary}--\r\n".encode()

    # Create an HTTP connection and make the request
    conn = http.client.HTTPSConnection(host)
    conn.request("POST", endpoint, body=body, headers=headers)
    response = conn.getresponse()
    response_data = response.read()
    conn.close()

    # Check if the request was successful
    if response.status == 200:
        # Parse and write the response text to the output file
        response_json = json.loads(response_data.decode())
        transcription = response_json.get("text", "")
        with open(output_path, 'w') as output_file:
            output_file.write(transcription)
        print(f"Transcription completed. Output saved to {output_path}")
    else:
        print(f"Failed to transcribe audio. Error: {response.status} - {response_data.decode()}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python transcribe.py <input_mp3_path> <output_txt_path>")
    else:
        input_mp3_path = sys.argv[1]
        output_txt_path = sys.argv[2]
        transcribe_audio(input_mp3_path, output_txt_path)
