# 简历目标口径（项目跑通后再冻结数字）

## 推荐项目名

**PCIe DMA Engine UVM 验证 | 个人项目**

不建议写“PCIe Gen3 Endpoint 全子系统”，因为当前真实 DUT 是 transaction-layer DMA engine，不覆盖 LTSSM/DLL/PHY，也不应该把 BAR、Ring、MSI 写成已经验证完成。

## 现阶段可写（不带未测数字）

- 基于开源 `verilog-pcie` 的 `dma_if_pcie` 搭建 SystemVerilog/UVM 验证环境，围绕 Host-to-Card / Card-to-Host DMA 数据通路开发 Descriptor Agent、PCIe TLP Host Agent、Device RAM Model、Reference Model、Scoreboard、SVA 与自动回归框架。
- 面向 PCIe Memory Read/Write 分段与 Completion 重组设计验证场景，覆盖 MPS/MRRS、4 KB Boundary、非对齐/Byte Enable、Split Completion、跨 Tag 乱序返回、16-tag Outstanding 以及 TLP/RAM 多层 Backpressure，并通过 Host/Device 双端内存模型检查端到端数据一致性。
- 对 Memory Read Request 的 Tag、Length、First/Last BE、Requester ID 以及 Completion 的 Byte Count、Lower Address、Status 建立事务级检查，重点验证多 Outstanding 下 Tag 生命周期、Completion 路由与数据重组正确性。

## 只有实测后才能加入的第四条

回归事务数、功能覆盖率、代码覆盖率、真实定位问题数量，都等 CI/VCS 实测后再填。不要继续沿用原简历中的“15,000 笔、92.4%/88.7%、2 个 bug”，除非新工程真的得到这些结果。
