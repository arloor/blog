---
author: "刘港欢"
date: 2019-01-03
linktitle: java-AES128加密-代码与一些约定
title: java-AES128加密-代码与一些约定 
categories: [ "java","加密"]
tags: ["program"]
weight: 10
---

在爬虫岗位实习，免不了接触加密解密，今天的工作中踩了一些java AES128加密的坑，也学习到了一些加密的常用做法。
<!--more-->

# 直接上代码

AES128.java
```
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;

import static java.nio.charset.StandardCharsets.UTF_8;

public class AES128 {

    public static final Charset CHARSET=UTF_8;
    /**
     * 加密
     * @param source
     * @param keyStr 原始秘钥字符串，注意不是最终的秘钥
     * @return 加密后的字节数组
     * @throws KeyLengthException 如果秘钥长度不为16则抛出
     */
    static byte[] encrypt(byte[] source, String keyStr) throws KeyLengthException {
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
    static byte[] decrypt(byte[] encoded, String keyStr) throws  KeyLengthException {
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

    /**
     * 由keyStr经过SHA256再取128bit作为秘钥
     * 这里SHA-256也可以换成SHA-1
     * @param keyStr
     * @return
     */
    static byte[] getKey(String keyStr){
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
    static String byte2Hex(byte[] array){
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

# 约定和注意点

1.  秘钥使用`getKey`方法生成。由用户输入的字符串做SHA-256，再取128bit作为最终秘钥
2.  秘钥以外的其他入参或者返回值都是`byte[]`。因为最终`cipher.doFinal()`的入参和返回值都是`byte[]`，减少不必要的string与byte[]转换。
3.  `String`与`byte[]`互相转换都要显式指定`UTF-8`编码，以支持中文和其他特殊字符并保证`byte[]`在转换过程中不发生变化。
4. 直接使用`new SecretKeySpec(key, "AES")`生成SecretKeySpec，不要什么SecureRandom。加密不同语言、不同平台结果不一样的凶手！
5. 使用`byte2Hex`返回16进制字符串来查看和比对加密结果。注意这个结果不是最终加密的结果。

# 测试类
```
import static java.nio.charset.StandardCharsets.UTF_8;

public class Main {
    public static void main(String[] args)  {

        //用于生成秘钥的字符串
        String keyStr="s";
        byte[] source="刘港欢".getBytes(UTF_8);
        try {
            byte[] encode=AES128.encrypt(source,keyStr);
            System.out.println(AES128.byte2Hex(encode));

            byte[] decode=AES128.decrypt(encode,keyStr);
            System.out.println(AES128.byte2Hex(decode));

            System.out.println(new String(decode,UTF_8));
        } catch (AES128.KeyLengthException e) {
            e.printStackTrace();
        }
    }
}

##################
663ee437b462418c0940373d4a793cf4
e58898e6b8afe6aca2
刘港欢
```

记住一定要显式使用`UTF-8`！！！