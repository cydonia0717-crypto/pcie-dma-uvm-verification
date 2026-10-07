# PCIe DMA Engine UVM 项目面试深挖题库

> 口径基于公开 GitHub Actions 实测结果。RTL 来自开源 verilog-pcie，自己的工作是独立验证环境、checker、coverage、回归、bug 定位与本地修复。

## 1. 这个项目具体验证什么？

验证的是 verilog-pcie 里的 `dma_if_pcie` Transaction-Layer DMA Engine，不是完整 PCIe Endpoint。项目覆盖 Descriptor 到 Memory Read/Write TLP、Completion、Device RAM 数据搬运和状态返回；LTSSM、DLL replay、PHY、BAR/config-space、MSI/MSI-X 不在当前 DUT scope。

## 2. H2C 和 C2H 的数据流分别是什么？

H2C 是 Host -> Device：Descriptor 进入 DUT，DUT 发 Memory Read TLP，Host Agent 返回 Completion with Data，DUT 再把数据写到 Device RAM。C2H 是 Device -> Host：DUT 从 Device RAM 读数据，生成 Memory Write TLP，由 Host Agent 写入 Host Memory Model。

## 3. 为什么 PCIe 侧不用完整 VIP？

这个项目目标是验证 DMA transaction-layer control，而不是复刻完整商用 PCIe VIP。Host Agent 只实现 DUT 所需的受限协议子集：MemRd/MemWr/CplD、Tag、Length、First/Last BE、Byte Count、Lower Address、Completion Status 和 backpressure。这样验证重点仍然落在 DMA splitting、outstanding 和 reassembly。

## 4. DUT 的关键配置是什么？

256-bit TLP datapath，64-bit PCIe address，16 个 PCIe Tag，read/write operation table 各 16 entry，device-side segmented RAM 为 1 MiB，descriptor tag 8 bit。验证 MRRS 256/512 B、MPS 128/256 B，并强制 4-DW Memory Request 方便确定性检查。

## 5. 16 Outstanding Memory Read 是怎么真正验证的？

Host responder 可以延迟所有 Completion，直到观察到 16 个不同 PCIe request tag 同时 pending 后才开始释放 CplD。Scoreboard 独立跟踪 live PCIe tag，directed test 要求 `max_pcie_outstanding==16`，否则直接报错。公开 qualification 中确实观察到 16 个同时 active 的 Memory Read tag。

## 6. 为什么之前简单发 16 个 Descriptor 还不等于 16 Outstanding？

因为每个 Descriptor 可能在前一个 Completion 很快回来后才继续发下一批请求。只看“发了 16 个 Descriptor”不能证明资源同时占用。后来把 Completion hold 做成确定性机制，必须在同一时间看到 16 个不同 request tag，才算真的覆盖 16 Outstanding。

## 7. Outstanding Request Table 里跟踪什么？

验证侧按 PCIe Tag 跟踪 request address、有效 byte 数、requester context、当前 Byte Count/Lower Address 进度以及 Completion sequence。它的核心用途是允许不同 Tag 的 Completion 乱序回来，而仍能把每个 CplD 路由到正确 request context。

## 8. 为什么 Completion 不能简单 FIFO 比较？

不同 PCIe Tag 之间允许 Completion 返回顺序不同，而且一个 Memory Read 还可能被拆成多个 Completion。如果 scoreboard 按 request FIFO 比对，会把合法的 cross-tag OOO 当成错误。必须以 Tag 为主键维护 transaction context。

## 9. Split Completion 怎么构造？

Host Agent 把一个 MemRd request 按较小 Completion payload 切成多个 CplD，逐个维护 Byte Count、Lower Address 和 payload offset。当前回归里累计观察到大量 read request 经过多个 CplD 完成，验证 DUT 能正确重组。

## 10. 同一个 Tag 的多个 Completion 能乱序吗？

