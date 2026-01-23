#!/usr/bin/env python3
"""
Apply file edit history from Claude Code jsonl transcript.
Reconstructs exact file state from Edit tool calls.
"""

import json
import sys
import os
import shutil
import re

def find_git_checkout_line(jsonl_path, target_file):
    """Find the line where git checkout destroyed the file"""
    print(f"Searching for git checkout disaster...")

    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            try:
                obj = json.loads(line)
                # Look for Bash tool calls with git checkout
                if obj.get('type') == 'assistant':
                    message = obj.get('message', {})
                    content = message.get('content', [])

                    for item in content:
                        if item.get('type') == 'tool_use' and item.get('name') == 'Bash':
                            params = item.get('input', {})
                            command = params.get('command', '')

                            # Found the destructive checkout
                            if 'git checkout --' in command and target_file in command:
                                print(f"Found git checkout at line {line_num}")
                                return line_num
            except json.JSONDecodeError:
                continue

    print("No git checkout found (good!)")
    return None

def extract_file_history(jsonl_path, target_file, cutoff_line=None):
    """Extract all Edit tool calls for a specific file in chronological order"""
    edits = []

    print(f"Scanning {jsonl_path}...")
    print(f"Looking for edits to: {target_file}\n")

    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            # Stop at cutoff if specified
            if cutoff_line and line_num >= cutoff_line:
                print(f"Stopped at line {cutoff_line} (git checkout)")
                break

            try:
                obj = json.loads(line)
                # Look for assistant messages with tool calls
                if obj.get('type') == 'assistant':
                    message = obj.get('message', {})
                    content = message.get('content', [])

                    for item in content:
                        if item.get('type') == 'tool_use' and item.get('name') == 'Edit':
                            params = item.get('input', {})
                            file_path = params.get('file_path', '')

                            # Check if this edit is for our target file
                            if target_file in file_path:
                                edits.append({
                                    'line': line_num,
                                    'file_path': file_path,
                                    'old_string': params.get('old_string', ''),
                                    'new_string': params.get('new_string', ''),
                                    'replace_all': params.get('replace_all', False)
                                })
            except json.JSONDecodeError:
                continue

    return edits

def find_all_file_reads(jsonl_path, target_file):
    """Find ALL Read tool results with file contents (we want the last one)"""
    print(f"Searching for file reads of {target_file}...")

    all_reads = []

    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            try:
                obj = json.loads(line)
                # Look for user messages with tool results (Read tool)
                if obj.get('type') == 'user':
                    message = obj.get('message', {})
                    content = message.get('content', [])

                    for item in content:
                        if item.get('type') == 'tool_result':
                            # Check if this is a Read result for our file
                            result_content = item.get('content', '')
                            if isinstance(result_content, str) and target_file in str(item):
                                # This might be our file - check if it has actual code
                                if 'func ' in result_content and '→' in result_content:
                                    # Parse the numbered lines format (cat -n output)
                                    lines = result_content.split('\n')
                                    file_lines = []
                                    for line in lines:
                                        # Format: "   123→code here"
                                        if '→' in line:
                                            code = line.split('→', 1)[1] if '→' in line else line
                                            file_lines.append(code)
                                    file_content = '\n'.join(file_lines)
                                    all_reads.append({
                                        'line': line_num,
                                        'content': file_content,
                                        'size': len(file_content)
                                    })
            except (json.JSONDecodeError, AttributeError):
                continue

    return all_reads

def deduplicate_content(content):
    """Remove duplicate function/variable declarations, keeping last occurrence"""
    func_pattern = r'^func\s+(\w+)\s*\([^)]*\)\s*(?:->.*?)?:\s*$'
    var_pattern = r'^(?:var|const|@export var|@export)\s+(\w+)'

    lines = content.split('\n')
    declarations = {}  # name -> list of (start_line, end_line, type)

    current_decl = None
    current_start = None
    current_type = None

    for i, line in enumerate(lines):
        func_match = re.match(func_pattern, line)
        var_match = re.match(var_pattern, line)

        if func_match or var_match:
            # Save previous declaration if any
            if current_decl:
                if current_decl not in declarations:
                    declarations[current_decl] = []
                declarations[current_decl].append((current_start, i, current_type))

            # Start new declaration
            if func_match:
                current_decl = func_match.group(1)
                current_start = i
                current_type = 'func'
            else:
                current_decl = var_match.group(1)
                current_start = i
                current_type = 'var'

        elif current_decl:
            if current_type == 'var':
                if current_decl not in declarations:
                    declarations[current_decl] = []
                declarations[current_decl].append((current_start, i, current_type))
                current_decl = None
            elif current_type == 'func' and line.strip() and not line.startswith('\t') and not line.startswith(' '):
                if current_decl not in declarations:
                    declarations[current_decl] = []
                declarations[current_decl].append((current_start, i, current_type))
                current_decl = None

    # Don't forget last declaration
    if current_decl:
        if current_decl not in declarations:
            declarations[current_decl] = []
        declarations[current_decl].append((current_start, len(lines), current_type))

    # Find duplicates
    duplicates = {name: ranges for name, ranges in declarations.items() if len(ranges) > 1}

    if not duplicates:
        return content, 0

    # Remove all but last occurrence
    lines_to_remove = set()
    for name, ranges in duplicates.items():
        for start, end, decl_type in ranges[:-1]:
            for line_num in range(start, end):
                lines_to_remove.add(line_num)

    # Build output without removed lines
    output_lines = [line for i, line in enumerate(lines) if i not in lines_to_remove]

    return '\n'.join(output_lines), len(duplicates)

