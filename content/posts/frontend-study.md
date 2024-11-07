---
title: "NextJS Study"
subtitle:
tags: 
- undefined
date: 2024-11-07T16:42:51+08:00
lastmod: 2024-11-07T16:42:51+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

是时候学习下现代的前端开发，之前学过html、css和js的dom操作，这次来系统学习下react、nextjs等前端技术栈。
<!--more-->

## 前置准备

### 安装nodejs

Debian12:

```bash
curl -Lf https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz -o /tmp/node-v20.18.0-linux-x64.tar.xz
apt-get install xz-utils -y
tar -xvf /tmp/node-v20.18.0-linux-x64.tar.xz -C /usr/local
export PATH=$PATH:/usr/local/node-v20.18.0-linux-x64/bin
echo "export PATH=$PATH:/usr/local/node-v20.18.0-linux-x64/bin" >> /etc/profile
echo "export PATH=$PATH:/usr/local/node-v20.18.0-linux-x64/bin" >> /etc/zshrc
node -v&&npm -v
```

macOS:

```bash
brew install node npm
node -v&&npm -v
```

## 创建example项目

```bash
npm install -g pnpm
yes| npx create-next-app@latest nextjs-dashboard-demo --example "https://github.com/vercel/next-learn/tree/main/dashboard/starter-example" --use-pnpm
sed -i 's/next dev --turbo/next dev --turbo -H 127.0.0.1 -p 3000/g' nextjs-dashboard-demo/package.json # 修改启动的host
cd nextjs-dashboard-demo
pnpm i #安装依赖
pnpm dev #启动项目
```

`/app`: 包含所有的路由、组件、逻辑，是主要代码的所在。
`/app/lib`: 包含应用使用的函数，例如可复用的utils函数和数据获取函数。
`/app/ui`: 包含所有的UI组件，例如卡片、表格、表单。
`/public`: 包含所有的静态资源，例如图片
**Config Files**: 在根目录还有 `next.config.js` 等配置文件。如果你使用 `create-next-app` 初始化项目，那么大部分文件已经预先配置好了。在NextJS的官方example中，不需要修改这个文件。

## 简单的TS

```typescript
export type Invoice = {
  id: string;
  customer_id: string;
  amount: number;
  date: string;
  // In TypeScript, this is called a string union type.
  // It means that the "status" property can only be one of the two strings: 'pending' or 'paid'.
  status: 'pending' | 'paid';
};
```

