class dma_coverage extends uvm_component;
  `uvm_component_utils(dma_coverage)
  uvm_analysis_imp_cov_desc #(dma_desc_obs,dma_coverage) desc_imp;
  uvm_analysis_imp_cov_tlp #(pcie_tlp_item,dma_coverage) tlp_imp;
  uvm_analysis_imp_cov_ram #(dma_ram_obs,dma_coverage) ram_imp;
  virtual dma_cfg_if cfg_vif;

  dma_dir_e dir_s;
  int unsigned len_s,align_s;
  pcie_tlp_kind_e kind_s;
  int unsigned tlp_len_s;
  bit cross4k_s;
  bit [2:0] cpl_status_s;
  bit [3:0] cpl_outcome_s;

  // Stateful coverage complements packet-field coverage.  It is derived only
  // from monitor observations, not from test intent, so these bins prove that
  // the corresponding concurrency/reordering behavior actually occurred.
  bit desc_live[longint unsigned];
  int unsigned rd_remaining[bit[9:0]];
  int unsigned rd_cpl_count[bit[9:0]];
  longint unsigned rd_issue_order[bit[9:0]];
  longint unsigned next_issue_order;
  int unsigned desc_out_s,pcie_out_s;
  bit split_s,ooo_s;
  bit tag_seen[bit[9:0]];
  bit tag_reuse_s;
  bit runtime_reset_s;

  covergroup desc_cg;
    cp_dir: coverpoint dir_s;
    cp_len: coverpoint len_s {
      bins len_zero={0};
      bins len_tiny={[1:4]};
      bins len_small={[5:32]};
      bins len_medium={[33:256]};
      bins len_large={[257:4096]};
      bins len_huge={[4097:65535]};
    }
    cp_align: coverpoint align_s {
      bins a0={0}; bins a1={1}; bins a2={2}; bins a3={3};
    }
    x_dir_len: cross cp_dir,cp_len;
  endgroup

  covergroup tlp_cg;
    cp_kind: coverpoint kind_s {
      bins rd={PCIE_MEM_RD};
      bins wr={PCIE_MEM_WR};
      bins cpl={PCIE_CPLD};
    }
    cp_len: coverpoint tlp_len_s {
      bins zero={0};
      bins le32={[1:32]};
      bins b33_128={[33:128]};
      bins b129_256={[129:256]};
      bins b257_512={[257:512]};
    }
    cp_4k: coverpoint cross4k_s {
      bins legal={0};
      illegal_bins crossed={1};
    }
    cp_cpl_status: coverpoint cpl_status_s iff(kind_s==PCIE_CPLD) {
      bins successful={3'b000};
      bins unsupported_request={3'b001};
      bins completer_abort={3'b100};
      ignore_bins other=default;
    }
    cp_cpl_outcome: coverpoint cpl_outcome_s iff(kind_s==PCIE_CPLD) {
      bins success={0};
      bins ur={1};
      bins ca={4};
      bins flr={8};
      bins poisoned={9};
      bins timeout={15};
    }
    cp_cpl_bus_span: coverpoint (tlp_len_s>32) iff(kind_s==PCIE_CPLD) {
      bins one_beat={0};
      bins multi_beat={1};
    }
  endgroup

  covergroup desc_state_cg;
    cp_desc_outstanding: coverpoint desc_out_s {
      bins one={1};
      bins b2_4={[2:4]};
      bins b5_8={[5:8]};
      bins b9_16={[9:16]};
    }
  endgroup

  covergroup pcie_state_cg;
    cp_pcie_outstanding: coverpoint pcie_out_s {
      bins one={1};
      bins b2_4={[2:4]};
      bins b5_8={[5:8]};
      bins b9_15={[9:15]};
      bins full16={16};
    }
    cp_split_completion: coverpoint split_s {
      bins first_or_single={0};
      bins split_followup={1};
    }
    cp_cross_tag_ooo: coverpoint ooo_s {
      bins in_order={0};
      bins reordered={1};
    }
  endgroup

  covergroup tag_lifecycle_cg;
    cp_tag_lifecycle: coverpoint tag_reuse_s {
      bins first_use={0};
      bins reuse={1};
    }
  endgroup

  covergroup reset_cg;
    cp_runtime_reset: coverpoint runtime_reset_s {
      bins observed={1};
    }
  endgroup

  function new(string name,uvm_component parent);
    super.new(name,parent);
    desc_imp=new("desc_imp",this);
    tlp_imp=new("tlp_imp",this);
    ram_imp=new("ram_imp",this);
    desc_cg=new;
    tlp_cg=new;
    desc_state_cg=new;
    pcie_state_cg=new;
    tag_lifecycle_cg=new;
    reset_cg=new;
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual dma_cfg_if)::get(this,"","cfg_vif",cfg_vif))
      `uvm_fatal("COV","no cfg vif")
  endfunction

  function void flush_on_reset();
    desc_live.delete();
    rd_remaining.delete();
    rd_cpl_count.delete();
    rd_issue_order.delete();
    tag_seen.delete();
    next_issue_order=0;
    desc_out_s=0;
    pcie_out_s=0;
  endfunction

  task run_phase(uvm_phase phase);
    bit saw_reset_deasserted=0;
    bit prev_rst=1;
    forever begin
      @(posedge cfg_vif.clk);
      if(!cfg_vif.rst) saw_reset_deasserted=1;
      if(cfg_vif.rst && !prev_rst && saw_reset_deasserted) begin
        runtime_reset_s=1;
        reset_cg.sample();
        flush_on_reset();
        runtime_reset_s=0;
      end
      prev_rst=cfg_vif.rst;
    end
  endtask

  function longint unsigned desc_key(dma_dir_e dir,bit[7:0] tag);
    return (longint'(dir)<<8)|tag;
  endfunction

  function void write_cov_desc(dma_desc_obs o);
    longint unsigned k;
    k=desc_key(o.dir,o.tag);

    if(!o.is_status) begin
      dir_s=o.dir;
      len_s=o.len;
      align_s=o.pcie_addr[1:0];
      desc_cg.sample();
      desc_live[k]=1;
    end else begin
      desc_live.delete(k);
    end

    desc_out_s=desc_live.num();
    if(desc_out_s!=0)
      desc_state_cg.sample();
  endfunction

  function void write_cov_tlp(pcie_tlp_item o);
    longint unsigned oldest;
    bit have_oldest;

    if(o.kind!=PCIE_MEM_WR_DONE) begin
      kind_s=o.kind;
      tlp_len_s=o.byte_len;
      cross4k_s=(((o.addr&'hfff)+o.byte_len)>4096);
      cpl_status_s=o.cpl_status;
      cpl_outcome_s=(o.cpl_status==3'b001)?4'd1:
                    (o.cpl_status==3'b100)?4'd4:
                    (o.terminal_error?
                       (o.rx_cpl_error == 4'd15 ? 4'd15 :
                        (o.rx_cpl_error == 4'd8 ? 4'd8 : 4'd9)):4'd0);
      tlp_cg.sample();
    end

    if(o.kind==PCIE_MEM_RD) begin
      tag_reuse_s=tag_seen.exists(o.tag);
      tag_seen[o.tag]=1;
      tag_lifecycle_cg.sample();
      rd_remaining[o.tag]=(o.byte_len==0)?1:o.byte_len;
      rd_cpl_count[o.tag]=0;
      rd_issue_order[o.tag]=next_issue_order++;
      pcie_out_s=rd_remaining.num();
      split_s=0;
      ooo_s=0;
      pcie_state_cg.sample();
    end else if(o.kind==PCIE_CPLD && rd_remaining.exists(o.tag)) begin
      have_oldest=0;
      oldest='0;
      foreach(rd_issue_order[t]) begin
        if(!have_oldest || rd_issue_order[t]<oldest) begin
          oldest=rd_issue_order[t];
          have_oldest=1;
        end
      end

      ooo_s=have_oldest && (rd_issue_order[o.tag]!=oldest);
      rd_cpl_count[o.tag]++;
      split_s=(rd_cpl_count[o.tag]>1);
      pcie_out_s=rd_remaining.num();
      pcie_state_cg.sample();

      if(o.cpl_status!=0 || o.byte_len>=rd_remaining[o.tag]) begin
        rd_remaining.delete(o.tag);
        rd_cpl_count.delete(o.tag);
        rd_issue_order.delete(o.tag);
      end else begin
        rd_remaining[o.tag]-=o.byte_len;
      end
    end
  endfunction

  function void write_cov_ram(dma_ram_obs o);
  endfunction
endclass
