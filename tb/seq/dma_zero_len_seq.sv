class dma_zero_len_seq extends dma_base_seq;
  `uvm_object_utils(dma_zero_len_seq)
  function new(string name="dma_zero_len_seq"); super.new(name); endfunction

  task body();
    // Use non-DW-aligned addresses so the test also proves that a zero-byte
    // operation does not accidentally touch a neighboring enabled byte.
    send(DMA_H2C, 64'h0000_0004_0000_1001, 20'h50001, 0, 8'h90);
    send(DMA_C2H, 64'h0000_0004_0000_2003, 20'h60003, 0, 8'h91);
  endtask
endclass
