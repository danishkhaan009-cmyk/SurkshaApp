#!/usr/bin/env python3

# Script to find TabBarView children boundaries

with open('lib/pages/childs_device/childs_device_widget.dart', 'r') as f:
    lines = f.readlines()

# Find TabBarView children array start
in_tabbarview = False
tab_count = 0
bracket_depth = 0
child_start = None
children_found = []

for i, line in enumerate(lines, 1):
    if 'TabBarView(' in line:
        in_tabbarview = True
        print(f"Found TabBarView at line {i}")
        continue
    
    if in_tabbarview and 'children: [' in line and bracket_depth == 0:
        print(f"Found children array at line {i}")
        bracket_depth = 1
        continue
    
    if bracket_depth > 0:
        # Count brackets
        bracket_depth += line.count('[')
        bracket_depth -= line.count(']')
        
        # Detect child widget start (at depth 1, after opening [)
        stripped = line.strip()
        if bracket_depth == 1 and child_start is None:
            if (stripped.startswith('SingleChildScrollView(') or 
                stripped.startswith('Column(') or
                '// ' in stripped and 'Tab' in stripped):
                child_start = i
                tab_count += 1
                print(f"\n=== Child #{tab_count} starts at line {i}: {stripped[:60]}")
        
        # Detect child end (when depth returns to 1 after going deeper)
        if bracket_depth == 1 and child_start is not None:
            if stripped.endswith('),'):
                print(f"    Child #{tab_count} ends at line {i}")
                children_found.append((child_start, i, tab_count))
                child_start = None
        
        # End of children array
        if bracket_depth == 0:
            print(f"\nChildren array closed at line {i}")
            print(f"\nTotal children found: {tab_count}")
            break

print("\n\n=== SUMMARY ===")
for start, end, num in children_found:
    print(f"Child {num}: lines {start}-{end}")
