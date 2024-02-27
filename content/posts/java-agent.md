---
title: "Java Agent实现指南"
date: 2022-03-07T14:11:11+08:00
draft: false
categories: [ "undefined"]
tags: ["observability","obs","java"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

Java Agent是字节码修改技术，Mtrace使用Java Agent修改字节码来实现trace的跨线程传递，opentelemetry也通过Java Agent来实现该需求。

<!--more-->

## 两种加载方式

### 静态加载

静态加载就是在java的启动命令中指定javaagent的路径。

```
JAVA_AGENT_JAR_PARH=java-agent.jar
java -Xbootclasspath/a:${JAVA_AGENT_JAR_PARH} -javaagent:${JAVA_AGENT_JAR_PARH} -jar xxxx.jar
```

### 动态加载

```java
String name = ManagementFactory.getRuntimeMXBean().getName();
String pid = name.split("@")[0];
final VirtualMachine vm = VirtualMachine.attach(pid);
vm.loadAgent(${JAVA_AGENT_JAR_PARH},${ARGS});
vm.detach();
```

> VirtualMachine在jdk（非jre）下的lib/tools.jar，classpath可能不包含该jar包，需要反射调用URLClassLoader类的addURL方法增加tools.jar，然后再得到VirtualMachine类，如下：

```java
import java.io.File;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.security.AccessController;
import java.security.PrivilegedActionException;
import java.security.PrivilegedExceptionAction;
import java.util.ArrayList;
import java.util.List;

/**
 * 从lib/tools.jar加载VirtualMachine
 */
public class VmClassLoader {
    private static final String VIRTUAL_MACHINE_CLASSNAME = "com.sun.tools.attach.VirtualMachine";
    private static volatile Class<?> vmClass;

    static {
        try {
            vmClass = getVirtualMachineClass();
        } catch (ClassNotFoundException e) {
            System.err.println("not found tools.jar");
        }
    }

    public static Class<?> getVmClass() {
        return vmClass;
    }

    private static Class<?> getVirtualMachineClass() throws ClassNotFoundException {
        try {
            return AccessController.doPrivileged(new PrivilegedExceptionAction<Class<?>>() {
                public Class<?> run() throws Exception {
                    try {
                        return ClassLoader.getSystemClassLoader().loadClass(VIRTUAL_MACHINE_CLASSNAME);
                    } catch (ClassNotFoundException cnfe) {
                        for (File jar : getPossibleToolsJars()) {
                            try {
                                Method method = URLClassLoader.class.getDeclaredMethod("addURL", URL.class);
                                method.setAccessible(true);
                                method.invoke(ClassLoader.getSystemClassLoader(), jar.toURI().toURL());

                                return ClassLoader.getSystemClassLoader().loadClass(VIRTUAL_MACHINE_CLASSNAME);
                            } catch (Exception t) {
                                System.err.println("Exception while loading tools.jar from  " + jar + " " + ExceptionUtil.getMessage(t));
                            }
                        }
                        throw new ClassNotFoundException(VIRTUAL_MACHINE_CLASSNAME);
                    }
                }
            });
        } catch (PrivilegedActionException pae) {
            Throwable actual = pae.getCause();
            if (actual instanceof ClassNotFoundException) {
                throw (ClassNotFoundException) actual;
            }
            throw new AssertionError("Unexpected checked exception : " + actual);
        }
    }

    private static List<File> getPossibleToolsJars() {
        List<File> jars = new ArrayList<>();

        File javaHome = new File(System.getProperty("java.home"));
        File jreSourced = new File(javaHome, "lib/tools.jar");
        if (jreSourced.exists()) {
            jars.add(jreSourced);
        }
        if ("jre".equals(javaHome.getName())) {
            File jdkHome = new File(javaHome, "../");
            File jdkSourced = new File(jdkHome, "lib/tools.jar");
            if (jdkSourced.exists()) {
                jars.add(jdkSourced);
            }
        }
        return jars;
    }
}
```

## Java Agent Jar包规范

Java Agent是以单独jar包的形式发布的，jar包本身有一些规范：

`MANIFEST.MF`文件，静态加载必须指定`Premain-Class`这个类；动态加载必须指定`Agent-Class`。通常也会加入`Can-Redefine-Classes` 和 `Can-Retransform-Classes` 选项。

`Premain-Class`一定要有premain方法，动态加载一定要有agentmain方法

`MANIFEST.MF`可以使用maven的`maven-jar-plugin`进行配置：

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.meituan.mtrace</groupId>
    <artifactId>mtrace-agent</artifactId>
    <version>1.3.1-SNAPSHOT</version>
    <dependencies>
        <dependency>
            <groupId>org.javassist</groupId>
            <artifactId>javassist</artifactId>
            <version>3.21.0-GA</version>
        </dependency>
    </dependencies>
    <packaging>jar</packaging>
    <name>${project.artifactId}</name>
    <build>
        <plugins>
            <plugin>
                <artifactId>maven-jar-plugin</artifactId>
                <version>3.0.2</version>
                <configuration>
                    <archive>
                        <manifestEntries>
                            <Premain-Class>com.meituan.mtrace.agent.Agent</Premain-Class>
                            <Agent-Class>com.meituan.mtrace.agent.Agent</Agent-Class>
                            <Boot-Class-Path>${project.artifactId}-${project.version}.jar</Boot-Class-Path>
                            <Can-Redefine-Classes>true</Can-Redefine-Classes>
                            <Can-Retransform-Classes>true</Can-Retransform-Classes>
                            <Can-Set-Native-Method-Prefix>false</Can-Set-Native-Method-Prefix>
                        </manifestEntries>
                    </archive>
                </configuration>
            </plugin>
            <plugin>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.0.0</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <createSourcesJar>true</createSourcesJar>
                            <relocations>
                                <relocation>
                                    <pattern>javassist</pattern>
                                    <shadedPattern>com.meituan.mtrace.agent.javassist</shadedPattern>
                                </relocation>
                            </relocations>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>

</project>
```

这里面还有个maven-shade-plugin插件将javassist的类移动到com.meituan.mtrace.agent.javassist。这么做的原因是避开类加载导致的问题，先不展开

## Agent如何做字节码修改的？

### 1.通过Instrumentation注册ClassFileTransformer

直接看Premain-class和Agent-class的定义，在我们这里名字就是Agent

```java
import java.io.*;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.jar.JarFile;


public class Agent {
    private Agent() {
        throw new InstantiationError("Must not instantiate this class");
    }

    /**
     * 静态加载
     */
    public static void premain(String agentArgs, Instrumentation instrumentation) {
        System.out.println("premain start");
        install(agentArgs, instrumentation, false);
        System.out.println("premain end");
    }

    /**
     * 动态加载
     */
    public static void agentmain(String agentArgs, Instrumentation instrumentation) {
        System.out.println("agentmain start");
        install(agentArgs, instrumentation, true);
        System.out.println("agentmain end");
    }

    static synchronized void install(String agentArgs, Instrumentation instrumentation, boolean atRuntime) {
        ClassFileTransformer transformer = new PoolTransformer();
        try {
            // 主动寻找agentJar中的TraceRunnable等类
            // 否则会报 compile error: no such class: com.meituan.mtrace.thread.TraceRunnable
            if (atRuntime) {
                instrumentation.appendToBootstrapClassLoaderSearch(new JarFile(new File(agentArgs)));
            }
        } catch (IOException e) {
            System.out.println(ExceptionUtil.getMessage(e));
        }
        instrumentation.addTransformer(transformer, true);
        if (atRuntime) {
            // Transformer触发的时机是类加载时，redefine时和retransform时
            // ForkJoinTask会在之后进行类加载，那是会触发transformer
            // 而ThreadPoolExecutor和ScheduledThreadPoolExecutor在之前已经类加载了
            // 所以需要手动retransform一下
            try {
                ClassLoader.getSystemClassLoader().loadClass("java.util.concurrent.ThreadPoolExecutor");
                ClassLoader.getSystemClassLoader().loadClass("java.util.concurrent.ScheduledThreadPoolExecutor");
                instrumentation.retransformClasses(ThreadPoolExecutor.class, ScheduledThreadPoolExecutor.class);
            } catch (Exception e) {
                System.out.println(ExceptionUtil.getMessage(e));
            }
        }
    }

}
```

用伪代码描述是

1. 将让BootstrapClassloader加载agent.jar中的类

    1. 一定需要使用BootstrapClassloader加载agent.jar中的类，可以使用如下两种方式
    ```
    启动参数：-Xbootclasspath/a:${JAVA_AGENT_JAR_PARH}
    运行时代码：instrumentation.appendToBootstrapClassLoaderSearch(new JarFile(new File(agentArgs)))
    ```

2. 注册ClassFileTransformer，ClassFileTransformer去做具体的字节码修改，内部使用javassist实现。

3. 由于字节码的修改触发时间是类加载、retransform、redefine。对于已经被类加载的类需要手动retransform才会触发字节码修改。

    1. 如果静态加载agent，则agent的加载早于其他类，则不需要手动retransform。

4. 如果希望ClassFileTransformer是一次性的，其他agent（idea远程debug，arthas）接入时这些变更不再来一遍，调用inst.removeTransformer(transformer);

### 2.ClassFileTransformer使用javassist修改字节码

ClassFileTransformer接口定义如下，只有一个transform接口

```java
public interface ClassFileTransformer {
    /**
     * 部分Java DOC
     * @param loader                the defining loader of the class to be transformed,
     *                              may be <code>null</code> if the bootstrap loader
     * @param className             the name of the class in the internal form of fully
     *                              qualified class and interface names as defined in
     *                              <i>The Java Virtual Machine Specification</i>.
     *                              For example, <code>"java/util/List"</code>.
     * @param classBeingRedefined   if this is triggered by a redefine or retransform,
     *                              the class being redefined or retransformed;
     *                              if this is a class load, <code>null</code>
     * @param protectionDomain      the protection domain of the class being defined or redefined
     * @param classfileBuffer       the input byte buffer in class file format - must not be modified
     *
     * @throws IllegalClassFormatException if the input does not represent a well-formed class file
     * @return  a well-formed class file buffer (the result of the transform),
                or <code>null</code> if no transform is performed.
     * @see Instrumentation#redefineClasses
     */
    byte[]
    transform(  ClassLoader         loader,
                String              className,
                Class<?>            classBeingRedefined,
                ProtectionDomain    protectionDomain,
                byte[]              classfileBuffer)
        throws IllegalClassFormatException;
}
```


一个ClassFIleTranformer的实现:

```java
import javassist.ClassPool;
import javassist.CtClass;
import javassist.LoaderClassPath;
import javassist.CtClass;
import javassist.CtMethod;
import java.lang.reflect.Modifier;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.IllegalClassFormatException;
import java.security.ProtectionDomain;
import java.util.HashSet;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;

public class PoolTransformer implements ClassFileTransformer {
    private static final Logger log = Logger.getLogger(AbstractTransformer.class.getName());
    private Set<String> targetClasses = new HashSet();

    public AbstractTransformer() {
        this.targetClasses.addAll(this.targets());
    }

    public Set<String> getTargetClasses() {
        return this.targetClasses;
    }

    public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined, ProtectionDomain protectionDomain, byte[] classfileBuffer) throws IllegalClassFormatException {
        if (className != null && className.length() != 0 && classfileBuffer != null && classfileBuffer.length != 0) {
            if (!this.targetClasses.contains(className)) {
                return null;
            } else {
                boolean atClassLoading = classBeingRedefined == null;
                log.log(Level.INFO, "Transforming class " + className + " @classloading?" + atClassLoading);
                try {
                    return this.doTransform(this.getCtClass(loader, classfileBuffer));
                } catch (Throwable var7) {
                    return null;
                }
            }
        } else {
            return null;
        }
    }

    private CtClass getCtClass(ClassLoader loader, byte[] classfileBuffer) throws IOException {
        ClassPool classPool = new ClassPool(true);
        if (loader == null) {
            classPool.appendClassPath(new LoaderClassPath(ClassLoader.getSystemClassLoader()));
        } else {
            classPool.appendClassPath(new LoaderClassPath(loader));
        }

        classPool.importPackage("com.meituan.mtrace.agent.runtime.wrapper");
        classPool.importPackage("java.util.concurrent");
        CtClass ctClass = classPool.makeClass(new ByteArrayInputStream(classfileBuffer), false);
        ctClass.defrost();
        return ctClass;
    }

    Set<String> targets() {
        return new HashSet(Arrays.asList("java/util/concurrent/ThreadPoolExecutor","java/util/concurrent/ScheduledThreadPoolExecutor"));
    }

    public boolean isBootstrap() {
        return true;
    }

        byte[] doTransform(CtClass ctClass) throws Exception {
        CtMethod[] methods = ctClass.getDeclaredMethods();
        int length = methods.length;

        for (int index = 0; index < length; ++index) {
            CtMethod method = methods[index];
            int modifiers = method.getModifiers();
            if (Modifier.isPublic(modifiers) && !Modifier.isStatic(modifiers)) {
                StringBuilder builder = new StringBuilder();
                CtClass[] types = method.getParameterTypes();

                for (int i = 0; i < types.length; ++i) {
                    if ("java.lang.Runnable".equals(types[i].getName())) {
                        builder.append(String.format("if (TaskWrapper.shouldReform() && $%d != null) { $%d = TaskWrapper.wrapRunnable($%d, \"%s\"); }", i + 1, i + 1, i + 1, method.getName()));
                    } else if ("java.util.concurrent.Callable".equals(types[i].getName())) {
                        builder.append(String.format("if (TaskWrapper.shouldReform() && $%d != null) { $%d = TaskWrapper.wrapCallable($%d, \"%s\"); }", i + 1, i + 1, i + 1, method.getName()));
                    }
                }

                if (builder.length() > 0) {
                    method.insertBefore(builder.toString());
                }
            }
        }

        return ctClass.toBytecode();
    }
}
```

伪代码:

1. 从classfileBuffer中生成javassist的CtClass对象——对字节码的抽象，并且可以进行修改。

2. 修改CtClass对象，插入一些增强代码。

## 类加载问题（动态加载中存在）

以上介绍了agent开发的全部过程，但是知道上面的内容并不能开发一个正确的agent，特别是能够动态加载的agent，根因就是类加载问题。

### 问题案例

arthas反编译我们修改后的ThreadPoolExecutor类，看到已经被正确的修改了——字节码修改生效了。

但是却没有达成我们的目标——跨线程传递span，为什么？

## 根因

很长一段时间，我一筹莫展，直到用arthas的jad反编译来看看字节码修改是否生效，才发现了一些端倪：
![](/img/arthas-jad-trace-runnable.png)

TraceRunnable、Context等类竟然有两个类，一个由SystemClassLoader加载（AppClassLoader），一个由BootstrapClassLoader加载（null）。mtrace的跨线程传递trace其实就是将当前span放到threadlocal中，跨线程时把父线程的threadlocal的span放置到子线程的threadlocal中。而Context类就是threadlocal的容器。但是现在Context类实际有两个，业务代码把span放到ContextA类中，threapool从ContextB类中拿span，但是ContextB中并没有span，这就导致了跨线程传递失败。

存放threadlocal的类的Context定义：

```java
public class Context {
    private static final ThreadLocal<Object> SERVER_CONTEXT = new ThreadLocal<Object>();
    private static final ThreadLocal<Object> CLIENT_CONTEXT = new ThreadLocal<Object>();

