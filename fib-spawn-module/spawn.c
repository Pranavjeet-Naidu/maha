#include <linux/module.h>
#include <linux/init.h>
#include <linux/kthread.h>
#include <linux/kmod.h>
#include <linux/delay.h>
#include <linux/fs.h>
#include <linux/sched.h>   // For current->pid

MODULE_LICENSE("GPL");
MODULE_AUTHOR("grass");
MODULE_DESCRIPTION("terminal goes brrr");
static int fib_n = 3;
module_param(fib_n, int, 0444);
MODULE_PARM_DESC(fib_n, "Fibonacci index (0,1,2,3,...)");

static struct task_struct *worker;
static int should_stop = 0;

// Calculate Fibonacci value (we need this for determining how many to spawn)
static int calculate_fib(int n)
{
    if (n < 2)
        return n;
    else
        return calculate_fib(n-1) + calculate_fib(n-2);
}

static void spawn_fib(int n, int depth)
{
    int fib_value;
    int i;
    pid_t kernel_pid = current->pid;
    
    /* Check if we should stop */
    if (should_stop) {
        return;
    }

    /* Print our position in the tree along with kernel thread ID */
    {
        char buf[128];
        int len = 0, j;
        for (j = 0; j < depth; j++) buf[len++] = ' ';
        len += scnprintf(buf+len, sizeof(buf)-len, "fib(%d) [kernel_tid=%d]\n", n, kernel_pid);
        buf[len] = 0;
        printk(KERN_INFO "%s", buf);
    }

    /* Calculate the fibonacci value to determine how many to spawn */
    fib_value = calculate_fib(n);
    
    /* Signal user-space with the Fibonacci value, depth, node value, and kernel thread ID */
    {
        char cmd[128];
        snprintf(cmd, sizeof(cmd), "echo 'SPAWN_GUI %d %d %d %d' > /tmp/fib_spawn_cmd", 
                n, depth, fib_value, kernel_pid);
        
        char *argv[] = { "/bin/sh", "-c", cmd, NULL };
        char *envp[] = {
            "HOME=/root",
            "PATH=/sbin:/bin:/usr/sbin:/usr/bin",
            NULL
        };
        
        // Wait for the command to complete to ensure it's processed
        if (call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC) != 0)
            printk(KERN_ERR "fib_spawn: failed to exec command\n");
        
        // Add a short delay to ensure the launcher processes the command
        msleep(200);
    }

    /* Add a delay for visualization */
    msleep(800);  // Slightly shorter delay
    
    /* If not at the bottom level, spawn the next level */
    if (n > 0) {
        for (i = 0; i < fib_value && !should_stop; i++) {
            // Make sure to pass the correct depth value
            spawn_fib(n-1, depth+1);
            
            // Add delay between siblings
            if (i < fib_value-1) msleep(200);
        }
    }
}

/* Kernel thread entry point */
static int fib_thread_fn(void *data)
{
    pid_t kernel_tid = current->pid;
    printk(KERN_INFO "fib_spawn: starting fib(%d) pattern in kernel thread %d\n", fib_n, kernel_tid);
    
    /* Allow thread to be stopped */
    while (!kthread_should_stop()) {
        should_stop = 0;
        spawn_fib(fib_n, 0);
        printk(KERN_INFO "fib_spawn: done in kernel thread %d\n", kernel_tid);
        
        /* Thread function complete, now wait to be stopped */
        set_current_state(TASK_INTERRUPTIBLE);
        schedule();
    }
    
    return 0;
}

static int __init fib_spawn_init(void)
{
    printk(KERN_INFO "fib_spawn: module loaded, fib_n=%d\n", fib_n);
    
    /* Create initial command file */
    char *argv[] = { "/bin/sh", "-c", "touch /tmp/fib_spawn_cmd; echo 'PID TRACKING LOG' > /tmp/fib_process_ids.log", NULL };
    char *envp[] = { "HOME=/root", "PATH=/sbin:/bin:/usr/sbin:/usr/bin", NULL };
    call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC);
    
    /* Start a kernel thread */
    worker = kthread_run(fib_thread_fn, NULL, "fib_spawn_thread");
    if (IS_ERR(worker)) {
        printk(KERN_ERR "fib_spawn: could not start thread\n");
        return PTR_ERR(worker);
    }
    return 0;
}

static void __exit fib_spawn_exit(void)
{
    /* Signal the recursive function to stop */
    should_stop = 1;
    
    /* Stop the worker thread */
    if (worker) {
        /* Wake it up in case it's sleeping */
        wake_up_process(worker);
        /* Then stop it */
        kthread_stop(worker);
    }
    
    printk(KERN_INFO "fib_spawn: module unloaded\n");
}

module_init(fib_spawn_init);
module_exit(fib_spawn_exit);