interface pcie_tlp_if #(
    parameter int DATA_W = 256,
    parameter int STRB_W = DATA_W/32,
    parameter int HDR_W  = 128
)(input logic clk);
    logic rst;

    logic [HDR_W-1:0]  tx_rd_hdr;
    logic              tx_rd_valid;
    logic              tx_rd_sop;
    logic              tx_rd_eop;
    logic              tx_rd_ready;

    logic [DATA_W-1:0] tx_wr_data;
    logic [STRB_W-1:0] tx_wr_strb;
    logic [HDR_W-1:0]  tx_wr_hdr;
    logic              tx_wr_valid;
    logic              tx_wr_sop;
    logic              tx_wr_eop;
    logic              tx_wr_ready;

    logic [DATA_W-1:0] rx_cpl_data;
    logic [HDR_W-1:0]  rx_cpl_hdr;
    logic [3:0]        rx_cpl_error;
    logic              rx_cpl_valid;
    logic              rx_cpl_sop;
    logic              rx_cpl_eop;
    logic              rx_cpl_ready;

    clocking host_cb @(posedge clk);
      default input #1step output #0;
      input rst, tx_rd_hdr, tx_rd_valid, tx_rd_sop, tx_rd_eop,
            tx_wr_data, tx_wr_strb, tx_wr_hdr, tx_wr_valid, tx_wr_sop, tx_wr_eop,
            rx_cpl_ready;
      output tx_rd_ready, tx_wr_ready, rx_cpl_data, rx_cpl_hdr, rx_cpl_error,
             rx_cpl_valid, rx_cpl_sop, rx_cpl_eop;
    endclocking

    clocking mon_cb @(posedge clk);
      default input #1step;
      input rst, tx_rd_hdr, tx_rd_valid, tx_rd_sop, tx_rd_eop, tx_rd_ready,
            tx_wr_data, tx_wr_strb, tx_wr_hdr, tx_wr_valid, tx_wr_sop, tx_wr_eop, tx_wr_ready,
            rx_cpl_data, rx_cpl_hdr, rx_cpl_error, rx_cpl_valid, rx_cpl_sop, rx_cpl_eop, rx_cpl_ready;
    endclocking
endinterface
