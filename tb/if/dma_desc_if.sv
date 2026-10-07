interface dma_desc_if #(
    parameter int PCIE_ADDR_W = 64,
    parameter int RAM_ADDR_W  = 20,
    parameter int LEN_W       = 16,
    parameter int TAG_W       = 8,
    parameter int RAM_SEL_W   = 2
)(input logic clk);
    logic rst;

    logic [PCIE_ADDR_W-1:0] rd_pcie_addr;
    logic [RAM_SEL_W-1:0]   rd_ram_sel;
    logic [RAM_ADDR_W-1:0]  rd_ram_addr;
    logic [LEN_W-1:0]       rd_len;
    logic [TAG_W-1:0]       rd_tag;
    logic                   rd_valid;
    logic                   rd_ready;
    logic [TAG_W-1:0]       rd_status_tag;
    logic [3:0]             rd_status_error;
    logic                   rd_status_valid;

    logic [PCIE_ADDR_W-1:0] wr_pcie_addr;
    logic [RAM_SEL_W-1:0]   wr_ram_sel;
    logic [RAM_ADDR_W-1:0]  wr_ram_addr;
    logic [LEN_W-1:0]       wr_len;
    logic [TAG_W-1:0]       wr_tag;
    logic                   wr_valid;
    logic                   wr_ready;
    logic [TAG_W-1:0]       wr_status_tag;
    logic [3:0]             wr_status_error;
    logic                   wr_status_valid;

    clocking drv_cb @(posedge clk);
      default input #1step output #0;
      input rst, rd_ready, wr_ready, rd_status_valid, rd_status_tag, rd_status_error,
            wr_status_valid, wr_status_tag, wr_status_error;
      output rd_pcie_addr, rd_ram_sel, rd_ram_addr, rd_len, rd_tag, rd_valid,
             wr_pcie_addr, wr_ram_sel, wr_ram_addr, wr_len, wr_tag, wr_valid;
    endclocking

    clocking mon_cb @(posedge clk);
      default input #1step;
      input rst, rd_pcie_addr, rd_ram_sel, rd_ram_addr, rd_len, rd_tag, rd_valid, rd_ready,
            rd_status_valid, rd_status_tag, rd_status_error,
            wr_pcie_addr, wr_ram_sel, wr_ram_addr, wr_len, wr_tag, wr_valid, wr_ready,
            wr_status_valid, wr_status_tag, wr_status_error;
    endclocking
endinterface
