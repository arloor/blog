---
title: "ZGC使用"
date: 2021-01-16T16:23:24+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 安装jdk15

```
wget "http://cdn.arloor.com/jdk/jdk-15.0.1_linux-x64_bin.rpm" -O jdk15.rpm
rpm -ivh jdk15.rpm
update-alternatives --config java
```

### jvm 参数

```
gc_option="-XX:+UseZGC -Xlog:safepoint,classhisto*=trace,age*,gc*=info:file=/opt/proxy/gc.log:uptime,tid,tags"
heap_option='-Xms400m -Xmx400m'
```

### GC日志

```shell
[0.004s][59574][gc,init] Initializing The Z Garbage Collector
[0.004s][59574][gc,init] Version: 15.0.1+9-18 (release)
[0.004s][59574][gc,init] NUMA Support: Disabled
[0.004s][59574][gc,init] CPUs: 1 total, 1 available
[0.004s][59574][gc,init] Memory: 1989M
[0.004s][59574][gc,init] Large Page Support: Disabled
[0.004s][59574][gc,init] Workers: 1 parallel, 1 concurrent
[0.004s][59574][gc,init] Address Space Type: Contiguous/Unrestricted/Complete
[0.004s][59574][gc,init] Address Space Size: 6400M x 3 = 19200M
[0.004s][59574][gc,init] Heap Backing File: /memfd:java_heap
[0.004s][59574][gc,init] Heap Backing Filesystem: tmpfs (0x1021994)
[0.004s][59574][gc,init] Min Capacity: 400M
[0.004s][59574][gc,init] Initial Capacity: 400M
[0.004s][59574][gc,init] Max Capacity: 400M
[0.004s][59574][gc,init] Max Reserve: 10M
[0.004s][59574][gc,init] Medium Page Size: 8M
[0.004s][59574][gc,init] Pre-touch: Disabled
[0.004s][59574][gc,init] Available space on backing filesystem: N/A
[0.004s][59574][gc,init] Uncommit: Implicitly Disabled (-Xms equals -Xmx)
[0.139s][59574][gc,init] Runtime Workers: 1 parallel
[0.139s][59574][gc     ] Using The Z Garbage Collector
[0.140s][59574][gc,metaspace] CDS archive(s) mapped at: [0x0000000800000000-0x0000000800b26000-0x0000000800b26000), size 11689984, SharedBaseAddress: 0x0000000800000000, ArchiveRelocationMode: 0.
[0.140s][59574][gc,metaspace] Compressed class space mapped at: 0x0000000800b28000-0x0000000840b28000, size: 1073741824
[0.140s][59574][gc,metaspace] Narrow klass base: 0x0000000800000000, Narrow klass shift: 3, Narrow klass range: 0x100000000
[1.203s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 1054578168 ns, Reaching safepoint: 90927 ns, At safepoint: 1949 ns, Total: 92876 ns
[1.255s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 52031842 ns, Reaching safepoint: 45133 ns, At safepoint: 3130 ns, Total: 48263 ns
[1.256s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 559753 ns, Reaching safepoint: 34422 ns, At safepoint: 2716 ns, Total: 37138 ns
[1.256s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 536179 ns, Reaching safepoint: 32911 ns, At safepoint: 2551 ns, Total: 35462 ns
[1.257s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 503311 ns, Reaching safepoint: 15273 ns, At safepoint: 2325 ns, Total: 17598 ns
[1.258s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 540182 ns, Reaching safepoint: 17729 ns, At safepoint: 2509 ns, Total: 20238 ns
[1.258s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 601927 ns, Reaching safepoint: 20443 ns, At safepoint: 2750 ns, Total: 23193 ns
[1.259s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 549278 ns, Reaching safepoint: 18594 ns, At safepoint: 2632 ns, Total: 21226 ns
[1.259s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 512627 ns, Reaching safepoint: 23279 ns, At safepoint: 3290 ns, Total: 26569 ns
[1.260s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 527167 ns, Reaching safepoint: 16536 ns, At safepoint: 2508 ns, Total: 19044 ns
[1.260s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 529278 ns, Reaching safepoint: 17327 ns, At safepoint: 2552 ns, Total: 19879 ns
[1.261s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 568250 ns, Reaching safepoint: 26441 ns, At safepoint: 3671 ns, Total: 30112 ns
[1.267s][59582][safepoint   ] Safepoint "ICBufferFull", Time since last: 6322579 ns, Reaching safepoint: 24277 ns, At safepoint: 2980 ns, Total: 27257 ns
[1.760s][59579][gc,start    ] GC(0) Garbage Collection (Warmup)
[1.790s][59582][gc,phases   ] GC(0) Pause Mark Start 0.649ms
[1.790s][59582][safepoint   ] Safepoint "ZMarkStart", Time since last: 504312373 ns, Reaching safepoint: 17972836 ns, At safepoint: 684237 ns, Total: 18657073 ns
[1.912s][59579][gc,phases   ] GC(0) Concurrent Mark 122.182ms
[1.913s][59582][gc,phases   ] GC(0) Pause Mark End 0.038ms
[1.913s][59582][safepoint   ] Safepoint "ZMarkEnd", Time since last: 122236407 ns, Reaching safepoint: 112448 ns, At safepoint: 55431 ns, Total: 167879 ns
[1.936s][59579][gc,phases   ] GC(0) Concurrent Process Non-Strong References 13.056ms
[1.937s][59579][gc,phases   ] GC(0) Concurrent Reset Relocation Set 0.001ms
[2.134s][59579][gc,phases   ] GC(0) Concurrent Select Relocation Set 197.081ms
[2.135s][59582][gc,phases   ] GC(0) Pause Relocate Start 0.302ms
[2.135s][59582][safepoint   ] Safepoint "ZRelocateStart", Time since last: 221185606 ns, Reaching safepoint: 719916 ns, At safepoint: 328152 ns, Total: 1048068 ns
[2.174s][59579][gc,phases   ] GC(0) Concurrent Relocate 39.366ms
[2.174s][59579][gc,load     ] GC(0) Load: 0.24/0.06/0.04
[2.174s][59579][gc,mmu      ] GC(0) MMU: 2ms/67.5%, 5ms/87.0%, 10ms/93.5%, 20ms/96.8%, 50ms/98.7%, 100ms/99.4%
[2.174s][59579][gc,marking  ] GC(0) Mark: 1 stripe(s), 3 proactive flush(es), 1 terminate flush(es), 1 completion(s), 0 continuation(s)
[2.174s][59579][gc,nmethod  ] GC(0) NMethods: 1212 registered, 0 unregistered
[2.174s][59579][gc,metaspace] GC(0) Metaspace: 13M used, 13M capacity, 14M committed, 1038M reserved
[2.174s][59579][gc,ref      ] GC(0) Soft: 2771 encountered, 0 discovered, 0 enqueued
[2.174s][59579][gc,ref      ] GC(0) Weak: 710 encountered, 569 discovered, 138 enqueued
[2.174s][59579][gc,ref      ] GC(0) Final: 8 encountered, 3 discovered, 2 enqueued
[2.174s][59579][gc,ref      ] GC(0) Phantom: 117 encountered, 111 discovered, 97 enqueued
[2.174s][59579][gc,reloc    ] GC(0) Small Pages: 18 / 36M(90%), Empty: 0M(0%), Compacting: 34M(85%)->8M(20%)
[2.174s][59579][gc,reloc    ] GC(0) Medium Pages: 0 / 0M(0%), Empty: 0M(0%), Compacting: 0M(0%)->0M(0%)
[2.174s][59579][gc,reloc    ] GC(0) Large Pages: 2 / 4M(10%), Empty: 2M(5%), Compacting: 0M(0%)->0M(0%)
[2.174s][59579][gc,reloc    ] GC(0) Relocation: Successful
[2.174s][59579][gc,heap     ] GC(0) Min Capacity: 400M(100%)
[2.174s][59579][gc,heap     ] GC(0) Max Capacity: 400M(100%)
[2.174s][59579][gc,heap     ] GC(0) Soft Max Capacity: 400M(100%)
[2.174s][59579][gc,heap     ] GC(0)                Mark Start          Mark End        Relocate Start      Relocate End           High               Low
[2.174s][59579][gc,heap     ] GC(0)  Capacity:      400M (100%)        400M (100%)        400M (100%)        400M (100%)        400M (100%)        400M (100%)
[2.174s][59579][gc,heap     ] GC(0)   Reserve:       10M (2%)           10M (2%)           10M (2%)           10M (2%)           10M (2%)           10M (2%)
[2.174s][59579][gc,heap     ] GC(0)      Free:      350M (88%)         346M (86%)         342M (86%)         366M (92%)         366M (92%)         340M (85%)
[2.175s][59579][gc,heap     ] GC(0)      Used:       40M (10%)          44M (11%)          48M (12%)          24M (6%)           50M (12%)          24M (6%)
[2.175s][59579][gc,heap     ] GC(0)      Live:         -                 9M (2%)            9M (2%)            9M (2%)             -                  -
[2.175s][59579][gc,heap     ] GC(0) Allocated:         -                 4M (1%)           10M (2%)           20M (5%)             -                  -
[2.175s][59579][gc,heap     ] GC(0)   Garbage:         -                30M (8%)           28M (7%)            2M (1%)             -                  -
[2.175s][59579][gc,heap     ] GC(0) Reclaimed:         -                  -                 2M (0%)           28M (7%)             -                  -
[2.175s][59579][gc          ] GC(0) Garbage Collection (Warmup) 40M(10%)->24M(6%)
[3.135s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 1000090776 ns, Reaching safepoint: 76921 ns, At safepoint: 1831 ns, Total: 78752 ns
[5.137s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 2002064821 ns, Reaching safepoint: 60635 ns, At safepoint: 1955 ns, Total: 62590 ns
[6.137s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 1000113106 ns, Reaching safepoint: 48171 ns, At safepoint: 1962 ns, Total: 50133 ns
[7.138s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 1000115816 ns, Reaching safepoint: 61347 ns, At safepoint: 1889 ns, Total: 63236 ns
[8.138s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 1000190145 ns, Reaching safepoint: 45746 ns, At safepoint: 2067 ns, Total: 47813 ns
[10.155s][59580][gc,stats    ] === Garbage Collection Statistics =======================================================================================================================
[10.155s][59580][gc,stats    ]                                                              Last 10s              Last 10m              Last 10h                Total
[10.155s][59580][gc,stats    ]                                                              Avg / Max             Avg / Max             Avg / Max             Avg / Max
[10.155s][59580][gc,stats    ]   Collector: Garbage Collection Cycle                    413.886 / 413.886     413.886 / 413.886     413.886 / 413.886     413.886 / 413.886     ms
[10.155s][59580][gc,stats    ]  Contention: Mark Segment Reset Contention                     0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]  Contention: Mark SeqNum Reset Contention                      0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]  Contention: Relocation Contention                             0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]    Critical: Allocation Stall                              0.000 / 0.000         0.000 / 0.000         0.000 / 0.000         0.000 / 0.000       ms
[10.155s][59580][gc,stats    ]    Critical: Allocation Stall                                  0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]    Critical: GC Locker Stall                               0.000 / 0.000         0.000 / 0.000         0.000 / 0.000         0.000 / 0.000       ms
[10.155s][59580][gc,stats    ]    Critical: GC Locker Stall                                   0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]      Memory: Allocation Rate                                  45 / 424              45 / 424              45 / 424              45 / 424         MB/s
[10.155s][59580][gc,stats    ]      Memory: Heap Used After Mark                             44 / 44               44 / 44               44 / 44               44 / 44          MB
[10.155s][59580][gc,stats    ]      Memory: Heap Used After Relocation                       24 / 24               24 / 24               24 / 24               24 / 24          MB
[10.155s][59580][gc,stats    ]      Memory: Heap Used Before Mark                            40 / 40               40 / 40               40 / 40               40 / 40          MB
[10.155s][59580][gc,stats    ]      Memory: Heap Used Before Relocation                      48 / 48               48 / 48               48 / 48               48 / 48          MB
[10.155s][59580][gc,stats    ]      Memory: Out Of Memory                                     0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]      Memory: Page Cache Flush                                  0 / 0                 0 / 0                 0 / 0                 0 / 0           MB/s
[10.155s][59580][gc,stats    ]      Memory: Page Cache Hit L1                                 0 / 5                 0 / 5                 0 / 5                 0 / 5           ops/s
[10.155s][59580][gc,stats    ]      Memory: Page Cache Hit L2                                 0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]      Memory: Page Cache Hit L3                                 2 / 14                2 / 14                2 / 14                2 / 14          ops/s
[10.155s][59580][gc,stats    ]      Memory: Page Cache Miss                                   0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]      Memory: Uncommit                                          0 / 0                 0 / 0                 0 / 0                 0 / 0           MB/s
[10.155s][59580][gc,stats    ]      Memory: Undo Object Allocation Failed                     0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]      Memory: Undo Object Allocation Succeeded                  0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]      Memory: Undo Page Allocation                              0 / 0                 0 / 0                 0 / 0                 0 / 0           ops/s
[10.155s][59580][gc,stats    ]       Phase: Concurrent Mark                             122.182 / 122.182     122.182 / 122.182     122.182 / 122.182     122.182 / 122.182     ms
[10.155s][59580][gc,stats    ]       Phase: Concurrent Mark Continue                      0.000 / 0.000         0.000 / 0.000         0.000 / 0.000         0.000 / 0.000       ms
[10.155s][59580][gc,stats    ]       Phase: Concurrent Process Non-Strong References     13.056 / 13.056       13.056 / 13.056       13.056 / 13.056       13.056 / 13.056      ms
[10.155s][59580][gc,stats    ]       Phase: Concurrent Relocate                          39.366 / 39.366       39.366 / 39.366       39.366 / 39.366       39.366 / 39.366      ms
[10.155s][59580][gc,stats    ]       Phase: Concurrent Reset Relocation Set               0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.155s][59580][gc,stats    ]       Phase: Concurrent Select Relocation Set            197.081 / 197.081     197.081 / 197.081     197.081 / 197.081     197.081 / 197.081     ms
[10.155s][59580][gc,stats    ]       Phase: Pause Mark End                                0.038 / 0.038         0.038 / 0.038         0.038 / 0.038         0.038 / 0.038       ms
[10.155s][59580][gc,stats    ]       Phase: Pause Mark Start                              0.649 / 0.649         0.649 / 0.649         0.649 / 0.649         0.649 / 0.649       ms
[10.155s][59580][gc,stats    ]       Phase: Pause Relocate Start                          0.302 / 0.302         0.302 / 0.302         0.302 / 0.302         0.302 / 0.302       ms
[10.155s][59580][gc,stats    ]    Subphase: Concurrent Classes Purge                      0.041 / 0.041         0.041 / 0.041         0.041 / 0.041         0.041 / 0.041       ms
[10.155s][59580][gc,stats    ]    Subphase: Concurrent Classes Unlink                     1.647 / 1.647         1.647 / 1.647         1.647 / 1.647         1.647 / 1.647       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Mark                             121.926 / 121.926     121.926 / 121.926     121.926 / 121.926     121.926 / 121.926     ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Mark Idle                          0.000 / 0.000         0.000 / 0.000         0.000 / 0.000         0.000 / 0.000       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Mark Try Flush                    20.056 / 23.579       20.056 / 23.579       20.056 / 23.579       20.056 / 23.579      ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Mark Try Terminate                10.902 / 21.803       10.902 / 21.803       10.902 / 21.803       10.902 / 21.803      ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent References Enqueue                 0.003 / 0.003         0.003 / 0.003         0.003 / 0.003         0.003 / 0.003       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent References Process                 0.122 / 0.122         0.122 / 0.122         0.122 / 0.122         0.122 / 0.122       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Roots                              0.118 / 0.118         0.118 / 0.118         0.118 / 0.118         0.118 / 0.118       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Roots ClassLoaderDataGraph         0.109 / 0.109         0.109 / 0.109         0.109 / 0.109         0.109 / 0.109       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Roots JNIHandles                   0.003 / 0.003         0.003 / 0.003         0.003 / 0.003         0.003 / 0.003       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Roots Setup                        0.005 / 0.005         0.005 / 0.005         0.005 / 0.005         0.005 / 0.005       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Roots Teardown                     0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Roots VMHandles                    0.004 / 0.004         0.004 / 0.004         0.004 / 0.004         0.004 / 0.004       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Weak Roots                         0.561 / 0.561         0.561 / 0.561         0.561 / 0.561         0.561 / 0.561       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Weak Roots JNIWeakHandles          0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Weak Roots ResolvedMethodTable     0.021 / 0.021         0.021 / 0.021         0.021 / 0.021         0.021 / 0.021       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Weak Roots StringTable             0.532 / 0.532         0.532 / 0.532         0.532 / 0.532         0.532 / 0.532       ms
[10.156s][59580][gc,stats    ]    Subphase: Concurrent Weak Roots VMWeakHandles           0.004 / 0.004         0.004 / 0.004         0.004 / 0.004         0.004 / 0.004       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Mark Try Complete                       0.003 / 0.003         0.003 / 0.003         0.003 / 0.003         0.003 / 0.003       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots                                   0.449 / 0.620         0.449 / 0.620         0.449 / 0.620         0.449 / 0.620       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots CodeCache                         0.000 / 0.000         0.000 / 0.000         0.000 / 0.000         0.000 / 0.000       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots JVMTIExport                       0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots JVMTIWeakExport                   0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots Java Threads                      0.435 / 0.607         0.435 / 0.607         0.435 / 0.607         0.435 / 0.607       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots Management                        0.001 / 0.002         0.001 / 0.002         0.001 / 0.002         0.001 / 0.002       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots ObjectSynchronizer                0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots Setup                             0.001 / 0.002         0.001 / 0.002         0.001 / 0.002         0.001 / 0.002       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots Teardown                          0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots Universe                          0.003 / 0.004         0.003 / 0.004         0.003 / 0.004         0.003 / 0.004       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Roots VM Thread                         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Weak Roots                              0.011 / 0.011         0.011 / 0.011         0.011 / 0.011         0.011 / 0.011       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Weak Roots JFRWeak                      0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Weak Roots JVMTIWeakExport              0.009 / 0.009         0.009 / 0.009         0.009 / 0.009         0.009 / 0.009       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Weak Roots Setup                        0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]    Subphase: Pause Weak Roots Teardown                     0.001 / 0.001         0.001 / 0.001         0.001 / 0.001         0.001 / 0.001       ms
[10.156s][59580][gc,stats    ]      System: Java Threads                                     10 / 10               10 / 10               10 / 10               10 / 10          threads
[10.156s][59580][gc,stats    ] =========================================================================================================================================================
[18.139s][59582][safepoint   ] Safepoint "Cleanup", Time since last: 10000813275 ns, Reaching safepoint: 60117 ns, At safepoint: 2003 ns, Total: 62120 ns
```


