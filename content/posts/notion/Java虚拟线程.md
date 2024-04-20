---
title: "Java虚拟线程"
date: 2024-04-20T12:04:13+08:00
draft: false
categories: [ "undefined"]
tags: ["java"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

# Java虚拟线程

1. thread-per-thread style。BIO
2. thread-sharing style. Reactive模式，write on complete 一个lambda表达式，异步编程十分痛苦。signal their completion to a callback，并且listener在不同的线程中，观测，trycatch等很困难。典型的就是Netty
3. **thread-per-request style with virtual threads**

详细说明：

Application code in the thread-per-request style can run in a virtual thread for the entire duration of a request, but the virtual thread consumes an OS thread only while it performs calculations on the CPU. The result is the same scalability as the asynchronous style, except it is achieved transparently: When code running in a virtual thread calls a blocking I/O operation in the `java.*` API, the runtime performs a non-blocking OS call and automatically suspends the virtual thread until it can be resumed later.

virtual thread让我们在编写IO处理程序（典型的是http服务器），可以用thread-per-request的风格编写看似同步的代码（没有call back，没有on complete，没有异步编程的复杂度）。但是这些代码只有在做CPU计算的时候才占据一个OS thread，当运行在虚拟线程中的代码调用一个阻塞IO操作时，jvm实际做了一个非阻塞的系统调用，并让出了OS thread。同时，虚拟线程也能更好地使用已有的java工具，例如stack、try catch、for循环等，因为这些代码都在一个线程里（虚拟的）

**BIO编写的便利性+reactive编程的并发性能**

**In summary, virtual threads preserve the reliable thread-per-request style that is harmonious with the design of the Java Platform while utilizing the hardware optimally.**

能够增加存在大量等待（BIO/sleep/BlockingQueue.take(））的程序的并发性

```sql
void handle(Request request, Response response) {
    var url1 = ...
    var url2 = ...
 
    try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
        var future1 = executor.submit(() -> fetchURL(url1));
        var future2 = executor.submit(() -> fetchURL(url2));
        response.send(future1.get() + future2.get());
    } catch (ExecutionException | InterruptedException e) {
        response.fail(e);
    }
}
 
String fetchURL(URL url) throws IOException {
    try (var in = url.openStream()) {
        return new String(in.readAllBytes(), StandardCharsets.UTF_8);
    }
}
```

但是不是所有的阻塞操作都可以让虚拟线程让出CPU，比如一些文件系统操作（来自操作系统），或者Object wait（来自JVM）

下面的过程会导致虚拟线程pin到平台线程上，导致不能unmount

1. When it executes code inside a `synchronized` block or method, or
2. When it executes a `native` method or a [foreign function](https://openjdk.java.net/jeps/424).

虚拟线程的stack存储在heap上

[Multithreaded Client Server Example](https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html#GUID-2DDA5807-5BD5-4ABC-B62A-A1230F0566E0)

```sql
public class EchoServer {
    
    public static void main(String[] args) throws IOException {
         
        if (args.length != 1) {
            System.err.println("Usage: java EchoServer <port>");
            System.exit(1);
        }
         
        int portNumber = Integer.parseInt(args[0]);
        try (
            ServerSocket serverSocket =
                new ServerSocket(Integer.parseInt(args[0]));
        ) {                
            while (true) {
                Socket clientSocket = serverSocket.accept();
                // Accept incoming connections
                // Start a service thread
                Thread.ofVirtual().start(() -> {
                    try (
                        PrintWriter out =
                            new PrintWriter(clientSocket.getOutputStream(), true);
                        BufferedReader in = new BufferedReader(
                            new InputStreamReader(clientSocket.getInputStream()));
                    ) {
                        String inputLine;
                        while ((inputLine = in.readLine()) != null) {
                            System.out.println(inputLine);
                            out.println(inputLine);
                        }
                    
                    } catch (IOException e) { 
                        e.printStackTrace();
                    }
                });
            }
        } catch (IOException e) {
            System.out.println("Exception caught when trying to listen on port "
                + portNumber + " or listening for a connection");
            System.out.println(e.getMessage());
        }
    }
}
```

```bash
public class EchoClient {
    public static void main(String[] args) throws IOException {
        if (args.length != 2) {
            System.err.println(
                "Usage: java EchoClient <hostname> <port>");
            System.exit(1);
        }
        String hostName = args[0];
        int portNumber = Integer.parseInt(args[1]);
        try (
            Socket echoSocket = new Socket(hostName, portNumber);
            PrintWriter out =
                new PrintWriter(echoSocket.getOutputStream(), true);
            BufferedReader in =
                new BufferedReader(
                    new InputStreamReader(echoSocket.getInputStream()));
        ) {
            BufferedReader stdIn =
                new BufferedReader(
                    new InputStreamReader(System.in));
            String userInput;
            while ((userInput = stdIn.readLine()) != null) {
                out.println(userInput);
                System.out.println("echo: " + in.readLine());
                if (userInput.equals("bye")) break;
            }
        } catch (UnknownHostException e) {
            System.err.println("Don't know about host " + hostName);
            System.exit(1);
        } catch (IOException e) {
            System.err.println("Couldn't get I/O for the connection to " +
                hostName);
            System.exit(1);
        } 
    }
}
```
