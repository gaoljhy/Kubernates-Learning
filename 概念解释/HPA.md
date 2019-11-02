# Horizontal Pod Autoscaler(HPA)

Horizontal Pod Autoscaler(HPA)即`Pod`横向自动扩容，与`RC`一样也属于k8s的资源对象。

`HPA`原理：通过追踪分析`RC`控制的所有目标`Pod`的负载变化情况，来确定是否针对性调整`Pod`的副本数。

## Pod负载度量指标：

+ `CPUUtilizationPercentage`：Pod所有副本自身的`CPU`利用率的平均值。即当前`Pod`的`CPU`使用量除以`Pod Request`的值。

+ 应用自定义的度量指标，比如服务**每秒内响应的请求数**（`TPS/QPS`）。