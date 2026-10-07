class dma_ram_model extends uvm_component;
  `uvm_component_utils(dma_ram_model)
  virtual dma_ram_if vif; dma_ref_mem mem; uvm_analysis_port #(dma_ram_obs) ap;
  int unsigned rd_stall_pct=0,wr_stall_pct=0;
  int unsigned rd_stall_cycles,wr_stall_cycles;
  int unsigned rd_queue_depth=8;
  bit [255:0] rd_q[2][$];

  function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual dma_ram_if)::get(this,"","vif",vif)) `uvm_fatal("RAM","no vif")
    if(!uvm_config_db#(dma_ref_mem)::get(this,"","mem",mem)) `uvm_fatal("RAM","no shared mem")
  endfunction
  function longint unsigned base_addr(int seg,int word_addr); return ((longint'(word_addr)*2)+seg)*32; endfunction

  task run_phase(uvm_phase phase);
    dma_ram_obs o; longint unsigned base; bit [255:0] word;
    vif.ram_cb.rd_cmd_ready<='0; vif.ram_cb.wr_cmd_ready<='0;
    vif.ram_cb.rd_resp_valid<='0; vif.ram_cb.wr_done<='0; vif.ram_cb.rd_resp_data<='0;

    forever begin
      @(vif.ram_cb);
      vif.ram_cb.wr_done<='0;

      if(vif.ram_cb.rst) begin
        vif.ram_cb.rd_cmd_ready<='0; vif.ram_cb.wr_cmd_ready<='0;
        vif.ram_cb.rd_resp_valid<='0;
        for(int s=0;s<2;s++) rd_q[s].delete();
        continue;
      end

      // A read command is accepted only when the response queue has storage.
      // This prevents a throttled consumer from causing the RAM model itself
      // to overwrite an older, not-yet-returned read response.
      for(int s=0;s<2;s++) begin
        vif.ram_cb.rd_cmd_ready[s] <=
          ($urandom_range(99)>=rd_stall_pct) && (rd_q[s].size()<rd_queue_depth);
        vif.ram_cb.wr_cmd_ready[s] <= ($urandom_range(99)>=wr_stall_pct);
      end

      if((|vif.ram_cb.rd_cmd_valid) && !(|vif.rd_cmd_ready)) rd_stall_cycles++;
      if((|vif.ram_cb.wr_cmd_valid) && !(|vif.wr_cmd_ready)) wr_stall_cycles++;

      for(int s=0;s<2;s++) begin
        if(vif.ram_cb.rd_cmd_valid[s] && vif.rd_cmd_ready[s]) begin
          base=base_addr(s,vif.ram_cb.rd_cmd_addr[s*14 +:14]);
          word='0;
          for(int i=0;i<32;i++) word[i*8 +:8]=mem.dev_get(base+i);
          rd_q[s].push_back(word);
          o=new("rdcmd"); o.kind=RAM_READ_CMD; o.segment=s; o.addr=base; ap.write(o);
        end

        // Hold response payload/valid stable while the DUT backpressures it.
        if(vif.rd_resp_valid[s]) begin
          if(vif.ram_cb.rd_resp_ready[s]) begin
            if(rd_q[s].size()!=0) begin
              word=rd_q[s].pop_front();
              vif.ram_cb.rd_resp_data[s*256 +:256]<=word;
              vif.ram_cb.rd_resp_valid[s]<=1;
            end else begin
              vif.ram_cb.rd_resp_valid[s]<=0;
            end
          end
        end else if(rd_q[s].size()!=0) begin
          word=rd_q[s].pop_front();
          vif.ram_cb.rd_resp_data[s*256 +:256]<=word;
          vif.ram_cb.rd_resp_valid[s]<=1;
        end

        if(vif.ram_cb.wr_cmd_valid[s] && vif.wr_cmd_ready[s]) begin
          base=base_addr(s,vif.ram_cb.wr_cmd_addr[s*14 +:14]);
          for(int i=0;i<32;i++) if(vif.ram_cb.wr_cmd_be[s*32+i])
            mem.dev_put(base+i,vif.ram_cb.wr_cmd_data[(s*256+i*8)+:8]);
          vif.ram_cb.wr_done[s]<=1;
          o=new("wrcmd"); o.kind=RAM_WRITE_CMD; o.segment=s; o.addr=base;
          o.data=vif.ram_cb.wr_cmd_data[s*256 +:256]; o.be=vif.ram_cb.wr_cmd_be[s*32 +:32]; ap.write(o);
        end
      end
    end
  endtask
endclass
