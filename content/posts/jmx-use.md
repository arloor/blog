---
title: "Java管理扩展：通过MBean获取jvm运行情况"
date: 2021-01-30T23:11:48+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

搞下jvm信息的监控
<!--more-->

```java
import java.lang.management.ClassLoadingMXBean;
import java.lang.management.CompilationMXBean;
import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryPoolMXBean;
import java.lang.management.MemoryUsage;
import com.sun.management.OperatingSystemMXBean;
import java.lang.management.RuntimeMXBean;
import java.lang.management.ThreadMXBean;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.text.NumberFormat;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

public class HeapMain {

    private static NumberFormat fmtI = new DecimalFormat("###,###", new DecimalFormatSymbols(Locale.ENGLISH));
    private static NumberFormat fmtD = new DecimalFormat("###,##0.000", new DecimalFormatSymbols(Locale.ENGLISH));

    public static void main(String[] args) throws InterruptedException {
        //运行时情况
        RuntimeMXBean runtime = ManagementFactory.getRuntimeMXBean();
        //操作系统情况
        com.sun.management.OperatingSystemMXBean  os = ManagementFactory.getPlatformMXBean(com.sun.management.OperatingSystemMXBean.class);
        //线程使用情况
        ThreadMXBean threads = ManagementFactory.getThreadMXBean();
        //堆内存使用情况
        MemoryUsage heapMemoryUsage = ManagementFactory.getMemoryMXBean().getHeapMemoryUsage();
        //非堆内存使用情况
        MemoryUsage nonHeapMemoryUsage = ManagementFactory.getMemoryMXBean().getNonHeapMemoryUsage();
        //类加载情况
        ClassLoadingMXBean cl = ManagementFactory.getClassLoadingMXBean();
        //内存池对象
        List<MemoryPoolMXBean> pools = ManagementFactory.getMemoryPoolMXBeans();
        //编译器和编译情况
        CompilationMXBean cm = ManagementFactory.getCompilationMXBean();
        //获取GC对象
        List<GarbageCollectorMXBean> gcmList = ManagementFactory.getGarbageCollectorMXBeans();


        //运行时情况
        System.out.printf("jvm.name (JVM名称-版本号-供应商):%s | version: %s | vendor: %s  %n", runtime.getVmName(), runtime.getVmVersion(), runtime.getVmVendor());
        System.out.printf("jvm.spec.name (JVM规范名称-版本号-供应商):%s | version: %s | vendor: %s  %n", runtime.getSpecName(), runtime.getSpecVersion(), runtime.getSpecVendor());
        System.out.printf("jvm.java.version (JVM JAVA版本):%s%n", System.getProperty("java.version"));
        System.out.printf("jvm.start.time (Java虚拟机的启动时间):%s%n", toDuration(runtime.getStartTime()));
        System.out.printf("jvm.uptime (Java虚拟机的正常运行时间):%s%n", runtime.getInputArguments());
        System.out.printf("jvm.uptime (Java虚拟机的正常运行时间):%s%n", toDuration(runtime.getUptime()));
        System.out.printf("jvm.getInputArguments (JVM 启动参数):%s%n", runtime.getInputArguments());
        System.out.printf("jvm.getSystemProperties (获取系统属性):%s%n", runtime.getSystemProperties());
        //获取cpu使用情况/gc垃圾回收活动情况
        Thread thread = new Thread(() -> showCpu(runtime, os, gcmList));
        thread.start();
        System.out.println("------------------------------------------------------------------------------------------------------");

        //编译情况
        System.out.printf("compilation.name(编译器名称)：%s%n",cm.getName());
        System.out.printf("compilation.total.time(编译器耗时)：%d毫秒%n",cm.getTotalCompilationTime());
        boolean isSupport=cm.isCompilationTimeMonitoringSupported();
        if(isSupport){
            System.out.println("支持即时编译器编译监控");
        }else{
            System.out.println("不支持即时编译器编译监控");
        }
        System.out.printf("------------------------------------------------------------------------------------------------------");
        //JVM 线程情况
        System.out.printf("jvm.threads.total.count (总线程数(守护+非守护)):%d%n", threads.getThreadCount());
        System.out.printf("jvm.threads.daemon.count (守护进程线程数):%d%n", threads.getDaemonThreadCount());
        System.out.printf("jvm.threads.peak.count (峰值线程数):%d%n", threads.getPeakThreadCount());
        System.out.printf("jvm.threads.total.start.count(Java虚拟机启动后创建并启动的线程总数):%d%n", threads.getTotalStartedThreadCount());
        for(Long threadId : threads.getAllThreadIds()) {
            System.out.printf("threadId: %d | threadName: %s%n", threadId, threads.getThreadInfo(threadId).getThreadName());
        }
        System.out.println("------------------------------------------------------------------------------------------------------");
        //获取GC信息
        for (GarbageCollectorMXBean collectorMXBean : gcmList) {
            System.out.printf("collectorMXBean.getCollectionCount(%s 垃圾回收器执行次数):%d%n",collectorMXBean.getName(), collectorMXBean.getCollectionCount());
            System.out.printf("collectorMXBean.getCollectionTime(%s 垃圾回收器执行时间):%d%n",collectorMXBean.getName(), collectorMXBean.getCollectionTime());
        }
        System.out.println("------------------------------------------------------------------------------------------------------");
        //堆内存情况
        System.out.printf("jvm.heap.init (初始化堆内存):%s %n",  bytesToMB(heapMemoryUsage.getInit()));
        System.out.printf("jvm.heap.used (已使用堆内存):%s %n", bytesToMB(heapMemoryUsage.getUsed()));
        System.out.printf("jvm.heap.committed (可使用堆内存):%s %n", bytesToMB(heapMemoryUsage.getCommitted()));
        System.out.printf("jvm.heap.max (最大堆内存):%s %n", bytesToMB(heapMemoryUsage.getMax()));

        System.out.println("------------------------------------------------------------------------------------------------------");

        //非堆内存使用情况
        System.out.printf("jvm.noheap.init (初始化非堆内存):%s %n",  bytesToMB(nonHeapMemoryUsage.getInit()));
        System.out.printf("jvm.noheap.used (已使用非堆内存):%s %n",  bytesToMB(nonHeapMemoryUsage.getUsed()));
        System.out.printf("jvm.noheap.committed (可使用非堆内存):%s %n",  bytesToMB(nonHeapMemoryUsage.getCommitted()));
        System.out.printf("jvm.noheap.max (最大非堆内存):%s %n", bytesToMB(nonHeapMemoryUsage.getMax()));

        System.out.println("------------------------------------------------------------------------------------------------------");

        //系统概况
        System.out.printf("os.name(操作系统名称-版本号):%s %s %s %n", os.getName(), "version", os.getVersion());
        System.out.printf("os.arch(操作系统内核):%s%n", os.getArch());
        System.out.printf("os.cores(可用的处理器数量):%s %n", os.getAvailableProcessors());
        System.out.printf("os.loadAverage(系统负载平均值):%s %n", os.getSystemLoadAverage());

        System.out.println("------------------------------------------------------------------------------------------------------");

        //类加载情况
        System.out.printf("class.current.load.count(当前加载类数量):%s %n", cl.getLoadedClassCount());
        System.out.printf("class.unload.count(未加载类数量):%s %n", cl.getUnloadedClassCount());
        System.out.printf("class.total.load.count(总加载类数量):%s %n", cl.getTotalLoadedClassCount());

        System.out.println("------------------------------------------------------------------------------------------------------");

        for(MemoryPoolMXBean pool : pools) {
            final String kind = pool.getType().name();
            final MemoryUsage usage = pool.getUsage();
            System.out.println("内存模型： " + getKindName(kind) + ", 内存空间名称： " + getPoolName(pool.getName()) + ", jvm." + pool.getName() + ".init(初始化):" + bytesToMB(usage.getInit()));
            System.out.println("内存模型： " + getKindName(kind) + ", 内存空间名称： " + getPoolName(pool.getName()) + ", jvm." + pool.getName() + ".used(已使用): " + bytesToMB(usage.getUsed()));
            System.out.println("内存模型： " + getKindName(kind) + ", 内存空间名称： " + getPoolName(pool.getName()) + ", jvm." + pool.getName()+ ".committed(可使用):" + bytesToMB(usage.getCommitted()));
            System.out.println("内存模型： " + getKindName(kind) + ", 内存空间名称： " + getPoolName(pool.getName()) + ", jvm." + pool.getName() + ".max(最大):" + bytesToMB(usage.getMax()));
            System.out.println("------------------------------------------------------------------------------------------------------");
        }
        thread.join();
    }

    private static void showCpu(RuntimeMXBean runtime,OperatingSystemMXBean os,List<GarbageCollectorMXBean> gcmList) {
        //上一个cpu运行记录时间点
        long prevUpTime = runtime.getUptime();
        //当时cpu运行时间
        long upTime;
        //上一次cpu运行总时间
        long prevProcessCpuTime =  os.getProcessCpuTime();
        //当前cpu运行总时间
        long processCpuTime;
        //上一次gc运行总时间
        long prevProcessGcTime = getTotalGarbageCollectionTime(gcmList);
        //当前gc运行总时间
        long processGcTime;
        //可用内核数量
        int processorCount =os.getAvailableProcessors();
        try {
            TimeUnit.SECONDS.sleep(1);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        int i =10;
        while (i>0){
            processCpuTime = os.getProcessCpuTime();
            processGcTime = getTotalGarbageCollectionTime(gcmList);
            upTime = runtime.getUptime();
            long upTimeDiff = upTime - prevUpTime;
            //计算cpu使用率
            long processTimeDiff = processCpuTime - prevProcessCpuTime;
            //processTimeDiff 取到得是纳秒数  1ms = 1000000ns
            double cpuDetail = processTimeDiff * 100.0 /1000000/ processorCount / upTimeDiff;
            //计算gccpu使用率
            long processGcTimeDiff = processGcTime - prevProcessGcTime;
            double gcDetail = processGcTimeDiff * 100.0 /1000000/ processorCount / upTimeDiff;
            System.out.printf("cpu使用率：%s ,gc使用率：%s %n",cpuDetail,gcDetail);
            try {
                TimeUnit.SECONDS.sleep(1);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            prevProcessCpuTime = processCpuTime;
            prevUpTime = upTime;
            prevProcessGcTime =processGcTime;
            i--;
        }
    }

    /**
     * 垃圾回收期总耗时
     */
    protected static long getTotalGarbageCollectionTime(List<GarbageCollectorMXBean> gcmList) {
        long total = -1L;
        for (GarbageCollectorMXBean collectorMXBean : gcmList) {
            total+=collectorMXBean.getCollectionTime();
        }
        return total;
    }

    protected static String getKindName(String kind) {
        if("NON_HEAP".equals(kind)) {
            return "NON_HEAP(非堆内存)";
        }else {
            return "HEAP(堆内存)";
        }
    }

    protected static String getPoolName(String poolName) {
        switch (poolName) {
            case "Code Cache":
                return poolName +"(代码缓存区)";
            case "Metaspace":
                return poolName +"(元空间)";
            case "Compressed Class Space":
                return poolName +"(类指针压缩空间)";
            case "PS Eden Space":
                return poolName +"(伊甸园区)";
            case "PS Survivor Space":
                return poolName +"(幸存者区)";
            case "PS Old Gen":
                return poolName +"(老年代)";
            default:
                return poolName;
        }
    }


    protected static String bytesToMB(long bytes) {
        return fmtI.format((long)(bytes / 1024 / 1024)) + " MB";
    }

    protected static String printSizeInKb(double size) {
        return fmtI.format((long) (size / 1024)) + " kbytes";
    }

    protected static String toDuration(double uptime) {
        uptime /= 1000;
        if (uptime < 60) {
            return fmtD.format(uptime) + " seconds";
        }
        uptime /= 60;
        if (uptime < 60) {
            long minutes = (long) uptime;
            String s = fmtI.format(minutes) + (minutes > 1 ? " minutes" : " minute");
            return s;
        }
        uptime /= 60;
        if (uptime < 24) {
            long hours = (long) uptime;
            long minutes = (long) ((uptime - hours) * 60);
            String s = fmtI.format(hours) + (hours > 1 ? " hours" : " hour");
            if (minutes != 0) {
                s += " " + fmtI.format(minutes) + (minutes > 1 ? " minutes" : " minute");
            }
            return s;
        }
        uptime /= 24;
        long days = (long) uptime;
        long hours = (long) ((uptime - days) * 24);
        String s = fmtI.format(days) + (days > 1 ? " days" : " day");
        if (hours != 0) {
            s += " " + fmtI.format(hours) + (hours > 1 ? " hours" : " hour");
        }
        return s;
    }

}
```