- 可以使用Prisma or Drizzle来生成database scheme对应的TS类型。
- 如果项目中存在TS，NextJS会自动安装必要的依赖和配置（应该是指`tsconfig.json`）。并且NextJS提供的[TypeScript plugin](https://nextjs.org/docs/app/building-your-application/configuring/typescript#typescript-plugin)可以帮助你自动补全和保证类型安全。

## 样式

### 全局样式

可以使用 `/app/ui/global.css` 文件将 CSS 规则添加到应用程序中的所有页面 —— 例如 CSS 重置规则（用来消除浏览器默认样式的差异）、链接等 HTML 元素的全栈范围样式等。（接受者是标签选择器，例如body、h1、p等。

您可以在应用程序的任何组件中导入 `global.css`，但通常最好将其添加到顶级组件中。在 `Next.js` 中，这是根布局（稍后会详细介绍）。通过导航到 `/app/layout.tsx` 并导入 `global.css` 文件，将全局样式添加到您的应用程序：

```tsx
// /app/layout.tsx
import '@/app/ui/global.css';
```

golbal.css中的内容如下，主要包含 `@tailwind` 的三个指令，用于引入 `tailwindcss` 的基础样式、组件和工具类。

```css
/* /app/ui/global.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

input[type='number'] {
  -moz-appearance: textfield;
  appearance: textfield;
}

input[type='number']::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

input[type='number']::-webkit-outer-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
```

`Tailwind` 是一个 CSS 框架，允许您直接在 TSX 标记中快速编写[实用程序类](https://tailwindcss.com/docs/utility-first)，从而加快开发过程。通过给元素增加类名称，可以快速实现样式的修改。

当您使用`create-next-app`启动新项目时，`Next.js` 会询问您是否要使用 `Tailwind`。如果您选择yes ，`Next.js` 将自动安装必要的软件包并在您的应用程序中配置 `Tailwind`。

尽管 CSS 样式是全局共享的，但每个类都单独应用于每个元素。例如 `/app/page.tsx`，就使用了`Tailwind`的类名：

```tsx
// /app/page.tsx
import AcmeLogo from '@/app/ui/acme-logo';
import { ArrowRightIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';
 
export default function Page() {
  return (
    // These are Tailwind classes:
    <main className="flex min-h-screen flex-col p-6">
      <div className="flex h-20 shrink-0 items-end rounded-lg bg-blue-500 p-4 md:h-52">
    // ...
  )
}
```

### CSS Modules

`CSS Modules` 是一种允许您在组件级别上使用 CSS 的技术，他使 CSS 类默认作用于组件的本地范围，从而降低样式冲突的风险。。Tailwind 和 CSS 模块是设计 Next.js 应用程序样式的两种最常见的方法。使用其中之一取决于您的偏好 - 您甚至可以在同一个应用程序中使用两者！

```css
/* /app/ui/home.module.css */
.shape {
  height: 0;
  width: 0;
  border-bottom: 30px solid black;
  border-left: 20px solid transparent;
  border-right: 20px solid transparent;
}
```

```tsx
import AcmeLogo from '@/app/ui/acme-logo';
import { ArrowRightIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';
import styles from '@/app/ui/home.module.css';
 
export default function Page() {
  return (
    <main className="flex min-h-screen flex-col p-6">
      <div className={styles.shape} />
    // ...
  )
}
```

### 使用 `clsx` 库切换类名

`clsx` 是一个小型库，用于在 TSX 中动态切换类名。它允许您在组件中使用条件逻辑来决定是否应该添加或删除类名。

```tsx
// /app/ui/invoices/status.tsx
import clsx from 'clsx';
 
export default function InvoiceStatus({ status }: { status: string }) {
  return (
    <span
      className={clsx(
        'inline-flex items-center rounded-full px-2 py-1 text-sm',
        {
          'bg-gray-100 text-gray-500': status === 'pending',
          'bg-green-500 text-white': status === 'paid',
        },
      )}
    >
    // ...
)}
```

## 优化字体和图像

字体在网站设计中发挥着重要作用，但如果需要获取和加载字体文件，在项目中使用自定义字体可能会影响性能。[累积布局偏移](https://vercel.com/blog/how-core-web-vitals-affect-seo)是 Google 用于评估网站性能和用户体验的指标。对于字体，当浏览器最初以后备字体或系统字体呈现文本，然后在加载后将其交换为自定义字体时，就会发生布局转换。这种交换可能会导致文本大小、间距或布局发生变化，从而移动其周围的元素。

当您使用`next/font`模块时，`Next.js` 会自动优化应用程序中的字体。它在构建时下载字体文件并将它们与其他静态资产一起托管。这意味着当用户访问您的应用程序时，不会出现会影响性能的额外网络请求字体。

### 添加字体

让我们向您的应用程序添加自定义 `Google` 字体，看看它是如何工作的！在 `/app/ui` 文件夹中，创建一个名为 `fonts.ts` 的新文件。您将使用此文件来保留将在整个应用程序中使用的字体。从 `next/font/google` 模块导入 `Inter` 字体 - 这将是您的主要字体。然后，指定您要加载的子集。在这种情况下，"拉丁语"：

```tsx
// /app/ui/fonts.ts
import { Inter, Lusitana } from 'next/font/google';
 
export const inter = Inter({ subsets: ['latin'] });
 
export const lusitana = Lusitana({
  weight: ['400', '700'],
  subsets: ['latin'],
});
```

最后将字体添加到 `/app/layout.tsx` 中的元素：看第二行import和body标签的`inter.className`。

```tsx
// /app/layout.tsx
import '@/app/ui/global.css';
import { inter } from '@/app/ui/fonts';
 
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased`}>{children}</body>
    </html>
  );
}
```

通过将Inter添加到`<body>`元素，该字体将应用于整个应用程序（因为字体相关的css属性默认会继承给子元素）。在这里，您还添加了 `Tailwind antialiased` 平滑字体的类。没有必要使用这个类，但它增加了一个不错的感觉。可以到[Google 字体(简体中文)](https://fonts.google.com/?lang=zh_Hans)搜索更多字体。

###  添加图像

Next.js 可以在顶级 /public 文件夹下提供静态资源，例如图像。 /public 内的文件可以在您的应用程序中引用。使用常规 HTML，您可以添加图像，如下所示：

```tsx
<img
  src="/hero.png"
  alt="Screenshots of the dashboard project showing desktop version"
