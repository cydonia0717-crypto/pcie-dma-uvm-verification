# Discovered RTL Issue — Maximum-length unaligned H2C request violates MRRS

## Status

- DUT: `alexforencich/verilog-pcie` / `dma_if_pcie_rd`
- pinned upstream commit: `25156a9a162c41c60f11f41590c7d006d015ae5a`
- discovered by this UVM environment during the 65,535-byte boundary test
- local one-line RTL fix carried under `patches/0001-fix-read-count-width-overflow.patch`
- upstream repository is left untouched; no claim is made that the patch has been accepted upstream

## Trigger

A maximum 16-bit descriptor length and non-DW-aligned PCIe address:

```text
H2C length  = 65535 bytes (16'hffff)
PCIe addr   = ...0001
MRRS        = 512 bytes
```

The original RTL evaluates:

```systemverilog
if (req_op_count_reg + req_pcie_addr_reg[1:0] <=
    {max_read_request_size_dw_reg, 2'b00})
```

`req_op_count_reg` is 16 bits.  For `16'hffff + 1`, the addition is evaluated at the operand width and wraps to zero.  The controller therefore incorrectly classifies the request as smaller than MRRS and takes its 4-KiB-boundary branch.

## Observable failure

The first Memory Read TLP becomes:

```text
Length field = 0  -> PCIe encoding for 1024 DW = 4096 bytes
First BE     = 0xE
MRRS         = 512 bytes
```

The protocol SVA fails immediately:

```text
MRRS violation len_field=0 cfg_enc=2
hdr=20000000010000fe0000b00000000000
```

So this is not merely a reference-model mismatch: the generated PCIe request itself violates the configured MRRS.

## Local fix

Widen the left-hand arithmetic before adding the 2-bit address offset, and widen the comparison RHS to the same width:

```systemverilog
if ({1'b0, req_op_count_reg} + req_pcie_addr_reg[1:0] <=
    {4'b0, max_read_request_size_dw_reg, 2'b00})
```

The qualification flow applies this patch after checking out the exact upstream SHA.  A separate negative-control script restores pristine upstream RTL, reruns the failing test, and requires the original MRRS violation signature to appear.  This keeps both the bug evidence and the fixed green regression reproducible.
