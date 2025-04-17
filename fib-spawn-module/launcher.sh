#!/bin/bash

# Get the current user who is running the desktop session
XUSER=$(who | grep -m1 '(:0)' | cut -d' ' -f1)
USER_ID=$(id -u $XUSER)

# Debug information
echo "Detected user: $XUSER with UID $USER_ID"

# Function to ensure file is accessible
ensure_accessible_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # If file exists but we can't write to it, fix permissions
        if [ ! -w "$file" ]; then
            sudo chmod 666 "$file"
        fi
    else
        # Create file with proper permissions
        sudo touch "$file"
        sudo chmod 666 "$file"
    fi
}

# Create and set permissions on all required files
ensure_accessible_file /tmp/fib_process_ids.log
ensure_accessible_file /tmp/fib_debug.log
ensure_accessible_file /tmp/fib_tree
ensure_accessible_file /tmp/fib_spawn_cmd

# Function to print the tree structure from the tree file
print_tree() {
    clear
    echo -e "\e[1;36m===== FIBONACCI HIERARCHICAL SPAWN VISUALIZATION =====\e[0m"
    echo
    cat /tmp/fib_tree
    echo
    echo -e "\e[1;33mTotal nodes visualized: $1\e[0m"
}

# Function to log process information in a simplified format
log_process_info() {
    local kernel_tid=$3
    local user_pid=$$
    
    # Format: [timestamp] k_tid=XXX user_pid=YYY
    echo "[$(date +%T.%N)] k_tid=$kernel_tid user_pid=$user_pid" >> /tmp/fib_process_ids.log 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Warning: Could not write to process log, fixing permissions..."
        sudo chmod 666 /tmp/fib_process_ids.log
        echo "[$(date +%T.%N)] k_tid=$kernel_tid user_pid=$user_pid" >> /tmp/fib_process_ids.log
    fi
}

# Initialize node counter
node_count=0

# Initialize the tree
echo -e "\e[1;33mHierarchical Fibonacci tree will appear here...\e[0m" > /tmp/fib_tree
print_tree $node_count

# Handle node notification and update the tree
handle_node() {
    n="$1"        # Fibonacci index
    depth="$2"    # Depth in the tree
    value="$3"    # Fibonacci value (how many to spawn)
    kernel_tid="$4" # Kernel thread ID
    
    # Log process information
    log_process_info "$n" "$depth" "$kernel_tid"
    
    # Build the tree representation
    indent=""
    for ((i=0; i<depth; i++)); do
        indent="$indent  "
    done
    
    # Color based on depth (cycle through colors)
    color=$((30 + (depth % 7)))
    
    # Update the tree visualization with thread/process IDs
    echo -e "${indent}\e[1;${color}m• fib($n) = $value [k_tid=$kernel_tid]\e[0m" >> /tmp/fib_tree
    
    # Increment node counter
    node_count=$((node_count + 1))
    
    # Update the display
    print_tree $node_count
    
    # Create a unique temporary file for this terminal
    tmp_pid_file="/tmp/term_pid_${n}_${depth}_${RANDOM}"
    
    # Launch terminals to represent the hierarchy
    if [ "$(id -u)" -eq 0 ]; then
        # Color for the terminal based on depth
        bg_color=$((40 + (depth % 8)))
        
        # Launch a terminal that writes its PID to a temp file
        sudo -u $XUSER DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus \
            gnome-terminal --geometry=50x5 -- bash -c "echo \$\$ > $tmp_pid_file; echo -e '\e[${bg_color};97m FIBONACCI($n) = $value (Depth $depth) \e[0m'; echo -e '\e[${bg_color};97m K_TID=$kernel_tid PID=\$\$ PPID=\$PPID \e[0m'; echo -e '\e[${bg_color};97m Will spawn $value nodes at next level \e[0m'; sleep 3" &
    else
        bg_color=$((40 + (depth % 8)))
        gnome-terminal --geometry=50x5 -- bash -c "echo \$\$ > $tmp_pid_file; echo -e '\e[${bg_color};97m FIBONACCI($n) = $value (Depth $depth) \e[0m'; echo -e '\e[${bg_color};97m K_TID=$kernel_tid PID=\$\$ PPID=\$PPID \e[0m'; echo -e '\e[${bg_color};97m Will spawn $value nodes at next level \e[0m'; sleep 3" &
    fi
    
    # Give the terminal a moment to write its PID
    sleep 0.1
    
    # Get the terminal PID if available
    if [ -f "$tmp_pid_file" ]; then
        terminal_pid=$(cat "$tmp_pid_file")
        rm -f "$tmp_pid_file"
        # Log the terminal PID in a simplified format
        echo "[$(date +%T.%N)] terminal_pid=$terminal_pid parent=$$ k_tid=$kernel_tid" >> /tmp/fib_process_ids.log
    else
        echo "[$(date +%T.%N)] terminal_pid=unknown parent=$$ k_tid=$kernel_tid" >> /tmp/fib_process_ids.log
    fi
    
    # Add a delay to help with visualization
    sleep 0.5
}

echo "GUI launcher started, watching for commands..."

# Modify the main loop to handle the new command format with thread ID
while true; do
    if [ -f /tmp/fib_spawn_cmd ]; then
        cmd=$(cat /tmp/fib_spawn_cmd)
        echo "DEBUG: Received command: '$cmd'" >> /tmp/fib_debug.log 2>/dev/null
        
        if [[ "$cmd" =~ ^SPAWN_GUI\ ([0-9]+)\ ([0-9]+)\ ([0-9]+)\ ([0-9]+)$ ]]; then
            n=${BASH_REMATCH[1]}
            depth=${BASH_REMATCH[2]}
            value=${BASH_REMATCH[3]}
            kernel_tid=${BASH_REMATCH[4]}
            
            echo "DEBUG: Parsed n=$n depth=$depth value=$value kernel_tid=$kernel_tid" >> /tmp/fib_debug.log 2>/dev/null
            
            # Clear the file immediately to prevent duplicate processing
            echo "" > /tmp/fib_spawn_cmd
            
            # Handle the command with the kernel thread ID
            handle_node "$n" "$depth" "$value" "$kernel_tid"
        else
            echo "DEBUG: Command did not match pattern" >> /tmp/fib_debug.log 2>/dev/null
            # Clear invalid commands
            echo "" > /tmp/fib_spawn_cmd
        fi
    fi
    sleep 0.1
done