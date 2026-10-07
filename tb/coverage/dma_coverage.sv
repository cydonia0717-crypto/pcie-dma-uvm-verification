class dma_coverage extends uvm_component;
  `uvm_component_utils(dma_coverage)
  uvm_analysis_imp_cov_desc #(dma_desc_obs,dma_coverage) desc_imp;
  uvm_analysis_imp_cov_tlp #(pcie_tlp_item,dma_coverage) tlp_imp;
  uvm_analysis_imp_cov_ram #(dma_ram_obs,dma_coverage) ram_imp;
  dma_dir_e dir_s; int unsigned len_s,align_s; pcie_tlp_kind_e kind_s; int unsigned tlp_len_s; bit cross4k_s;

  covergroup desc_cg;
    cp_dir: coverpoint dir_s;
    cp_len: coverpoint len_s { bins len_tiny={[1:4]}; bins len_small={[5:32]}; bins len_medium={[33:256]}; bins len_large={[257:4096]}; bins len_huge={[4097:65535]}; }
    cp_align: coverpoint align_s { bins a0={0}; bins a1={1}; bins a2={2}; bins a3={3}; }
    x_dir_len: cross cp_dir,cp_len;
  endgroup
  covergroup tlp_cg;
    cp_kind: coverpoint kind_s { bins rd={PCIE_MEM_RD}; bins wr={PCIE_MEM_WR}; bins cpl={PCIE_CPLD}; }
    cp_len: coverpoint tlp_len_s { bins le32={[1:32]}; bins b33_128={[33:128]}; bins b129_256={[129:256]}; bins b257_512={[257:512]}; }
    cp_4k: coverpoint cross4k_s { bins legal={0}; illegal_bins crossed={1}; }
  endgroup
  function new(string name,uvm_component parent); super.new(name,parent); desc_imp=new("desc_imp",this); tlp_imp=new("tlp_imp",this); ram_imp=new("ram_imp",this); desc_cg=new; tlp_cg=new; endfunction
  function void write_cov_desc(dma_desc_obs o); if(!o.is_status) begin dir_s=o.dir; len_s=o.len; align_s=o.pcie_addr[1:0]; desc_cg.sample(); end endfunction
  function void write_cov_tlp(pcie_tlp_item o); kind_s=o.kind; tlp_len_s=o.byte_len; cross4k_s=(((o.addr&'hfff)+o.byte_len)>4096); tlp_cg.sample(); endfunction
  function void write_cov_ram(dma_ram_obs o); endfunction
endclass
