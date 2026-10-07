module dma_desc_assertions(dma_desc_if vif);
  property p_rd_hold; @(posedge vif.clk) disable iff(vif.rst) vif.rd_valid && !vif.rd_ready |=> vif.rd_valid && $stable({vif.rd_pcie_addr,vif.rd_ram_sel,vif.rd_ram_addr,vif.rd_len,vif.rd_tag}); endproperty
  property p_wr_hold; @(posedge vif.clk) disable iff(vif.rst) vif.wr_valid && !vif.wr_ready |=> vif.wr_valid && $stable({vif.wr_pcie_addr,vif.wr_ram_sel,vif.wr_ram_addr,vif.wr_len,vif.wr_tag}); endproperty
  a_rd_hold: assert property(p_rd_hold);
  a_wr_hold: assert property(p_wr_hold);
endmodule

module pcie_tlp_assertions(pcie_tlp_if vif,dma_cfg_if cfg);
  function automatic int unsigned tlp_bytes(bit[127:0] h); int dw; begin dw=(h[105:96]==0)?1024:h[105:96]; return dw*4; end endfunction
  function automatic longint unsigned tlp_addr(bit[127:0] h); return {h[63:2],2'b00}; endfunction
  property p_rd_hold; @(posedge vif.clk) disable iff(vif.rst) vif.tx_rd_valid&&!vif.tx_rd_ready |=> vif.tx_rd_valid&&$stable(vif.tx_rd_hdr); endproperty
  property p_wr_hold; @(posedge vif.clk) disable iff(vif.rst) vif.tx_wr_valid&&!vif.tx_wr_ready |=> vif.tx_wr_valid&&$stable({vif.tx_wr_hdr,vif.tx_wr_data,vif.tx_wr_strb,vif.tx_wr_sop,vif.tx_wr_eop}); endproperty
  property p_cpl_hold; @(posedge vif.clk) disable iff(vif.rst) vif.rx_cpl_valid&&!vif.rx_cpl_ready |=> vif.rx_cpl_valid&&$stable({vif.rx_cpl_hdr,vif.rx_cpl_data,vif.rx_cpl_error,vif.rx_cpl_sop,vif.rx_cpl_eop}); endproperty
  property p_rd_4k; @(posedge vif.clk) disable iff(vif.rst) vif.tx_rd_valid&&vif.tx_rd_ready |-> ((tlp_addr(vif.tx_rd_hdr)[11:0]+tlp_bytes(vif.tx_rd_hdr))<=4096); endproperty
  property p_wr_4k; @(posedge vif.clk) disable iff(vif.rst) vif.tx_wr_valid&&vif.tx_wr_ready&&vif.tx_wr_sop |-> ((tlp_addr(vif.tx_wr_hdr)[11:0]+tlp_bytes(vif.tx_wr_hdr))<=4096); endproperty
  property p_rd_mrrs; @(posedge vif.clk) disable iff(vif.rst) vif.tx_rd_valid&&vif.tx_rd_ready |-> (tlp_bytes(vif.tx_rd_hdr) <= (128<<cfg.max_read_request_size)); endproperty
  property p_wr_mps; @(posedge vif.clk) disable iff(vif.rst) vif.tx_wr_valid&&vif.tx_wr_ready&&vif.tx_wr_sop |-> (tlp_bytes(vif.tx_wr_hdr) <= (128<<cfg.max_payload_size)); endproperty
  a_rd_hold: assert property(p_rd_hold);
  a_wr_hold: assert property(p_wr_hold);
  a_cpl_hold: assert property(p_cpl_hold);
  a_rd_4k: assert property(p_rd_4k);
  a_wr_4k: assert property(p_wr_4k);
  a_rd_mrrs: assert property(p_rd_mrrs)
    else $error("MRRS violation len_field=%0h cfg_enc=%0d hdr=%h",
      vif.tx_rd_hdr[105:96],cfg.max_read_request_size,vif.tx_rd_hdr);
  a_wr_mps: assert property(p_wr_mps)
    else $error("MPS violation len_field=%0h cfg_enc=%0d hdr=%h",
      vif.tx_wr_hdr[105:96],cfg.max_payload_size,vif.tx_wr_hdr);
endmodule

module dma_ram_assertions #(
  parameter int SEG_COUNT=2,
  parameter int SEL_W=2,
  parameter int SEG_ADDR_W=14,
  parameter int SEG_DATA_W=256,
  parameter int SEG_BE_W=32
)(dma_ram_if vif);
  for(genvar g=0; g<SEG_COUNT; g++) begin : g_ram_protocol
    property p_rd_cmd_hold;
      @(posedge vif.clk) disable iff(vif.rst)
      vif.rd_cmd_valid[g] && !vif.rd_cmd_ready[g] |=>
        vif.rd_cmd_valid[g] &&
        $stable({
          vif.rd_cmd_sel[g*SEL_W +: SEL_W],
          vif.rd_cmd_addr[g*SEG_ADDR_W +: SEG_ADDR_W]
        });
    endproperty

    property p_wr_cmd_hold;
      @(posedge vif.clk) disable iff(vif.rst)
      vif.wr_cmd_valid[g] && !vif.wr_cmd_ready[g] |=>
        vif.wr_cmd_valid[g] &&
        $stable({
          vif.wr_cmd_sel[g*SEL_W +: SEL_W],
          vif.wr_cmd_be[g*SEG_BE_W +: SEG_BE_W],
          vif.wr_cmd_addr[g*SEG_ADDR_W +: SEG_ADDR_W],
          vif.wr_cmd_data[g*SEG_DATA_W +: SEG_DATA_W]
        });
    endproperty

    // The RAM model is part of the verification environment.  Check its
    // response-side valid/ready behavior as well so backpressure tests cannot
    // pass with a lossy reactive model.
    property p_rd_rsp_hold;
      @(posedge vif.clk) disable iff(vif.rst)
      vif.rd_resp_valid[g] && !vif.rd_resp_ready[g] |=>
        vif.rd_resp_valid[g] &&
        $stable(vif.rd_resp_data[g*SEG_DATA_W +: SEG_DATA_W]);
    endproperty

    a_rd_cmd_hold: assert property(p_rd_cmd_hold);
    a_wr_cmd_hold: assert property(p_wr_cmd_hold);
    a_rd_rsp_hold: assert property(p_rd_rsp_hold);
  end
endmodule
