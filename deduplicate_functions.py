#!/usr/bin/env python3
"""
Remove duplicate function definitions, keeping only the last occurrence.
"""

import sys
import re

def deduplicate_functions(file_path, output_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all top-level declarations (functions, variables, constants, exports)
    func_pattern = r'^func\s+(\w+)\s*\([^)]*\)\s*(?:->.*?)?:\s*$'
    var_pattern = r'^(?:var|const|@export var|@export)\s+(\w+)'

    lines = content.split('\n')
    declarations = {}  # name -> list of (start_line, end_line, type)

    current_decl = None
    current_start = None
    current_type = None

    for i, line in enumerate(lines):
        # Check if this is a function definition
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

        # Check if we're ending a declaration (dedent back to module level for funcs, or simple var end)
        elif current_decl:
            if current_type == 'var':
                # Variables are usually single-line, end immediately
                if current_decl not in declarations:
                    declarations[current_decl] = []
                declarations[current_decl].append((current_start, i, current_type))
                current_decl = None
            elif current_type == 'func' and line.strip() and not line.startswith('\t') and not line.startswith(' '):
                # This line is at module level, previous function ended
                if current_decl not in declarations:
                    declarations[current_decl] = []
                declarations[current_decl].append((current_start, i, current_type))
                current_decl = None

    # Don't forget last declaration
    if current_decl:
        if current_decl not in declarations:
            declarations[current_decl] = []
        declarations[current_decl].append((current_start, len(lines), current_type))

    # Find duplicates (declarations with multiple definitions)
    duplicates = {name: ranges for name, ranges in declarations.items() if len(ranges) > 1}

    if not duplicates:
        print("No duplicate declarations found!")
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return

    print(f"Found {len(duplicates)} duplicate declarations:")
    for name, ranges in duplicates.items():
        types = [r[2] for r in ranges]
        print(f"  {name} ({types[0]}): {len(ranges)} definitions at lines {[r[0]+1 for r in ranges]}")

    # Create line removal set (remove all but last occurrence)
    lines_to_remove = set()
    for name, ranges in duplicates.items():
        # Keep last occurrence, remove all others
        for start, end, decl_type in ranges[:-1]:
            for line_num in range(start, end):
                lines_to_remove.add(line_num)
        print(f"  Keeping {name} at line {ranges[-1][0]+1}, removing others")

    # Build output without removed lines
    output_lines = []
    for i, line in enumerate(lines):
        if i not in lines_to_remove:
            output_lines.append(line)

    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output_lines))

    print(f"\n✓ Deduplicated file saved to: {output_path}")
    print(f"  Removed {len(lines_to_remove)} lines")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python deduplicate_functions.py <input_file> <output_file>")
        print("\nExample:")
        print("  python deduplicate_functions.py scripts/GameController_RECOVERED.gd scripts/GameController_CLEAN.gd")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    deduplicate_functions(input_file, output_file)