当前 Host Agent 保持同一个 Tag 内的 split completions 顺序，只对不同 Tag 做随机 reorder。这与项目要验证的 cross-tag OOO 目标一致，也避免制造不符合 requester completion sequence 预期的非法流量。

## 11. Cross-Tag OOO 怎么证明实际发生？

Host responder 在多个已经 ready 的不同 Tag completion 中随机选择返回。Directed `dma_split_ooo_test` 会统计 reorder event；公开 qualification 中该用例实际观察到 `cross_tag_ooo=44`，不是只打开了一个配置开关。

## 12. MRRS 是怎么检查的？

Scoreboard 根据 `max_read_request_size` 配置解码允许的最大 MemRd payload，逐笔检查 Memory Read TLP 的有效 byte length。SVA 也直接检查 TLP Length field 不超过配置 MRRS。MRRS=512 B 的 directed test 已实际观察到最大 512 B MemRd。

## 13. MPS 是怎么检查的？

对 C2H 生成的 Memory Write TLP，checker 根据 `max_payload_size` 计算允许的最大 payload，检查每笔 MemWr 不超过 MPS。MPS=256 B directed test 中实际观察到最大 256 B MemWr。

## 14. 4 KB Boundary 怎么验证？

对接近 4 KiB 边界的 H2C/C2H descriptor，检查拆出的每笔 MemRd/MemWr 都满足 `(addr[11:0] + byte_len) <= 4096`。Functional Coverage 里把真正跨 4 KiB 的单笔 request 定义成 illegal bin，而不是拿非法行为做 coverage closure。

## 15. First BE / Last BE 为什么重要？

非 DW 对齐的 PCIe request 首尾有效字节不是完整 4-byte。验证环境从 header 解码 First/Last BE，计算真正有效 byte range，再做 Host/Device reference memory 的字节级比较，防止只按 Length×4 检查而掩盖首尾数据错误。

## 16. 非对齐场景怎么覆盖？

有专门 small/unaligned sequence，覆盖 1/2/3/4/8/16/31/32 B 等长度和地址 offset 1/2/3。Host/Device memory 周围保留原值，确保未被 byte enable 覆盖的相邻字节不能被误写。

## 17. Device RAM 为什么不是 AXI Memory Model？

真实 `dma_if_pcie` 原生接口是 segmented RAM，不是 AXI。为了让项目和 RTL scope 一致，验证环境实现 Segmented RAM Model。把它写成 AXI 会给简历增加一个实际上不存在的 interface，面试时很容易被追问穿。

## 18. Segmented RAM Model 怎么工作？

H2C 接收 DUT 的多 segment write command，并按 segment address/byte-enable 更新 Device Memory image；C2H 响应 DUT 的 RAM read command并返回对应数据。Model 可以独立对 read/write path 注入 backpressure。

## 19. Reference Model 怎么设计？

维护两份独立的 byte-addressed architectural image：Host Memory 和 Device Memory。Descriptor 被接受时 snapshot source 数据；descriptor status 返回时，根据方向检查 destination memory 每个 byte 是否与 snapshot 一致，从而做真正端到端数据完整性验证。

## 20. 为什么要在 Descriptor 接受时 snapshot source 数据？

如果直到完成时才重新读取 source memory，期间其他并发事务可能修改 source，checker 就无法判断该 descriptor 启动时应该搬什么数据。Snapshot 能固定事务的 reference context，避免并发下 reference model 自己产生 race。

## 21. Descriptor 并发怎么验证？

Scoreboard 用 `{direction, descriptor_tag}` 管理 live operation，不按 FIFO 结束。随机压力测试中已经观察到最多 11 个 DMA descriptor 同时 outstanding，同时 PCIe read path 能达到 16 active tags。

## 22. Backpressure 做了哪些层？