    public static Object getServerContext() {
        return SERVER_CONTEXT.get();
    }

    public static Object getClientContext() {
        return CLIENT_CONTEXT.get();
    }

    public static void setServerContext(Object obj) {
        SERVER_CONTEXT.set(obj);
    }

    public static void setClientContext(Object obj) {
        CLIENT_CONTEXT.set(obj);
    }

    public static void removeServerContext() {
        SERVER_CONTEXT.remove();
    }

    public static void removeClientContext() {
        CLIENT_CONTEXT.remove();
    }
}
```

经过反复试验，如果在加载agent前，业务代码加载了TraceRunnale（进一步加载了Context类），则跨线程透传失败——根因是生成了不同的Context类。如果在加载agent之后，才使用TraceRunnable，那么会直接使用agent中由BootstrapClassloader加载的TraceRunnable——只有一个Context类，跨线程透传成功。

### 解决

避免在Agent中加载任何会使用Context类的类，比如TraceRunnable等。

最终我们采用一种类似“代理模式”的设计。agent中使用的TaskWrapper是一个代理，真实实现（TraceRunnable）在非agent中注册进去。

TaskWrapper定义：

```java
import java.util.concurrent.Callable;

public class TaskWrapper {
    private static TaskWrapper.Reformer reformer; //真实实现

