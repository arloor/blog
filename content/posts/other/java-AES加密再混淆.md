---
author: "刘港欢"
date: 2019-01-04
linktitle: java-AES加密后再混淆
title: java-AES加密后再混淆
categories: [ "java","加密"]
tags: ["program"]
weight: 10
---

这是上一篇[java-AES128加密-代码与一些约定](/posts/other/java-aes128加密.代码与一些约定/)的后续。这一篇将会记录自己看到的YMM手机app在AES128之后所做的混淆。混淆原来为OC实现，自己转成了java实现。感觉这一套比较好用，所以记下来变成自己的😁<!--more-->

# 直接上代码

```
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;

import static java.nio.charset.StandardCharsets.UTF_8;

public class AES128 {

    private static final Charset CHARSET=UTF_8;//所有string转byte都使用UTF-8

    /**
     * 加密
     * @param source
     * @param keyStr 原始秘钥字符串，注意不是最终的秘钥
     * @return 加密后的字节数组
     * @throws KeyLengthException 如果秘钥长度不为16则抛出
     */
    public static byte[] encrypt(byte[] source, String keyStr) throws KeyLengthException {
        byte[] key=getKey(keyStr);
        if(key.length!=16){
            throw new KeyLengthException();
        }
        try {
            Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
            SecretKeySpec keySpec=new SecretKeySpec(key, "AES");
            cipher.init(Cipher.ENCRYPT_MODE,keySpec );
            return cipher.doFinal(source);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }


    /**
     * 解密
     * @param encoded
     * @param keyStr 原始秘钥字符串，注意不是最终的秘钥
     * @return 解密后的字节数组
     * @throws KeyLengthException 如果秘钥长度不为16则抛出
     */
    public static byte[] decrypt(byte[] encoded, String keyStr) throws  KeyLengthException {
        byte[] key=getKey(keyStr);
        if(key.length!=16){
            throw new KeyLengthException();
        }
        try {
            Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"));
            return cipher.doFinal(encoded);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }
    public static byte[] confusion(byte[] raw) {
        int v13 = raw.length;
        byte[] ebbytes = raw;
        byte[] v11 = new byte[((v13 + 2) / 3) * 4];//这里直接用byte数组
        for (int i = 0; i < v13; i += 3) {
            int v9 = 0;
            for (int j = i; j < i + 3; ++j) {
                v9 <<= 8;
                if (j < v13)
                    v9 |= ebbytes[j]&0xFF;//c语言unsigned char转int
            }
            //byte: 80 122 35 96 40 58 55 70 ............................44 74(共65个   v12[64]=74
            //这个byte[] 就是c语言下的char*的char[]
            byte[] v12 = "Pz#`(:7F-a%diHm<kQDTVEKXI68loAqwsGgC42!R^ju0h@xYc][}S9B{M~+t$.>,J".getBytes();
            //0
            v11[4 * (i / 3)] = v12[((v9 >> 18) & 0x3F)];
            //1
            v11[4 * (i / 3) + 1] = v12[((v9 >> 12) & 0x3F)];
            //2
            byte v7;
            if (i + 1 >= v13)
                v7 = v12[64];
            else {
                v7 = v12[((v9 >> 6) & 0x3F)];
            }
            v11[4 * (i / 3) + 2] = v7;
            //3
            byte v6;
            if (i + 2 >= v13)
                v6 = v12[64];
            else {
                v6 = v12[(v9 & 0x3F)];
            }
            v11[4 * (i / 3) + 3] = v6;
        }
        return v11;
    }
    public static byte[] disConfusion(byte[] confusioned){
        int a1=0;
        byte v6=0;
        byte v7=0;
        byte v8=0;
        byte v9=0;
        byte v10=0;
        byte v11=0;
        byte v12=0;
        byte[] v15="Pz#`(:7F-a%diHm<kQDTVEKXI68loAqwsGgC42!R^ju0h@xYc][}S9B{M~+t$.>,J".getBytes(UTF_8);
        v15=Arrays.copyOf(v15,v15.length+1);
        v15[v15.length-1]=0;
        byte[] v16=confusioned;
        int a3=v16.length;
        int v14=a3/4;
        a1=3*((int)a3/4);
        byte[] v13=new byte[a1];
        for (int i = 0; i < v14; ++i ){
            //v6 = strchr(v15, *(char *)(v16 + 4 * i));
            int index1=indexOfbyte(v15,v16[4*i]);
            if(index1==-1){
                return null;
            }
            v6=v15[index1];
            v12=(byte)((4*index1));
            int index2=indexOfbyte(v15,v16[4*i+1]);
            if(index2==-1){
                return null;
            }
            v7=v15[index2];
            v11 = (byte)(index2);
            v13[3*i]=(byte)(v12+((index2 & 0x30) >> 4));

            int index3 = indexOfbyte(v15, v16[ 4 * i + 2]);
            if(index3==-1){
                return null;
            }
            v8=v15[index3];
            if ( index3 == 64 ) {
                a1 = 3 * i + 1;
                return Arrays.copyOf(v13,a1);
            }
            v10 = (byte)(index3);
            v13[3 * i + 1]=(byte)(16 * v11+((index3 & 0x3C) >> 2));
            int index4=indexOfbyte(v15,v16[ 4 * i + 3]);
            if(index4==-1){
                return null;
            }
            v9=v15[index4];
            if(index4 == 64){
                a1 = 3 * i + 2;
                return Arrays.copyOf(v13,a1);
            }
            v13[3 * i + 2] = (byte)((v10 << 6) + index4);

        }
        return v13 ;
    }

    private static int indexOfbyte(byte[] source,byte target){
        for (int j = 0; j <source.length ; j++) {
            if(source[j]==target){
                return j;
            }
        }
        return -1;
    }

    /**
     * 由keyStr经过SHA256再取128bit作为秘钥
     * 这里SHA-256也可以换成SHA-1
     * @param keyStr
     * @return
     */
    private static byte[] getKey(String keyStr){
        byte[] raw=keyStr.getBytes(CHARSET);
        MessageDigest sha = null;
        try {
            sha = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
        }
        byte[] key = sha.digest(raw);
        key = Arrays.copyOf(key, 16); // use only first 128 bit
        return key;
    }
    /**
     * 返回byte数组的16进制字符串
     * @param array
     * @return
     */
    public static String byte2Hex(byte[] array){
        StringBuffer strHexString = new StringBuffer();
        for (int i = 0; i < array.length; i++)
        {
            String hex = Integer.toHexString(0xff & array[i]);
            if (hex.length() == 1)
            {
                strHexString.append('0');
            }
            strHexString.append(hex);
        }
        return strHexString.toString();
    }
    public static class KeyLengthException extends Exception{
    }
}
```

相比上一篇增加了`confusion`和`disConfusion`方法，这是新加入的混淆方法，也是运满满app所采取的混淆。（运满满整套流程就是，先SHA256再取128bit作为密钥进行AES128加密，再进行这个confusion函数，解密反之）。

# 重申加密中的约定和注意点

1.  秘钥使用`getKey`方法生成。由用户输入的字符串做SHA-256，再取128bit作为最终秘钥
2.  秘钥以外的其他入参或者返回值都是`byte[]`。因为最终`cipher.doFinal()`的入参和返回值都是`byte[]`，减少不必要的string与byte[]转换。
3.  `String`与`byte[]`互相转换都要显式指定`UTF-8`编码，以支持中文和其他特殊字符并保证`byte[]`在转换过程中不发生变化。
4. 直接使用`new SecretKeySpec(key, "AES")`生成SecretKeySpec，不要什么SecureRandom。加密不同语言、不同平台结果不一样的凶手！
5. 使用`byte2Hex`返回16进制字符串来查看和比对加密结果。注意这个结果不是最终加密的结果。

# 测试类

```
import java.io.UnsupportedEncodingException;

