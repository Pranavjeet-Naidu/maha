#!/bin/bash

# Get the current user who is running the desktop session
XUSER=$(who | grep -m1 '(:0)' | cut -d' ' -f1)
USER_ID=$(id -u $XUSER)

# Debug information
echo "Detected user: $XUSER with UID $USER_ID"

# Remove old command file if exists
rm -f /tmp/fib_spawn_cmd
touch /tmp/fib_spawn_cmd
chmod 666 /tmp/fib_spawn_cmd  # Make sure both root and user can write to it

# Create a file to store the tree structure
rm -f /tmp/fib_tree
touch /tmp/fib_tree
chmod 666 /tmp/fib_tree

# Clear the terminal and print the header
clear
echo -e "\e[1;36m===== FIBONACCI RECURSION TREE VISUALIZATION =====\e[0m"
echo

# Print the tree structure from the tree file
print_tree() {
    clear
    echo -e "\e[1;36m===== FIBONACCI RECURSION TREE VISUALIZATION =====\e[0m"
    echo
    cat /tmp/fib_tree
    echo
    echo -e "\e[1;33mLeaf nodes visited: $1\e[0m"
}

# Handle node notification and update the tree
handle_node() {
    n="$1"
    depth="$2"
    
    # Build the tree representation
    indent=""
    for ((i=0; i<depth; i++)); do
        indent="$indent "
    done
    
    if [ "$n" -lt 2 ]; then
        # Leaf node with checkmark
        echo -e "${indent}\e[1;32m└── fib($n) ✓\e[0m" >> /tmp/fib_tree
        leaf_count=$((leaf_count + 1))
        
        # Launch terminal for leaf nodes
        if [ "$(id -u)" -eq 0 ]; then
            color=$((n*50))
            sudo -u $XUSER DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus \
                gnome-terminal --geometry=40x10 -- bash -c "echo -e '\e[48;5;${color}m\e[97m\e[1m FIBONACCI ($n) \e[0m'; sleep 2" &
        else
            color=$((n*50))
            gnome-terminal --geometry=40x10 -- bash -c "echo -e '\e[48;5;${color}m\e[97m\e[1m FIBONACCI ($n) \e[0m'; sleep 2" &
        fi
        sleep 0.3
    else
        # Internal node
        echo -e "${indent}\e[1;36m├── fib($n)\e[0m" >> /tmp/fib_tree
    fi
    
    # Update the display
    print_tree $leaf_count
}

# Initialize leaf counter
leaf_count=0

# Initialize the tree
echo -e "\e[1;33mfib tree will appear here...\e[0m" > /tmp/fib_tree
print_tree $leaf_count

echo "GUI launcher started, watching for commands..."

# Explicitly handle each line, one at a time
while true; do
    if [ -f /tmp/fib_spawn_cmd ]; then
        cmd=$(cat /tmp/fib_spawn_cmd)
        if [[ "$cmd" =~ ^SPAWN_GUI\ ([0-9]+)\ ([0-9]+)$ ]]; then
            n=${BASH_REMATCH[1]}
            depth=${BASH_REMATCH[2]}
            # Clear the file immediately to prevent duplicate processing
            echo "" > /tmp/fib_spawn_cmd
            # Handle the command
            handle_node "$n" "$depth"
        fi
    fi
    sleep 0.1
done