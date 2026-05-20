---
title: "Jetpack Compose 中实现长按拖拽排序"
date: 2026-05-20T00:00:00+08:00
lastmod: 2026-05-20T00:00:00+08:00
draft: false
categories:
  - Android
tags:
  - Android
  - Jetpack Compose
  - 拖拽排序
  - 交互设计
description: "记录一次在股票持仓列表中实现长按拖拽排序的过程，包括提示词、状态设计、坐标冻结、跨屏自动滚动、插入线和被挤压行的视觉反馈。"
---

## 可复用提示词

```text
请在现有 Android Jetpack Compose 列表页面中实现“长按拖拽排序”能力，要求尽量复用当前页面、ViewModel 和保存接口，不引入不必要的新库。

交互要求：
1. 用户长按列表行后进入拖动状态，整行跟随手指移动。
2. 长按生效时需要有明确反馈，例如背景高亮、轻微缩放、透明度变化或触觉反馈。
3. 拖动过程中展示一条高亮插入线，表示松手后条目会插入的位置。
4. 拖动过程中，被拖动条目跨过的其他行要动态让位。例如向下拖时，中间行上移；向上拖时，中间行下移。
5. 普通行间分隔线需要跟随对应行一起移动，插入线替换对应位置的分隔线，不要出现分隔线丢失或覆盖文字。
6. 松手后再真正修改数据顺序，不要在拖动过程中反复重排真实列表。
7. 当列表超过一屏时，拖动到列表顶部或底部附近需要自动滚动，让用户可以跨屏幕拖动条目。
8. 被挤压行移动时，行内容、行间分隔线、行间空白要作为一个完整视觉单元移动，不要把外边距或分隔线残留在原地。
9. 最终顺序应能通过现有保存流程持久化。

实现约束：
1. 使用 detectDragGesturesAfterLongPress 监听长按拖动。
2. 使用稳定 key 保持行身份，避免滚动或重排后移动到错误条目。
3. pointerInput 尽量保持稳定；如果回调依赖最新 index 或状态，用 rememberUpdatedState 转接最新回调。
4. 拖动开始时记录起始 index、起始手指 Y 坐标，并冻结一份当前可见行的真实屏幕坐标，拖动过程中用冻结坐标计算插入位置，避免视觉位移反过来影响命中判断导致抖动。
5. 插入位置使用 insertionIndex 表示，范围为 0..items.size；松手时把 fromIndex 转换成实际 targetIndex。
6. 用 onGloballyPositioned / positionInWindow 记录每一行 top、bottom，用 onSizeChanged 或兜底 dp 值记录行高。
7. 对被挤压的行使用 graphicsLayer.translationY 做视觉位移，不在拖动中修改真实列表顺序。
8. 行位移步长不要只用行内容高度，优先用相邻两行 top 坐标差，确保步长包含行间分隔线和行间空白。
9. LazyColumn 使用 rememberLazyListState，并记录列表 viewport 的 top、bottom；拖动时如果手指靠近 viewport 顶部或底部，使用 scrollBy 持续自动滚动。
10. 自动滚动会改变内容相对屏幕的位置，需要维护 dragScrollOffset：被拖动行的 translationY 要补上滚动消耗，命中插入位置时则用 fingerY = dragStartFingerY + dragOffset - dragScrollOffset，并让冻结坐标按 scrollOffset 修正。
11. 完成后运行 Kotlin/Gradle 编译检查，并说明验证结果。

请先阅读现有代码结构，再按项目已有风格实现。保持改动聚焦，避免重构无关逻辑。
```

<!--more-->

## 实现细节

这次改的是一个股票持仓管理页面。列表本身是 Compose 的 `LazyColumn`，每行是一只股票，ViewModel 中已有 `entries: List<StockEntry>` 作为当前顺序，也已有保存接口。目标不是引入一个完整拖拽库，而是在现有结构上把“长按拖动改变排序”补齐。

最终实现里，拖动排序拆成了三层：

1. 手势层：长按后开始拖动，记录手指位移。
2. 视觉层：被拖动行跟随手指，被跨过的行动态让位，插入线显示落点。
3. 数据层：松手时一次性提交新的顺序。

### 为什么不边拖边修改列表

