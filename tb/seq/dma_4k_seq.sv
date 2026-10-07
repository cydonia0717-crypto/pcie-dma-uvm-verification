class dma_4k_seq extends dma_base_seq;
  `uvm_object_utils(dma_4k_seq)
  function new(string name="dma_4k_seq"); super.new(name); endfunction
  task body(); send(DMA_H2C,64'h0000_0001_0000_1ff0,20'h08000,512,8'h31); send(DMA_C2H,64'h0000_0001_0000_2ff0,20'h0a000,512,8'h32); endtask
endclass
