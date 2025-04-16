#!/bin/bash

# Get the current user who is running the desktop session
XUSER=$(who | grep -m1 '(:0)' | cut -d' ' -f1)
USER_ID=$(id -u $XUSER)

# Debug information
echo "Detected user: $XUSER with UID $USER_ID"

# Function to calculate Fibonacci number (pure bash implementation)
calculate_fib() {
    local n=$1
    if [ "$n" -lt 2 ]; then
        echo "$n"
        return
    fi
    local a=0
    local b=1
    local i=2
    local result=0
    while [ $i -le $n ]; do
        result=$((a + b))
        a=$b
        b=$result
        i=$((i + 1))
    done
    echo $result
}

# Function to calculate hierarchical spawn count (matches kernel implementation)
calculate_hierarchical_spawn_count() {
    local n=$1
    local depth=$2
    
    # Base case: if n=0, no more spawning occurs
    if [ "$n" -eq 0 ]; then
        echo 1  # Still count the node itself
        return
    fi
    
    # Calculate Fibonacci value for this level
    local fib_value=$(calculate_fib $n)
    
    # Count this node
    local total=1
    
    # Add children from the next level (n-1)
    # Each node spawns exactly fib_value children
    if [ "$n" -gt 0 ]; then
        local child_count=$(calculate_hierarchical_spawn_count $((n-1)) $((depth+1)))
        total=$((total + fib_value * child_count))
    fi
    
    echo $total
}