def apply_edit(content, old_string, new_string, replace_all):
    """Apply a single edit to content. Returns (new_content, success)"""
    if replace_all:
        return content.replace(old_string, new_string), True
    else:
        # Single replacement
        if old_string in content:
            return content.replace(old_string, new_string, 1), True
        else:
            # Old string not found - this edit might have failed or been on different state
            print(f"  WARNING: old_string not found in current content")
            return content, False

def apply_edits(original_content, edits, output_file):
    """Apply all edits in sequence to reconstruct the file"""
    content = original_content
    failed_edits = []
    failed_new_strings = []

    print(f"\nApplying {len(edits)} edits...")

    for i, edit in enumerate(edits, 1):
        old_len = len(content)
        content, success = apply_edit(content, edit['old_string'], edit['new_string'], edit['replace_all'])
        new_len = len(content)

        if not success:
            print(f"  Edit {i}: FAILED (old_string not found)")
            failed_edits.append(i)
            failed_new_strings.append({
                'edit_num': i,
                'old_string': edit['old_string'],
                'new_string': edit['new_string']
            })
        else:
            print(f"  Edit {i}: OK ({old_len} -> {new_len} chars)")

        # Deduplicate every 5 edits to prevent duplicate buildup
        if i % 5 == 0:
            content, dup_count = deduplicate_content(content)
            if dup_count > 0:
                print(f"    -> Removed {dup_count} duplicates")

    # Final deduplication pass
    print("\nFinal deduplication...")
    content, final_dup_count = deduplicate_content(content)
    if final_dup_count > 0:
        print(f"  -> Removed {final_dup_count} final duplicates")
    else:
        print(f"  -> No duplicates found")

    # Append failed edits as comments at the end
    if failed_new_strings:
        content += "\n\n" + "="*80 + "\n"
        content += "# FAILED EDITS - These edits could not be applied because old_string was not found\n"
        content += "# Review these to see if any important code is missing\n"
        content += "="*80 + "\n\n"

        for failed in failed_new_strings:
            content += f"\n# ========== FAILED EDIT #{failed['edit_num']} ==========\n"
            content += "# OLD_STRING (not found in file):\n"
            for line in failed['old_string'].split('\n'):
                content += f"# OLD: {line}\n"
            content += "#\n# NEW_STRING (what it wanted to replace with):\n"
            for line in failed['new_string'].split('\n'):
                content += f"# NEW: {line}\n"

    # Write reconstructed file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)

    return failed_edits

def main():
    if len(sys.argv) < 3:
        print("Usage: python extract_file_history.py <source_file> <target_file> [search_filename] [jsonl_path]")
        print("\nExample:")
        print("  python extract_file_history.py scripts/rendering/GridRenderer.gd scripts/rendering/GridRenderer_RECOVERED.gd")
        print("  python extract_file_history.py scripts/GameController_FROM_GIT.gd scripts/GameController_RECOVERED.gd GameController.gd")
        print("\nThis will:")
        print("  1. Read source_file as the starting content")
        print("  2. Search jsonl for Edit tool calls matching search_filename (or source_file basename)")
        print("  3. Apply all Edit tool calls in chronological order")
        print("  4. Save the reconstructed file to target_file")
        sys.exit(1)

    source_file = sys.argv[1]
    target_file = sys.argv[2]

    # Extract just the filename for searching - can be overridden
    if len(sys.argv) >= 4 and not sys.argv[3].endswith('.jsonl'):
        filename = sys.argv[3]
        jsonl_arg_index = 4
    else:
        filename = os.path.basename(source_file)
        jsonl_arg_index = 3

    # Default jsonl path
    if len(sys.argv) > jsonl_arg_index:
        jsonl_path = sys.argv[jsonl_arg_index]
    else:
        jsonl_path = r"C:\Users\Matthew\.claude\projects\c--Dev-Minesweeper\a6639ef8-b972-480a-a0d7-b50ea80a5eac.jsonl"

    if not os.path.exists(jsonl_path):
        print(f"ERROR: jsonl file not found: {jsonl_path}")
        sys.exit(1)

    # Read the source file directly
    if not os.path.exists(source_file):
        print(f"ERROR: source file not found: {source_file}")
        sys.exit(1)

    print(f"Reading source file: {source_file}")
    with open(source_file, 'r', encoding='utf-8') as f:
        original = f.read()
    print(f"Loaded {len(original)} chars from source file\n")

    # Find where git checkout happened (if at all)
    cutoff_line = find_git_checkout_line(jsonl_path, filename)
    if cutoff_line:
        print(f"Will only apply edits BEFORE line {cutoff_line}\n")

    # Extract edit history up to the cutoff
    edits = extract_file_history(jsonl_path, filename, cutoff_line)

    if not edits:
        print(f"No edits found for '{filename}'")
        print(f"Saving original to {target_file}")
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(original)
        sys.exit(0)

    print(f"Found {len(edits)} edits for {filename}\n")

    # Apply all edits
    failed = apply_edits(original, edits, target_file)

    print(f"\n[OK] Reconstructed file saved to: {target_file}")
    if failed:
        print(f"\n[WARNING] {len(failed)} edits failed to apply: {failed}")
        print(f"The file may be incomplete - review carefully")
    else:
        print(f"[OK] All edits applied successfully!")

if __name__ == "__main__":
    main()