PCIe request ready 可以随机拉低，Completion 侧会等待 DUT ready，Device RAM read/write 也可以独立 throttle。协议 SVA 检查 valid&&!ready 时 payload 稳定，Scoreboard检查最终没有 request loss、重复或数据破坏。

## 23. Completion Error 怎么验证？

Host responder 可以为指定 read 注入 Unsupported Request Completion。DUT 应把 PCIe completion error 映射到 descriptor status，而不是继续当正常 payload 写 RAM。当前 directed test 已验证 UR 能传播成 DMA error 0xA。

## 24. 最大 Descriptor 长度为什么是 65,535 B？

DUT 的 LEN_WIDTH 固定为 16，因此 descriptor len 最大是 `16'hffff`。项目分别验证 H2C/C2H 65,535 B 单 descriptor 边界，保证计数器、分包和 RAM addressing 不在最大值附近溢出。

## 25. 1 MiB DMA 是不是一个 Descriptor？

不是。16-bit length 不可能单 descriptor 表示 1 MiB。项目用 17 个 descriptors 链接成 1 MiB logical H2C transfer，所以简历必须写“1 MiB chained DMA”，不能说“单笔 1 MiB descriptor”。

## 26. 1 MiB 场景实际测到了什么？

公开 qualification 中 17 个 descriptor 全部完成，累计写入 Device RAM 1,048,576 bytes，同时观察到 16 PCIe read tags in flight。这个场景主要验证长时间 sustained splitting、tag reuse 和跨 descriptor 端到端数据一致性。

## 27. 你真正发现的 RTL bug 是什么？

在 pinned upstream revision 上，65,535-byte H2C descriptor 如果 PCIe address offset=1，`req_op_count_reg + req_pcie_addr_reg[1:0]` 的运算宽度不足。16'hffff + 1 在 16-bit 算术里回绕为 0，导致 request-size 判定错误。

## 28. 这个 bug 外部表现是什么？

DUT 第一笔 Memory Read TLP 的 Length field 变成 0。PCIe 中 Length=0 表示 1024 DW，也就是 4096 B；而当时 MRRS 配置只有 512 B，所以协议 SVA 直接报 `MRRS violation`。这不是 reference mismatch，而是 DUT 真正生成了非法 request。

## 29. 为什么它只在极限长度+非对齐下出现？

65,535 已经是 16-bit 最大值，地址 offset=1 后正好进位到 65,536。如果不是最大值，或者 offset=0，就不会发生这个特定的 wraparound，因此普通几 KB DMA 回归很难触发。

## 30. 怎么修的？

把左边先显式扩展一位再相加，并把比较右边扩展到相同宽度：
`{1'b0, req_op_count_reg} + req_pcie_addr_reg[1:0]`。修复后 65,535 B H2C/C2H directed case 全绿。

## 31. 怎么证明不是 testbench 自己误报？

项目有 negative-control script：恢复 pristine pinned upstream RTL，重新编译同一个 directed test，并要求原来的 MRRS assertion 必须再次出现。正常 qualification 用本地一行修复应全绿；pristine RTL 必须稳定失败，两边形成闭环。

## 32. 这个 bug 能不能说成 upstream 已修复？

不能。目前只能说“在固定的 upstream commit 上发现，并在项目中做了 local patch”。除非真实提交 PR 并被 upstream 接受，否则不能写“已被官方修复”或“贡献 upstream patch”。

## 33. 当前覆盖率怎么解释？

公开合并回归的 reachable functional coverage 是 51/51=100%。Raw covergroup 是 51/53=96.2%，少的两个分别是明确的 illegal 4KiB-cross request bin 和 ignore Completion-status catch-all，所以不放入 closure denominator。新增的 Tag lifecycle first-use/reuse 和 runtime-reset coverage 也都已命中。DUT scoped line coverage 97.4%，branch coverage 82.2%。

## 34. 为什么 Branch Coverage 82.2% 还可以收敛？