    public TaskWrapper() {
    }

    public static void registerReformer(TaskWrapper.Reformer r) { // 提供运行时注册方案
        reformer = r;
    }

    public static boolean shouldReform() {
        return reformer == null ? false : reformer.shouldReform();
    }

    public static Runnable wrapRunnable(Runnable runnable, String methodName) {
        return reformer == null ? runnable : reformer.wrapRunnable(runnable, methodName);
    }

    public static Callable wrapCallable(Callable callable, String methodName) {
        return reformer == null ? callable : reformer.wrapCallable(callable, methodName);
    }

    public interface Reformer {
        boolean shouldReform();

        Runnable wrapRunnable(Runnable runnable, String methodName);

        Callable wrapCallable(Callable callable, String methodName);
    }
}
```

具体在非agent中注册进去的过程是：

```java
//  1. 动态加载agent
String name = ManagementFactory.getRuntimeMXBean().getName();
String pid = name.split("@")[0];
final VirtualMachine vm = VirtualMachine.attach(pid);
vm.loadAgent(${JAVA_AGENT_JAR_PARH},${ARGS});
vm.detach();
// 2. 注册reformer
            TaskWrapper.registerReformer(new TaskWrapper.Reformer() {
                @Override
                public boolean shouldReform() {
                    return Tracer.id() != null;
                }

                @Override
                public Runnable wrapRunnable(Runnable runnable, String methodName) {
                    return TraceRunnable.get(runnable);
                }

                @Override
                public Callable wrapCallable(Callable callable, String methodName) {
                    return TraceCallable.get(callable);
                }
            });
