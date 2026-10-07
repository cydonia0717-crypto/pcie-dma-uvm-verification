class dma_small_unaligned_seq extends dma_base_seq;
  `uvm_object_utils(dma_small_unaligned_seq)
  function new(string name="dma_small_unaligned_seq"); super.new(name); endfunction
  task body();
    int lens[8]='{1,2,3,4,8,16,31,32};
    for(int i=0;i<8;i++)
      send(DMA_H2C,64'h0000_0003_0000_0000+i*'h100+(i%4),20'h20000+i*'h80+(i%4),lens[i],8'h80+i);
    for(int i=0;i<8;i++)
      send(DMA_C2H,64'h0000_0003_1000_0000+i*'h100+((i+1)%4),20'h30000+i*'h80+((i+1)%4),lens[i],8'h90+i);
  endtask
endclass
