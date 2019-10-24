---
title: "Jdk8 Function"
date: 2019-10-24T22:04:01+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

不用就不会了解，不了解就不会用，今天来记一下Java8的lambda表达式相关的一点点东西。
<!--more-->

## 先上代码

```java
//Main.java
import java.util.function.Consumer;

public class Main {
    public static void main(String[] args) {
        System.out.println(dosometing(Model::aFunction));

        Model model = new Model();
        dosometing(model::aConsume);
    }

    private static String dosometing(IConvert<String, String> function) {
        return function.convert("war");
    }
    private static void dosometing(Consumer<String> function) {
        function.accept("war");
    }
}

//Model.java
public class Model {

    public void aConsume(String raw) {
        System.out.println("consume");
    }

    public static String aFunction(String raw) {
        System.out.println("function");
        return raw;
    }

    public String aProvide() {
        System.out.println("provide");
        return "provide";
    }
}

//IConvert.java
@FunctionalInterface
interface IConvert<F, T> {
    T convert(F form);
}
```

## 解释

上面代码有什么东西？能看到一个`@FunctionalInterface`注解的接口`IConvert`。还能看到`Model::aFunction`作为`IConvert`类型的参数传给了`doSomething`方法。`Model::aFunction`指的是Model类的静态方法aFunction。`model::aConsume`指的是model对象的非静态方法`aConsume`。

也就是说`Model::aFunction`是`IConvert`类型的。为什么JDK8引入这个设定？


“鸭子模型”——走得像鸭子，那他就是鸭子。这是go语言里使用的Interface原理——行为符合什么类型，就是什么类型。在java里interface接口定义的就是行为。这里的IConvert定义了一个行为`convert`，以F为参数，以T为输出。而`Model::aFunction`这个静态方法所定义的正是以F为参数，以T为输出（正确设置泛型的前提下），也就是说`Model::aFunction`这个静态方法符合`convert`行为，在鸭子模型下，`Model::aFunction`就是`IConvert`。

当然`IConvert`接口也是有一些限制的，他需要是一个`FunctionalInterface`——只有一个抽象方法的接口。也就是他只能有一个未定义方法。当然他也是可以有`default`和`static`方法的。所以`IConvert`接口也可以如下：

```java
@FunctionalInterface
interface IConvert<F, T> {
    T convert(F form);

    static void some() {
        System.out.println("static方法");
    }
    default void another() {
        System.out.println("default方法");
    }
}
```

两句话总结：

1. Class::method可以作为某Interface的实例，从而用作参数或者返回值
2. 该Interface需要符合@FunctionalInterface，也就是只有一个抽象方法

## java.util.function包

像`IConvert`一样的`@FunctionalInterface`接口其实是有一些很通用的，jdk内置了这些接口，就放在`java.util.function`包中。

有Function、Consumer、Provider这些通用的类

## 值得注意的用法：以@FunctionalInterface为返回值

以“功能接口”作为参数的用法很常用，比如各种回调函数，EventListenr等等。

以“功能接口”作为返回值（也就是“功能接口”工厂方法），则可以更加自由地给“功能接口”塞入一些属性，完成定制化。

```
    public static <T, E extends Enum<E>> Function<T, E> lookupMap(E[] values, Function<E, T> mapper) {
        Map<T, E> index = Maps.newHashMapWithExpectedSize(values.length);
        for (E value : values) {
            index.put(mapper.apply(value), value);
        }
        return (T key) -> index.get(key);
    }
```
这样一段代码，创建了一个包含Map的Funciton。这其实是一个闭包，返回的Function对象可以使用index这个引用。因为内部类可以使用外部对象的变量。——java的内部类就是闭包实现。

什么是闭包？——闭包可以让你从内部函数访问外部函数作用域。[生动形象且详细并举例子地解释闭包]([https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Closures](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Closures))

我们先看一段js代码：

```js
function makeFunc() {
    var name = "Mozilla";
    function displayName() {
        alert(name);
    }
    return displayName;
}

var myFunc = makeFunc();
myFunc();
```

引用：第一眼看上去，也许不能直观的看出这段代码能够正常运行。在一些编程语言中，函数中的局部变量仅在函数的执行期间可用。一旦 makeFunc() 执行完毕，我们会认为 name 变量将不能被访问。然而，因为代码运行得没问题，所以很显然在 JavaScript 中并不是这样的。

我们的java就是这种局部标量仅在函数执行期才可用的语言，为什么这里又可行呢？？？？？？？？？因为java内部类可以访问外部类的变量。

