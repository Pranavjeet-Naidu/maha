# Fibonacci Spawn Module

This project implements a Linux kernel module that spawns instances of `gedit` (or a similar application) based on the Fibonacci series. The module prints a hierarchical tree structure of the processes created, allowing users to visualize the spawning process.

## Files

- **Makefile**: Contains the build instructions for compiling the kernel module.
- **spawn.c**: Implements the kernel module logic for spawning processes and managing module lifecycle.
- **.gitignore**: Specifies files and directories to be ignored by Git.
- **tests/test_load.sh**: A shell script for testing the loading and unloading of the kernel module.

## Building the Module

To build the kernel module, navigate to the project directory and run:

```bash
make
```

This will compile the `spawn.c` file and create the kernel module.

## Loading the Module

To load the module into the kernel, use the following command:

```bash
sudo insmod fib_spawn.ko fib_n=<number>
```

Replace `<number>` with the desired Fibonacci index (e.g., 3).

## Unloading the Module

To unload the module, use the following command:

```bash
sudo rmmod fib_spawn
```

## Testing the Module

To test the loading and unloading of the kernel module, run the provided shell script:

```bash
cd tests
./test_load.sh
```

This script will insert the module and check for expected behavior.

## License

This project is licensed under the GPL.