# Show warning about terminal count for higher Fibonacci numbers
print_warning() {
    local fib_param=$1
    
    # Calculate expected spawn count with the hierarchical method
    local total_count=$(calculate_hierarchical_spawn_count $fib_param 0)
    
    # Generate a pre-calculated list of Fibonacci values and hierarchical counts
    local fib_list=""
    local count_list=""
    for i in $(seq 0 $fib_param); do
        local fib_val=$(calculate_fib $i)
        # Use the new hierarchical calculation for each level
        local count=$(calculate_hierarchical_spawn_count $i 0)
        fib_list="$fib_list$i:$fib_val "
        count_list="$count_list$i:$count "
    done
    
    # Display warning in a separate terminal to make sure it's seen
    if [ "$(id -u)" -eq 0 ]; then
        sudo -u $XUSER DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus \
            gnome-terminal --geometry=80x25 -- bash -c "
            echo -e '\e[1;36m===== FIBONACCI SPAWN WARNING =====\e[0m'
            echo -e '\e[1;33m⚠️  WARNING: fib($fib_param) will spawn approximately $total_count terminals!\e[0m'
            if [ $total_count -gt 50 ]; then
                echo -e '\e[1;31m⚠️  This is a large number and might overwhelm your system.\e[0m'
                echo -e '\e[1;31m   Consider using a smaller value (fib_n ≤ 4 recommended).\e[0m'
            fi
            echo
            echo 'Details of calculation (Hierarchical Model):'
            echo '--------------------------------------------'
            
            # Use pre-calculated values from the parent script
            for item in $fib_list; do
                i=\$(echo \$item | cut -d: -f1)
                fib_val=\$(echo \$item | cut -d: -f2)
                
                # Find corresponding count
                count=''
                for count_item in $count_list; do
                    count_i=\$(echo \$count_item | cut -d: -f1)
                    if [ \"\$i\" = \"\$count_i\" ]; then
                        count=\$(echo \$count_item | cut -d: -f2)
                        break
                    fi
                done
                
                echo \"fib(\$i) = \$fib_val, total spawn count = \$count\"
            done
            
            echo
            echo 'Note: This calculation reflects the actual hierarchical spawning'
            echo 'pattern implemented in the kernel module, where each fib(n) node'
            echo 'spawns exactly fib(n) child instances of fib(n-1).'
            echo
            echo -ne '\e[1;33mPress any key to continue or Ctrl+C to abort... \e[0m'
            read -n 1
            " &
    fi
    
    # Also show in the main terminal
    echo "Module loaded with fib_n = $fib_param"
    echo -e "\e[1;33m⚠️  WARNING: fib($fib_param) will spawn approximately $total_count terminals!\e[0m"
}
# Background monitor for module loading
monitor_module_load() {
    # Initialize previous state to not loaded
    local prev_loaded=0
    local prev_param=0
    
    # Monitor in background
    (
        while true; do
            # Check if module is loaded
            if lsmod | grep -q "spawn"; then
                local loaded=1
                # Check if parameter file exists and get value
                if [ -f "/sys/module/spawn/parameters/fib_n" ]; then
                    local current_param=$(cat /sys/module/spawn/parameters/fib_n)
                    
                    # If module was just loaded or parameter changed, show warning
                    if [ $loaded -ne $prev_loaded ] || [ "$current_param" != "$prev_param" ]; then
                        print_warning "$current_param"
                        prev_loaded=$loaded
                        prev_param=$current_param
                    fi
                fi
            else
                local loaded=0
                # If module was unloaded, update state
                if [ $loaded -ne $prev_loaded ]; then
                    echo "Module was unloaded"
                    prev_loaded=$loaded
                fi
            fi
            
            # Check every 2 seconds
            sleep 2
        done
    ) &
    
    # Save background process ID for cleanup
    MONITOR_PID=$!
}

# Cleanup on exit
cleanup() {
    # Kill the background monitor if it's running
    if [ ! -z "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
    fi
    
    # Remove temporary files
    rm -f /tmp/fib_spawn_cmd /tmp/fib_tree
    
    echo "Launcher exiting, cleanup complete"
    exit 0
}

# Set trap for clean exit
trap cleanup EXIT INT TERM

# Remove old command file if exists
rm -f /tmp/fib_spawn_cmd
touch /tmp/fib_spawn_cmd
chmod 666 /tmp/fib_spawn_cmd  # Make sure both root and user can write to it

# Create a file to store the tree structure
rm -f /tmp/fib_tree
touch /tmp/fib_tree
chmod 666 /tmp/fib_tree

# Start monitoring for module loading
monitor_module_load

# Clear the terminal and print the header
clear
echo -e "\e[1;36m===== FIBONACCI HIERARCHICAL SPAWN VISUALIZATION =====\e[0m"
echo
echo -e "\e[1;33mWaiting for module to load...\e[0m"
echo

# Print the tree structure from the tree file
print_tree() {
    clear
    echo -e "\e[1;36m===== FIBONACCI HIERARCHICAL SPAWN VISUALIZATION =====\e[0m"
    echo
    cat /tmp/fib_tree
    echo
    echo -e "\e[1;33mTotal nodes visualized: $1\e[0m"
}

# Handle node notification and update the tree
handle_node() {
    n="$1"        # Fibonacci index
    depth="$2"    # Depth in the tree
    value="$3"    # Fibonacci value (how many to spawn)
    
    # Build the tree representation
    indent=""
    for ((i=0; i<depth; i++)); do
        indent="$indent  "
    done
    
    # Color based on depth (cycle through colors)
    color=$((30 + (depth % 7)))
    
    # Update the tree visualization
    echo -e "${indent}\e[1;${color}m• fib($n) = $value\e[0m" >> /tmp/fib_tree
    
    # Increment node counter
    node_count=$((node_count + 1))
    
    # Update the display
    print_tree $node_count
    
    # Launch terminals to represent the hierarchy
    if [ "$(id -u)" -eq 0 ]; then
        # Color for the terminal based on depth
        bg_color=$((40 + (depth % 8)))
        
        # Launch a terminal with appropriate color
        sudo -u $XUSER DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus \
            gnome-terminal --geometry=50x5 -- bash -c "echo -e '\e[${bg_color};97m FIBONACCI($n) = $value (Depth $depth) \e[0m'; echo -e '\e[${bg_color};97m Will spawn $value nodes at next level \e[0m'; sleep 3" &
    else
        bg_color=$((40 + (depth % 8)))
        gnome-terminal --geometry=50x5 -- bash -c "echo -e '\e[${bg_color};97m FIBONACCI($n) = $value (Depth $depth) \e[0m'; echo -e '\e[${bg_color};97m Will spawn $value nodes at next level \e[0m'; sleep 3" &
    fi
    
    # Add a delay to help with visualization
    sleep 0.5
}

# Initialize node counter
node_count=0

# Initialize the tree
echo -e "\e[1;33mHierarchical Fibonacci tree will appear here...\e[0m" > /tmp/fib_tree
print_tree $node_count

echo "GUI launcher started, watching for commands..."

# Explicitly handle each line, one at a time
while true; do
    if [ -f /tmp/fib_spawn_cmd ]; then
        cmd=$(cat /tmp/fib_spawn_cmd)
        echo "DEBUG: Received command: '$cmd'" >> /tmp/fib_debug.log
        
        if [[ "$cmd" =~ ^SPAWN_GUI\ ([0-9]+)\ ([0-9]+)\ ([0-9]+)$ ]]; then
            n=${BASH_REMATCH[1]}
            depth=${BASH_REMATCH[2]}
            value=${BASH_REMATCH[3]}
            
            echo "DEBUG: Parsed n=$n depth=$depth value=$value" >> /tmp/fib_debug.log
            
            # Clear the file immediately to prevent duplicate processing
            echo "" > /tmp/fib_spawn_cmd
            
            # Handle the command
            handle_node "$n" "$depth" "$value"
        else
            echo "DEBUG: Command did not match pattern" >> /tmp/fib_debug.log
            # Clear invalid commands
            echo "" > /tmp/fib_spawn_cmd
        fi
    fi
    sleep 0.1
done