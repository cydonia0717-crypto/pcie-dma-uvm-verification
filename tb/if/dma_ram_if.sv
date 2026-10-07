interface dma_ram_if #(
    parameter int SEG_COUNT = 2,
    parameter int SEL_W = 2,
    parameter int SEG_ADDR_W = 14,
    parameter int SEG_DATA_W = 256,
    parameter int SEG_BE_W = SEG_DATA_W/8
)(input logic clk);
    logic rst;

    logic [SEG_COUNT*SEL_W-1:0]      rd_cmd_sel;
    logic [SEG_COUNT*SEG_ADDR_W-1:0] rd_cmd_addr;
    logic [SEG_COUNT-1:0]            rd_cmd_valid;
    logic [SEG_COUNT-1:0]            rd_cmd_ready;
    logic [SEG_COUNT*SEG_DATA_W-1:0] rd_resp_data;
    logic [SEG_COUNT-1:0]            rd_resp_valid;
    logic [SEG_COUNT-1:0]            rd_resp_ready;

    logic [SEG_COUNT*SEL_W-1:0]      wr_cmd_sel;
    logic [SEG_COUNT*SEG_BE_W-1:0]   wr_cmd_be;
    logic [SEG_COUNT*SEG_ADDR_W-1:0] wr_cmd_addr;
    logic [SEG_COUNT*SEG_DATA_W-1:0] wr_cmd_data;
    logic [SEG_COUNT-1:0]            wr_cmd_valid;
    logic [SEG_COUNT-1:0]            wr_cmd_ready;
    logic [SEG_COUNT-1:0]            wr_done;

    clocking ram_cb @(posedge clk);
      default input #1step output #0;
      input rst, rd_cmd_sel, rd_cmd_addr, rd_cmd_valid, rd_resp_ready,
            wr_cmd_sel, wr_cmd_be, wr_cmd_addr, wr_cmd_data, wr_cmd_valid;
      output rd_cmd_ready, rd_resp_data, rd_resp_valid, wr_cmd_ready, wr_done;
    endclocking

    clocking mon_cb @(posedge clk);
      default input #1step;
      input rst, rd_cmd_sel, rd_cmd_addr, rd_cmd_valid, rd_cmd_ready,
            rd_resp_data, rd_resp_valid, rd_resp_ready,
            wr_cmd_sel, wr_cmd_be, wr_cmd_addr, wr_cmd_data, wr_cmd_valid, wr_cmd_ready, wr_done;
    endclocking
endinterface
