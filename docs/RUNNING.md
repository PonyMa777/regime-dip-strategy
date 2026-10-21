# 运行与数据

在 MATLAB 中进入项目目录，显式运行 startup 添加 lib 路径：

    cd('D:\项目群组\project2_regime_dip')
    startup
    testRegimeDip
    r = runRegimeDip;

完整参数网格与随机对照：

    [G,R] = runGrid;

数据放在 data/（不上传 Git）：
- SPY_1993_2026.csv：Date,Open,High,Low,Close。
- SPY_dividends.csv：ExDate,Amount。

项目原始记录注明数据来自 Yahoo，价格和分红必须保持一致口径。
单次输出位于 results/single_<模式>_stop<止损>/；网格结果为 results/grid.csv 和 random_control.csv。结果目录不上传 Git。
默认参数见 ../regimeConfig.m。Project 1 对账测试依赖旁边的 Project 1；其长仓分红处理需要与基准对齐。
本项目仅研究回测，不连接券商、不下单。旧研究记录中的“仓库还没建”“分红待下载”等是历史状态，不作为当前运行指引。