最开始尝试过在拖动过程中直接调用 `moveEntry`，每跨过一行就真实修改一次 `entries`。这个方案的问题很明显：Compose 会因为列表数据变化而重新布局，被拖动行又有 `translationY`，两者叠加后容易产生“越拖越偏”的错位。

后来改成“拖动中只做视觉位移，松手时提交数据”。这样被拖动行的位置完全由手指位移控制，真实列表顺序在拖动结束前保持不变，稳定性好很多。

### 关键状态

页面中维护了几类拖动状态：

```kotlin
var draggingCode by remember { mutableStateOf<String?>(null) }
var dragStartIndex by remember { mutableIntStateOf(-1) }
var dragInsertionIndex by remember { mutableIntStateOf(-1) }
var dragStartFingerY by remember { mutableFloatStateOf(0f) }
var dragOffset by remember { mutableFloatStateOf(0f) }
var dragScrollOffset by remember { mutableFloatStateOf(0f) }
val rowBounds = remember { mutableMapOf<String, StockManagerRowBounds>() }
var dragRowBounds by remember { mutableStateOf<Map<String, StockManagerRowBounds>>(emptyMap()) }
```

这里有两个 index：

- `dragStartIndex`：被拖动股票原来的位置。
- `dragInsertionIndex`：当前高亮插入线的位置，范围是 `0..entries.size`。
- `dragScrollOffset`：拖动过程中由自动滚动产生的累计滚动补偿。

`dragInsertionIndex` 不是目标行 index，而是“插入到第几个元素前面”。例如值为 `0` 表示插到最前面，值为 `entries.size` 表示插到最后。

### 长按手势

拖动手势由 `detectDragGesturesAfterLongPress` 负责：

```kotlin
pointerInput(code) {
    detectDragGesturesAfterLongPress(
        onDragStart = { offset -> currentOnDragStart(offset.y) },
        onDragEnd = { currentOnDragEnd() },
        onDragCancel = { currentOnDragEnd() },
        onDrag = { change, dragAmount ->
            change.consume()
            currentOnDragMove(dragAmount.y)
        },
    )
}
```

这里的 `pointerInput` 使用股票代码作为 key，保证同一只股票的手势监听比较稳定。同时用 `rememberUpdatedState` 包一层回调，避免滚动或重组后手势内部仍然拿到旧的 index。这一点很关键，否则会出现“按住 A，实际移动 B”的问题。

### 冻结行坐标，避免抖动

每行通过 `onGloballyPositioned` 记录当前真实屏幕坐标：

```kotlin
onGloballyPositioned { coordinates ->
    val top = coordinates.positionInWindow().y
    onPositioned(top, top + coordinates.size.height)
}
```

进入拖动时，会复制一份当前坐标：

```kotlin
val boundsSnapshot = rowBounds.toMap()
dragRowBounds = boundsSnapshot
```

后续拖动过程中，落点计算优先使用这份冻结坐标，而不是实时坐标。原因是被挤压的行会通过 `graphicsLayer.translationY` 发生视觉位移，如果继续用实时坐标计算插入位置，就会形成反馈环：插入位置变化导致行移动，行移动又导致插入位置变化，表现为抖动。

冻结坐标后，视觉动画不会影响命中判断。

### 根据手指位置计算插入线

拖动时累计 `dragOffset`，然后用起始手指位置加上累计位移得到当前手指 Y 坐标：

```kotlin
dragOffset += deltaY
val fingerY = dragStartFingerY + dragOffset - dragScrollOffset
dragInsertionIndex = resolveStockManagerDragInsertionIndex(
    fingerY = fingerY,
    entries = uiState.entries,
    rowBounds = dragRowBounds.ifEmpty { rowBounds },
    scrollOffset = dragScrollOffset,
) ?: fallback
```

插入位置计算逻辑是：遍历可见行的 `top..bottom`，如果手指在某行上半部分，就插到该行前面；如果在下半部分，就插到该行后面。

```kotlin
if (fingerY <= bounds.bottom) {
    val center = (bounds.top + bounds.bottom) / 2f
    return if (fingerY < center) bounds.index else bounds.index + 1
}
```

