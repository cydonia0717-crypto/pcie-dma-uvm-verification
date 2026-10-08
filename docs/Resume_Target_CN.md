# PCIe DMA Engine UVM 验证 — 简历最终口径

## 推荐项目名称

**PCIe DMA Engine UVM验证 | 个人项目**

时间建议按真实项目时间填写，例如：**2026年10月 - 至今**。

当前真实 DUT 是 transaction-layer DMA engine，因此不写“完整 PCIe Gen3 Endpoint 子系统”，也不把 LTSSM、DLL/PHY、BAR、Descriptor Ring、MSI/MSI-X 或 AXI Memory Model 写成已完成内容。

## 推荐简历版本

- 基于开源 **verilog-pcie / dma_if_pcie** 搭建独立 SystemVerilog/UVM 验证平台，围绕 H2C/C2H DMA 数据通路完成 Descriptor Agent、PCIe TLP Host Agent、Segmented RAM Model、Host/Device 双端 Reference Model、Scoreboard、SVA、Functional Coverage 及 CI 回归框架。
- 构建 **PCIe Tag Outstanding Request Table**，对 Memory Read/Write 的 Length、First/Last BE、4 KB Boundary、MRRS/MPS 及 Completion 的 Requester ID、Tag、Byte Count、Lower Address、Status 建立事务级检查；实测支持 **16 笔并发 Memory Read、Split Completion、单个 64 B CplD 跨 2 个 256-bit beat 传输及跨 Tag 乱序返回**。
- 覆盖 **1 B 小包/非对齐访问、MRRS 256/512 B、MPS 128/256 B、PCIe/RAM 多层反压、Read/Write Enable 门控恢复、UR Completion Error、运行时 Reset Recovery、65,535 B 单 Descriptor 边界**，并通过 17 个 Descriptor 完成 **1 MiB H2C chained DMA**；17 次正常 CI 仿真完成 263 个 Descriptor 端到端检查，均为 0 UVM_ERROR / 0 UVM_FATAL。
- 完成覆盖率收敛，实测 **可达 Functional Coverage 100%（53/53）、DUT Line/Branch Coverage 97.6%/86.2%**；定位 pinned upstream dma_if_pcie_rd 最大长度非对齐请求的位宽溢出问题，复现首个 MemRd 被错误生成 4096 B、违反 MRRS=512 B，通过 SVA、位宽扩展修复及 pristine-upstream negative-control 回归完成闭环。

## 版面较紧时的三条版本

- 基于开源 verilog-pcie/dma_if_pcie 自建 UVM 验证平台，完成 Descriptor/PCIe Host Agent、Segmented RAM Model、双端 Reference Model、Scoreboard、SVA、Functional Coverage 与自动回归。
- 验证 MRRS/MPS 分包、4 KB Boundary、非对齐/Byte Enable、16 Outstanding Memory Read、PCIe Tag 释放/复用、Split/Multi-beat Completion、跨 Tag OOO、PCIe/RAM Backpressure、Enable 门控恢复、Completion Error、Mid-flight Reset Recovery 及 1 MiB chained DMA；17 次正常 CI 回归完成 263 个 Descriptor 检查，0 UVM_ERROR/FATAL。
- 实测可达 Functional Coverage 100%（53/53）、DUT Line/Branch Coverage 97.6%/86.2%；真实定位最大长度非对齐 H2C 请求的位宽溢出问题，导致 4096 B MemRd 违反 MRRS=512 B，并完成 SVA 复现、RTL 修复与 negative-control 验证。

## 面试必须保持一致的数字

- PCIe Tag：16
- Read Operation Table：16
- Write Operation Table：16
- Peak simultaneous PCIe Memory Read：16
- Peak simultaneous DMA descriptors：11
- PCIe Tag 合法复用：全回归 2,568 次；16-tag directed test 中 48 次
- Mid-flight Reset：实测 flush 1 个 Descriptor / 2 个 PCIe Read context，丢弃 16 个 stale CplD，随后 H2C/C2H 正常恢复
- MRRS：256 / 512 B
- MPS：128 / 256 B
- 单 Descriptor 最大验证长度：65,535 B
- 大传输：1 MiB H2C，由 17 个 Descriptor 链接完成
- Multi-beat Completion：64 个 64 B CplD；单个 CplD 最大 2 个 256-bit beat；实测 13 个 Completion backpressure stall cycles
- 正常 qualification：17 runs
- Descriptor end-to-end checks：263
- MemRd / MemWr：2,726 / 1,116
- CplD：41,479
- Reachable Functional Coverage：53/53 = 100%
- Raw Verilator covergroup：53/55 = 96.4%，其中 2 个是 illegal/ignore bin
- DUT Line / Branch Coverage：97.6% / 86.2%
- 真实 DUT bug：1 个，目前不要说 2 个

- 当前公开 baseline：GitHub Actions Run #133，head `a5f01ad61eeaa37a72466d70068f87271735fefc`

## 表述边界

1. RTL 来自开源 verilog-pcie；自己的工作是独立验证环境、checker、coverage、回归和本地修复。
2. 真实发现的问题是 pinned upstream revision 上的 width overflow；不要说 upstream 已接受修复。
3. 1 MiB 是 chained logical DMA，不是单 Descriptor 长度。
4. 当前公开实测结果来自 Verilator/UVM GitHub Actions；VCS/Verdi/URG 脚本存在，但还没有商业 license 实跑结果。
