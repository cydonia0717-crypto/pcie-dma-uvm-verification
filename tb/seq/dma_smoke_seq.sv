class dma_smoke_seq extends dma_base_seq;
  `uvm_object_utils(dma_smoke_seq)
  function new(string name="dma_smoke_seq"); super.new(name); endfunction
  task body(); send(DMA_H2C,64'h0000_0001_0000_1000,20'h01000,256,8'h11); send(DMA_C2H,64'h0000_0001_0000_4000,20'h04000,256,8'h22); endtask
endclass