/>
```

但是，这意味着您必须手动：

- 确保您的图像在不同的屏幕尺寸上都能响应。（响应式布局）
- 指定不同设备的图像尺寸。
- 防止图像加载时布局发生变化。
- 延迟加载用户视口之外的图像。

图像优化是 Web 开发中的一个大主题，其本身可以被视为一个专业领域。您可以使用`next/image`组件自动优化图像，而不是手动实现这些优化。

`<Image>`组件是`<img>`标签的扩展，他有一些自动优化的措施，例如：

- 加载图像时自动防止布局移动。
- 调整图像大小以避免将大图像传送到具有较小视口的设备。
- 默认情况下延迟加载图像（图像在进入视口时加载）。
- 以现代格式（例如WebP）提供图像和AVIF ，当浏览器支持时。

在 `/app/page.tsx` 文件中，从 `next/image` 导入组件。然后，在注释下添加图片:

```tsx
// /app/page.tsx
import AcmeLogo from '@/app/ui/acme-logo';
import { ArrowRightIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';
import { lusitana } from '@/app/ui/fonts';
import Image from 'next/image';
 
export default function Page() {
  return (
    // ...
    <div className="flex items-center justify-center p-6 md:w-3/5 md:px-28 md:py-12">
      {/* Add Hero Images Here */}
      <Image
        src="/hero-desktop.png"
        width={1000}
        height={760}
        className="hidden md:block"
        alt="Screenshots of the dashboard project showing desktop version"
      />
    <Image
        src="/hero-mobile.png"
        width={560}
        height={620}
        className="block md:hidden"
        alt="Screenshot of the dashboard project showing mobile version"
      />
    </div>
    //...
  );
}
```

在这里，您将width设置为1000 ， height设置为760像素。**最好设置图像的width和height以避免布局移位，这些宽高比应该与源图像相同**。您还会注意到 `hidden` 类用于从移动屏幕上的 DOM 中删除图像，以及 `md:block` 用于在桌面屏幕上显示图像。类似的 `block md:hidden` 用于在移动屏幕上显示图像，而在平板上隐藏图像。

## 布局和页面

Next.js 使用文件系统路由，其中​​文件夹用于创建嵌套路由。每个文件夹代表一个映射到 URL 段的路由段。您可以使用layout.tsx和page.tsx文件为每个路由创建单独的UI。

![](/img/folders-to-url-segments.avif)

### 创建页面

page.tsx是一个特殊的 Next.js 文件，它导出 React 组件，并且需要它才能访问路由。在您的应用程序中，您已经有一个页面文件： `/app/page.tsx` —— 这是与路径/关联的主页。要创建嵌套路由，您可以将文件夹相互嵌套并在其中添加 page.tsx 文件。例如：/app/dashboard/page.tsx 与 /dashboard 路径关联。让我们创建页面来看看它是如何工作的！

```tsx
export default function Page() {
  return <p>Dashboard Page</p>;
}
```

现在，确保开发服务器正在运行并访问 http://localhost:3000/dashboard。您应该看到"仪表板页面"文本。

### 创建布局

仪表板具有某种跨多个页面共享的导航。在 Next.js 中，您可以使用特殊的layout.tsx文件来创建在多个页面之间共享的 UI。

```tsx
// /app/dashboard/layout.tsx
import SideNav from '@/app/ui/dashboard/sidenav';
 
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen flex-col md:flex-row md:overflow-hidden">
      <div className="w-full flex-none md:w-64">
        <SideNav />
      </div>
      <div className="flex-grow p-6 md:overflow-y-auto md:p-12">{children}</div>
    </div>
  );
}
```

`/app/layout.tsx` 是根布局，并且是必须的。

## 优化导航


传统的`<a>` HTML 元素会导致全页面刷新。在 Next.js 中，您可以使用用于在应用程序中的页面之间链接的组件。允许您使用 JavaScript 进行客户端导航。

```tsx
import {
  UserGroupIcon,
  HomeIcon,
  DocumentDuplicateIcon,
} from '@heroicons/react/24/outline';
import Link from 'next/link';
 
// ...
 
