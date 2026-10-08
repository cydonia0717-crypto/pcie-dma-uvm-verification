module tb_top;
  import uvm_pkg::*;
  import dma_uvm_pkg::*;
  logic clk=0; always #5 clk=~clk;
  dma_desc_if desc_if(clk); pcie_tlp_if pcie_if(clk); dma_ram_if ram_if(clk); dma_cfg_if cfg_if(clk);

  logic init_rst=1;
  logic rst;

  // Generic TLP link transmit acknowledgments.  Read requests are single
  // beat; writes can span beats, so report one TX completion at accepted EOP.
  // Even when TX_SEQ_NUM_ENABLE=0, the pinned DUT uses these valid strobes to
  // retire active_tx_count and update status_busy.
  logic rd_tx_ack_valid=0,wr_tx_ack_valid=0;
  always @(posedge clk) begin
    if(rst) begin
      rd_tx_ack_valid<=0;
      wr_tx_ack_valid<=0;
    end else begin
      rd_tx_ack_valid<=pcie_if.tx_rd_valid && pcie_if.tx_rd_ready;
      wr_tx_ack_valid<=pcie_if.tx_wr_valid && pcie_if.tx_wr_ready && pcie_if.tx_wr_eop;
    end
  end
  assign rst=init_rst | cfg_if.force_reset;
  initial begin repeat(8) @(posedge clk); init_rst<=0; end
  assign desc_if.rst=rst; assign pcie_if.rst=rst; assign ram_if.rst=rst; assign cfg_if.rst=rst;

  initial begin
    cfg_if.read_enable=1; cfg_if.write_enable=1; cfg_if.ext_tag_enable=0; cfg_if.rcb_128b=1;
    cfg_if.requester_id=16'h0100; cfg_if.max_read_request_size=3'd1; // 256 B
    cfg_if.max_payload_size=3'd0; // 128 B
  end

  dma_if_pcie #(
    .TLP_DATA_WIDTH(256),.TLP_STRB_WIDTH(8),.TLP_HDR_WIDTH(128),.TLP_SEG_COUNT(1),
    .TX_SEQ_NUM_COUNT(1),.TX_SEQ_NUM_WIDTH(4),.TX_SEQ_NUM_ENABLE(0),
    .RAM_SEL_WIDTH(2),.RAM_ADDR_WIDTH(20),.RAM_SEG_COUNT(2),.RAM_SEG_DATA_WIDTH(256),.RAM_SEG_BE_WIDTH(32),.RAM_SEG_ADDR_WIDTH(14),
    .PCIE_ADDR_WIDTH(64),.PCIE_TAG_COUNT(16),.IMM_ENABLE(0),.IMM_WIDTH(32),.LEN_WIDTH(16),.TAG_WIDTH(8),
    .READ_OP_TABLE_SIZE(16),.READ_TX_LIMIT(16),.WRITE_OP_TABLE_SIZE(16),.WRITE_TX_LIMIT(16),
    .TLP_FORCE_64_BIT_ADDR(1),.CHECK_BUS_NUMBER(1)
  ) dut (
    .clk(clk),.rst(rst),
    .rx_cpl_tlp_data(pcie_if.rx_cpl_data),.rx_cpl_tlp_hdr(pcie_if.rx_cpl_hdr),.rx_cpl_tlp_error(pcie_if.rx_cpl_error),.rx_cpl_tlp_valid(pcie_if.rx_cpl_valid),.rx_cpl_tlp_sop(pcie_if.rx_cpl_sop),.rx_cpl_tlp_eop(pcie_if.rx_cpl_eop),.rx_cpl_tlp_ready(pcie_if.rx_cpl_ready),
    .tx_rd_req_tlp_hdr(pcie_if.tx_rd_hdr),.tx_rd_req_tlp_seq(),.tx_rd_req_tlp_valid(pcie_if.tx_rd_valid),.tx_rd_req_tlp_sop(pcie_if.tx_rd_sop),.tx_rd_req_tlp_eop(pcie_if.tx_rd_eop),.tx_rd_req_tlp_ready(pcie_if.tx_rd_ready),
    .tx_wr_req_tlp_data(pcie_if.tx_wr_data),.tx_wr_req_tlp_strb(pcie_if.tx_wr_strb),.tx_wr_req_tlp_hdr(pcie_if.tx_wr_hdr),.tx_wr_req_tlp_seq(),.tx_wr_req_tlp_valid(pcie_if.tx_wr_valid),.tx_wr_req_tlp_sop(pcie_if.tx_wr_sop),.tx_wr_req_tlp_eop(pcie_if.tx_wr_eop),.tx_wr_req_tlp_ready(pcie_if.tx_wr_ready),
    .s_axis_rd_req_tx_seq_num('0),.s_axis_rd_req_tx_seq_num_valid(rd_tx_ack_valid),.s_axis_wr_req_tx_seq_num('0),.s_axis_wr_req_tx_seq_num_valid(wr_tx_ack_valid),
    .s_axis_read_desc_pcie_addr(desc_if.rd_pcie_addr),.s_axis_read_desc_ram_sel(desc_if.rd_ram_sel),.s_axis_read_desc_ram_addr(desc_if.rd_ram_addr),.s_axis_read_desc_len(desc_if.rd_len),.s_axis_read_desc_tag(desc_if.rd_tag),.s_axis_read_desc_valid(desc_if.rd_valid),.s_axis_read_desc_ready(desc_if.rd_ready),
    .m_axis_read_desc_status_tag(desc_if.rd_status_tag),.m_axis_read_desc_status_error(desc_if.rd_status_error),.m_axis_read_desc_status_valid(desc_if.rd_status_valid),
    .s_axis_write_desc_pcie_addr(desc_if.wr_pcie_addr),.s_axis_write_desc_ram_sel(desc_if.wr_ram_sel),.s_axis_write_desc_ram_addr(desc_if.wr_ram_addr),.s_axis_write_desc_imm('0),.s_axis_write_desc_imm_en(1'b0),.s_axis_write_desc_len(desc_if.wr_len),.s_axis_write_desc_tag(desc_if.wr_tag),.s_axis_write_desc_valid(desc_if.wr_valid),.s_axis_write_desc_ready(desc_if.wr_ready),
    .m_axis_write_desc_status_tag(desc_if.wr_status_tag),.m_axis_write_desc_status_error(desc_if.wr_status_error),.m_axis_write_desc_status_valid(desc_if.wr_status_valid),
    .ram_rd_cmd_sel(ram_if.rd_cmd_sel),.ram_rd_cmd_addr(ram_if.rd_cmd_addr),.ram_rd_cmd_valid(ram_if.rd_cmd_valid),.ram_rd_cmd_ready(ram_if.rd_cmd_ready),.ram_rd_resp_data(ram_if.rd_resp_data),.ram_rd_resp_valid(ram_if.rd_resp_valid),.ram_rd_resp_ready(ram_if.rd_resp_ready),
    .ram_wr_cmd_sel(ram_if.wr_cmd_sel),.ram_wr_cmd_be(ram_if.wr_cmd_be),.ram_wr_cmd_addr(ram_if.wr_cmd_addr),.ram_wr_cmd_data(ram_if.wr_cmd_data),.ram_wr_cmd_valid(ram_if.wr_cmd_valid),.ram_wr_cmd_ready(ram_if.wr_cmd_ready),.ram_wr_done(ram_if.wr_done),
    .read_enable(cfg_if.read_enable),.write_enable(cfg_if.write_enable),.ext_tag_enable(cfg_if.ext_tag_enable),.rcb_128b(cfg_if.rcb_128b),.requester_id(cfg_if.requester_id),.max_read_request_size(cfg_if.max_read_request_size),.max_payload_size(cfg_if.max_payload_size),
    .status_rd_busy(cfg_if.status_rd_busy),.status_wr_busy(cfg_if.status_wr_busy),.status_error_cor(cfg_if.status_error_cor),.status_error_uncor(cfg_if.status_error_uncor)
  );

  dma_desc_assertions a_desc(desc_if);
  pcie_tlp_assertions a_tlp(pcie_if,cfg_if);
  dma_ram_assertions a_ram(ram_if);
  initial begin
    uvm_config_db#(virtual dma_desc_if)::set(null,"uvm_test_top.env.desc.*","vif",desc_if);
    uvm_config_db#(virtual pcie_tlp_if)::set(null,"uvm_test_top.env.host.*","vif",pcie_if);
    uvm_config_db#(virtual dma_ram_if)::set(null,"uvm_test_top.env.ram.*","vif",ram_if);
    uvm_config_db#(virtual dma_cfg_if)::set(null,"uvm_test_top","cfg_vif",cfg_if);
    run_test();
  end
endmodule
