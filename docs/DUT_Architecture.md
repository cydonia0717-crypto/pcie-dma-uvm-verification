# DUT Architecture

The DUT is `dma_if_pcie` from Alex Forencich's `verilog-pcie` repository. It is an FPGA-independent PCIe DMA transaction-layer block with generic TLP request/completion ports and a segmented local-RAM interface.

## H2C path

A read descriptor contains host PCIe address, local RAM destination address, length and descriptor tag. The DUT segments the operation into PCIe Memory Read requests according to MRRS and 4 KiB boundaries, allocates PCIe tags, accepts Completion with Data packets, and writes the payload into the device RAM interface. Descriptor status is generated after the operation completes.

## C2H path

A write descriptor contains host PCIe destination address, local RAM source address, length and descriptor tag. The DUT segments the transfer according to MPS and 4 KiB boundaries, issues segmented RAM reads, and emits PCIe Memory Write TLPs. Descriptor status marks operation completion.

## Source-supported control points

The pinned RTL contains explicit logic for:

- PCIe tag allocation and tag tables for reads;
- read/write operation tables;
- 4 KiB boundary splitting;
- MRRS-based read-request segmentation;
- MPS-based write-request segmentation;
- Completion parsing using Requester ID, Tag, Byte Count and Lower Address;
- descriptor completion/status generation;
- flow-control / transmit-limit status hooks.

## Deliberate scope boundary

This milestone does **not** claim:

- PCIe LTSSM, DLL replay or PHY verification;
- BAR/config-space verification;
- descriptor-ring RTL verification;
- MSI/MSI-X verification.

Those are separate blocks in a complete endpoint and may be integrated later. Keeping the first scope on the DMA datapath makes the project technically defensible and lets verification concentrate on segmentation, tags, completion reassembly and data integrity.
