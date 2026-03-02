#!/usr/bin/env fish

function create_llm_markdown
    set -l output_file "/tmp/llm_code_output.md"
    set -l max_file_size 1048576  # 1MB limit per file
    set -l excluded_extensions ".jpg" ".jpeg" ".png" ".gif" ".bmp" ".svg" ".ico" ".pdf" ".zip" ".tar" ".gz" ".exe" ".bin" ".so" ".dylib" ".dll" ".pyc" ".pyo" ".class" ".jar" ".war" ".ear" ".rar" ".7z"
    set -l excluded_dirs "node_modules" ".git" "__pycache__" ".venv" "venv" "env" ".env" "dist" "build" ".next" ".nuxt" "target" "vendor"

    # Clear the output file
    echo -n "" > "$output_file" # Use -n to avoid extra newline if echo adds one by default

    set -l files_to_process # Initialize an empty list

    # Check if we're in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1
        echo "## File Structure (Git Repository)" >> "$output_file"
        echo "" >> "$output_file"
        echo '```' >> "$output_file"
        git ls-files >> "$output_file"
        echo '```' >> "$output_file"
        echo "" >> "$output_file"

        # Get files for processing directly
        set files_to_process (git ls-files)
    else
        # Use find for non-git directories
        set -l find_cmd_list find . -type f # Start building the find command as a list

        # Exclude common directories
        for dir in $excluded_dirs
            # Add exclusion for the directory itself and its contents
            set -a find_cmd_list -not \( -path "./$dir" -o -path "./$dir/*" \)
        end

        echo "## File Structure (Non-Git Directory)" >> "$output_file"
        echo "" >> "$output_file"
        echo '```' >> "$output_file"
        command $find_cmd_list >> "$output_file" # Execute the find command
        echo '```' >> "$output_file"
        echo "" >> "$output_file"

        # Get files for processing directly
        set files_to_process (command $find_cmd_list) # Execute the find command again for the list
    end

    if test (count $files_to_process) -eq 0
        echo "No files found to process." >> "$output_file"
        echo "No files found to process." # Also to stdout
        # No need to clean up /tmp/file_list.txt as it's not used for this list
        # Continue to clipboard copy for the file structure part
    else
        echo "## File Contents" >> "$output_file"
        echo "" >> "$output_file"
    end

    set -l processed_count 0

    for file_path in $files_to_process
        # Ensure file paths from find (like "./foo.txt") are handled cleanly
        set -l current_file (string trim -- $file_path)

        # Skip if file doesn't exist (broken symlinks, etc.) or is not a regular file
        if not test -f "$current_file"
            # echo "Skipping (not a regular file): $current_file" # Optional debug
            continue
        end

        # Get file extension
        set -l extension (path extension "$current_file") # Fish has a builtin for this

        # Skip binary/image files
        set -l skip_file false
        for ext_to_skip in $excluded_extensions
            if test "$extension" = "$ext_to_skip"
                set skip_file true
                break
            end
        end

        if test "$skip_file" = "true"
            # echo "Skipping (excluded extension $extension): $current_file" # Optional debug
            continue
        end

        # Skip files that are too large
        # Use `stat -c %s` for Linux, `stat -f %z` for macOS
        set -l file_size 0
        if command -s gstat > /dev/null # GNU stat often available as gstat on macOS
            set file_size (gstat -c%s "$current_file" 2>/dev/null)
        else if type "stat" > /dev/null && stat --version 2>/dev/null | grep -q "GNU coreutils" # Linux stat
             set file_size (stat -c%s "$current_file" 2>/dev/null)
        else # macOS/BSD stat
             set file_size (stat -f%z "$current_file" 2>/dev/null)
        end
        
        # Fallback if size couldn't be determined or error occurred
        if not test "$file_size" -gt 0
            set file_size 0 # Or handle as an error/skip
        end
        
        if test "$file_size" -gt "$max_file_size"
            echo "### $current_file" >> "$output_file"
            echo "" >> "$output_file"
            echo "*File too large ($(math --scale=2 $file_size / 1024)KB), skipped*" >> "$output_file"
            echo "" >> "$output_file"
            continue
        end

        # Process the file
        echo "### $current_file" >> "$output_file"
        echo "" >> "$output_file"
        echo '```' >> "$output_file" # Consider adding language hint if possible, e.g., ```fish
        # To prevent issues with files ending without a newline, or empty files.
        # `cat` is fine, but ensure output ends with a newline for markdown block.
        if test -s "$current_file" # Check if file is not empty
            cat "$current_file" >> "$output_file"
            # Ensure the content block is followed by a newline before the closing ```
            # This is important if the file itself doesn't end with a newline.
            echo "" >> "$output_file" 
        else
            echo "" >> "$output_file" # Empty content for empty file
        end
        echo '```' >> "$output_file"
        echo "" >> "$output_file"

        set processed_count (math $processed_count + 1)
    end

    echo "Processed $processed_count files." # To stdout

    # Clean up temp file (not used for $files_to_process anymore, so can remove this line if desired)
    # rm -f /tmp/file_list.txt # This file is only used for file structure if not in git.

    # Copy to clipboard
    if command -v pbcopy >/dev/null 2>&1
        cat "$output_file" | pbcopy
        echo "✅ Content copied to clipboard (macOS)"
    else if command -v xclip >/dev/null 2>&1
        cat "$output_file" | xclip -selection clipboard
        echo "✅ Content copied to clipboard (Linux - xclip)"
    else if command -v wl-copy >/dev/null 2>&1
        cat "$output_file" | wl-copy
        echo "✅ Content copied to clipboard (Linux - Wayland)"
    else
        echo "⚠️  Clipboard tool not found. Content saved to: $output_file"
        echo "Please install pbcopy (macOS), xclip, or wl-clipboard (Linux) for clipboard functionality."
    end
end

# Run the function
create_llm_markdown