```

可能唯一要注意的是TaskWrapper.register也要在vm.loadAgent后面，否则的话TaskWrapper也会加载两遍。

### Java Agent中类加载的更多信息

javaDoc中有一段描述：

```
* <p> The agent should take care to ensure that the JAR does not contain any* classes or resources other than those to be defined by the bootstrap* class loader for the purpose of instrumentation.* Failure to observe this warning could result in unexpected* behavior that is difficult to diagnose. For example, suppose there is a* loader L, and L's parent for delegation is the bootstrap class loader.* Furthermore, a method in class C, a class defined by L, makes reference to* a non-public accessor class C$1. If the JAR file contains a class C$1 then* the delegation to the bootstrap class loader will cause C$1 to be defined* by the bootstrap class loader. In this example an <code>IllegalAccessError</code>* will be thrown that may cause the application to fail. One approach to* avoiding these types of issues, is to use a unique package name for the* instrumentation classes.
```

类加载问题会导致一些奇怪问题，上述javaDoc举了一个例子。[Java Agent 的类加载隔离实现 | Poison (tianshuang.me)](https://tianshuang.me/2021/10/Java-Agent-%E7%9A%84%E7%B1%BB%E5%8A%A0%E8%BD%BD%E9%9A%94%E7%A6%BB%E5%AE%9E%E7%8E%B0/)这篇博客举了另一个例子，他解释了为什么要用Maven Shade Plugin去做一些relocation，通过移动包路径改变类名，从而消灭同名但由不同类加载器加载导致的不同类存在，并且给出了opentelemtry、elasticsearch APM agent的agent类加载隔离实现。

我们直接跳到opentelemtry的类加载隔离实现：[opentelemetry-java-instrumentation/javaagent-jar-components.md at main · open-telemetry/opentelemetry-java-instrumentation (github.com)](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/docs/contributing/javaagent-jar-components.md)

这个文档先陈述了一个事实——**agentJar中的类除了Premain-Class/Agent-class由SystemClassLoader（应用类加载器）加载，其他类都由BootstrapClassloader加载**。

### 其他注意点

对于ThreadPoolExecutor的封装比较简单，对于ForkJoinPool的封装需要对ForkJoinTask进行修改，而且需要增加Field。**JVM规范里写到，一旦一个类被加载后，他的scheme不能被改变，也就是不能增减属性和方法**。如果在ForkJoinTask已经被类加载后尝试修改，会失败并报错：

```java
java.lang.UnsupportedOperationException: class redefinition failed: attempted to change the schema (add/remove fields)
	at sun.instrument.InstrumentationImpl.retransformClasses0(Native Method) ~[?:1.8.0_251]
	at sun.instrument.InstrumentationImpl.retransformClasses(InstrumentationImpl.java:144) ~[?:1.8.0_251]
	at com.meituan.mtrace.agent.runtime.Injector.doRetransform(Injector.java:68) [?:?]
	at com.meituan.mtrace.agent.runtime.Injector.inject(Injector.java:48) [?:?]
	at com.meituan.mtrace.agent.runtime.Injector.start(Injector.java:26) [?:?]
	at com.meituan.mtrace.agent.runtime.AgentLaunch.start(AgentLaunch.java:45) [?:?]
	at com.meituan.mtrace.agent.runtime.AgentLaunch.agentmain(AgentLaunch.java:25) [?:?]
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method) ~[?:1.8.0_251]
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62) ~[?:1.8.0_251]
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43) ~[?:1.8.0_251]
	at java.lang.reflect.Method.invoke(Method.java:498) ~[?:1.8.0_251]
	at sun.instrument.InstrumentationImpl.loadClassAndStartAgent(InstrumentationImpl.java:386) [?:1.8.0_251]
	at sun.instrument.InstrumentationImpl.loadClassAndCallAgentmain(InstrumentationImpl.java:411) [?:1.8.0_251]
```

## 参考文档

[详解常用类加载器：ContextClassLoader | 静坐听雨，无问西东 (jawhiow.github.io)](https://jawhiow.github.io/2019/04/24/java/%E8%AF%A6%E8%A7%A3%E5%B8%B8%E7%94%A8%E7%B1%BB%E5%8A%A0%E8%BD%BD%E5%99%A8%EF%BC%9AContextClassLoader/)

[Java Agent 的类加载隔离实现 | Poison (tianshuang.me)](https://tianshuang.me/2021/10/Java-Agent-%E7%9A%84%E7%B1%BB%E5%8A%A0%E8%BD%BD%E9%9A%94%E7%A6%BB%E5%AE%9E%E7%8E%B0/)