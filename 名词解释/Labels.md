# 名词解释 Labels

标签其实就一对 `key/value` ，被关联到对象上

> 用于批量选择标识,或者单个选择标识操作对象

### 比如 Pod 中的标签

1. 标签的使用倾向于能够标示对象的特殊特点，并且对用户而言是有意义的（就是一眼就看出了这个Pod是尼玛数据库）
2. 但是标签对**内核系统**是没有直接意义的。

3. 标签可以用来划分特定组的对象（比如，所有女的）
4. 标签可以在创建一个对象的时候直接给与，也可以在后期随时修改
5. 每一个对象可以拥有多个标签，但是，key值必须是唯一的

```json
"labels": {
 "key1" : "value1",
 "key2" : "value2"
 }
 ```

最终会索引并且反向索引（reverse-index）labels，以获得更高效的**查询**和**监视**，把他们用到`UI`或者`CLI`中用来排序或者分组等等。

不想用那些不具有指认效果的`label`来污染`label`，特别是那些体积较大和结构型的的数据。

> 不具有指认效果的信息应该使用`annotation`来记录。

## Motivation

Label可以让用户将他们自己的有组织目的的结构以一种松耦合的方式应用到系统的对象上，且不需要客户端存放这些对应关系（`mappings`）。

服务部署和批处理管道通常是多维的实体（例如多个分区或者部署，多个发布轨道，多层，每层多微服务）。
管理通常需要跨越式的切割操作，这会打破有严格层级展示关系的封装，特别对那些是由基础设施而非用户决定的很死板的层级关系。

### Label例子

```
“release” : “stable”, “release” : “canary”, …
 “environment” : “dev”, “environment” : “qa”, “environment” : “production”
 “tier” : “frontend”, “tier” : “backend”, “tier” : “middleware”
 “partition” : “customerA”, “partition” : “customerB”, …
 “track” : “daily”, “track” : “weekly”
```

## Label的语法和字符集

Label其实是一对 `key/value`

有效的Label keys必须是部分：
1. 一个可选前缀+名称，通过`/`来区分
2. 名称部分是必须的，并且最多63个字符
3. 开始和结束的字符必须是字母或者数字，中间是字母数字和”_”，”-“，”.”
4. 前缀是刻有可无的，如果指定了，那么前缀必须是一个`DNS`子域
    一系列的DNSlabel通过`.`来划分，长度不超过253个字符，`/`来结尾。

5. 如果前缀被省略了，这个`Label`的`key`被假定为对用户私有的，自动组成系统部分（比如`kube-scheduler`,` kube-controller-manager`, `kube-apiserver`, `kubectl`）,这些为最终用户添加标签的必须要指定一个前缀
    > `Kuberentes.io` 前缀是为`Kubernetes` 内核部分保留的。

6. 合法的`label`值必须是`63`个或者更短的字符。

> 要么是空，要么首位字符必须为字母数字字符，中间必须是横线，下划线，点或者数字字母。

## Label选择器

与`name`和`UID`不同，`label`不提供唯一性。

通常，会看到很多对象有着一样的label。

通过`label`选择器，`客户端/用户`能方便辨识出一组对象。

`label`选择器是`kubernetes`中核心的组织原语。

### `API`目前支持两种选择器：基于相等的和基于集合的。

1. 一个`label`选择器一可以由多个必须条件组成，由**逗号**分隔。
    > 在多个必须条件指定的情况下，所有的条件都必须满足，因而逗号起着`AND`逻辑运算符的作用。

2. 一个空的`label`选择器（即有`0`个必须条件的选择器）会选择集合中的每一个对象。

3. 一个`null`型`label`选择器（仅对于可选的选择器字段才可能）不会返回任何对象。

### Equality-based requirement

基于相等性或者不相等性的条件允许用`label`的键或者值进行过滤。

匹配的对象必须满足所有指定的`label`约束，尽管他们可能也有额外的`label`。

有三种运算符是允许的，`=`，`==`和`!=`

> 前两种代表相等性（他们是同义运算符），后一种代表非相等性。例如：

### 示例

`environment = production`
`tier != frontend`

第一个选择所有键等于 `environment` 值为 `production` 的资源。

后一种选择所有键为 `tier` 值不等于 `frontend` 的资源，和那些**没有**键为 `tier` 的`label`的资源。

要过滤所有处于 `production` 但不是 `frontend` 的资源，可以使用逗号操作符， `environment=production,tier!=frontend`

## 基于set的条件

基于集合的`label`条件允许用一组值来过滤键。

支持三种操作符: `in` ， `notin` ,和 `exists`(仅针对于key符号) 。

例如：

```
environment in (production, qa)
tier notin (frontend, backend)
partition
!partitio
```

1. 第一个例子，选择所有键等于 `environment` ，且`value`等于 `production` 或者 `qa` 的资源。
2. 第二个例子，选择所有键等于 `tier` 且值是除了 `frontend` 和 `backend` 之外的资源，和那些**没有**`label`的键是 `tier` 的资源。
3. 第三个例子，选择所有所有有一个`label`的键为`partition`的资源；**值**是什么不会被检查。 
4. 第四个例子，选择所有的没有`lable`的键名为 `partition` 的资源；值是什么不会被检查。

### 类似的，**逗号**操作符相当于一个`AND`操作符。

因而要使用一个 `partition` 键（不管值是什么），并且 `environment` 不是 `qa` 过滤资源可以用 partition,environment notin (qa) 。

基于集合的选择器是一个相等性的宽泛的形式，因为 `environment=production` 相当于`environment in (production) `，与 `!= and notin` 类似。

基于集合的条件可以与基于相等性 的条件混合。
例如， `partition in (customerA,customerB),environment!=qa` 。