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

class dma_pcie_read_ctx extends uvm_object;
  `uvm_object_utils(dma_pcie_read_ctx)
  bit [9:0] tag;
  bit [15:0] requester_id;
  longint unsigned start_addr;
  longint unsigned next_addr;
  int unsigned remaining;
  int unsigned cpl_count;
  bit zero_len;
  function new(string name="dma_pcie_read_ctx"); super.new(name); endfunction
endclass

class dma_scoreboard extends uvm_component;
  `uvm_component_utils(dma_scoreboard)
  uvm_analysis_imp_desc #(dma_desc_obs,dma_scoreboard) desc_imp;
  uvm_analysis_imp_tlp  #(pcie_tlp_item,dma_scoreboard) tlp_imp;
  uvm_analysis_imp_ram_sb #(dma_ram_obs,dma_scoreboard) ram_imp;
  dma_ref_mem mem; virtual dma_cfg_if cfg_vif;
  dma_expected_op pending[longint unsigned];
  dma_pcie_read_ctx pcie_reads[bit[9:0]];
  bit [3:0] expected_desc_error[longint unsigned];
  int unsigned expected_desc_errors_seen;
  int unsigned expected_completion_errors;
  int unsigned completion_errors_seen;

  int unsigned checks,errors,memrd_count,memwr_count,max_h2c_outstanding;
  int unsigned max_memrd_tlp_bytes,max_memwr_tlp_bytes;
  int unsigned max_pcie_outstanding,cpld_count,split_read_requests;
  bit pcie_tag_seen[bit[9:0]];
  int unsigned unique_pcie_tags_seen,pcie_tag_reuse_count;
  int unsigned ram_rd_cmd_count,ram_wr_cmd_count,ram_wr_byte_count;
  longint unsigned first_ram_wr_addr,last_ram_wr_addr;
  int unsigned h2c_outstanding,c2h_outstanding,max_desc_outstanding,max_c2h_outstanding;
  int unsigned runtime_reset_events,reset_flushed_descriptors,reset_flushed_pcie_reads;

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

  function void flush_on_reset();
    reset_flushed_descriptors += pending.num();
    reset_flushed_pcie_reads += pcie_reads.num();
    pending.delete();
    pcie_reads.delete();
    expected_desc_error.delete();
    expected_completion_errors=0;
    completion_errors_seen=0;
    h2c_outstanding=0;
    c2h_outstanding=0;
    pcie_tag_seen.delete();
    unique_pcie_tags_seen=0;
    pcie_tag_reuse_count=0;
  endfunction

  task run_phase(uvm_phase phase);
    bit saw_reset_deasserted=0;
    bit prev_rst=1;
    forever begin
      @(posedge cfg_vif.clk);
      if(!cfg_vif.rst) saw_reset_deasserted=1;
      if(cfg_vif.rst && !prev_rst && saw_reset_deasserted) begin
        runtime_reset_events++;
        flush_on_reset();
      end
      prev_rst=cfg_vif.rst;
    end
  endtask

  function void expect_descriptor_error(dma_dir_e dir,bit[7:0] tag,bit[3:0] error);
    expected_desc_error[key(dir,tag)] = error;
  endfunction

  function void compare_and_retire(longint unsigned k);
    dma_expected_op e;
    if(!pending.exists(k)) return;
    e=pending[k];

    if(expected_desc_error.exists(k)) begin
      if(e.status_error!==expected_desc_error[k]) begin
        errors++;
        `uvm_error("SB",$sformatf("descriptor error mismatch dir=%0d tag=%0h exp=%0h act=%0h",
          e.dir,e.tag,expected_desc_error[k],e.status_error))
      end else begin
        expected_desc_errors_seen++;
      end
      expected_desc_error.delete(k);
      checks++;
      if(e.dir==DMA_H2C) h2c_outstanding--;
      else c2h_outstanding--;
      pending.delete(k);
      return;
    end

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
    else c2h_outstanding--;
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
      if(pending.num()>max_desc_outstanding) max_desc_outstanding=pending.num();
      if(o.dir==DMA_H2C) begin
        h2c_outstanding++;
        if(h2c_outstanding>max_h2c_outstanding) max_h2c_outstanding=h2c_outstanding;
      end else begin
        c2h_outstanding++;
        if(c2h_outstanding>max_c2h_outstanding) max_c2h_outstanding=c2h_outstanding;
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

    foreach(pending[k]) begin
      e=pending[k];
      if(e.dir!=DMA_C2H) continue;
      // A PCIe zero-length Memory Write is encoded as one DW with First BE=0.
      // The semantic commit contains zero bytes, so interval-overlap math has
      // an empty range.  Match it to the live zero-length descriptor by the
      // naturally DW-aligned request address instead.
      if((e.len==0 && o.byte_len==0 && ((e.pcie_addr & ~64'h3)==o.addr)) ||
         (e.len!=0 && o.addr < e.pcie_addr+e.len && o.addr+o.byte_len > e.pcie_addr)) begin
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

  function void start_pcie_read(pcie_tlp_item o);
    dma_pcie_read_ctx c;
    if(pcie_reads.exists(o.tag)) begin
      errors++;
      `uvm_error("SB_TAG",$sformatf("PCIe read tag reused while active tag=%0h old_remaining=%0d",
        o.tag,pcie_reads[o.tag].remaining))
      return;
    end
    if(pcie_tag_seen.exists(o.tag)) begin
      pcie_tag_reuse_count++;
    end else begin
      pcie_tag_seen[o.tag]=1;
      unique_pcie_tags_seen++;
    end
    c=dma_pcie_read_ctx::type_id::create("rd_ctx");
    c.tag=o.tag; c.requester_id=o.requester_id; c.start_addr=o.addr; c.next_addr=o.addr;
    c.zero_len=(o.byte_len==0);
    // A zero-length MemRd still consumes one successful Completion with
    // Byte Count=1 / Length=1DW; the DUT suppresses the RAM write internally.
    c.remaining=c.zero_len ? 1 : o.byte_len;
    pcie_reads[o.tag]=c;
    if(pcie_reads.num()>max_pcie_outstanding) max_pcie_outstanding=pcie_reads.num();
  endfunction

  function void consume_completion(pcie_tlp_item o);
    dma_pcie_read_ctx c;
    if(!pcie_reads.exists(o.tag)) begin
      errors++;
      `uvm_error("SB_CPL",$sformatf("completion for inactive PCIe tag=%0h",o.tag))
      return;
    end
    c=pcie_reads[o.tag];
    if(o.requester_id!=c.requester_id) begin
      errors++; `uvm_error("SB_CPL",$sformatf("Requester ID mismatch tag=%0h exp=%h act=%h",o.tag,c.requester_id,o.requester_id))
    end
    if(o.cpl_status!=0 || o.cpl_error!=0) begin
      if(completion_errors_seen < expected_completion_errors) begin
        completion_errors_seen++;
        pcie_reads.delete(o.tag);
        return;
      end
      errors++;
      `uvm_error("SB_CPL",$sformatf("unexpected completion error tag=%0h status=%0h rx_error=%0h",
        o.tag,o.cpl_status,o.cpl_error))
    end
    if(o.byte_count!=c.remaining) begin
      errors++; `uvm_error("SB_CPL",$sformatf("Byte Count mismatch tag=%0h exp=%0d act=%0d",o.tag,c.remaining,o.byte_count))
    end
    if(o.lower_addr!=c.next_addr[6:0]) begin
      errors++; `uvm_error("SB_CPL",$sformatf("Lower Address mismatch tag=%0h exp=%0h act=%0h",o.tag,c.next_addr[6:0],o.lower_addr))
    end
    if(o.byte_len==0 || o.byte_len>c.remaining) begin
      errors++;
      `uvm_error("SB_CPL",$sformatf("invalid completion length tag=%0h len=%0d remaining=%0d",o.tag,o.byte_len,c.remaining))
      return;
    end

    c.cpl_count++;
    c.next_addr += o.byte_len;
    c.remaining -= o.byte_len;
    cpld_count++;
    if(c.remaining==0) begin
      if(c.cpl_count>1) split_read_requests++;
      pcie_reads.delete(o.tag);
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
    if(o.kind==PCIE_CPLD) begin
      consume_completion(o);
      return;
    end
    if(o.kind==PCIE_MEM_RD) begin
      memrd_count++; lim=cfg_bytes(cfg_vif.max_read_request_size);
      if(o.byte_len>max_memrd_tlp_bytes) max_memrd_tlp_bytes=o.byte_len;
      start_pcie_read(o);
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
    if(pcie_reads.num()!=0)
      `uvm_error("SB_TAG",$sformatf("%0d PCIe read tags still active",pcie_reads.num()))
    if(expected_desc_error.num()!=0)
      `uvm_error("SB",$sformatf("%0d expected descriptor errors were not observed",expected_desc_error.num()))
    if(completion_errors_seen!=expected_completion_errors)
      `uvm_error("SB_CPL",$sformatf("expected %0d completion errors, observed %0d",
        expected_completion_errors,completion_errors_seen))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB",$sformatf("checks=%0d errors=%0d memrd=%0d memwr=%0d cpld=%0d max_pcie_outstanding=%0d split_reads=%0d max_desc_outstanding=%0d max_h2c_desc=%0d max_c2h_desc=%0d max_memrd_tlp=%0d max_memwr_tlp=%0d ram_rd_cmds=%0d ram_wr_cmds=%0d ram_wr_bytes=%0d unique_pcie_tags=%0d pcie_tag_reuse=%0d",
      checks,errors,memrd_count,memwr_count,cpld_count,max_pcie_outstanding,split_read_requests,max_desc_outstanding,
      max_h2c_outstanding,max_c2h_outstanding,max_memrd_tlp_bytes,max_memwr_tlp_bytes,
      ram_rd_cmd_count,ram_wr_cmd_count,ram_wr_byte_count,unique_pcie_tags_seen,pcie_tag_reuse_count),UVM_LOW)
  endfunction
endclass