这个算法比“拖动距离除以行高”更准确，因为它考虑了实际行坐标、字体高度、分隔线和屏幕密度。

### 跨屏拖动：边缘自动滚动

列表超过一屏后，只让行在当前屏幕里拖动是不够的。跨屏拖动的做法是给 `LazyColumn` 增加 `LazyListState`，并记录整个列表 viewport 的屏幕坐标：

```kotlin
val listState = rememberLazyListState()
var listViewportTop by remember { mutableFloatStateOf(0f) }
var listViewportBottom by remember { mutableFloatStateOf(0f) }

LazyColumn(
    state = listState,
    modifier = Modifier
        .fillMaxSize()
        .onGloballyPositioned { coordinates ->
            val top = coordinates.positionInWindow().y
            listViewportTop = top
            listViewportBottom = top + coordinates.size.height
        },
) {
    // ...
}
```

拖动状态存在时，启动一个 `LaunchedEffect(draggingCode)` 循环。每一帧检查手指是否靠近列表顶部或底部，如果靠近，就调用 `listState.scrollBy(scrollDelta)`：

```kotlin
LaunchedEffect(draggingCode) {
    while (draggingCode != null) {
        val fingerY = dragStartFingerY + dragOffset - dragScrollOffset
        val scrollDelta = stockManagerAutoScrollDelta(
            fingerY = fingerY,
            viewportTop = listViewportTop,
            viewportBottom = listViewportBottom,
            edgeThresholdPx = autoScrollEdgePx,
            maxScrollStepPx = autoScrollStepPx,
        )
        if (scrollDelta != 0f) {
            val consumed = listState.scrollBy(scrollDelta)
            if (consumed != 0f) {
                dragOffset += consumed
                dragScrollOffset += consumed
                // 继续用新的手指位置刷新插入线
            }
        }
        withFrameNanos { }
    }
}
```

这里有一个不太直观但很重要的补偿：自动滚动会让列表内容在屏幕上移动，如果只滚列表，不补偿拖动行，手指和被拖动行会立刻错开。所以滚动消耗了多少，就同步加到 `dragOffset`；但计算插入位置时，又要减掉 `dragScrollOffset`，也就是：

```kotlin
val fingerY = dragStartFingerY + dragOffset - dragScrollOffset
```

冻结坐标也要接受同样的滚动修正：

```kotlin
val visibleBounds = entries.mapNotNull { entry -> rowBounds[entry.code] }
    .map { bounds ->
        bounds.copy(
            top = bounds.top - scrollOffset,
            bottom = bounds.bottom - scrollOffset,
        )
    }
```

这样被拖动行继续贴着手指，插入位置也能跟随列表自动滚动后新的视觉位置更新。

### 被挤压行的视觉位移

拖动过程中不改真实列表，但要让其他行看起来已经让位。做法是计算每一行的 `rowDisplacement`：

```kotlin
return when {
    dragInsertionIndex > dragStartIndex &&
        index > dragStartIndex &&
        index < dragInsertionIndex -> -rowDragStepPx

    dragInsertionIndex < dragStartIndex &&
        index >= dragInsertionIndex &&
        index < dragStartIndex -> rowDragStepPx

    else -> 0f
}
```

向下拖时，起始行和插入线之间的行上移一行；向上拖时，中间行下移一行。每个普通行通过 `graphicsLayer.translationY` 应用这个位移。

被拖动行本身则使用手指累计位移：

```kotlin
translationY = if (isDragging) dragOffset else rowDisplacement
```

同时加了一点视觉反馈：

- 背景高亮。
- 透明度轻微变化。
- 轻微缩放。
- 长按进入拖动时触发一次 `HapticFeedbackType.LongPress`。

后来去掉了阴影，因为在密集表格里阴影看起来比较脏。

### 位移步长要包含分隔线和空白

这里还有一个细节：`rowDragStepPx` 不能简单等于某一行自身的高度。因为视觉上相邻两行之间通常还有分隔线、padding 或其它空白。如果被挤压行只移动“行内容高度”，行间空白就会像留在原地一样，看起来有一块外边距没有跟着行走。

更稳的做法是拖动开始时根据冻结坐标计算完整步长：优先取相邻两行的 top 坐标差。

