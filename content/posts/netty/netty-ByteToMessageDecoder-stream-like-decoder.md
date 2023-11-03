---
title: "Netty实现自定义流式解析器"
date: 2019-04-26
author: "刘港欢"
categories: [ "java","网络编程","netty"]
tags: ["Netty"]
weight: 10
---

tcp分包一般在pipeline的前部使用DelimiterBasedFrameDecoder, FixedLengthFrameDecoder, LengthFieldBasedFrameDecoder, or LineBasedFrameDecoder，分别适用于固定分隔符、固定长度帧、长度字段、换行符分割四种情况。但是，这四种不能涵盖tcp分包的全部情况，举个栗子：http协议的解析就不是上面四种中的一种。解析http协议或者其他自定义协议时，就需要用到ByteToMessageDecoder创建自己的“流式”解析器。netty的http解析器（HttpObectDecoder）就是继承ByteToMessageDecoder并override decode方法实现的。
<!--more-->

## 介绍ByteTo MessageDecoder

望文生义，这个类的作用是将Bytebuf转成其他类型的Message。这个类是有状态的，所以不能@Sharable。这个类的解析是流式的，有成员变量Cumulator（累积器）和cumulation（累积）。累积器不断地将新到来得Bytebuf累积到cumulation中，并且调用decode方法。

decode方法会产生List<OUT>，并通过fireChannelRead传递到下一个handler。

最后，cumulation会被重置，以便开始下一次解析

上面说的其实就是channelRead的代码，请看下面：

```java
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        if (msg instanceof ByteBuf) {
            CodecOutputList out = CodecOutputList.newInstance();
            try {
                ByteBuf data = (ByteBuf) msg;
                first = cumulation == null;
                if (first) {
                    cumulation = data;
                } else {
                    cumulation = cumulator.cumulate(ctx.alloc(), cumulation, data);
                }
                callDecode(ctx, cumulation, out);
            } catch (DecoderException e) {
                throw e;
            } catch (Exception e) {
                throw new DecoderException(e);
            } finally {
                if (cumulation != null && !cumulation.isReadable()) {
                    numReads = 0;
                    cumulation.release();
                    cumulation = null;
                } else if (++ numReads >= discardAfterReads) {
                    // We did enough reads already try to discard some bytes so we not risk to see a OOME.
                    // See https://github.com/netty/netty/issues/4275
                    numReads = 0;
                    discardSomeReadBytes();
                }

                int size = out.size();
                decodeWasNull = !out.insertSinceRecycled();
                fireChannelRead(ctx, out, size);
                out.recycle();
            }
        } else {
            ctx.fireChannelRead(msg);
        }
    }
```

## 实现自己的decode()方法

实现自己的流式解析器，只要实现自己的decode方法即可。但是在这里面，又有一些细节：

1. 需要确保byteBuf中有完整的一帧，使用ByteBuf.readableBytes()来查看有多少可读字节。
2. 如果没有足够的一帧，则不要修改byteBuf的readerIndex，直接return。byteBuf.readxx() 会修改readerIndex。而byteBuf.getxx(Int) 则不会修改该readerIndex。
3. javaDoc提到的一个陷阱：Some methods such as ByteBuf.readBytes(int) will cause a memory leak if the returned buffer is not released or added to the out List. Use derived buffers like ByteBuf.readSlice(int) to avoid leaking memory.
 - ByteBuf.readBytes(int)返回一个新的Bytebuf，拥有自己的引用计数，因此需要以后自己release。ByteBuf.readSlice(int)则是原Bytebuf的一个slice，并且不会调用retain()来使引用计数++。所以这个slice往往要手动调用retain之后再加入out列表。
4. decode()方法的第二个参数ByteBuf不需要我们release，父类ByteToMessageHandler会自动处理。

## 自己实现一个简单的http解析器

解析以下response：

```bash
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
Content-Length: 85

��D�����Z��Nͼ!N�l-�0+��q`ߵM��Y@�|<,�2;O������	b�J�x'��מ��a��s\}��
```

其中前74字节是固定的，接着是contentlength字段，随后是\r\n\r\n，之后是content

```java
public class HttpResponseDecoder extends ByteToMessageDecoder {
    private static Logger logger= LoggerFactory.getLogger(HttpResponseDecoder.class);
    private byte[] headStore=new byte[74];
    private final static byte[] validHead="HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: ".getBytes();

    private int contentLength=0;
    private State state= State.START;

    private enum State{
        START,CONTENTLENGTH,CRLFCRLF,CONTENT
    }

    //检查响应的其实部分是否正确
    private boolean headValid(ByteBuf slice){
        slice.markReaderIndex();
        slice.readBytes(headStore);
        slice.resetReaderIndex();

        for (int i = 0; i < validHead.length; i++) {
            if(headStore[i]!=validHead[i]){
                return false;
            }
        }
        return true;
    }

    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {

        switch (state){
            case START:
                if(in.readableBytes()>=74){//如果不以 “"HTTP/1.1 200 OK。。。。。"”开始则直接点开连接
                    if(!headValid(in)){
                        logger.error("来自服务器的错误的响应。请检查sogo.json配置");
                        SocksServerUtils.closeOnFlush(ctx.channel());
                        return;
                    }
                }

                if(in.readableBytes()<=74){
                    return;
                }else{
                    in.readerIndex(in.readerIndex()+74);
                    state= State.CONTENTLENGTH;
                }
            case CONTENTLENGTH:
                int index=in.forEachByte(ByteProcessor.FIND_CRLF);
                if(index==-1){
                    return;
                }else {
                    CharSequence cs=in.readCharSequence(index-in.readerIndex(), StandardCharsets.UTF_8);
                    contentLength=Integer.parseInt(cs.toString());

                    state= State.CRLFCRLF;
                }
            case CRLFCRLF:
                if(in.readableBytes()<4){
                    return;
                }else {
                    in.readerIndex(in.readerIndex()+4);
                    state= State.CONTENT;
                }
            case CONTENT:
                if(in.readableBytes()<contentLength){
                    return;
                }else {
                    ByteBuf buf=in.readSlice(contentLength);
                    ByteBuf content = PooledByteBufAllocator.DEFAULT.buffer();
                    buf.forEachByte(value -> {
                        content.writeByte(~value);
                        return true;
                    });
                    out.add(content);
                    state= State.START;
                }
        }
    }
}

```

