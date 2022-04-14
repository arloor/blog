---
author: "刘港欢"
date: 2018-06-15
linktitle: opencv c++学习
title: opencv c++学习
categories: [ "opencv"]
tags: ["program"]
weight: 10
---



终于来搞搞opencv啦。。

# 在windows上安装opencv，并且创建visual studio 2017项目


本来想要用clion的，但是编译源码总是出错，就直接用vs2017了。。。


## 安装


在[opencv的release页面](https://opencv.org/releases.html)下载opencv3.4.1的win pack。win pack是opencv适用于vs的免编译版本。

下载好一个exe之后，双击安装到`D:\opencv34`。

然后配置PATH环境变量，增加`D:\opencv34\build\x64\vc15\bin`


## 配置vs2017 创建项目


现在就可以使用vs2017创建一个opencv项目了。

vs2017需要安装"使用c++的桌面开发"工作负载

![vs2017安装选项](/img/vs2017%E5%AE%89%E8%A3%85%E9%80%89%E9%A1%B9.png)

如果有这一项，可以直接创建新项目了。新建项目->visual c++->windows控制台应用程序。（windows控制台程序应该不是必须，目前只会这个）

在解决方案资源管理器中右击项目名，然后右击属性。可以直接`ALT+enter`快捷键打开属性页面 

首先将配置改为debug、平台改为x64!!!!!

![vc++目录](/img/vc%2B%2B%E7%9B%AE%E5%BD%95%E9%85%8D%E7%BD%AE.png)

在vc++目录中编辑包含目录，增加opencv的include目录，在这里是`D:\opencv34\build\include`、`D:\opencv34\build\include\opencv`、`D:\opencv34\build\include\opencv2`

在vc++目录中编辑库目录，增加opencv的库，在这里是`D:\opencv34\build\x64\vc15\lib`、`D:\opencv34\build\x64\vc15\bin`

然后在连接器->输入->外部依赖项中输入`opencv_world341d.lib`。这个文件在`D:\opencv34\build\x64\vc15\lib`中可以找到。说明——****d表示debug版本。不加d表示release版本。

![附加依赖项编辑](/img/%E9%99%84%E5%8A%A0%E4%BE%9D%E8%B5%96%E9%A1%B9.png)


现在就可以进行编程了，这是一个显示图片的例子

注意：需要在debug和x64平台下编译和运行！！！！！
```
#include "stdafx.h"  //vs2017自定义
#include <opencv2/opencv.hpp>
#include<opencv2\core\core.hpp>  
#include<opencv2\highgui\highgui.hpp>  
using namespace cv;
using namespace std;
int main()
{
	// 读入一张图片    
	Mat Image = imread("E:\\TIM.png");//路径自己改
	// 创建一个名为 "photo"窗口    
	cvNamedWindow("photo");
	Size dsize = Size(Image.cols*0.5, Image.rows*0.5);
	Mat dst(dsize, Image.type());
	resize(Image, dst, dst.size());

	// 在窗口中显示游戏原画    
	imshow("photo", dst);
	// 等待10000 ms后窗口自动关闭    
	waitKey(10000);
	return 0;
}
```
应该能正常运行啦!


# core模块


## Mat


在早期的opencv中，使用了一个叫做`IplImage`的c语言数据结构来存储图像信息。这带来所有c语言的问题。最大的问题是需要手动内存管理。c++引入了类的概念使得可以自动内存管理（文档中加了more or less）。c++的唯一不足是当前大部分嵌入式设备只支持c语言。

首先需要需要知道`Mat`不需要手动的分配内存空间和释放空间。尽管仍然可以手动分配Mat内容空间，但是大部分opencv的函数都会自动地分配输出数据的内存空间。另外一个好处是，已经被分配的`Mat`可以被复用。换一句话说，就是只需要使用需要的内存空间即可。

`Mat`这个类包含两部分信息：矩阵头信息和指向包含像素“值”的矩阵的指针。矩阵头信息包含：矩阵的大小、存储的方法、矩阵的地址等等。矩阵头信息中的矩阵大小是constant的，尽管矩阵本身大小会根据不同的图片改变。（mat代表一个图片，而mat由matrix实现，并且matrix会被复用。）

opencv是图像处理库，传递图像给函数是一种普遍的操作。下面讲讲将大大降低程序速度的行为——复制大图片（拷贝操作）。

首先`Mat A,B`只创建了A,B的header，并没有创建一个matrix实例。当进行读取图片操作时，才真正创建了matrix，并且将此matrix的指针给了Mat对象。当进行复制/赋值操作时，实际上被复制的是header信息和matrix指针，并没有进行“深拷贝”（将对象完全复制一遍）。看一段代码

```c++
Mat A, C;                          // creates just the header parts
A = imread(argv[1], IMREAD_COLOR); // here we'll know the method used (allocate matrix)
Mat B(A);                                 // Use the copy constructor
C = A;                                    // Assignment operator
```

上面的所有Mat对象，最终都指向了一个matrix，只是他们可能拥有不同的header。这意味着一个`Mat`修改会影响其他的`Mat`。而不同的header决定了访问matrix的不同方式。

例如，创建一个只关注某一矩形区域的Mat：

```c++
Mat D (A, Rect(10, 10, 100, 100) ); // using a rectangle
Mat E = A(Range::all(), Range(1,3)); // using row and column boundaries
```

现在的问题是，既然这么多Mat都拥有Matrix的指针，谁负责释放Matrix。简单的回答是：最后使用它的人。这里面有一个引用计数的机制，当一个对象复制了mat的header，matrix的计数就会增加。当一个header被清除时，matrix的计数就会减少。减到0，matrix就会被清理。

当然opencv也提供了复制matrix本身的方法：`cv::Mat::clone()`、`cv::Mat::copyTo()`

```c++
Mat F = A.clone();
Mat G;
A.copyTo(G);
```

这样，Mat F、G的修改就不会影响到A。

## matrix在内存中存储方式 


那么在内存中，图片的matrix是怎么存储的呢？

一句话：根据图片通道数量的不同，存储方式不同。以灰度图像和RGB图像为例

灰度图像每列只有一个值
![灰度图像](https://docs.opencv.org/3.4.1/tutorial_how_matrix_stored_1.png)

RGB图像每列有三个值，分别记录B、G、R的值
![RGB图像](https://docs.opencv.org/3.4.1/tutorial_how_matrix_stored_2.png)

`Mat M(200, 200, CV_8UC3, Scalar(0, 0, 255));`这段代码地含义是创建一个`CV_8UC3`类型地宽200，高200的图片，BGR值分别为0，0，255，也就是红色。详细解释见下

Mat对象的type方法会返回图片的类型，最常见的图片类型是
16对应`CV_8UC3`。对应关系见下表。8UC3含义是用8位（也就是char）无符号地（U）表示像素值，所以像素值范围0-255。C3表示3 Channel（3个通道）。

| |  C1 | C2 | C3 | C4 |
|---|-----|----|---|---|
|CV_8U|0|8|16|24|
|CV_8S|1|9|17|25|
|CV_16U|2|10|18|26|
|CV_16S|3|11|19|27|
|CV_32S|4|12|20|28|
|CV_32F|5|13|21|29|
|CV_64F|6|14|22|30|

## cv::LUT函数 遍历每个像素并改变其值

函数定义：`void LUT(InputArray src, InputArray lut, OutputArray dst)`

```shell
Parameters: 都是Mat类型
第一个参数：原始图像的地址； 
第二个参数：查找表的地址，对于多通道图像的查找，它可以有一个通道，也可以与原始图像有相同的通道； 
第三个参数：输出图像的地址。
```
对于多通道图像的查找，查找表可以有一个通道，也可以与原始图像有相同的通道

给一个查找表的例子：

```
Mat lookUpTable(1, 256, CV_8U);
uchar* p = lookUpTable.data; 
for( int i = 0; i < 256; ++i)
   p[i] = 255-i;

LUT(img,lut,img)
```

可以知道，一个像素点的取值为0-255。其中`p[i] = 255-i;` 下标i表示旧的像素值，255-i表示新的像素值。也就是原图中像素值为i的改变为255-i。这样的效果就是图片取反。类似的还可以做减少图片的色彩类型的功能，比如原来值在0-9变为0，10-19变为1....那么lut[256]={0,0.....0,1,1....,2.....,2...}就行


## 操作图片

```
Mat img = imread(filename)//读取图片
Mat img = imread(filename, IMREAD_GRAYSCALE);//以灰度图像的形式读取RGB 3通道的图片

imwrite(filename, img);//将图片写进文件，文件的格式取决于后缀。
```


获取某点的像素值：

```
//注意y在前、x在后
//8UC1
Scalar intensity = img.at<uchar>(y, x);


//8UC3 最常用
Vec3b intensity = img.at<Vec3b>(y, x);
uchar blue = intensity.val[0];
uchar green = intensity.val[1];
uchar red = intensity.val[2];
```

对应关系如下：

|  |C1|	C2|	C3|	C4|	C6
|---|---|---|--|---|---|
|uchar|uchar|	cv::Vec2b|	cv::Vec3b	|cv::Vec4b|
|short|short|	cv::Vec2s|	cv::Vec3s|	cv::Vec4s|
|int|int|	cv::Vec2i|	cv::Vec3i|	cv::Vec4i|
|float|float|	cv::Vec2f|	cv::Vec3f|	cv::Vec4f|cv::Vec6f|
|double|double|	cv::Vec2d|	cv::Vec3d|	cv::Vec4d|	cv::Vec6d|

同样的方法可以用于设置像素值：

```
//8UC3
img.at<uchar>(y, x) = 128;
```

在操作过程中方便的显示图片的办法：

```
Mat img = imread(".....");
cvNamedWindow("photo");//好像不是必须 另3.x是cvNamedWindow
imshow("photo", img);
waitKey();
```

缩小图片的方法

```
Size dsize = Size(Image.cols*0.5, Image.rows*0.5);
Mat dst(dsize, Image.type());
resize(Image, dst, dst.size());
```


# vedeoio模块 调用摄像头、显示视频


先放一段可以获取摄像头视频的代码：

```
#include "stdafx.h"
#include <opencv2/core.hpp>
#include <opencv2/videoio.hpp>
#include <opencv2/highgui.hpp>
#include <iostream>
#include <stdio.h>
using namespace cv;
using namespace std;
int main(int, char**)
{
	Mat frame;
	//--- INITIALIZE VIDEOCAPTURE
	VideoCapture cap;
	// open the default camera using default API
	cap.open(0);
	// OR advance usage: select any API backend
	int deviceID = 0;             // 0 = open default camera
	int apiID = cv::CAP_ANY;      // 0 = autodetect default API
								  // open selected camera using selected API
	cap.open(deviceID + apiID);
	// check if we succeeded
	if (!cap.isOpened()) {
		cerr << "ERROR! Unable to open camera\n";
		return -1;
	}
	//--- GRAB AND WRITE LOOP
	cout << "Start grabbing" << endl
		<< "Press any key to terminate" << endl;
	for (;;)
	{
		// wait for a new frame from camera and store it into 'frame'
		cap.read(frame);
		// check if we succeeded
		if (frame.empty()) {
			cerr << "ERROR! blank frame grabbed\n";
			break;
		}
		// show live and wait for a key with timeout long enough to show images
		imshow("Live", frame);
		if (waitKey(5) >= 0)
			break;
	}
	// the camera will be deinitialized automatically in VideoCapture destructor
	return 0;
}
```

 `cv::VideoCapture`这个类提供了进行视频操作的能力。这个本身依赖于FFmpeg开源库。video是由一连串的图片构成的，这些图片称之为帧（frame）。

 再搞搞怎么保存视频。在“合适”的地方加入下面代码。要是别的小伙伴看不懂“合适”，别骂我。。

 ```
 //初始化
 VideoWriter vw;     //新建一个多媒体文件  
int fps = cap.get(CAP_PROP_FPS); //获取摄像头的帧率 
if (fps <= 0)fps = 25;
//设置视频的格式  
vw.open("E:\out.avi", VideoWriter::fourcc('M', 'J', 'P', 'G'), fps, Size(cap.get(CAP_PROP_FRAME_WIDTH), cap.get(CAP_PROP_FRAME_HEIGHT)));

//for循环中
vw.write(frame);   //将视频帧写入文件 
```

在一个博客中看到这样一段话：

首先要先纠正个误区，我见有人用OpenCV做多媒体开发，真的是很搞笑，OpenCV这东西再强大，这方面也不行的，之所以把视频读取写入这部分做的强大一些，也是为了方便大家做视频处理的时候方便些，而且这部分也是基于vfw和ffmpeg二次开发的，功能还是很弱的。一定要记住一点，OpenCV是一个强大的计算机视觉库，而不是视频流编码器或者解码器。希望大家不要走入这个误区，可以把这部分简单单独看待。目前，OpenCV只支持avi的格式，而且生成的视频文件不能大于2GB，而且不能添加音频。如果你想突破这些限制，我建议你最好还是看看ffMpeg，而不是浪费时间在OpenCV上。

哈哈，有时间看看ffmpeg吧

还是看一下`VideoWriter`的构造函数或者open函数是什么意思吧

```
cv::VideoWriter::VideoWriter(
const String & 	filename,//文件名
int 	fourcc,//格式
double 	fps,//帧率
Size 	frameSize,//帧大小
bool 	isColor = true //是否彩色
)
```


暂时到此为止吧。。。