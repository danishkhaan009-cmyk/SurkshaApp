#!/usr/bin/env python3
import re

with open('lib/pages/childs_device/childs_device_widget.dart', 'r') as f:
    content = f.read()
    lines = content.split('\n')

# Find TabBarView children array
in_children = False
depth = 0
child_count = 0
line_num = 0

for i, line in enumerate(lines, 1):
    if 'child: TabBarView(' in line:
        print(f"Found TabBarView at line {i}")
        line_num = i
    
    if line_num > 0 and i > line_num:
        if 'children: [' in line and not in_children:
            in_children = True
            depth = 1
            print(f"Children array starts at line {i}")
            continue
        
        if in_children:
            # Track opening brackets
            for char in line:
                if char == '[':
                    depth += 1
                elif char == ']':
                    depth -= 1
                    if depth == 0:
                        print(f"Children array ends at line {i}")
                        print(f"\nTotal direct children: {child_count}")
                        in_children = False
                        break
            
            # Count direct children (depth == 1)
            if depth == 1 and line.strip() and not line.strip().startswith('//'):
                # Check if this line starts a widget (ends with '(')
                if ('SingleChildScrollView(' in line or 
                    'Column(' in line or
                    'Container(' in line):
                    child_count += 1
                    print(f"  Child #{child_count} at line {i}: {line.strip()[:70]}")