export default function NavLinks() {
  return (
    <>
      {links.map((link) => {
        const LinkIcon = link.icon;
        return (
          <Link
            key={link.name}
            href={link.href}
            className="flex h-[48px] grow items-center justify-center gap-2 rounded-md bg-gray-50 p-3 text-sm font-medium hover:bg-sky-100 hover:text-blue-600 md:flex-none md:justify-start md:p-2 md:px-3"
          >
            <LinkIcon className="w-6" />
            <p className="hidden md:block">{link.name}</p>
          </Link>
        );
      })}
    </>
  );
}
```

为了改善导航体验，Next.js 自动按路线段对应用程序进行代码分割。这与传统的 React SPA不同，浏览器在初始加载时加载所有应用程序代码。

按路由拆分代码意味着页面变得孤立。如果某个页面抛出错误，应用程序的其余部分仍然可以工作。

此外，在生产中，只要<Link>组件出现在浏览器的视口中，Next.js 就会自动在后台预取链接路由的代码。当用户单击链接时，目标页面的代码将已经在后台加载，这使得页面转换几乎是即时的！

常见的 UI 模式是显示活动链接以向用户指示他们当前所在的页面。为此，您需要从 URL 获取用户的当前路径。 Next.js 提供了一个名为usePathname()的钩子，您可以使用它来检查路径并实现此模式。由于 `usePathname()` 是一个钩子，因此您需要将 `nav-links.tsx` 转换为客户端组件。将 React 的"use client"指令添加到文件顶部，然后从 `next/navigation` 导入` usePathname()`，并且使用clsx库在链接处于活动状态时有条件地应用类名。

```tsx
'use client';
 
import {
  UserGroupIcon,
  HomeIcon,
  DocumentDuplicateIcon,
} from '@heroicons/react/24/outline';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import clsx from 'clsx';
 
// ...
 
export default function NavLinks() {
  const pathname = usePathname();
 
  return (
    <>
      {links.map((link) => {
        const LinkIcon = link.icon;
        return (
          <Link
            key={link.name}
            href={link.href}
            className={clsx(
              'flex h-[48px] grow items-center justify-center gap-2 rounded-md bg-gray-50 p-3 text-sm font-medium hover:bg-sky-100 hover:text-blue-600 md:flex-none md:justify-start md:p-2 md:px-3',
              {
                'bg-sky-100 text-blue-600': pathname === link.href,
              },
            )}
          >
            <LinkIcon className="w-6" />
            <p className="hidden md:block">{link.name}</p>
          </Link>
        );
      })}
    </>
  );
}
```

## 使用服务器组件(Server Components)获取数据

默认情况下，Next.js 应用程序使用 **React Server Components**。使用服务器组件获取数据是一种相对较新的方法，使用它们有一些好处：

- 服务器组件支持 Promise，为数据获取等异步任务提供更简单的解决方案。您可以使用async/await语法，而无需使用useEffect 、 useState或数据获取库。
- 服务器组件在服务器上执行，因此您可以将昂贵的数据获取和逻辑保留在服务器上，并且仅将结果发送到客户端。
- 如前所述，由于服务器组件在服务器上执行，因此您可以直接查询数据库，而无需额外的 API 层。

NextJS的教程主要是如何使用SQL查询数据，但我想用API来获取数据。这里整理下通用的一些东西。

```tsx
// /app/dashboard/page.tsx
import { Card } from '@/app/ui/dashboard/cards';
import RevenueChart from '@/app/ui/dashboard/revenue-chart';
import LatestInvoices from '@/app/ui/dashboard/latest-invoices';
import { lusitana } from '@/app/ui/fonts';
import {
  fetchRevenue,
  fetchLatestInvoices,
  fetchCardData,
} from '@/app/lib/data';
 
export default async function Page() { // async方法，从而可以使用async/await语法
  const revenue = await fetchRevenue();
  const latestInvoices = await fetchLatestInvoices();
  const {
    numberOfInvoices,
    numberOfCustomers,
    totalPaidInvoices,
    totalPendingInvoices,
  } = await fetchCardData();
 
  return (
    <main>
      <h1 className={`${lusitana.className} mb-4 text-xl md:text-2xl`}>
        Dashboard
      </h1>
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card title="Collected" value={totalPaidInvoices} type="collected" />
        <Card title="Pending" value={totalPendingInvoices} type="pending" />
        <Card title="Total Invoices" value={numberOfInvoices} type="invoices" />
        <Card
          title="Total Customers"
          value={numberOfCustomers}
          type="customers"
        />
      </div>
      <div className="mt-6 grid grid-cols-1 gap-6 md:grid-cols-4 lg:grid-cols-8">
        <RevenueChart revenue={revenue} />
        <LatestInvoices latestInvoices={latestInvoices} />
      </div>
    </main>
  );
}

