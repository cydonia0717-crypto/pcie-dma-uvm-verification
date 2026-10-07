class dma_ooo_seq extends dma_base_seq;
  `uvm_object_utils(dma_ooo_seq)
  function new(string name="dma_ooo_seq"); super.new(name); endfunction
  task body();
    for(int i=0;i<4;i++)
      send(DMA_H2C,64'h0000_0006_0000_0000+i*'h1000,20'h60000+i*'h400,512,8'hb0+i);
  endtask
endclass
