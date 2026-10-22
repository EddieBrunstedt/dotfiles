function yt
    if test (count $argv) -lt 2
        echo "Usage: yt <url> <cookie_file>"
        echo "Error: both URL and cookie file path are required."
        return 1
    end

    set -l url $argv[1]
    set -l cookie_file $argv[2]
    set -l output "%(upload_date)s-%(uploader)s-%(title)s-[%(id)s].%(ext)s"

    yt-dlp --cookies "$cookie_file" --restrict-filenames -f "bv*+ba/b" --merge-output-format mkv \
        --embed-metadata --embed-chapters --embed-thumbnail --convert-thumbnails jpg \
        -o "$output" "$url"
end