// 获取数据的一个例子，主要关注如何使用Promise和setTimeout
export async function fetchRevenue() {
  try {
    // Artificially delay a response for demo purposes.
    // Don't do this in production :)

    // console.log('Fetching revenue data...');
    // await new Promise((resolve) => setTimeout(resolve, 3000));

    const data = await sql<Revenue>`SELECT * FROM revenue`;

    // console.log('Data fetch completed after 3 seconds.');

    return data.rows;
  } catch (error) {
    console.error('Database Error:', error);
    throw new Error('Failed to fetch revenue data.');
  }
}
```

可以使用 `Promise.all()` 或 `Promise.allSettled()` 来避免请求瀑布：

```tsx
export async function fetchCardData() {
  try {
    const invoiceCountPromise = sql`SELECT COUNT(*) FROM invoices`;
    const customerCountPromise = sql`SELECT COUNT(*) FROM customers`;
    const invoiceStatusPromise = sql`SELECT
         SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) AS "paid",
         SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) AS "pending"
         FROM invoices`;
 
    const data = await Promise.all([
      invoiceCountPromise,
      customerCountPromise,
      invoiceStatusPromise,
    ]);
    // ...
  }
}
```

## 静态渲染和动态渲染

### 什么是静态渲染？

通过静态渲染，数据获取和渲染发生在构建时（部署时）或重新验证数据时在服务器上。每当用户访问您的应用程序时，就会提供缓存的结果。静态渲染有几个好处：

- 更快的网站 - 预渲染的内容可以缓存并在全球范围内分发。这可以确保世界各地的用户可以更快、更可靠地访问您网站的内容。
- 减少服务器负载 - 由于内容被缓存，您的服务器不必为每个用户请求动态生成内容。
- SEO - 预渲染的内容更容易让搜索引擎爬虫索引，因为内容在页面加载时就已经可用。这可以提高搜索引擎排名。

### 什么是动态渲染？

通过动态呈现，内容会在请求时（当用户访问页面时）在服务器上为每个用户呈现。动态渲染有几个好处：

- 实时数据 - 动态渲染允许您的应用程序显示实时或经常更新的数据。这对于数据经常变化的应用程序来说是理想的选择。
- 用户特定的内容 - 更容易提供个性化内容（例如仪表板或用户配置文件），并根据用户交互更新数据。
- 请求时间信息 - 动态呈现允许您访问只能在请求时知道的信息，例如 cookie 或 URL 搜索参数。

## Streaming 渐进式渲染

通过流式传输，您可以防止缓慢的数据请求阻塞整个页面。这允许用户查看页面的部分内容并与之交互，而无需等待所有数据加载后再向用户显示任何 UI。流式处理与 React 的组件模型配合得很好，因为每个组件都可以被视为一个块。在 Next.js 中实现流式传输有两种方法：


1. 在页面级别，使用loading.tsx 文件。
2. 对于特定的组件，用 `<Suspense>`

### 使用 loading.tsx 文件

`loading.tsx` 是一个基于 `Suspense` 构建的特殊 `Next.js` 文件，它允许您创建后备 UI 以在页面内容加载时显示为替换。

最基本的：

```tsx
// /app/dashboard/loading.tsx
export default function Loading() {
  return <div>Loading...</div>;
}
```

添加加载骨架：加载骨架是 UI 的简化版本。许多网站使用它们作为占位符（或后备）来向用户指示内容正在加载。您在loading.tsx中添加的任何UI都将作为静态文件的一部分嵌入，并首先发送。然后，其余的动态内容将从服务器流式传输到客户端。

```tsx
// /app/dashboard/loading.tsx
import DashboardSkeleton from '@/app/ui/skeletons';
 
export default function Loading() {
  return <DashboardSkeleton />;
}


