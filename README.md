
> People still have not recognized all areas that were affected by AI. Have you ever encountered Apple's HEIC format after an Airdrop to your Mac? Such an amazing format! Probably one of the most common ChatGPT questions is "How do I convert HEIC to JPG?"
>
>So file conversion is a pretty underrated area, not yet enough affected by UX-innovation (AI?)...
>

... and Apple's Finder's file extension renaming mechanism a pretty underrated feature 

Thinking all day about our red dot (not yet award winning) startup "Sophia Edu Labs", we also encountered file conversions everyday. (rant: Why is it not possible to properly insert a multi-page [or even single-page] PDF into Apple Freeform? That would be helpful if you use it for online tutoring...)

Okay, file conversion is a difficult topic, but it shouldn't be that hard for most users and uses cases (from a UX perspective)....

**That's why you can now just change a file's extension in your finder and the conversion is automatically done!**

## Current Features
- Write custom converters using python (documentation follows)
- Convert by changing the file extension in Finder

## Current Formats
- [x] .heic -> .jpg
- [x] .jpg -> png
- [x] .mp3 -> .ogg
- [x] .mp3 -> .m4a
- [x] .mp3 -> .txt (with AI, add your open ai key – documentation follows)
- [x] .ogg -> .mp3
- [x] .m4a -> .mp3

## Thoughts/ToDos
- [ ] better UI...
- [ ] ImageMagick (for advanced image conversions... You can manually build it using python for now...)
- [ ] More stuff from ffmpeg (btw. ffmpeg is currently included in the binary)
- [ ] Support entire folders (think about .pdf -> .png as a folder full of pngs of the pdf pages)
- [ ] Undo button (to undo a conversion – right now the original file will remain in your Trash)
- [ ] Error handling (file conversion is not always successful, and right now this isn't handled very well [or at all?])
- [ ] ?? not sure: Some kind of opening prevention mechanism (for longer conversions, to make sure that the user recognizes that the conversion is running)
- [ ] More Magic AI Conversions (like the current .mp3 -> .txt example)
      Some Ideas:
        - .sh -> .py (just because python is cool and that conversion is cool)
        - .py -> .hs (haskell...)
        - .xlsx -> .csv (for data analysis)
        - .xlsx -> .pptx (for presentations, and just because Excel is great!)
        - .csv -> .xlsx (because Excel hates utf-8 csv files!!!)
- [ ] Magic conversions by renaming the file from "FILENAME.pdf" to "FILENAME_redacted.pdf" (to clean metadata, for example)
- [ ] Much more file types...

## Cool available domains...
- rename.sh