```kotlin
private fun stockManagerRowStepPx(
    index: Int,
    entries: List<StockEntry>,
    rowBounds: Map<String, StockManagerRowBounds>,
    fallback: Float,
): Float {
    val current = entries.getOrNull(index)?.let { rowBounds[it.code] } ?: return fallback
    val next = entries.getOrNull(index + 1)?.let { rowBounds[it.code] }
    if (next != null) {
        return (next.top - current.top).takeIf { it > 0f } ?: fallback
    }

    val previous = entries.getOrNull(index - 1)?.let { rowBounds[it.code] }
    if (previous != null) {
        return (current.top - previous.top).takeIf { it > 0f } ?: fallback
    }

    return (current.bottom - current.top).takeIf { it > 0f } ?: fallback
}
```

这样 `rowDisplacement` 移动的是“从一行到下一行”的完整视觉距离，而不只是行内容高度。普通分隔线和插入线也使用同一个 `rowDisplacement`，视觉上就不会出现内容移动了、线或空白还残留在原位置的问题。

### 插入线和分隔线

插入线使用一个很薄的独立组件：

```kotlin
@Composable
private fun StockManagerDropIndicator(
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(7.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(2.dp)
                .background(
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(999.dp),
                ),
        )
    }
}
```

这里有两个细节：

1. 插入线不画在股票行内容上，避免和文字顶部重合。
2. 插入线替换对应位置的普通分隔线，而不是额外叠在上面。

普通分隔线也要跟随对应股票行位移，否则向上拖时会出现“股票动了，线没动”的违和感。所以分隔线也应用同一个 `rowDisplacement`：

```kotlin
HorizontalDivider(
    modifier = Modifier.graphicsLayer {
        translationY = rowDisplacement
    },
    color = Border.copy(alpha = 0.7f),
)
```

插入线同理，也根据当前位置应用位移。

### 松手时提交真实顺序

拖动结束时才调用 ViewModel 修改真实数据：

```kotlin
viewModel.moveEntryToInsertionIndex(dragStartIndex, dragInsertionIndex)
```

ViewModel 中的 `moveEntryToInsertionIndex` 负责把“插入位置”转换成真正的目标 index：

```kotlin
val targetIndex = if (boundedInsertionIndex > fromIndex) {
    boundedInsertionIndex - 1
} else {
    boundedInsertionIndex
}
```

这是因为从原列表里先移除 `fromIndex` 后，如果插入点在它后面，后续元素整体前移了一位，所以需要减一。

实际移动代码是：

```kotlin
val next = state.entries.toMutableList()
val item = next.removeAt(fromIndex)
next.add(targetIndex.coerceIn(0, next.size), item)
```

之后复用原来的保存流程，用户点击“保存更改”即可持久化。添加股票时的保存也沿用原接口，只是把添加相关提示放到了“添加股票”按钮附近。

### 容易踩的坑

这次实现里，几个坑比较典型：

1. 不要拖动中反复真实重排列表，否则容易出现拖动行和手指距离越来越远。
2. 不要只用 `dragOffset / rowHeight` 算目标位置，长列表、分隔线和不同密度屏幕下容易差一两行。
3. 不要用被挤压后的实时坐标算插入位置，否则会抖动。
4. 不要让插入线覆盖在文字内容上，密集表格里会很明显。
5. 如果行和分隔线是分开 composable，分隔线也要跟随被挤压行位移。
6. `pointerInput` 如果为了稳定只用 code 做 key，内部回调必须用 `rememberUpdatedState` 接住最新状态。
7. 跨屏拖动时，自动滚动要同步维护滚动补偿；否则列表滚了，但被拖动行或插入线会和手指错位。
8. 被挤压行的位移步长要用相邻行 top 差，不能只用行自身高度，否则行间空白会像“外边距残留”一样停在原地。

## 总结

这个实现的核心不是“让列表项能动”，而是把拖动拆成两个阶段：

- 拖动中：只做视觉模拟。
- 松手后：一次性修改真实数据。

再配合冻结坐标、边缘自动滚动、滚动补偿、插入线、被挤压行位移和稳定手势回调，就能在不引入第三方库的情况下，做出比较稳的 Compose 长按拖拽排序体验。
