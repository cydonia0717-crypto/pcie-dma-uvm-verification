class dma_1m_chain_seq extends dma_base_seq;
  `uvm_object_utils(dma_1m_chain_seq)
  localparam int unsigned TOTAL_BYTES = 1024*1024;
  localparam int unsigned DESC_MAX    = 16'hffff;
  function new(string name="dma_1m_chain_seq"); super.new(name); endfunction

  task body();
    longint unsigned host_base = 64'h0000_000c_0000_0000;
    int unsigned offset=0;
    int unsigned idx=0;
    while(offset<TOTAL_BYTES) begin
      int unsigned len=((TOTAL_BYTES-offset)>DESC_MAX)?DESC_MAX:(TOTAL_BYTES-offset);
      send(DMA_H2C,host_base+offset,offset,len,8'h40+idx);
      offset+=len;
      idx++;
    end
  endtask
endclass
