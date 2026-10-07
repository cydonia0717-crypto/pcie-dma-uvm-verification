class dma_expected_op extends uvm_object;
  `uvm_object_utils(dma_expected_op)
  dma_dir_e dir; longint unsigned pcie_addr; int unsigned ram_addr,len; bit[7:0] tag; byte unsigned exp[];
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
  int unsigned ram_rd_cmd_count,ram_wr_cmd_count,ram_wr_byte_count;
  longint unsigned first_ram_wr_addr,last_ram_wr_addr;
  int unsigned h2c_outstanding;

  function new(string name,uvm_component parent); super.new(name,parent); desc_imp=new("desc_imp",this); tlp_imp=new("tlp_imp",this); ram_imp=new("ram_imp",this); endfunction
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(dma_ref_mem)::get(this,"","mem",mem)) `uvm_fatal("SB","no mem")
    if(!uvm_config_db#(virtual dma_cfg_if)::get(this,"","cfg_vif",cfg_vif)) `uvm_fatal("SB","no cfg vif")
  endfunction
  function longint unsigned key(dma_dir_e d,bit[7:0] tag); return (longint'(d)<<8)|tag; endfunction
  function int unsigned cfg_bytes(bit[2:0] enc); return 128<<enc; endfunction

  function void write_desc(dma_desc_obs o);
    longint unsigned k=key(o.dir,o.tag); dma_expected_op e;
    if(!o.is_status) begin
      if(pending.exists(k)) begin errors++; `uvm_error("SB","descriptor tag reused before completion") end
      e=dma_expected_op::type_id::create("e"); e.dir=o.dir; e.pcie_addr=o.pcie_addr; e.ram_addr=o.ram_addr; e.len=o.len; e.tag=o.tag; e.exp=new[o.len];
      for(int i=0;i<o.len;i++) e.exp[i]=(o.dir==DMA_H2C)?mem.host_get(o.pcie_addr+i):mem.dev_get(o.ram_addr+i);
      pending[k]=e; if(o.dir==DMA_H2C) begin h2c_outstanding++; if(h2c_outstanding>max_h2c_outstanding) max_h2c_outstanding=h2c_outstanding; end
    end else begin
      checks++; if(!pending.exists(k)) begin errors++; `uvm_error("SB",$sformatf("unexpected status dir=%0d tag=%0h",o.dir,o.tag)); return; end
      e=pending[k];
      if(o.error!=0) begin errors++; `uvm_error("SB",$sformatf("descriptor error tag=%0h error=%0h",o.tag,o.error)); end
      for(int i=0;i<e.len;i++) begin
        byte unsigned act=(e.dir==DMA_H2C)?mem.dev_get(e.ram_addr+i):mem.host_get(e.pcie_addr+i);
        if(act!==e.exp[i]) begin
          errors++;
          `uvm_error("SB",$sformatf("data mismatch dir=%0d tag=%0h byte=%0d exp=%02x act=%02x dst=%h ram_wr_cmds=%0d ram_wr_bytes=%0d first_wr=%h last_wr=%h",
            e.dir,e.tag,i,e.exp[i],act,e.ram_addr+i,ram_wr_cmd_count,ram_wr_byte_count,first_ram_wr_addr,last_ram_wr_addr))
          break;
        end
      end
      if(e.dir==DMA_H2C) h2c_outstanding--;
      pending.delete(k);
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
    if(o.kind==PCIE_MEM_RD) begin memrd_count++; lim=cfg_bytes(cfg_vif.max_read_request_size); end
    else if(o.kind==PCIE_MEM_WR) begin memwr_count++; lim=cfg_bytes(cfg_vif.max_payload_size); end else return;
    if(o.byte_len>lim) begin errors++; `uvm_error("SB",$sformatf("TLP length %0d exceeds limit %0d",o.byte_len,lim)); end
    if(((o.addr & 64'hfff)+o.byte_len)>4096) begin errors++; `uvm_error("SB",$sformatf("TLP crosses 4KiB addr=%h len=%0d",o.addr,o.byte_len)); end
  endfunction

  function void check_phase(uvm_phase phase);
    if(pending.num()!=0) `uvm_error("SB",$sformatf("%0d descriptors still pending",pending.num()))
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SB",$sformatf("checks=%0d errors=%0d memrd=%0d memwr=%0d max_h2c_outstanding=%0d ram_rd_cmds=%0d ram_wr_cmds=%0d ram_wr_bytes=%0d",checks,errors,memrd_count,memwr_count,max_h2c_outstanding,ram_rd_cmd_count,ram_wr_cmd_count,ram_wr_byte_count),UVM_LOW)
  endfunction
endclass
