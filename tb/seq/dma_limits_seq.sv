class dma_limits_seq extends dma_base_seq;
  `uvm_object_utils(dma_limits_seq)
  function new(string name="dma_limits_seq"); super.new(name); endfunction
  task body();
    send(DMA_H2C,64'h0000_0004_0000_0000,20'h40000,1536,8'ha0);
    send(DMA_C2H,64'h0000_0005_0000_0000,20'h50000,1536,8'ha1);
  endtask
endclass