// /app/ui/skeletons.tsx
export default function DashboardSkeleton() {
  return (
    <>
      <div
        className={`${shimmer} relative mb-4 h-8 w-36 overflow-hidden rounded-md bg-gray-100`}
      />
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <CardSkeleton />
        <CardSkeleton />
        <CardSkeleton />
        <CardSkeleton />
      </div>
      <div className="mt-6 grid grid-cols-1 gap-6 md:grid-cols-4 lg:grid-cols-8">
        <RevenueChartSkeleton />
        <LatestInvoicesSkeleton />
      </div>
    </>
  );
}
```

![](/img/loading-page-with-skeleton.avif)

现在还有个问题，这个loading的骨架界面会对下面的页面也生效。我们可以通过路由组来改变这一点。在仪表板文件夹内创建一个名为 /(overview) 的新文件夹。然后，将 loading.tsx 和 page.tsx 文件移至文件夹内：路由组允许您将文件组织到逻辑组中，而不影响 URL 路径结构。当您使用括号()创建新文件夹时，该名称不会包含在 URL 路径中。因此/dashboard/(overview)/page.tsx变为/dashboard 。

![](/img/route-group.avif)

### 流式传输动态组件

使用 `<Suspense>` 包裹原来的组件，并添加fallback为骨架即可。

```tsx
import { Card } from '@/app/ui/dashboard/cards';
import RevenueChart from '@/app/ui/dashboard/revenue-chart';
import LatestInvoices from '@/app/ui/dashboard/latest-invoices';
import { lusitana } from '@/app/ui/fonts';
import { fetchLatestInvoices, fetchCardData } from '@/app/lib/data';
import { Suspense } from 'react';
import { RevenueChartSkeleton } from '@/app/ui/skeletons';
 
export default async function Page() {
  const latestInvoices = await fetchLatestInvoices();
  const {
    numberOfInvoices,
    numberOfCustomers,
    totalPaidInvoices,
    totalPendingInvoices,
  } = await fetchCardData();
 
  return (
    <main>
      <h1 className={`${lusitana.className} mb-4 text-xl md:text-2xl`}>
        Dashboard
      </h1>
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card title="Collected" value={totalPaidInvoices} type="collected" />
        <Card title="Pending" value={totalPendingInvoices} type="pending" />
        <Card title="Total Invoices" value={numberOfInvoices} type="invoices" />
        <Card
          title="Total Customers"
          value={numberOfCustomers}
          type="customers"
        />
      </div>
      <div className="mt-6 grid grid-cols-1 gap-6 md:grid-cols-4 lg:grid-cols-8">
        <Suspense fallback={<RevenueChartSkeleton />}>
          <RevenueChart />
        </Suspense>
        <LatestInvoices latestInvoices={latestInvoices} />
      </div>
    </main>
  );
}
```

## 部分预渲染Partial Prerendering (PPR)和增量静态生成Incremental Static Regeneration (ISR)

Next.js 14 引入了部分预渲染的实验版本 - 一种新的渲染模型，允许您在同一路径中结合静态和动态渲染的优点。例如：

当用户访问某条路线时：

- 提供包含导航栏和产品信息的静态路由的外壳，确保快速初始加载。
- 外壳留下了一些空洞，动态内容（例如购物车和推荐产品）将异步加载。
- 这些空洞将并行移步加载，从而减少总体加载时间

### 部分预渲染如何工作？

部分预渲染使用 React 的 Suspense（您在上一章中了解过）来推迟应用程序的渲染部分，直到满足某些条件（例如加载数据）。Suspense fallback 与静态内容一起嵌入到初始 HTML 文件中。在构建时（或revalidation期间），静态内容被预渲染以创建静态外壳。动态内容的呈现被推迟，直到用户请求该页面。

将组件包装在 Suspense 中并不会使组件本身变得动态，而是 Suspense 被用作静态和动态代码之间的边界。

### 启用部分预渲染

```tsx
// next.config.ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /* config options here */
   experimental: {
    ppr: 'incremental',
  },
};

export default nextConfig;
```

然后在page.tsx中增加这个

```tsx
export const experimental_ppr = true;
```

就是这样。您可能在开发中看不到应用程序的差异，但您应该注意到生产中的性能改进。 Next.js 将预渲染路由的静态部分，并推迟动态部分，直到用户请求它们。部分预渲染的优点在于您无需更改代码即可使用它。只要您使用 Suspense 包装路线的动态部分，Next.js 就会知道路线的哪些部分是静态的，哪些部分是动态的。我们相信 PPR 有潜力成为 Web 应用程序的默认渲染模型，汇集了静态站点和动态渲染的优点。然而，它仍处于实验阶段。我们希望将来能够稳定它，并使其成为 Next.js 构建的默认方式。








## Route Handlers

在 Next.js 中，您可以使用路由处理程序创建 API 端点。https://nextjs.org/docs/app/building-your-application/routing/route-handlers

## Route Segment Config

https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config#dynamic

https://nextjs.org/docs/app/building-your-application/data-fetching

https://nextjs.org/docs/app/building-your-application/data-fetching/incremental-static-regeneration

https://nextjs.org/docs/app/building-your-application/caching#data-cache