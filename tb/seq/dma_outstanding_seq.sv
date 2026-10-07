class dma_outstanding_seq extends dma_base_seq;
  `uvm_object_utils(dma_outstanding_seq)
  function new(string name="dma_outstanding_seq"); super.new(name); endfunction
  task body(); for(int i=0;i<16;i++) send(DMA_H2C,64'h0000_0002_0000_0000+i*'h1000,20'h10000+i*'h400,1024,8'h40+i); endtask
endclass
