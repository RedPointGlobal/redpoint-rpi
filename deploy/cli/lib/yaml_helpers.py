#!/usr/bin/env python3
"""
YAML list manipulation helpers for the Interaction CLI.

Usage:
  python3 lib/yaml_helpers.py <command> <file> [args...]

Commands:
  append_to_list <file> <marker> <entry>
      Append an entry after the last item in a YAML list identified by <marker>.
      Example: append_to_list overrides.yaml "servers:" "    - name: foo"

  create_section <file> <parent> <content>
      Insert <content> at the end of an existing <parent> block.
      Example: create_section overrides.yaml "storage:" "  persistentVolumes:\n..."

  insert_in_nested <file> <class_name> <sub_key> <entry>
      Find a named list item (- name: <class_name>), locate <sub_key> within it,
      and append <entry> after the last child of that sub_key.

  extract_names <file> <pattern>
      Print all values matching '- <pattern>: <value>' lines.
"""
import sys, re


def append_to_list(filepath, marker, entry):
    """Find marker line, scan to end of indented block, insert entry."""
    lines = open(filepath).readlines()
    in_block = False
    last_entry = -1
    for i, l in enumerate(lines):
        if marker in l and not l.strip().startswith('#'):
            in_block = True
            continue
        if in_block:
            stripped = l.rstrip()
            if not stripped:
                # peek ahead — if next non-blank line is still indented, keep going
                still_in = False
                for j in range(i + 1, len(lines)):
                    nxt = lines[j].rstrip()
                    if nxt:
                        if nxt[0] == ' ':
                            still_in = True
                        break
                if not still_in:
                    break
                continue
            if not stripped[0] == ' ':
                break
            indent = len(l) - len(l.lstrip())
            if indent <= 2 and ':' in stripped and not stripped.startswith('#'):
                break
            last_entry = i

    insert_at = last_entry + 1 if last_entry >= 0 else len(lines)
    text = entry if entry.endswith('\n') else entry + '\n'
    lines.insert(insert_at, text)
    open(filepath, 'w').writelines(lines)


def create_section(filepath, parent, content):
    """Insert content at the end of an existing parent block."""
    lines = open(filepath).readlines()
    idx = -1
    for i, l in enumerate(lines):
        if l.startswith(parent):
            idx = i
            break
    if idx < 0:
        sys.exit(1)
    # Find last indented line belonging to parent, buffering trailing
    # blank/comment lines so we insert before the next section's heading.
    end = idx + 1
    for j in range(idx + 1, len(lines)):
        stripped = lines[j].rstrip()
        if not stripped:
            continue  # blank — skip, don't advance end
        if stripped[0] == ' ':
            end = j + 1  # indented content belongs to parent
        elif stripped[0] == '#' and lines[j][0] == '#':
            break  # unindented comment = next section heading
        else:
            break  # next top-level key
    text = content if content.endswith('\n') else content + '\n'
    lines.insert(end, text)
    open(filepath, 'w').writelines(lines)


def insert_in_nested(filepath, class_name, sub_key, entry):
    """State-machine insert into a named list item's sub-key."""
    lines = open(filepath).readlines()
    in_target = False
    in_sub = False
    insert_at = -1
    sub_indent = 0  # indent level of the sub_key line

    for i, l in enumerate(lines):
        stripped = l.strip()
        if ('- name: ' + class_name in l
                or '- name: "' + class_name + '"' in l):
            in_target = True
            continue
        if in_target:
            if stripped.startswith('- name:'):
                break
            if stripped == sub_key:
                in_sub = True
                sub_indent = len(l) - len(l.lstrip())
                continue
            if in_sub:
                line_indent = len(l) - len(l.lstrip()) if stripped else 0
                if stripped.startswith('- '):
                    insert_at = i
                    # scan past continuation lines (deeper indent than list item)
                    for j in range(i + 1, len(lines)):
                        jl = lines[j]
                        js = jl.strip()
                        j_indent = len(jl) - len(jl.lstrip()) if js else 0
                        if not js or js.startswith('- ') or j_indent <= sub_indent:
                            break
                        insert_at = j
                elif stripped and not stripped.startswith('#') and line_indent <= sub_indent:
                    in_sub = False

    if insert_at >= 0:
        text = entry if entry.endswith('\n') else entry + '\n'
        lines.insert(insert_at + 1, text)
        open(filepath, 'w').writelines(lines)
        print('OK')
    else:
        print('NOT_FOUND')


def extract_names(filepath, pattern):
    """Extract values from lines matching ^\\s+- <pattern>:\\s*(.+)"""
    rx = re.compile(r'^\s+- ' + re.escape(pattern) + r':\s*(.+)')
    for l in open(filepath):
        m = rx.match(l)
        if m:
            print(m.group(1).strip().strip('"'))


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'append_to_list':
        append_to_list(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == 'create_section':
        create_section(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == 'insert_in_nested':
        insert_in_nested(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif cmd == 'extract_names':
        extract_names(sys.argv[2], sys.argv[3])
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)
