class pcie_pending_cpl extends uvm_object;
  `uvm_object_utils(pcie_pending_cpl)
  bit [127:0] hdr; bit [255:0] data; bit [9:0] tag; int due_cycle;
  function new(string name="pcie_pending_cpl"); super.new(name); endfunction
endclass

class pcie_host_responder extends uvm_component;
  `uvm_component_utils(pcie_host_responder)
  virtual pcie_tlp_if vif;
  pcie_host_cfg cfg;
  dma_ref_mem mem;
  uvm_analysis_port #(pcie_tlp_item) ap;
  pcie_pending_cpl pending[$];
  int cycle;
  bit cpl_release_armed;
  bit forced_ooo_done;
  int unsigned max_unique_pending_tags;
  int unsigned split_memrd_count;
  int unsigned cross_tag_ooo_count;
  int unsigned tx_rd_stall_cycles;
  int unsigned tx_wr_stall_cycles;
  int unsigned cpl_stall_cycles;
  bit wr_active;
  longint unsigned wr_addr;
  int unsigned wr_dw_len,wr_dw_seen,wr_byte_len;
  bit [3:0] wr_first_be,wr_last_be;

  function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual pcie_tlp_if)::get(this,"","vif",vif)) `uvm_fatal("PCIE","no vif")
    if(!uvm_config_db#(pcie_host_cfg)::get(this,"","cfg",cfg)) cfg=pcie_host_cfg::type_id::create("cfg");
    if(!uvm_config_db#(dma_ref_mem)::get(this,"","mem",mem)) `uvm_fatal("PCIE","no shared mem")
  endfunction

  function int unsigned unique_pending_tags();
    bit seen[1024];
    int unsigned n=0;
    foreach(pending[i]) begin
      if(!seen[pending[i].tag]) begin seen[pending[i].tag]=1; n++; end
    end
    return n;
  endfunction

  function int first_be_off(bit[3:0] be); for(int i=0;i<4;i++) if(be[i]) return i; return 0; endfunction
  function int last_be_end(bit[3:0] be); for(int i=3;i>=0;i--) if(be[i]) return i; return 3; endfunction
  function int bytes_from_req(bit[127:0] h);
    int dw=(h[105:96]==0)?1024:h[105:96]; bit[3:0] f=h[67:64],l=h[71:68];
    if(dw==1) return $countones(f); return (4-first_be_off(f)) + (dw-2)*4 + (last_be_end(l)+1);
  endfunction
  function longint unsigned first_byte_addr(bit[127:0] h);
    longint unsigned a={h[63:2],2'b00}; return a+first_be_off(h[67:64]);
  endfunction

  task enqueue_completions(bit[127:0] h);
    pcie_tlp_item req,cpl; pcie_pending_cpl p; longint unsigned a;
    int remain,chunk,off,chunks,one_beat_cap;
    req=pcie_tlp_item::type_id::create("rd_req"); req.decode_request(h); req.byte_len=bytes_from_req(h); req.addr=first_byte_addr(h); ap.write(req);
    a=req.addr; remain=req.byte_len; chunks=0;
    while(remain>0) begin
      off=a[1:0];
      // This host model emits one CplD beat per pending item.  Never advertise
      // more payload than the 256-bit (32-byte) interface can carry in one beat.
      one_beat_cap=(cfg.cpl_payload_max<32)?cfg.cpl_payload_max:32;
      chunk=(remain < (one_beat_cap-off)) ? remain : (one_beat_cap-off);
      p=pcie_pending_cpl::type_id::create("pc"); cpl=pcie_tlp_item::type_id::create("cpl");
      cpl.kind=PCIE_CPLD; cpl.requester_id=req.requester_id; cpl.completer_id=cfg.completer_id; cpl.tag=req.tag;
      cpl.addr=a; cpl.byte_len=chunk; cpl.byte_count=remain; cpl.lower_addr=a[6:0]; cpl.cpl_status=3'b000;
      cpl.data='0; for(int i=0;i<chunk;i++) cpl.data[(off+i)*8 +:8]=mem.host_get(a+i);
      p.hdr=cpl.build_cpld_header(); p.data=cpl.data; p.tag=req.tag;
      p.due_cycle=cycle+$urandom_range(cfg.cpl_max_latency,cfg.cpl_min_latency);
      pending.push_back(p); chunks++;
      if(unique_pending_tags()>max_unique_pending_tags) max_unique_pending_tags=unique_pending_tags();
      if(!cpl_release_armed && cfg.hold_cpl_until_unique_tags!=0 &&
         unique_pending_tags()>=cfg.hold_cpl_until_unique_tags)
        cpl_release_armed=1;
      a+=chunk; remain-=chunk;
    end
    if(chunks>1) split_memrd_count++;
  endtask

  task capture_write_beat();
    longint unsigned base; bit[3:0] be;
    pcie_tlp_item o;
    if(vif.host_cb.tx_wr_sop) begin
      wr_active=1; wr_addr=first_byte_addr(vif.host_cb.tx_wr_hdr);
      wr_dw_len=(vif.host_cb.tx_wr_hdr[105:96]==0)?1024:vif.host_cb.tx_wr_hdr[105:96]; wr_dw_seen=0;
      wr_byte_len=bytes_from_req(vif.host_cb.tx_wr_hdr);
      wr_first_be=vif.host_cb.tx_wr_hdr[67:64]; wr_last_be=vif.host_cb.tx_wr_hdr[71:68];
      o=pcie_tlp_item::type_id::create("wr_req"); o.decode_request(vif.host_cb.tx_wr_hdr);
      o.addr=wr_addr; o.byte_len=bytes_from_req(vif.host_cb.tx_wr_hdr); o.data=vif.host_cb.tx_wr_data; o.strb=vif.host_cb.tx_wr_strb; ap.write(o);
    end
    if(wr_active) begin
      for(int d=0;d<8;d++) if(vif.host_cb.tx_wr_strb[d]) begin
        be=4'hf;
        if(wr_dw_seen+d==0) be &= wr_first_be;
        if(wr_dw_seen+d==wr_dw_len-1 && wr_dw_len>1) be &= wr_last_be;
        for(int b=0;b<4;b++) if(be[b]) begin
          base=(wr_addr & ~64'h3) + (wr_dw_seen+d)*4+b;
          mem.host_put(base,vif.host_cb.tx_wr_data[(d*4+b)*8 +:8]);
        end
      end
      wr_dw_seen += $countones(vif.host_cb.tx_wr_strb);
      if(vif.host_cb.tx_wr_eop) begin
        // Descriptor status may be generated by the DUT before a backpressured
        // final Memory Write beat is accepted by the host.  Publish a semantic
        // commit event only after every beat of this TLP has updated host memory.
        o=pcie_tlp_item::type_id::create("wr_done");
        o.kind=PCIE_MEM_WR_DONE; o.addr=wr_addr; o.byte_len=wr_byte_len;
        ap.write(o);
        wr_active=0;
      end
    end
  endtask

  task drive_completions();
    int idx; pcie_pending_cpl p;
    vif.host_cb.rx_cpl_valid<=0; vif.host_cb.rx_cpl_sop<=0; vif.host_cb.rx_cpl_eop<=0; vif.host_cb.rx_cpl_error<=0;
    cpl_release_armed=(cfg.hold_cpl_until_unique_tags==0);
    forever begin
      @(vif.host_cb); cycle++;
      if(vif.host_cb.rst) begin
        vif.host_cb.rx_cpl_valid<=0;
        cpl_release_armed=(cfg.hold_cpl_until_unique_tags==0);
        forced_ooo_done=0;
        max_unique_pending_tags=0;
        continue;
      end
      if(vif.rx_cpl_valid && !vif.host_cb.rx_cpl_ready) begin cpl_stall_cycles++; continue; end
      vif.host_cb.rx_cpl_valid<=0;
      idx=-1;
      if(!cpl_release_armed && cfg.hold_cpl_until_unique_tags!=0) continue;

      if(cfg.enable_cross_tag_ooo) begin
        int ready_idx[$];
        for(int i=0;i<pending.size();i++) begin
          bit older_same_tag;
          older_same_tag=0;
          for(int j=0;j<i;j++) if(pending[j].tag==pending[i].tag) older_same_tag=1;
          if(!older_same_tag && pending[i].due_cycle<=cycle) ready_idx.push_back(i);
        end
        if(ready_idx.size()) begin
          if(cfg.force_cross_tag_ooo_once && !forced_ooo_done && ready_idx.size()>1) begin
            idx=ready_idx[ready_idx.size()-1];
            forced_ooo_done=1;
          end else idx=ready_idx[$urandom_range(ready_idx.size()-1,0)];
        end
      end else if(pending.size() && pending[0].due_cycle<=cycle) idx=0;

      if(idx>=0) begin
        if(idx>0 && pending[idx].tag!=pending[0].tag) cross_tag_ooo_count++;
        p=pending[idx]; pending.delete(idx);
        vif.host_cb.rx_cpl_hdr<=p.hdr; vif.host_cb.rx_cpl_data<=p.data; vif.host_cb.rx_cpl_error<=0;
        vif.host_cb.rx_cpl_sop<=1; vif.host_cb.rx_cpl_eop<=1; vif.host_cb.rx_cpl_valid<=1;
      end
    end
  endtask

  task run_phase(uvm_phase phase);
    vif.host_cb.tx_rd_ready<=0; vif.host_cb.tx_wr_ready<=0;
    fork
      begin
        forever begin
          @(vif.host_cb);
          if(vif.host_cb.rst) begin
            vif.host_cb.tx_rd_ready<=0; vif.host_cb.tx_wr_ready<=0;
          end else begin
            vif.host_cb.tx_rd_ready<=($urandom_range(99)>=cfg.rd_ready_stall_pct);
            vif.host_cb.tx_wr_ready<=($urandom_range(99)>=cfg.wr_ready_stall_pct);
            if(vif.host_cb.tx_rd_valid&&!vif.tx_rd_ready) tx_rd_stall_cycles++;
            if(vif.host_cb.tx_wr_valid&&!vif.tx_wr_ready) tx_wr_stall_cycles++;
            if(vif.host_cb.tx_rd_valid&&vif.tx_rd_ready) enqueue_completions(vif.host_cb.tx_rd_hdr);
            if(vif.host_cb.tx_wr_valid&&vif.tx_wr_ready) capture_write_beat();
          end
        end
      end
      drive_completions();
    join
  endtask
endclass
