class dma_completion_error_seq extends dma_base_seq;
  `uvm_object_utils(dma_completion_error_seq)
  function new(string name="dma_completion_error_seq"); super.new(name); endfunction
  task body();
    send(DMA_H2C,64'h0000_000b_0000_1000,20'h0b000,128,8'he1);
  endtask
endclass
