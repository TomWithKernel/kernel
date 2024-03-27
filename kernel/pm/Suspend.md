## Suspend (kernel 5.10)

- [state_store](#state sotre)
- [pm_suspend](#pm_suspend)
  
  - [enter_state](#enter_state)
      - [valid_state](#valid_state)
    
      - [suspend_prepare](#suspend_prepare)
      - [sleep_state_supported](#sleep_state_supported)
        - [pm_notifier_call_chain_robust](#pm_notifier_call_chain_robust)
      
        - [suspend_freeze_processes](#suspend_freeze_processes)
          - [freeze_processes](#freeze_processes)
        - [freeze_kernel_threads](#freeze_kernel_threads)


      - [suspend_devices_and_enter](#suspend_devices_and_enter)
        - [dpm_suspend_start](#dpm_suspend_start)
          - [dpm_prepare](#dpm_prepare)
          - [dpm_suspend](#dpm_suspend)
            - [device_suspend](#device_suspend)
        - [suspend_enter](#suspend_enter)
          - [dpm_supsend_noirq](#dpm_suspend_noirq)
            - [device_wakeup_arm_wake_irqs](#device_wakeup_arm_wake_irqs)
            - [suspend_device_irqs](#suspend_device_irqs)
              - [suspend_device_irq](#suspend_device_irq)
            - [dpm_noirq_suspend_devices](#dpm_noirq_suspend_devices)
              - [device_suspend_noirq](#device_suspend_noirq)
          - [suspend_disable_secondary_cpus](#suspend_disable_secondary_cpus)
            - [freeze_secondary_cpus](#freeze_secondary_cpus)
          - [arch_suspend_disable_irqs](#arch_suspend_disable_irqs)
            - [local_irq_disable](#local_irq_disable)
          - [syscore_suspend](#syscore_suspend)
          - [suspend_ops->enter](#suspend_ops->enter)

### state_store

``` c
static ssize_t state_store(struct kobject *kobj, struct kobj_attribute *attr,
			   const char *buf, size_t n)
{
	suspend_state_t state;
	int error;

	error = pm_autosleep_lock();		//获取autosleep锁
	if (error)
		return error;

	if (pm_autosleep_state() > PM_SUSPEND_ON) {	//判断当前autosleep状态
		error = -EBUSY;
		goto out;
	}
    /*关于suspend状态如下：
    	#define PM_SUSPEND_ON		((__force suspend_state_t) 0)
		#define PM_SUSPEND_TO_IDLE	((__force suspend_state_t) 1)
		#define PM_SUSPEND_STANDBY	((__force suspend_state_t) 2)
		#define PM_SUSPEND_MEM		((__force suspend_state_t) 3)
		#define PM_SUSPEND_MIN		PM_SUSPEND_TO_IDLE
		#define PM_SUSPEND_MAX		((__force suspend_state_t) 4)	*/

	state = decode_state(buf, n);		//解析传入的state状态值
	if (state < PM_SUSPEND_MAX) {
		if (state == PM_SUSPEND_MEM)
			state = mem_sleep_current;

		error = pm_suspend(state);			//S3
	} else if (state == PM_SUSPEND_MAX) {
		error = hibernate();				//S4
	} else {
		error = -EINVAL;
	}

 out:
	pm_autosleep_unlock();
	return error ? error : n;
}
```

### pm_suspend

```c
/**
 * pm_suspend - Externally visible function for suspending the system.
 * @state: System sleep state to enter.
 *
 * Check if the value of @state represents one of the supported states,
 * execute enter_state() and update system suspend statistics.
 */
int pm_suspend(suspend_state_t state)
{
	int error;

	if (state <= PM_SUSPEND_ON || state >= PM_SUSPEND_MAX)	//再次判断state
		return -EINVAL;

	pr_info("suspend entry (%s)\n", mem_sleep_labels[state]);
	error = enter_state(state);
	if (error) {
		suspend_stats.fail++;
		dpm_save_failed_errno(error);
	} else {
		suspend_stats.success++;
	}
	pr_info("suspend exit\n");
	return error;
}
```

### enter_state

```c
/**
 * enter_state - Do common work needed to enter system sleep state.
 * @state: System sleep state to enter.
 *
 * Make sure that no one else is trying to put the system into a sleep state.
 * Fail if that's not the case.  Otherwise, prepare for system suspend, make the
 * system enter the given sleep state and clean up after wakeup.
 */
static int enter_state(suspend_state_t state)
{
	int error;

	trace_suspend_resume(TPS("suspend_enter"), state, true);	//记录挂起过程的跟踪信息
	if (state == PM_SUSPEND_TO_IDLE) {
#ifdef CONFIG_PM_DEBUG
		if (pm_test_level != TEST_NONE && pm_test_level <= TEST_CPUS) {
			pr_warn("Unsupported test mode for suspend to idle, please choose none/freezer/devices/platform.\n");
			return -EAGAIN;
		}
#endif
	} else if (!valid_state(state)) {	//判断平台是否支持该睡眠状态
		return -EINVAL;
	}
	if (!mutex_trylock(&system_transition_mutex))
		return -EBUSY;

	if (state == PM_SUSPEND_TO_IDLE)
		s2idle_begin();

	if (sync_on_suspend_enabled) {
		trace_suspend_resume(TPS("sync_filesystems"), 0, true);
		ksys_sync_helper();				//同步文件系统
		trace_suspend_resume(TPS("sync_filesystems"), 0, false);
	}

	pm_pr_dbg("Preparing system for sleep (%s)\n", mem_sleep_labels[state]);
	pm_suspend_clear_flags();
	error = suspend_prepare(state);
	if (error)
		goto Unlock;

	if (suspend_test(TEST_FREEZER))
		goto Finish;

	trace_suspend_resume(TPS("suspend_enter"), state, false);
	pm_pr_dbg("Suspending system (%s)\n", mem_sleep_labels[state]);
	pm_restrict_gfp_mask();
	error = suspend_devices_and_enter(state);		//挂起设备
	pm_restore_gfp_mask();

 Finish:
	events_check_enabled = false;
	pm_pr_dbg("Finishing wakeup.\n");
	suspend_finish();
 Unlock:
	mutex_unlock(&system_transition_mutex);
	return error;
}
```

### valid_state

```c
static bool valid_state(suspend_state_t state)	//判断该平台是否支持该状态睡眠
{
	/*
	 * PM_SUSPEND_STANDBY and PM_SUSPEND_MEM states need low level
	 * support and need to be valid to the low level
	 * implementation, no valid callback implies that none are valid.
	 */
	return suspend_ops && suspend_ops->valid && suspend_ops->valid(state);
}
```

### suspend_prepare

```c
/**
 * suspend_prepare - Prepare for entering system sleep state.
 *
 * Common code run for every system sleep state that can be entered (except for
 * hibernation).  Run suspend notifiers, allocate the "suspend" console and
 * freeze processes.
 */
static int suspend_prepare(suspend_state_t state)
{
	int error;

	if (!sleep_state_supported(state))		//检查指定的睡眠状态是否受支持
		return -EPERM;

	pm_prepare_console();		//切换控制台，将内核消息重定向到指定的控制台。这样做可以确保在睡眠过程中，内核消息能够正确地输出到指定的控制台,重定向kmsg

	error = pm_notifier_call_chain_robust(PM_SUSPEND_PREPARE, PM_POST_SUSPEND);	//运行挂起通知器链。这些通知器允许设备驱动程序和其他子系统在系统挂起之前和之后执行必要的操作
	if (error)
		goto Restore;

	trace_suspend_resume(TPS("freeze_processes"), 0, true);
	error = suspend_freeze_processes();
	trace_suspend_resume(TPS("freeze_processes"), 0, false);
	if (!error)
		return 0;

	suspend_stats.failed_freeze++;
	dpm_save_failed_step(SUSPEND_FREEZE);
	pm_notifier_call_chain(PM_POST_SUSPEND);
 Restore:
	pm_restore_console();
	return error;
}
```

#### sleep_state_supported

```c
static bool sleep_state_supported(suspend_state_t state)
{
	return state == PM_SUSPEND_TO_IDLE || (suspend_ops && suspend_ops->enter);
    // 检查 suspend_ops 结构体和其中的 enter 成员是否存在。如果 suspend_ops 结构体存在且其中的 enter 成员不为 NULL，则返回 true。这表示系统支持进入指定的睡眠状态
}
```

#### pm_notifier_call_chain_robust

```c
int pm_notifier_call_chain_robust(unsigned long val_up, unsigned long val_down)
{																				//用于调用睡眠相关的通知链
	int ret;
	ret = blocking_notifier_call_chain_robust(&pm_chain_head, val_up, val_down, NULL);
	return notifier_to_errno(ret);
}
```

### suspend_freeze_processes

```c
static inline int suspend_freeze_processes(void)
{
	int error;
	error = freeze_processes();											//冻结所有用户进程
	/*
	 * freeze_processes() automatically thaws every task if freezing
	 * fails. So we need not do anything extra upon error.
	 */
	if (error)
		return error;
	error = freeze_kernel_threads();									//冻结内核线程
	/*
	 * freeze_kernel_threads() thaws only kernel threads upon freezing
	 * failure. So we have to thaw the userspace tasks ourselves.
	 */
	if (error)
		thaw_processes();
	return error;
}
```

#### freeze_processes

```c
/**
 * freeze_processes - Signal user space processes to enter the refrigerator.
 * The current thread will not be frozen.  The same process that calls
 * freeze_processes must later call thaw_processes.
 *
 * On success, returns 0.  On failure, -errno and system is fully thawed.
 */
int freeze_processes(void)
{
	int error;

	error = __usermodehelper_disable(UMH_FREEZING);
	if (error)
		return error;

	/* Make sure this task doesn't get frozen */
	current->flags |= PF_SUSPEND_TASK;

	if (!pm_freezing)
		atomic_inc(&system_freezing_cnt);

	pm_wakeup_clear(0);
	pr_info("Freezing user space processes ... ");
	pm_freezing = true;
	error = try_to_freeze_tasks(true);						//冻结所有用户空间进程
	if (!error) {
		__usermodehelper_set_disable_depth(UMH_DISABLED);
		pr_cont("done.");
	}
	pr_cont("\n");
	BUG_ON(in_atomic());

	/*
	 * Now that the whole userspace is frozen we need to disable
	 * the OOM killer to disallow any further interference with
	 * killable tasks. There is no guarantee oom victims will
	 * ever reach a point they go away we have to wait with a timeout.
	 */
	if (!error && !oom_killer_disable(msecs_to_jiffies(freeze_timeout_msecs)))
		error = -EBUSY;

	if (error)
		thaw_processes();									//解冻所有进程
	return error;
}
```

#### freeze_kernel_threads

```c
/**
 * freeze_kernel_threads - Make freezable kernel threads go to the refrigerator.
 *
 * On success, returns 0.  On failure, -errno and only the kernel threads are
 * thawed, so as to give a chance to the caller to do additional cleanups
 * (if any) before thawing the userspace tasks. So, it is the responsibility
 * of the caller to thaw the userspace tasks, when the time is right.
 */
int freeze_kernel_threads(void)
{
	int error;
	pr_info("Freezing remaining freezable tasks ... ");
	pm_nosig_freezing = true;
	error = try_to_freeze_tasks(false);				//冻结内核线程	通过true和false来区别冻结用户进程还是内核线程
	if (!error)
		pr_cont("done.");
	pr_cont("\n");
	BUG_ON(in_atomic());
	if (error)
		thaw_kernel_threads();
	return error;
}
```

### suspend_devices_and_enter

```c
/**
 * suspend_devices_and_enter - Suspend devices and enter system sleep state.
 * @state: System sleep state to enter.
 */
int suspend_devices_and_enter(suspend_state_t state)
{
	int error;
	bool wakeup = false;

	if (!sleep_state_supported(state))			//判断当前平台是否实现了suspend_ops->enter
		return -ENOSYS;

	pm_suspend_target_state = state;

	if (state == PM_SUSPEND_TO_IDLE)
		pm_set_suspend_no_platform();

	error = platform_suspend_begin(state);		//平台挂起
	if (error)
		goto Close;

	suspend_console();							//挂起控制台
	suspend_test_start();						
	error = dpm_suspend_start(PMSG_SUSPEND);
	if (error) {
		pr_err("Some devices failed to suspend, or early wake event detected\n");
		goto Recover_platform;
	}
	suspend_test_finish("suspend devices");
	if (suspend_test(TEST_DEVICES))
		goto Recover_platform;

	do {
		error = suspend_enter(state, &wakeup);
	} while (!error && !wakeup && platform_suspend_again(state));

 Resume_devices:
	suspend_test_start();
	dpm_resume_end(PMSG_RESUME);
	suspend_test_finish("resume devices");
	trace_suspend_resume(TPS("resume_console"), state, true);
	resume_console();
	trace_suspend_resume(TPS("resume_console"), state, false);

 Close:
	platform_resume_end(state);
	pm_suspend_target_state = PM_SUSPEND_ON;
	return error;

 Recover_platform:
	platform_recover(state);
	goto Resume_devices;
}
```

#### dpm_suspend_start

```c
/**
 * dpm_suspend_start - Prepare devices for PM transition and suspend them.
 * @state: PM transition of the system being carried out.
 *
 * Prepare all non-sysdev devices for system PM transition and execute "suspend"
 * callbacks for them.
 */
int dpm_suspend_start(pm_message_t state)			//挂起设备
{
	ktime_t starttime = ktime_get();
	int error;

	error = dpm_prepare(state);						//执行所有设备的prepare回调函数
	if (error) {
		suspend_stats.failed_prepare++;
		dpm_save_failed_step(SUSPEND_PREPARE);
	} else
		error = dpm_suspend(state);					//执行所有设备的suspend回调函数
	dpm_show_time(starttime, state, error, "start");
	return error;
}
```

##### dpm_prepare

```c
/**
 * dpm_prepare - Prepare all non-sysdev devices for a system PM transition.
 * @state: PM transition of the system being carried out.
 *
 * Execute the ->prepare() callback(s) for all devices.
 */
int dpm_prepare(pm_message_t state)
{
	int error = 0;

	trace_suspend_resume(TPS("dpm_prepare"), state.event, true);
	might_sleep();									//在可能会导致进程睡眠的上下文中检查睡眠情况

	/*
	 * Give a chance for the known devices to complete their probes, before
	 * disable probing of devices. This sync point is important at least
	 * at boot time + hibernation restore.
	 */
	wait_for_device_probe();	//等待所有设备的探测完成。在系统启动或从休眠状态恢复时，设备可能正在被探测，这个函数确保在进行电源管理转换之前，所有设备的探测都已完成
	/*
	 * It is unsafe if probing of devices will happen during suspend or
	 * hibernation and system behavior will be unpredictable in this case.
	 * So, let's prohibit device's probing here and defer their probes
	 * instead. The normal behavior will be restored in dpm_complete().
	 */
	device_block_probing();							//禁止设备探测,在执行系统挂起或休眠操作期间，新的设备探测可能会导致不确定的系统行为，因此需要禁止设备探测。这个函数会暂时禁止设备探测，并推迟设备的探测直到稍后的时间点

	mutex_lock(&dpm_list_mtx);
	while (!list_empty(&dpm_list)) {
		struct device *dev = to_device(dpm_list.next);

		get_device(dev);
		mutex_unlock(&dpm_list_mtx);

		trace_device_pm_callback_start(dev, "", state.event);
		error = device_prepare(dev, state);	//准备设备进行电源管理转换。调用设备的 prepare() 回调函数来执行准备工作，以确保设备在进行电源管理转换之前处于正确的状态
		trace_device_pm_callback_end(dev, error);

		mutex_lock(&dpm_list_mtx);
		if (error) {
			if (error == -EAGAIN) {
				put_device(dev);
				error = 0;
				continue;
			}
			pr_info("Device %s not prepared for power transition: code %d\n",
				dev_name(dev), error);
			put_device(dev);
			break;
		}
		dev->power.is_prepared = true;
		if (!list_empty(&dev->power.entry))
			list_move_tail(&dev->power.entry, &dpm_prepared_list);	//用于将准备好的设备移到已准备列表中
		put_device(dev);
	}
	mutex_unlock(&dpm_list_mtx);
	trace_suspend_resume(TPS("dpm_prepare"), state.event, false);
	return error;
}
```

##### dpm_suspend

```c
/**
 * dpm_suspend - Execute "suspend" callbacks for all non-sysdev devices.
 * @state: PM transition of the system being carried out.
 */
int dpm_suspend(pm_message_t state)						//执行所有非系统设备的 "suspend" 回调函数
{
	ktime_t starttime = ktime_get();
	int error = 0;

	trace_suspend_resume(TPS("dpm_suspend"), state.event, true);
	might_sleep();

	devfreq_suspend();							//暂时挂起设备频率调节器
	cpufreq_suspend();							//暂时挂起 CPU 频率调节器

	mutex_lock(&dpm_list_mtx);
	pm_transition = state;
	async_error = 0;
	while (!list_empty(&dpm_prepared_list)) {
		struct device *dev = to_device(dpm_prepared_list.prev);

		get_device(dev);
		mutex_unlock(&dpm_list_mtx);

		error = device_suspend(dev);			//调用设备的挂起回调函数，执行设备的挂起操作

		mutex_lock(&dpm_list_mtx);
		if (error) {
			pm_dev_err(dev, state, "", error);
			dpm_save_failed_dev(dev_name(dev));
			put_device(dev);
			break;
		}
		if (!list_empty(&dev->power.entry))
			list_move(&dev->power.entry, &dpm_suspended_list);	//将已挂起的设备从准备好的设备列表移到已挂起的设备列表中
		put_device(dev);
		if (async_error)
			break;
	}
	mutex_unlock(&dpm_list_mtx);
	async_synchronize_full();
	if (!error)
		error = async_error;
	if (error) {
		suspend_stats.failed_suspend++;
		dpm_save_failed_step(SUSPEND_SUSPEND);
	}
	dpm_show_time(starttime, state, error, NULL);
	trace_suspend_resume(TPS("dpm_suspend"), state.event, false);
	return error;
}
```

###### device_suspend

```c
static int device_suspend(struct device *dev)
{
	if (dpm_async_fn(dev, async_suspend))
		return 0;
	return __device_suspend(dev, pm_transition, false);
}
```

#### suspend_enter

```c
/**
 * suspend_enter - Make the system enter the given sleep state.
 * @state: System sleep state to enter.
 * @wakeup: Returns information that the sleep state should not be re-entered.
 *
 * This function should be called after devices have been suspended.
 */
static int suspend_enter(suspend_state_t state, bool *wakeup)
{
	int error;

	error = platform_suspend_prepare(state);			//调用平台相关的prepare回调函数
	if (error)
		goto Platform_finish;

	error = dpm_suspend_late(PMSG_SUSPEND);				//对所有设备执行“suspend late”回调
	if (error) {
		pr_err("late suspend of devices failed\n");
		goto Platform_finish;
	}
	error = platform_suspend_prepare_late(state);
	if (error)
		goto Devices_early_resume;

	error = dpm_suspend_noirq(PMSG_SUSPEND);		//执行系统挂起过程中的"noirq挂起"回调函数。这些回调函数会在设备驱动程序的中断处理程序被调用之前执行
	if (error) {
		pr_err("noirq suspend of devices failed\n");
		goto Platform_early_resume;
	}
	error = platform_suspend_prepare_noirq(state);
	if (error)
		goto Platform_wake;

	if (suspend_test(TEST_PLATFORM))
		goto Platform_wake;

	if (state == PM_SUSPEND_TO_IDLE) {
		s2idle_loop();
		goto Platform_wake;
	}

	error = suspend_disable_secondary_cpus();
	if (error || suspend_test(TEST_CPUS))
		goto Enable_cpus;

	arch_suspend_disable_irqs();			//禁用本地 CPU 上的中断
	BUG_ON(!irqs_disabled());

	system_state = SYSTEM_SUSPEND;

	error = syscore_suspend();
	if (!error) {
		*wakeup = pm_wakeup_pending();
		if (!(suspend_test(TEST_CORE) || *wakeup)) {
			trace_suspend_resume(TPS("machine_suspend"),
				state, true);
			error = suspend_ops->enter(state);
			trace_suspend_resume(TPS("machine_suspend"),
				state, false);
		} else if (*wakeup) {
			error = -EBUSY;
		}
		syscore_resume();
	}

	system_state = SYSTEM_RUNNING;

	arch_suspend_enable_irqs();
	BUG_ON(irqs_disabled());

 Enable_cpus:
	suspend_enable_secondary_cpus();

 Platform_wake:
	platform_resume_noirq(state);
	dpm_resume_noirq(PMSG_RESUME);

 Platform_early_resume:
	platform_resume_early(state);

 Devices_early_resume:
	dpm_resume_early(PMSG_RESUME);

 Platform_finish:
	platform_resume_finish(state);
	return error;
}
```

##### dpm_suspend_noirq

```c

/**
 * dpm_suspend_noirq - Execute "noirq suspend" callbacks for all devices.
 * @state: PM transition of the system being carried out.
 *
 * Prevent device drivers' interrupt handlers from being called and invoke
 * "noirq" suspend callbacks for all non-sysdev devices.
 */
int dpm_suspend_noirq(pm_message_t state)
{
	int ret;

	cpuidle_pause();					//暂停CPU空闲状态管理器，以确保CPU不会在挂起过程中进入空闲状态

	device_wakeup_arm_wake_irqs();		//激活设备唤醒的唤醒中断
	suspend_device_irqs();				//暂停设备的中断处理程序，防止在挂起过程中中断被处理

	ret = dpm_noirq_suspend_devices(state);		//执行所有设备的"noirq挂起"回调函数。这些回调函数是在设备的中断处理程序被禁用后执行的
	if (ret)
		dpm_resume_noirq(resume_event(state));

	return ret;
}
```

###### device_wakeup_arm_wake_irqs

```c
/**
 * device_wakeup_arm_wake_irqs(void)
 *
 * Itereates over the list of device wakeirqs to arm them.
 */
void device_wakeup_arm_wake_irqs(void)		//迭代设备的唤醒中断列表，以启用它们的唤醒状态
{
	struct wakeup_source *ws;
	int srcuidx;

	srcuidx = srcu_read_lock(&wakeup_srcu);
	list_for_each_entry_rcu_locked(ws, &wakeup_sources, entry)
		dev_pm_arm_wake_irq(ws->wakeirq);
	srcu_read_unlock(&wakeup_srcu, srcuidx);
}
```

###### suspend_device_irqs

```c
/**
 * suspend_device_irqs - disable all currently enabled interrupt lines
 *
 * During system-wide suspend or hibernation device drivers need to be
 * prevented from receiving interrupts and this function is provided
 * for this purpose.
 *
 * So we disable all interrupts and mark them IRQS_SUSPENDED except
 * for those which are unused, those which are marked as not
 * suspendable via an interrupt request with the flag IRQF_NO_SUSPEND
 * set and those which are marked as active wakeup sources.
 *
 * The active wakeup sources are handled by the flow handler entry
 * code which checks for the IRQD_WAKEUP_ARMED flag, suspends the
 * interrupt and notifies the pm core about the wakeup.
 * 在系统全局挂起或休眠期间，防止设备驱动程序接收中断。在挂起期间，函数将禁用所有中断，并将它们标记为 IRQS_SUSPENDED，除非中断未使用、被标记为不可挂起（通过设置 IRQF_NO_SUSPEND 标志），或者被标记为活动唤醒源
 */
void suspend_device_irqs(void)					//在系统挂起或休眠期间禁用所有当前已启用的中断线
{
	struct irq_desc *desc;
	int irq;

	for_each_irq_desc(irq, desc) {
		unsigned long flags;
		bool sync;

		if (irq_settings_is_nested_thread(desc))
			continue;
		raw_spin_lock_irqsave(&desc->lock, flags);
		sync = suspend_device_irq(desc);
		raw_spin_unlock_irqrestore(&desc->lock, flags);

		if (sync)
			synchronize_irq(irq);
	}
}
```

###### suspend_device_irq

```c
static bool suspend_device_irq(struct irq_desc *desc)
{
	unsigned long chipflags = irq_desc_get_chip(desc)->flags;	//获取与中断描述符相关联的中断控制器的标志
	struct irq_data *irqd = &desc->irq_data;

	if (!desc->action || irq_desc_is_chained(desc) ||
	    desc->no_suspend_depth)
		return false;

	if (irqd_is_wakeup_set(irqd)) {							//检查中断是否设置为唤醒中断
		irqd_set(irqd, IRQD_WAKEUP_ARMED);					//设置中断数据结构的 IRQD_WAKEUP_ARMED 标志，表示该中断已被设置为唤醒中断

		if ((chipflags & IRQCHIP_ENABLE_WAKEUP_ON_SUSPEND) &&
		     irqd_irq_disabled(irqd)) {
			/*
			 * Interrupt marked for wakeup is in disabled state.
			 * Enable interrupt here to unmask/enable in irqchip
			 * to be able to resume with such interrupts.
			 */
			__enable_irq(desc);								//启用该中断，以便在中断控制器中取消屏蔽该中断
			irqd_set(irqd, IRQD_IRQ_ENABLED_ON_SUSPEND);	//设置中断数据结构的 IRQD_IRQ_ENABLED_ON_SUSPEND 标志，表示该中断在挂起期间已被启用
		}
		/*
		 * We return true here to force the caller to issue
		 * synchronize_irq(). We need to make sure that the
		 * IRQD_WAKEUP_ARMED is visible before we return from
		 * suspend_device_irqs().
		 */
		return true;
	}

	desc->istate |= IRQS_SUSPENDED;				//将中断描述符的 istate 字段的 IRQS_SUSPENDED 标志设置为1，表示该中断已被挂起
	__disable_irq(desc);						//禁用该中断

	/*
	 * Hardware which has no wakeup source configuration facility
	 * requires that the non wakeup interrupts are masked at the
	 * chip level. The chip implementation indicates that with
	 * IRQCHIP_MASK_ON_SUSPEND.
	 */
	if (chipflags & IRQCHIP_MASK_ON_SUSPEND)	//检查中断控制器标志是否设置了 IRQCHIP_MASK_ON_SUSPEND 标志，如果设置了，表示硬件没有唤醒源配置功能，需要在芯片级别屏蔽非唤醒中断
		mask_irq(desc);						//在硬件层面屏蔽非唤醒中断，调用中断控制器芯片中的特定函数来实现这一操作
	return true;
}
```

###### dpm_noirq_suspend_devices

```c
static int dpm_noirq_suspend_devices(pm_message_t state)
{
	ktime_t starttime = ktime_get();
	int error = 0;

	trace_suspend_resume(TPS("dpm_suspend_noirq"), state.event, true);
	mutex_lock(&dpm_list_mtx);
	pm_transition = state;
	async_error = 0;

	while (!list_empty(&dpm_late_early_list)) {
		struct device *dev = to_device(dpm_late_early_list.prev);

		get_device(dev);
		mutex_unlock(&dpm_list_mtx);

		error = device_suspend_noirq(dev);

		mutex_lock(&dpm_list_mtx);
		if (error) {
			pm_dev_err(dev, state, " noirq", error);
			dpm_save_failed_dev(dev_name(dev));
			put_device(dev);
			break;
		}
		if (!list_empty(&dev->power.entry))
			list_move(&dev->power.entry, &dpm_noirq_list);
		put_device(dev);

		if (async_error)
			break;
	}
	mutex_unlock(&dpm_list_mtx);
	async_synchronize_full();
	if (!error)
		error = async_error;

	if (error) {
		suspend_stats.failed_suspend_noirq++;
		dpm_save_failed_step(SUSPEND_SUSPEND_NOIRQ);
	}
	dpm_show_time(starttime, state, error, "noirq");
	trace_suspend_resume(TPS("dpm_suspend_noirq"), state.event, false);
	return error;
}
```

###### device_suspend_noirq

```c
static int device_suspend_noirq(struct device *dev)
{
	if (dpm_async_fn(dev, async_suspend_noirq))
		return 0;

	return __device_suspend_noirq(dev, pm_transition, false);
}
```

##### suspend_disable_secondary_cpus

```c
static inline int suspend_disable_secondary_cpus(void)
{
	int cpu = 0;

	if (IS_ENABLED(CONFIG_PM_SLEEP_SMP_NONZERO_CPU))	//如果启用了这个配置选项，将 cpu 的值设置为-1，表示要禁用所有辅助 CPU
		cpu = -1;

	return freeze_secondary_cpus(cpu);
}
```

###### freeze_secondary_cpus

```c
int freeze_secondary_cpus(int primary)
{
	int cpu, error = 0;

	cpu_maps_update_begin();
	if (primary == -1) {
		primary = cpumask_first(cpu_online_mask);
		if (!housekeeping_cpu(primary, HK_FLAG_TIMER))
			primary = housekeeping_any_cpu(HK_FLAG_TIMER);
	} else {
		if (!cpu_online(primary))
			primary = cpumask_first(cpu_online_mask);
	}

	/*
	 * We take down all of the non-boot CPUs in one shot to avoid races
	 * with the userspace trying to use the CPU hotplug at the same time
	 */
	cpumask_clear(frozen_cpus);

	pr_info("Disabling non-boot CPUs ...\n");
	for_each_online_cpu(cpu) {
		if (cpu == primary)
			continue;

		if (pm_wakeup_pending()) {
			pr_info("Wakeup pending. Abort CPU freeze\n");
			error = -EBUSY;
			break;
		}

		trace_suspend_resume(TPS("CPU_OFF"), cpu, true);
		error = _cpu_down(cpu, 1, CPUHP_OFFLINE);			//禁用指定的 CPU
		trace_suspend_resume(TPS("CPU_OFF"), cpu, false);
		if (!error)
			cpumask_set_cpu(cpu, frozen_cpus);
		else {
			pr_err("Error taking CPU%d down: %d\n", cpu, error);
			break;
		}
	}

	if (!error)
		BUG_ON(num_online_cpus() > 1);
	else
		pr_err("Non-boot CPUs are not disabled\n");

	/*
	 * Make sure the CPUs won't be enabled by someone else. We need to do
	 * this even in case of failure as all freeze_secondary_cpus() users are
	 * supposed to do thaw_secondary_cpus() on the failure path.
	 */
	cpu_hotplug_disabled++;

	cpu_maps_update_done();
	return error;
}
```

##### arch_suspend_disable_irqs

```c
/* default implementation */
void __weak arch_suspend_disable_irqs(void)
{
	local_irq_disable();
}
```

###### local_irq_disable

```c
#define local_irq_disable()				\
	do {						\
		bool was_disabled = raw_irqs_disabled();\			//检查中断是否已经被禁用
		raw_local_irq_disable();		\		//禁用本地 CPU 上的中断，这是一个底层函数，用于将中断掩码设置为禁用状态
		if (!was_disabled)			\
			trace_hardirqs_off();		\
	} while (0)
```

##### syscore_suspend

```c
/**
 * syscore_suspend - Execute all the registered system core suspend callbacks.
 *
 * This function is executed with one CPU on-line and disabled interrupts.
 */
int syscore_suspend(void)
{
	struct syscore_ops *ops;
	int ret = 0;

	trace_suspend_resume(TPS("syscore_suspend"), 0, true);
	pm_pr_dbg("Checking wakeup interrupts\n");

	/* Return error code if there are any wakeup interrupts pending. */
	if (pm_wakeup_pending())
		return -EBUSY;

	WARN_ONCE(!irqs_disabled(),
		"Interrupts enabled before system core suspend.\n");

	list_for_each_entry_reverse(ops, &syscore_ops_list, node)
		if (ops->suspend) {
			pm_pr_dbg("Calling %pS\n", ops->suspend);
			ret = ops->suspend();
			if (ret)
				goto err_out;
			WARN_ONCE(!irqs_disabled(),
				"Interrupts enabled after %pS\n", ops->suspend);
		}

	trace_suspend_resume(TPS("syscore_suspend"), 0, false);
	return 0;

 err_out:
	pr_err("PM: System core suspend callback %pS failed.\n", ops->suspend);

	list_for_each_entry_continue(ops, &syscore_ops_list, node)
		if (ops->resume)
			ops->resume();

	return ret;
}
```

#### suspend_ops->enter

执行挂起操作等待唤醒信号
