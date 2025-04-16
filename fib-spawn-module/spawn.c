#include <linux/module.h>
#include <linux/init.h>
#include <linux/kthread.h>
#include <linux/kmod.h>
#include <linux/delay.h>
#include <linux/fs.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ChatGPT");
MODULE_DESCRIPTION("Fibonacci spawn pattern demonstration");
static int fib_n = 3;
module_param(fib_n, int, 0444);
MODULE_PARM_DESC(fib_n, "Fibonacci index (0,1,2,3,...)");

static struct task_struct *worker;
static int should_stop = 0;


static void spawn_fib(int n, int depth)
{
    /* Signal user-space with a command file - include depth information */
    char cmd[64];
    snprintf(cmd, sizeof(cmd), "echo 'SPAWN_GUI %d %d' > /tmp/fib_spawn_cmd", n, depth);
    
    char *argv[] = { "/bin/sh", "-c", cmd, NULL };
    char *envp[] = {
        "HOME=/root",
        "PATH=/sbin:/bin:/usr/sbin:/usr/bin",
        NULL
    };

    /* Check if we should stop */
    if (should_stop) {
        return;
    }

    /* Print our position in the tree */
    {
        char buf[64];
        int len = 0, i;
        for (i = 0; i < depth; i++) buf[len++] = ' ';
        len += scnprintf(buf+len, sizeof(buf)-len, "fib(%d)\n", n);
        buf[len] = 0;
        printk(KERN_INFO "%s", buf);
    }

    /* Always signal to user-space to show both internal nodes and leaves */
    if (call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC) != 0)
        printk(KERN_ERR "fib_spawn: failed to exec command\n");

    if (n < 2) {
        /* Leaf node - just add a delay */
        msleep(500);  // Longer delay to help with visualization
    } else {
        /* Internal node: recurse for fib(n-1) and fib(n-2) */
        spawn_fib(n-1, depth+2);
        if (should_stop) return;
        spawn_fib(n-2, depth+2);
    }
}
/* Kernel thread entry point */
static int fib_thread_fn(void *data)
{
    printk(KERN_INFO "fib_spawn: starting fib(%d) pattern\n", fib_n);
    
    /* Allow thread to be stopped */
    while (!kthread_should_stop()) {
        should_stop = 0;
        spawn_fib(fib_n, 0);
        printk(KERN_INFO "fib_spawn: done\n");
        
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
    char *argv[] = { "/bin/touch", "/tmp/fib_spawn_cmd", NULL };
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