这个 RTL 是参数化通用 DMA engine，固定 qualification 配置关闭了部分分支，例如不同 address format、扩展 tag/某些 flow-control/parameter-specific 路径。Branch Coverage 需要结合 feature scope 做 hole review，不能为了数字去改变项目配置。功能 closure 和协议关键路径已经由 vPlan、SVA、directed/random regression共同覆盖。

## 35. 正常 regression 有多少？

当前公开 baseline 是 GitHub Actions Run #110，共 15 个 clean simulation runs，包括 smoke、4KiB、16-tag、small/unaligned、MRRS/MPS、split/OOO、backpressure、completion error、max length、zero-length、mid-flight reset recovery、1MiB chain 和 3 个 random seeds。总计完成 260 个 descriptor end-to-end checks，全部 0 UVM_ERROR / 0 UVM_FATAL。

## 36. 随机测试不是只跑一个 Seed 吗？

不是。当前 qualification 固定跑 11、29、47 三个 seed，便于 CI 可复现，同时 directed testcase 负责风险闭环。随机测试中都同时出现 MemRd/MemWr、多个 descriptor、16 PCIe tags 和大量 cross-tag OOO。

## 37. 项目里最难的部分是什么？

最难的是同时处理三层 context：Descriptor-level operation、PCIe Tag-level read request、以及每个 Tag 内多个 Completion。Checker 如果只看 FIFO 或只看最终 memory，很容易漏掉 splitting/reassembly 的控制错误；因此环境把 descriptor table、PCIe Outstanding Table、CplD progression 和双端 memory image分层建模。

## 38. 为什么最后没有把 BAR、MSI、Descriptor Ring 强行加进来？

因为当前 DUT `dma_if_pcie` 的职责就是 DMA transaction engine。BAR/config-space、interrupt 和 descriptor fetch/ring 属于其他 block。把 TB 自己模拟出来的功能包装成 DUT 已验证会失真。这个项目优先追求 scope 准确和可追溯证据。

## 39. VCS/Verdi 用过了吗？

当前公开测量数据来自 Verilator/UVM GitHub Actions。仓库里已经维护 VCS/Verdi/URG flow，包括 VCS code coverage 和 Verdi KDB/debug database，但没有商业 license 的真实运行结果，所以简历不写“VCS coverage 已跑”。

## 40. 你自己完成了哪些内容？

独立搭建 Descriptor Agent、PCIe Host responder/monitor、Segmented RAM Model、Host/Device Reference Model、Scoreboard、PCIe Tag Outstanding tracking、SVA、Functional Coverage、directed/random sequences、runtime-reset recovery、GitHub Actions regression/coverage flow，以及最大长度 bug 的定位、local RTL fix 和 negative-control reproducer。开源 DMA RTL 本身不是自己设计的。

## 41. PCIe Tag 的释放和重复使用怎么验证？

Scoreboard 除了维护 active Tag table、禁止 Tag 在尚未完成时提前复用，还单独记录每个 Tag 的生命周期。16-tag directed test 先证明 16 个 Tag 同时占满，随后 Completion 退休后继续发后续 request，Run #110 在这个用例里观察到 **48 次合法 Tag reuse**；整个 15-run qualification 累计观察到 **2,568 次**，对应 coverage 里 first-use/reuse 两个 bin 都命中。

## 42. Mid-flight Reset Recovery 怎么验证？

这个测试不和 16-tag capacity pressure 绑在一起，而是先让一个真实 H2C descriptor 产生未完成 PCIe read，再扣住 Completion 后打运行时 reset。Run #110 实测 reset 时 Scoreboard flush 了 **1 个 Descriptor 和 2 个 PCIe Read context**，Host responder 丢弃了 **16 个 stale CplD**；reset 后再发新的 H2C/C2H，两边都正常完成，DUT busy 也恢复为 0。这样同时验证了旧事务不会跨 reset 泄漏，以及 reset 后资源能重新初始化并继续前进。
