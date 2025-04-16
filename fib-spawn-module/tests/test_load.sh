#!/bin/bash

# Test script for loading and unloading the fib_spawn kernel module

MODULE_NAME="fib_spawn"

# Load the module
echo "Loading the $MODULE_NAME module..."
sudo insmod ../spawn.ko fib_n=5  # Adjust the Fibonacci index as needed
if [ $? -ne 0 ]; then
    echo "Failed to load the $MODULE_NAME module."
    exit 1
fi

# Check dmesg for module loading messages
echo "Checking dmesg for module messages..."
dmesg | tail -n 20

# Unload the module
echo "Unloading the $MODULE_NAME module..."
sudo rmmod $MODULE_NAME
if [ $? -ne 0 ]; then
    echo "Failed to unload the $MODULE_NAME module."
    exit 1
fi

# Check dmesg for module unloading messages
echo "Checking dmesg for module messages..."
dmesg | tail -n 20

echo "$MODULE_NAME module loaded and unloaded successfully."