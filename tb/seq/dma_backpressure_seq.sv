class dma_backpressure_seq extends dma_base_seq;
  `uvm_object_utils(dma_backpressure_seq)
  function new(string name="dma_backpressure_seq"); super.new(name); endfunction
  task body();
    send(DMA_H2C,64'h0000_0007_0000_0000,20'h70000,4096,8'hc0);
    send(DMA_C2H,64'h0000_0008_0000_0000,20'h80000,4096,8'hc1);
  endtask
endclass
