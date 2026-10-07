class dma_expected_op extends uvm_object;
  `uvm_object_utils(dma_expected_op)
  dma_dir_e dir;
  longint unsigned pcie_addr;
  int unsigned ram_addr,len;
  bit[7:0] tag;
  byte unsigned exp[];
  bit committed[];
  int unsigned committed_count;
  bit status_seen;
  bit [3:0] status_error;
  function new(string name="dma_expected_op"); super.new(name); endfunction
endclass

class dma_scoreboard extends uvm_component;
  `uvm_component_utils(dma_scoreboard)
  uvm_analysis_imp_desc #(dma_desc_obs,dma_scoreboard) desc_imp;
  uvm_analysis_imp_tlp  #(pcie_tlp_item,dma_scoreboard) tlp_imp;
  uvm_analysis_imp_ram_sb #(dma_ram_obs,dma_scoreboard) ram_imp;
  dma_ref_mem mem; virtual dma_cfg_if cfg_vif;
  dma_expected_op pending[longint unsigned];
  int unsigned checks,errors,memrd_count,memwr_count,max_h2c_outstanding;
  int unsigned max_memrd_tlp_bytes,max_memwr_tlp_bytes;
  int unsigned ram_rd_cmd_count,ram_wr_cmd_count,ram_wr_byte_count;
  longint unsigned first_ram_wr_addr,last_ram_wr_addr;
  int unsigned h2c_outstanding;

  function new(string name,uvm_component parent);
    super.new(name,parent);
    desc_imp=new("desc_imp",this); tlp_imp=new("tlp_imp",this); ram_imp=new("ram_imp",this);
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(dma_ref_mem)::get(this,"","mem",mem)) `uvm_fatal("SB","no mem")
    if(!uvm_config_db#(virtual dma_cfg_if)::get(this,"","cfg_vif",cfg_vif)) `uvm_fatal("SB","no cfg vif")
  endfunction

  function longint unsigned key(dma_dir_e d,bit[7:0] tag); return (longint'(d)<<8)|tag; endfunction
  function int unsigned cfg_bytes(bit[2:0] enc); return 128<<enc; endfunction

  function void compare_and_retire(longint unsigned k);
    dma_expected_op e;
    if(!pending.exists(k)) return;
    e=pending[k];

    if(e.status_error!=0) begin
      errors++;
      `uvm_error("SB",$sformatf("descriptor error dir=%0d tag=%0h error=%0h",e.dir,e.tag,e.status_error))
    end

    for(int i=0;i<e.len;i++) begin
      byte unsigned act=(e.dir==DMA_H2C)?mem.dev_get(e.ram_addr+i):mem.host_get(e.pcie_addr+i);
      if(act!==e.exp[i]) begin
        errors++;
        `uvm_error("SB",$sformatf("data mismatch dir=%0d tag=%0h byte=%0d exp=%02x act=%02x",
          e.dir,e.tag,i,e.exp[i],act))
        break;
      end
    end

    checks++;
    if(e.dir==DMA_H2C) h2c_outstanding--;
    pending.delete(k);
  endfunction

  function void try_retire_c2h(longint unsigned k);
    dma_expected_op e;
    if(!pending.exists(k)) return;
    e=pending[k];
    if(e.dir==DMA_C2H && e.status_seen && e.committed_count==e.len)
      compare_and_retire(k);
  endfunction

  function void write_desc(dma_desc_obs o);
    longint unsigned k=key(o.dir,o.tag);
    dma_expected_op e;

    if(!o.is_status) begin
      if(pending.exists(k)) begin
        errors++;
        `uvm_error("SB","descriptor tag reused before completion")
        return;
      end
      e=dma_expected_op::type_id::create("e");
      e.dir=o.dir; e.pcie_addr=o.pcie_addr; e.ram_addr=o.ram_addr; e.len=o.len; e.tag=o.tag;
      e.exp=new[o.len]; e.committed=new[o.len];
      for(int i=0;i<o.len;i++) begin
        e.exp[i]=(o.dir==DMA_H2C)?mem.host_get(o.pcie_addr+i):mem.dev_get(o.ram_addr+i);
        e.committed[i]=0;
      end
      pending[k]=e;
      if(o.dir==DMA_H2C) begin
        h2c_outstanding++;
        if(h2c_outstanding>max_h2c_outstanding) max_h2c_outstanding=h2c_outstanding;
      end
      return;
    end

    if(!pending.exists(k)) begin
      errors++;
      `uvm_error("SB",$sformatf("unexpected status dir=%0d tag=%0h",o.dir,o.tag))
      return;
    end

    e=pending[k];
    e.status_seen=1;
    e.status_error=o.error;
    if(e.dir==DMA_H2C)
      compare_and_retire(k);
    else
      try_retire_c2h(k);
  endfunction

  function void mark_c2h_commit(pcie_tlp_item o);
    longint unsigned k,a;
    dma_expected_op e;
    int overlap_count=0;

    // A Memory Write carries no DMA descriptor tag.  Resolve ownership by the
    // non-overlapping destination range of every live C2H descriptor.
    foreach(pending[k]) begin
      e=pending[k];
      if(e.dir!=DMA_C2H) continue;
      if(o.addr < e.pcie_addr+e.len && o.addr+o.byte_len > e.pcie_addr) begin
        overlap_count++;
        for(int i=0;i<o.byte_len;i++) begin
          a=o.addr+i;
          if(a>=e.pcie_addr && a<e.pcie_addr+e.len) begin
            int unsigned idx=int'(a-e.pcie_addr);
            if(!e.committed[idx]) begin
              e.committed[idx]=1;
              e.committed_count++;
            end
          end
        end
        try_retire_c2h(k);
      end
    end

    if(overlap_count==0) begin
      errors++;
      `uvm_error("SB",$sformatf("completed MemWr does not map to a live C2H descriptor addr=%h len=%0d",o.addr,o.byte_len))
    end else if(overlap_count>1) begin
      errors++;
      `uvm_error("SB",$sformatf("completed MemWr ambiguously overlaps %0d C2H descriptors addr=%h len=%0d",overlap_count,o.addr,o.byte_len))
    end
  endfunction

  function void write_ram_sb(dma_ram_obs o);
    if(o.kind==RAM_READ_CMD) begin
      ram_rd_cmd_count++;
    end else if(o.kind==RAM_WRITE_CMD) begin
      ram_wr_cmd_count++;
      ram_wr_byte_count += $countones(o.be);
      if(ram_wr_cmd_count==1) first_ram_wr_addr=o.addr;
      last_ram_wr_addr=o.addr;
      if(ram_wr_cmd_count<=8)
        `uvm_info("SB_RAM",$sformatf("write_cmd[%0d] seg=%0d base=%h be=%08h data_lo=%016h",
          ram_wr_cmd_count,o.segment,o.addr,o.be,o.data[63:0]),UVM_LOW)
    end
  endfunction

  function void write_tlp(pcie_tlp_item o);
    int unsigned lim;
    if(o.kind==PCIE_MEM_WR_DONE) begin
      mark_c2h_commit(o);
      return;
    end
    if(o.kind==PCIE_MEM_RD) begin
      memrd_count++; lim=cfg_bytes(cfg_vif.max_read_request_size);
      if(o.byte_len>max_memrd_tlp_bytes) max_memrd_tlp_bytes=o.byte_len;
    end else if(o.kind==PCIE_MEM_WR) begin
      memwr_count++; lim=cfg_bytes(cfg_vif.max_payload_size);
      if(o.byte_len>max_memwr_tlp_bytes) max_memwr_tlp_bytes=o.byte_len;
    end else return;

    if(o.byte_len>lim) begin
      errors++;
      `uvm_error("SB",$sformatf("TLP length %0d exceeds limit %0d",o.byte_len,lim))
    end
    if(((o.addr & 64'hfff)+o.byte_len)>4096) begin
      errors++;
      `uvm_error("SB",$sformatf("TLP crosses 4KiB addr=%h len=%0d",o.addr,o.byte_len))
    end
  endfunction

  function void check_phase(uvm_phase phase);
    if(pending.num()!=0)
      `uvm_error("SB",$sformatf("%0d descriptors still pending",pending.num()))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB",$sformatf("checks=%0d errors=%0d memrd=%0d memwr=%0d max_h2c_outstanding=%0d max_memrd_tlp=%0d max_memwr_tlp=%0d ram_rd_cmds=%0d ram_wr_cmds=%0d ram_wr_bytes=%0d",
      checks,errors,memrd_count,memwr_count,max_h2c_outstanding,max_memrd_tlp_bytes,max_memwr_tlp_bytes,
      ram_rd_cmd_count,ram_wr_cmd_count,ram_wr_byte_count),UVM_LOW)
  endfunction
endclass