import static java.nio.charset.StandardCharsets.UTF_8;

public class Main {
    public static void main(String[] args) throws UnsupportedEncodingException, AES128.KeyLengthException {
        String source="刘港欢";
        System.out.println("加密前字符串为："+source);
        System.out.println("===================================");
        //集成SHA256、AES128和confusion
        String key="我的密钥";
        byte[] afterAESEncrypt=AES128.encrypt(source.getBytes(UTF_8),key);
        byte[] afterConfusion=AES128.confusion(afterAESEncrypt);
        String encodeStr=new String(afterConfusion,UTF_8);
        System.out.println("加密最终结果; "+encodeStr);
        byte[] afterDisConfusion= AES128.disConfusion(afterConfusion);
        byte[] afterAESDescrypt=AES128.decrypt(afterDisConfusion,key);
        String decodeStr=new String(afterAESDescrypt,UTF_8);
        System.out.println("解密之后："+decodeStr);
        System.out.println("与加密前结果相同？"+decodeStr.equals(source));
        System.out.println("===================================");
        //只使用confusion
        byte[] afterConfusion1=AES128.confusion(source.getBytes(UTF_8));
        String encodeStr1=new String(afterConfusion1,UTF_8);
        System.out.println("混淆最终结果: "+encodeStr1);
        byte[] afterDisConfusion1= AES128.disConfusion(afterConfusion1);
        String decodeStr1=new String(afterDisConfusion1,UTF_8);
        System.out.println("解混淆后："+decodeStr1);
        System.out.println("与混淆前结果相同？"+decodeStr1.equals(source));
    }
}

##############控制台################
加密前字符串为：刘港欢
===================================
加密最终结果; ChCH4-%t-EYDsM09MG<o{sJJ
解密之后：刘港欢
与加密前结果相同？true
===================================
混淆最终结果: ~IgI~0gY~u[g
解混淆后：刘港欢
与混淆前结果相同？true
```

以上展示了使用AES+confusion、单独使用confusion两种例子。所以也可以不使用AES，直接使用这个confusion作为加密方式。可以看到一点，经过confusion运算之后的所有字节都是可以打印的，不会出现乱码的情况。
