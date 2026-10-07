class dma_max_len_seq extends dma_base_seq;
  `uvm_object_utils(dma_max_len_seq)
  function new(string name="dma_max_len_seq"); super.new(name); endfunction
  task body();
    send(DMA_H2C,64'h0000_b000_0000_0001,20'h00001,16'hffff,8'he0);
    send(DMA_C2H,64'h0000_c000_0000_0003,20'h20003,16'hffff,8'he1);
  endtask
endclass