输出：

```bash
jvm.name (JVM名称-版本号-供应商):Java HotSpot(TM) 64-Bit Server VM | version: 15.0.1+9-18 | vendor: Oracle Corporation  
jvm.spec.name (JVM规范名称-版本号-供应商):Java Virtual Machine Specification | version: 15 | vendor: Oracle Corporation  
jvm.java.version (JVM JAVA版本):15.0.1
jvm.start.time (Java虚拟机的启动时间):18,657 days 15 hours
jvm.uptime (Java虚拟机的正常运行时间):[-agentlib:jdwp=transport=dt_socket,address=127.0.0.1:65473,suspend=y,server=n, -XX:+UseZGC, -javaagent:D:\JetBrains\ideaIU-2020.3.1.win\plugins\java\lib\rt\debugger-agent.jar, -Dfile.encoding=UTF-8]
jvm.uptime (Java虚拟机的正常运行时间):0.421 seconds
jvm.getInputArguments (JVM 启动参数):[-agentlib:jdwp=transport=dt_socket,address=127.0.0.1:65473,suspend=y,server=n, -XX:+UseZGC, -javaagent:D:\JetBrains\ideaIU-2020.3.1.win\plugins\java\lib\rt\debugger-agent.jar, -Dfile.encoding=UTF-8]
jvm.getSystemProperties (获取系统属性):{java.specification.version=15, sun.cpu.isalist=amd64, sun.jnu.encoding=GBK, java.class.path=E:\IdeaProjects\HttpProxy\target\classes;C:\Users\arloor\.m2\repository\io\netty\netty-all\4.1.53.Final\netty-all-4.1.53.Final.jar;C:\Users\arloor\.m2\repository\org\thymeleaf\thymeleaf\3.0.11.RELEASE\thymeleaf-3.0.11.RELEASE.jar;C:\Users\arloor\.m2\repository\ognl\ognl\3.1.12\ognl-3.1.12.jar;C:\Users\arloor\.m2\repository\org\javassist\javassist\3.20.0-GA\javassist-3.20.0-GA.jar;C:\Users\arloor\.m2\repository\org\attoparser\attoparser\2.0.5.RELEASE\attoparser-2.0.5.RELEASE.jar;C:\Users\arloor\.m2\repository\org\unbescape\unbescape\1.1.6.RELEASE\unbescape-1.1.6.RELEASE.jar;C:\Users\arloor\.m2\repository\io\netty\netty-tcnative-boringssl-static\2.0.34.Final\netty-tcnative-boringssl-static-2.0.34.Final.jar;C:\Users\arloor\.m2\repository\com\google\guava\guava\29.0-jre\guava-29.0-jre.jar;C:\Users\arloor\.m2\repository\com\google\guava\failureaccess\1.0.1\failureaccess-1.0.1.jar;C:\Users\arloor\.m2\repository\com\google\guava\listenablefuture\9999.0-empty-to-avoid-conflict-with-guava\listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar;C:\Users\arloor\.m2\repository\com\google\code\findbugs\jsr305\3.0.2\jsr305-3.0.2.jar;C:\Users\arloor\.m2\repository\org\checkerframework\checker-qual\2.11.1\checker-qual-2.11.1.jar;C:\Users\arloor\.m2\repository\com\google\errorprone\error_prone_annotations\2.3.4\error_prone_annotations-2.3.4.jar;C:\Users\arloor\.m2\repository\com\google\j2objc\j2objc-annotations\1.3\j2objc-annotations-1.3.jar;C:\Users\arloor\.m2\repository\ch\qos\logback\logback-core\1.2.3\logback-core-1.2.3.jar;C:\Users\arloor\.m2\repository\ch\qos\logback\logback-classic\1.2.3\logback-classic-1.2.3.jar;C:\Users\arloor\.m2\repository\org\slf4j\slf4j-api\1.7.7\slf4j-api-1.7.7.jar;C:\Users\arloor\.m2\repository\org\bouncycastle\bcprov-jdk15on\1.64\bcprov-jdk15on-1.64.jar;C:\Users\arloor\.m2\repository\com\alibaba\fastjson\1.2.73\fastjson-1.2.73.jar;D:\JetBrains\ideaIU-2020.3.1.win\lib\idea_rt.jar, java.vm.vendor=Oracle Corporation, sun.arch.data.model=64, user.variant=, java.vendor.url=https://java.oracle.com/, java.vm.specification.version=15, os.name=Windows 10, sun.java.launcher=SUN_STANDARD, user.country=CN, sun.boot.library.path=D:\Java\jdk-15.0.1\bin, sun.java.command=com.arloor.forwardproxy.monitor.HeapMain, jdk.debug=release, sun.cpu.endian=little, user.home=C:\Users\arloor, user.language=zh, java.specification.vendor=Oracle Corporation, java.version.date=2020-10-20, java.home=D:\Java\jdk-15.0.1, file.separator=\, line.separator=
, java.vm.specification.vendor=Oracle Corporation, java.specification.name=Java Platform API Specification, intellij.debug.agent=true, user.script=, sun.management.compiler=HotSpot 64-Bit Tiered Compilers, java.runtime.version=15.0.1+9-18, user.name=arloor, path.separator=;, os.version=10.0, java.runtime.name=Java(TM) SE Runtime Environment, file.encoding=UTF-8, java.vm.name=Java HotSpot(TM) 64-Bit Server VM, java.vendor.url.bug=https://bugreport.java.com/bugreport/, java.io.tmpdir=C:\Users\arloor\AppData\Local\Temp\, java.version=15.0.1, jboss.modules.system.pkgs=com.intellij.rt, user.dir=E:\IdeaProjects\HttpProxy, os.arch=amd64, java.vm.specification.name=Java Virtual Machine Specification, sun.os.patch.level=, java.library.path=D:\Java\jdk-15.0.1\bin;C:\Windows\Sun\Java\bin;C:\Windows\system32;C:\Windows;C:\Program Files\Common Files\Oracle\Java\javapath;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Windows\System32\OpenSSH\;D:\Java\jdk-15.0.1\bin;C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common;C:\Program Files\NVIDIA Corporation\NVIDIA NvDLISR;D:\bin;D:\git\bin;D:\apache-maven-3.6.3-bin\apache-maven-3.6.3\bin;C:\Users\arloor\.cargo\bin;C:\Users\arloor\AppData\Local\Programs\Python\Python38-32\Scripts\;C:\Users\arloor\AppData\Local\Programs\Python\Python38-32\;C:\Users\arloor\AppData\Local\Microsoft\WindowsApps;;D:\Microsoft VS Code\bin;., java.vm.info=mixed mode, sharing, java.vendor=Oracle Corporation, java.vm.version=15.0.1+9-18, sun.io.unicode.encoding=UnicodeLittle, java.class.version=59.0}
------------------------------------------------------------------------------------------------------
compilation.name(编译器名称)：HotSpot 64-Bit Tiered Compilers
compilation.total.time(编译器耗时)：203毫秒
支持即时编译器编译监控
------------------------------------------------------------------------------------------------------jvm.threads.total.count (总线程数(守护+非守护)):8
jvm.threads.daemon.count (守护进程线程数):6
jvm.threads.peak.count (峰值线程数):8
jvm.threads.total.start.count(Java虚拟机启动后创建并启动的线程总数):8
threadId: 1 | threadName: main
threadId: 2 | threadName: Reference Handler
threadId: 3 | threadName: Finalizer
threadId: 4 | threadName: Signal Dispatcher
threadId: 5 | threadName: Attach Listener
threadId: 12 | threadName: Common-Cleaner
threadId: 16 | threadName: Notification Thread
threadId: 17 | threadName: Thread-0
------------------------------------------------------------------------------------------------------
collectorMXBean.getCollectionCount(ZGC 垃圾回收器执行次数):0
collectorMXBean.getCollectionTime(ZGC 垃圾回收器执行时间):0
------------------------------------------------------------------------------------------------------
jvm.heap.init (初始化堆内存):256 MB 
jvm.heap.used (已使用堆内存):46 MB 
jvm.heap.committed (可使用堆内存):256 MB 
jvm.heap.max (最大堆内存):4,084 MB 
------------------------------------------------------------------------------------------------------
jvm.noheap.init (初始化非堆内存):7 MB 
jvm.noheap.used (已使用非堆内存):3 MB 
jvm.noheap.committed (可使用非堆内存):12 MB 
jvm.noheap.max (最大非堆内存):0 MB 
------------------------------------------------------------------------------------------------------
os.name(操作系统名称-版本号):Windows 10 version 10.0 
os.arch(操作系统内核):amd64
os.cores(可用的处理器数量):8 
os.loadAverage(系统负载平均值):-1.0 
------------------------------------------------------------------------------------------------------
class.current.load.count(当前加载类数量):1123 
class.unload.count(未加载类数量):0 
class.total.load.count(总加载类数量):1123 
------------------------------------------------------------------------------------------------------
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-nmethods', jvm.CodeHeap 'non-nmethods'.init(初始化):2 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-nmethods', jvm.CodeHeap 'non-nmethods'.used(已使用): 1 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-nmethods', jvm.CodeHeap 'non-nmethods'.committed(可使用):2 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-nmethods', jvm.CodeHeap 'non-nmethods'.max(最大):5 MB
------------------------------------------------------------------------------------------------------
内存模型： NON_HEAP(非堆内存), 内存空间名称： Metaspace(元空间), jvm.Metaspace.init(初始化):0 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： Metaspace(元空间), jvm.Metaspace.used(已使用): 1 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： Metaspace(元空间), jvm.Metaspace.committed(可使用):4 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： Metaspace(元空间), jvm.Metaspace.max(最大):0 MB
------------------------------------------------------------------------------------------------------
内存模型： HEAP(堆内存), 内存空间名称： ZHeap, jvm.ZHeap.init(初始化):42 MB
内存模型： HEAP(堆内存), 内存空间名称： ZHeap, jvm.ZHeap.used(已使用): 50 MB
内存模型： HEAP(堆内存), 内存空间名称： ZHeap, jvm.ZHeap.committed(可使用):256 MB
内存模型： HEAP(堆内存), 内存空间名称： ZHeap, jvm.ZHeap.max(最大):4,084 MB
------------------------------------------------------------------------------------------------------
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'profiled nmethods', jvm.CodeHeap 'profiled nmethods'.init(初始化):2 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'profiled nmethods', jvm.CodeHeap 'profiled nmethods'.used(已使用): 0 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'profiled nmethods', jvm.CodeHeap 'profiled nmethods'.committed(可使用):2 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'profiled nmethods', jvm.CodeHeap 'profiled nmethods'.max(最大):117 MB
------------------------------------------------------------------------------------------------------
内存模型： NON_HEAP(非堆内存), 内存空间名称： Compressed Class Space(类指针压缩空间), jvm.Compressed Class Space.init(初始化):0 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： Compressed Class Space(类指针压缩空间), jvm.Compressed Class Space.used(已使用): 0 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： Compressed Class Space(类指针压缩空间), jvm.Compressed Class Space.committed(可使用):0 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： Compressed Class Space(类指针压缩空间), jvm.Compressed Class Space.max(最大):1,024 MB
------------------------------------------------------------------------------------------------------
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-profiled nmethods', jvm.CodeHeap 'non-profiled nmethods'.init(初始化):2 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-profiled nmethods', jvm.CodeHeap 'non-profiled nmethods'.used(已使用): 0 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-profiled nmethods', jvm.CodeHeap 'non-profiled nmethods'.committed(可使用):2 MB
内存模型： NON_HEAP(非堆内存), 内存空间名称： CodeHeap 'non-profiled nmethods', jvm.CodeHeap 'non-profiled nmethods'.max(最大):117 MB
------------------------------------------------------------------------------------------------------
cpu使用率：0.3852317554240631 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.0 ,gc使用率：0.0 
cpu使用率：0.19280602171767028 ,gc使用率：0.0
```